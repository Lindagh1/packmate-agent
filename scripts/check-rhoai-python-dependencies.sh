#!/usr/bin/env bash
# Check Packmate Python deps against the RHOAI 3.4 package mirror in a clean venv.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_INDEX="https://console.redhat.com/api/pypi/public-rhai/rhoai/3.4/cpu-ubi9/simple"
LIGHTWEIGHT="${PACKMATE_DEPS_LIGHTWEIGHT:-false}"
KEEP_VENV="${PACKMATE_DEPS_KEEP_VENV:-false}"
ALLOW_PUBLIC_PYPI="${PACKMATE_ALLOW_PUBLIC_PYPI:-false}"

redact() {
  sed -E \
    -e 's#(https?://[^/@[:space:]]*:)[^/@[:space:]]+@#\1***@#g' \
    -e 's/(token|password|passwd|secret|authorization)=[^[:space:]]+/\1=***/Ig'
}

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; exit 1; }

detect_index() {
  local idx=""
  if [[ -n "${RHOAI_PYPI_INDEX_URL:-}" ]]; then
    idx="${RHOAI_PYPI_INDEX_URL}"
  elif [[ -n "${PIP_INDEX_URL:-}" ]]; then
    idx="${PIP_INDEX_URL}"
  else
    # pip config may contain credentials — never print raw values.
    idx="$(python3 -m pip config get global.index-url 2>/dev/null || true)"
    if [[ -z "${idx}" ]]; then
      idx="$(python3 -m pip config get install.index-url 2>/dev/null || true)"
    fi
  fi
  if [[ -z "${idx}" ]]; then
    idx="${DEFAULT_INDEX}"
  fi
  # Refuse accidental public PyPI unless explicitly allowed.
  if [[ "${ALLOW_PUBLIC_PYPI}" != "true" ]]; then
    case "${idx}" in
      *pypi.org*|*pythonhosted.org*)
        die "Refusing public PyPI index (${idx%%\?*}). Set RHOAI_PYPI_INDEX_URL to the RHOAI mirror."
        ;;
    esac
  fi
  printf '%s' "${idx}"
}

index_host() {
  python3 -c 'from urllib.parse import urlparse; import sys; print(urlparse(sys.argv[1]).hostname or "")' "$1"
}

pick_python() {
  if [[ -n "${PACKMATE_PYTHON_BIN:-}" ]]; then
    command -v "${PACKMATE_PYTHON_BIN}" >/dev/null || die "PACKMATE_PYTHON_BIN not found: ${PACKMATE_PYTHON_BIN}"
    printf '%s' "${PACKMATE_PYTHON_BIN}"
    return 0
  fi
  if command -v python3.12 >/dev/null 2>&1; then
    printf '%s' "python3.12"
    return 0
  fi
  # Fall back only if already 3.12.
  local ver
  ver="$(python3 -c 'import sys; print("%d.%d"%sys.version_info[:2])' 2>/dev/null || true)"
  if [[ "${ver}" == "3.12" ]]; then
    printf '%s' "python3"
    return 0
  fi
  die "Need Python 3.12 for RHOAI cpu-ubi9 wheels (found ${ver:-unknown}). Install python3.12 or set PACKMATE_PYTHON_BIN."
}

INDEX_URL="$(detect_index)"
INDEX_HOST="$(index_host "${INDEX_URL}")"
[[ -n "${INDEX_HOST}" ]] || die "Unable to parse RHOAI index host"
PY_BIN="$(pick_python)"
PY_VER="$("${PY_BIN}" -c 'import sys; print("%d.%d.%d"%sys.version_info[:3])')"

log "=== RHOAI Python dependency check ==="
log "python=${PY_BIN} (${PY_VER})"
log "index_host=${INDEX_HOST}"
pass "RHOAI Python package mirror configured (${INDEX_HOST})"

# Reachability (no credentials printed)
CODE="$(curl -sk -o /dev/null -w '%{http_code}' -m 25 "${INDEX_URL%/}/mcp/" || echo 000)"
[[ "${CODE}" == "200" || "${CODE}" == "401" || "${CODE}" == "403" ]] \
  && pass "RHOAI Python package mirror reachable (HTTP ${CODE})" \
  || fail "RHOAI Python package mirror reachable (HTTP ${CODE})"

if [[ "${LIGHTWEIGHT}" == "true" ]]; then
  # Lightweight preflight: confirm critical packages exist on the simple index.
  for pkg in mcp json-repair pydantic fastapi httpx openai prometheus-client pytest; do
    c="$(curl -sk -o /dev/null -w '%{http_code}' -m 20 "${INDEX_URL%/}/${pkg}/" || echo 000)"
    [[ "${c}" == "200" ]] && pass "Mirror has ${pkg}" || fail "Mirror missing ${pkg} (HTTP ${c})"
  done
  exit 0
fi

VENV_DIR="$(mktemp -d /tmp/packmate-rhoai-deps.XXXXXX)"
cleanup() {
  if [[ "${KEEP_VENV}" == "true" ]]; then
    log "Kept venv at ${VENV_DIR}"
  else
    rm -rf "${VENV_DIR}"
  fi
}
trap cleanup EXIT

"${PY_BIN}" -m venv "${VENV_DIR}"
# Ensure include-system-site-packages=false
if grep -qi '^include-system-site-packages[[:space:]]*=[[:space:]]*true' "${VENV_DIR}/pyvenv.cfg" 2>/dev/null; then
  fail "Workbench virtual environment leaks system site-packages"
fi
pass "Clean venv isolates site-packages (include-system-site-packages=false)"

[[ -x "${VENV_DIR}/bin/python" ]] || die "venv python missing"

export PIP_INDEX_URL="${INDEX_URL}"
export PIP_TRUSTED_HOST="${INDEX_HOST}"
unset PIP_EXTRA_INDEX_URL || true

PIP=( "${VENV_DIR}/bin/python" -m pip )
"${PIP[@]}" install -q -U pip --index-url "${INDEX_URL}" --trusted-host "${INDEX_HOST}" --no-cache-dir

REQ_FILES=(
  "${ROOT}/backend/requirements-dev.txt"
  "${ROOT}/mcp-servers/weather/requirements.txt"
  "${ROOT}/mcp-servers/baggage-policy/requirements.txt"
)

for req in "${REQ_FILES[@]}"; do
  [[ -f "${req}" ]] || die "Missing requirements file: ${req}"
  log "Installing ${req#"${ROOT}"/} from RHOAI mirror..."
  if ! "${PIP[@]}" install --no-cache-dir --index-url "${INDEX_URL}" --trusted-host "${INDEX_HOST}" \
      -r "${req}" 2> >(redact >&2); then
    fail "Dependency installation failed for ${req#"${ROOT}"/}"
  fi
done
pass "All direct Python dependencies resolvable"
pass "Backend dependency installation works in isolation"

if ! "${PIP[@]}" check 2> >(redact >&2); then
  fail "pip check failed"
fi
pass "pip check passed"

log "Installed critical versions:"
"${PIP[@]}" freeze | grep -Ei '^(mcp|json-repair|fastapi|uvicorn|pydantic|pydantic-core|httpx|openai|prometheus-client|opentelemetry-api|opentelemetry-sdk|pytest|pytest-asyncio)==' \
  | redact || true

MCP_VER="$("${VENV_DIR}/bin/python" -c 'from importlib.metadata import version; print(version("mcp"))')"
[[ "${MCP_VER}" == "1.27.2" ]] && pass "MCP SDK version is 1.27.2" || fail "MCP SDK version is 1.27.2 (got ${MCP_VER})"

"${VENV_DIR}/bin/python" - <<'PY' || fail "MCP streamable_http_client import supported"
from mcp.client.streamable_http import streamable_http_client
assert callable(streamable_http_client)
print("symbol_ok")
PY
pass "MCP streamable_http_client import supported"

JR_VER="$("${VENV_DIR}/bin/python" -c 'from importlib.metadata import version; print(version("json-repair"))')"
[[ "${JR_VER}" == "0.25.3" ]] && pass "json-repair version is 0.25.3" || fail "json-repair version is 0.25.3 (got ${JR_VER})"

"${VENV_DIR}/bin/python" - <<'PY' || fail "json-repair compatibility tests passed"
from json_repair import loads as repair_loads
assert repair_loads('{"a": 1}') == {"a": 1}
assert repair_loads('{"overview": "Mild "sunny" day."}')["overview"] == 'Mild "sunny" day.'
print("json_repair_ok")
PY
pass "json-repair compatibility tests passed"

# Critical imports used by Packmate backend
"${VENV_DIR}/bin/python" - <<'PY' || fail "Critical imports"
import fastapi, pydantic, httpx, openai, pytest
from mcp.client.streamable_http import streamable_http_client
import json_repair
print("imports_ok")
PY
pass "Critical runtime imports succeeded"

# Focused compatibility tests (backend only; needs app on PYTHONPATH)
export PYTHONPATH="${ROOT}/backend${PYTHONPATH:+:${PYTHONPATH}}"
if ! (
  cd "${ROOT}/backend"
  "${VENV_DIR}/bin/python" -m pytest -q \
    tests/test_rhoai_compatibility.py \
    tests/test_mcp_adapters.py \
    -k "mcp or json_repair or rhoai or streamable" \
    --maxfail=1
) 2> >(redact >&2); then
  fail "Focused compatibility tests"
fi
pass "Focused compatibility tests passed"

log "=== RHOAI dependency check complete ==="
