#!/usr/bin/env bash
# Check Packmate Python deps against the RHOAI 3.4 package mirror.
# Source of truth: clean in-cluster install using the Tekton Python image.
# Local throwaway venv TLS/CA errors are WARN-only when in-cluster validation succeeds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh" 2>/dev/null || true

DEFAULT_INDEX="https://console.redhat.com/api/pypi/public-rhai/rhoai/3.4/cpu-ubi9/simple"
LIGHTWEIGHT="${PACKMATE_DEPS_LIGHTWEIGHT:-false}"
ALLOW_PUBLIC_PYPI="${PACKMATE_ALLOW_PUBLIC_PYPI:-false}"
FORCE_LOCAL="${PACKMATE_DEPS_FORCE_LOCAL:-false}"
NS="${PACKMATE_NAMESPACE:-packmate-lab}"

redact() {
  sed -E \
    -e 's#(https?://[^/@[:space:]]*:)[^/@[:space:]]+@#\1***@#g' \
    -e 's/(token|password|passwd|secret|authorization)=[^[:space:]]+/\1=***/Ig'
}

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS  %s\n' "$*"; }
warn() { printf 'WARN  %s\n' "$*" >&2; }
fail() { printf 'FAIL  %s\n' "$*"; exit 1; }

detect_index() {
  local idx=""
  if [[ -n "${RHOAI_PYPI_INDEX_URL:-}" ]]; then
    idx="${RHOAI_PYPI_INDEX_URL}"
  elif [[ -n "${PIP_INDEX_URL:-}" ]]; then
    idx="${PIP_INDEX_URL}"
  else
    idx="$(python3 -m pip config get global.index-url 2>/dev/null || true)"
    if [[ -z "${idx}" ]]; then
      idx="$(python3 -m pip config get install.index-url 2>/dev/null || true)"
    fi
  fi
  [[ -n "${idx}" ]] || idx="${DEFAULT_INDEX}"
  if [[ "${ALLOW_PUBLIC_PYPI}" != "true" ]]; then
    case "${idx}" in
      *pypi.org*|*pythonhosted.org*)
        die "Refusing public PyPI index (${idx%%\?*}). Set RHOAI_PYPI_INDEX_URL to the RHOAI mirror."
        ;;
    esac
  fi
  printf '%s' "${idx}"
}

INDEX_URL="$(detect_index)"
INDEX_HOST="$(python3 -c 'from urllib.parse import urlparse; import sys; print(urlparse(sys.argv[1]).hostname or "")' "${INDEX_URL}")"
[[ -n "${INDEX_HOST}" ]] || die "Unable to parse RHOAI index host"

log "=== RHOAI Python dependency check ==="
log "index_host=${INDEX_HOST}"
pass "RHOAI Python package mirror configured (${INDEX_HOST})"

CODE="$(curl -sk -o /dev/null -w '%{http_code}' -m 25 "${INDEX_URL%/}/mcp/" || echo 000)"
[[ "${CODE}" == "200" || "${CODE}" == "401" || "${CODE}" == "403" ]] \
  && pass "RHOAI Python package mirror reachable (HTTP ${CODE})" \
  || fail "RHOAI Python package mirror reachable (HTTP ${CODE})"

if [[ "${LIGHTWEIGHT}" == "true" ]]; then
  for pkg in mcp json-repair pydantic fastapi httpx openai prometheus-client pytest; do
    c="$(curl -sk -o /dev/null -w '%{http_code}' -m 20 "${INDEX_URL%/}/${pkg}/" || echo 000)"
    [[ "${c}" == "200" ]] && pass "Mirror has ${pkg}" || fail "Mirror missing ${pkg} (HTTP ${c})"
  done
  # Pin presence (best-effort HTML probe)
  body="$(curl -sk -m 25 "${INDEX_URL%/}/mcp/" || true)"
  printf '%s' "${body}" | grep -q '1.27.2' && pass "Mirror lists mcp 1.27.2" || fail "Mirror lists mcp 1.27.2"
  body="$(curl -sk -m 25 "${INDEX_URL%/}/json-repair/" || true)"
  printf '%s' "${body}" | grep -q '0.25.3' && pass "Mirror lists json-repair 0.25.3" || fail "Mirror lists json-repair 0.25.3"
  exit 0
fi

run_in_cluster() {
  command -v oc >/dev/null 2>&1 || return 1
  oc whoami >/dev/null 2>&1 || return 1
  oc get project "${NS}" >/dev/null 2>&1 || return 1

  local img
  img="$(
    PACKMATE_SKIP_PYTHON_IMAGE_PULL_PROBE=true \
    PACKMATE_NAMESPACE="${NS}" \
      bash "${ROOT}/scripts/resolve-pipeline-python-image.sh" 2>/dev/null | tail -n1
  )"
  [[ -n "${img}" ]] || return 1

  local pod="packmate-deps-check-$$"
  oc -n "${NS}" delete pod "${pod}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  oc -n "${NS}" run "${pod}" --image="${img}" --restart=Never --quiet \
    --overrides="$(cat <<EOF
{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"deps","image":"${img}","command":["sleep","900"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsNonRoot":true}}]}}
EOF
)" --command -- sleep 900 >/dev/null

  oc -n "${NS}" wait --for=condition=Ready "pod/${pod}" --timeout=180s >/dev/null

  cleanup_pod() {
    oc -n "${NS}" delete pod "${pod}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  }
  trap cleanup_pod RETURN

  # Copy requirement files into the pod
  oc -n "${NS}" exec "${pod}" -- mkdir -p /tmp/packmate/backend /tmp/packmate/mcp-weather /tmp/packmate/mcp-baggage /tmp/packmate/tests
  oc -n "${NS}" cp "${ROOT}/backend/requirements.txt" "${pod}:/tmp/packmate/backend/requirements.txt"
  oc -n "${NS}" cp "${ROOT}/backend/requirements-dev.txt" "${pod}:/tmp/packmate/backend/requirements-dev.txt"
  oc -n "${NS}" cp "${ROOT}/mcp-servers/weather/requirements.txt" "${pod}:/tmp/packmate/mcp-weather/requirements.txt"
  oc -n "${NS}" cp "${ROOT}/mcp-servers/baggage-policy/requirements.txt" "${pod}:/tmp/packmate/mcp-baggage/requirements.txt"

  # Bounded timeout: quiet pip can appear hung on slow mirrors; always delete the pod.
  local exec_rc=0
  set +e
  timeout --signal=TERM --kill-after=30s 480 \
    oc -n "${NS}" exec "${pod}" -- bash -lc "
set -euo pipefail
export PIP_INDEX_URL='${INDEX_URL}'
unset PIP_EXTRA_INDEX_URL || true
python -m venv /tmp/v
grep -qi '^include-system-site-packages[[:space:]]*=[[:space:]]*true' /tmp/v/pyvenv.cfg && exit 40
source /tmp/v/bin/activate
python -m pip install -U pip --index-url \"\${PIP_INDEX_URL}\"
python -m pip install --index-url \"\${PIP_INDEX_URL}\" -r /tmp/packmate/backend/requirements-dev.txt
python -m pip install --index-url \"\${PIP_INDEX_URL}\" -r /tmp/packmate/mcp-weather/requirements.txt
python -m pip install --index-url \"\${PIP_INDEX_URL}\" -r /tmp/packmate/mcp-baggage/requirements.txt
python -m pip check
python - <<'PY'
from importlib.metadata import version
from mcp.client.streamable_http import streamable_http_client
from json_repair import loads as repair_loads
import fastapi, pydantic, httpx, openai, pytest
assert version('mcp') == '1.27.2'
assert version('json-repair') == '0.25.3'
assert callable(streamable_http_client)
assert repair_loads('{\"a\": 1}') == {'a': 1}
print('IN_CLUSTER_OK')
PY
" 2> >(redact >&2)
  exec_rc=$?
  set -e

  cleanup_pod
  trap - RETURN
  return "${exec_rc}"
}

IN_CLUSTER_OK=false
if [[ "${FORCE_LOCAL}" != "true" ]] && run_in_cluster; then
  IN_CLUSTER_OK=true
  pass "All direct Python dependencies resolvable"
  pass "Backend dependency installation works in isolation"
  pass "pip check passed"
  pass "MCP SDK version is 1.27.2"
  pass "MCP streamable_http_client import supported"
  pass "json-repair version is 0.25.3"
  pass "json-repair compatibility tests passed"
  pass "Critical runtime imports succeeded"
  pass "RHOAI dependency compatibility passed (in-cluster)"
else
  if [[ "${FORCE_LOCAL}" != "true" ]]; then
    warn "In-cluster dependency check unavailable or failed — attempting local Python 3.12 venv"
  fi
  # Local fallback (not source of truth)
  PY_BIN=""
  if command -v python3.12 >/dev/null 2>&1; then PY_BIN=python3.12; fi
  if [[ -z "${PY_BIN}" ]]; then
    fail "In-cluster check failed and python3.12 is unavailable locally"
  fi
  VENV_DIR="$(mktemp -d /tmp/packmate-rhoai-deps.XXXXXX)"
  cleanup() { rm -rf "${VENV_DIR}"; }
  trap cleanup EXIT
  if ! (
    set -euo pipefail
    "${PY_BIN}" -m venv "${VENV_DIR}"
    grep -qi '^include-system-site-packages[[:space:]]*=[[:space:]]*true' "${VENV_DIR}/pyvenv.cfg" && exit 40
    export PIP_INDEX_URL="${INDEX_URL}"
    unset PIP_EXTRA_INDEX_URL || true
    "${VENV_DIR}/bin/python" -m pip install -q -U pip --index-url "${INDEX_URL}"
    "${VENV_DIR}/bin/python" -m pip install -q --index-url "${INDEX_URL}" -r "${ROOT}/backend/requirements-dev.txt"
    "${VENV_DIR}/bin/python" -m pip check
    "${VENV_DIR}/bin/python" - <<'PY'
from importlib.metadata import version
from mcp.client.streamable_http import streamable_http_client
from json_repair import loads as repair_loads
assert version("mcp") == "1.27.2"
assert version("json-repair") == "0.25.3"
assert callable(streamable_http_client)
assert repair_loads('{"a": 1}') == {"a": 1}
print("LOCAL_OK")
PY
  ) 2> >(redact >&2); then
    warn "Local throwaway venv failed (often TLS/CA). In-cluster validation is the source of truth."
    fail "RHOAI dependency compatibility failed (local and in-cluster)"
  fi
  if [[ "${IN_CLUSTER_OK}" != "true" ]]; then
    warn "Local venv succeeded but in-cluster check did not run — prefer make bootstrap on the cluster"
  fi
  pass "Local dependency compatibility checks passed"
fi

log "=== RHOAI dependency check complete ==="
