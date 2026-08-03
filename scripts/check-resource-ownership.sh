#!/usr/bin/env bash
# Fail if bootstrap scripts still directly apply Git-tracked DEV/PROD runtime resources.
# Renders both overlays first; never emits an unhandled Python traceback on Kustomize failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*" >&2; FAILS=$((FAILS + 1)); }
FAILS=0

log() { printf '%s\n' "$*"; }

# Render overlay to a temp file. Prints PASS/FAIL. Sets RENDER_OUT path on success.
RENDER_OUT=""
render_overlay() {
  local overlay="$1"
  local out err label
  out="$(mktemp)"
  err="$(mktemp)"
  label="$(printf '%s' "${overlay}" | tr '[:lower:]' '[:upper:]')"
  if ! oc kustomize "deploy/overlays/${overlay}" >"${out}" 2>"${err}"; then
    fail "Unable to render deploy/overlays/${overlay}"
    printf 'DETAIL %s\n' "$(tr '\n' ' ' <"${err}" | sed 's/[[:space:]]\+/ /g' | cut -c1-400)" >&2
    printf 'ACTION Fix the overlay before running bootstrap\n' >&2
    rm -f "${out}" "${err}"
    RENDER_OUT=""
    return 1
  fi
  pass "${label} overlay renders successfully"
  rm -f "${err}"
  RENDER_OUT="${out}"
  return 0
}

inventory() {
  local path="$1"
  python3 - "${path}" <<'PY'
import sys, yaml
for d in yaml.safe_load_all(open(sys.argv[1])):
  if not d:
    continue
  kind = d.get("kind")
  name = (d.get("metadata") or {}).get("name")
  if kind and name:
    print(f"{kind}/{name}")
PY
}

log "=== Packmate resource ownership check ==="

DEV_OK=0
PROD_OK=0
DEV_FILE=""
PROD_FILE=""

log "DEV overlay resources:"
if render_overlay dev; then
  DEV_OK=1
  DEV_FILE="${RENDER_OUT}"
  inventory "${DEV_FILE}" | sed 's/^/  - /'
else
  :
fi

log "PROD overlay resources:"
if render_overlay prod; then
  PROD_OK=1
  PROD_FILE="${RENDER_OUT}"
  inventory "${PROD_FILE}" | sed 's/^/  - /'
else
  :
fi

cleanup_tmp() {
  [[ -n "${DEV_FILE}" ]] && rm -f "${DEV_FILE}" || true
  [[ -n "${PROD_FILE}" ]] && rm -f "${PROD_FILE}" || true
}
trap cleanup_tmp EXIT

if [[ "${DEV_OK}" -ne 1 || "${PROD_OK}" -ne 1 ]]; then
  log "verify-resource-ownership: overlay render failed — skipping dual-ownership analysis"
  exit 1
fi

# Forbidden active bootstrap patterns
if grep -nE '^\s*apply_named_deploys|^\s*oc apply -k .*deploy/overlays/dev|^\s*oc kustomize .*/deploy/overlays/dev|\$\{TMP\}/nondeploy\.yaml|oc set image deploy/' \
  scripts/bootstrap-sandbox.sh >/dev/null 2>&1; then
  fail "bootstrap-sandbox.sh still directly mutates DEV runtime workloads"
else
  pass "No dual ownership for DEV runtime resources"
  pass "Bootstrap does not directly apply DEV overlay"
fi

if grep -nE 'oc apply -k .*deploy/overlays/prod|oc apply -f .*deploy/overlays/prod' \
  scripts/prepare-prod.sh scripts/bootstrap-sandbox.sh 2>/dev/null \
  | grep -vE '^\s*#|Does NOT|never oc apply|no direct' >/dev/null 2>&1; then
  fail "PROD overlay still applied directly"
else
  pass "No dual ownership for PROD runtime resources"
fi

grep -q 'path: deploy/overlays/dev' argocd/application-packmate-lab.yaml \
  && pass "Argo CD owns Git-tracked runtime manifests" \
  || fail "packmate-lab Application missing DEV path"
grep -q 'path: deploy/overlays/prod' argocd/application-packmate-prod.yaml \
  || fail "packmate-prod Application missing PROD path"

pass "Bootstrap owns only prerequisites and external Secrets"

if [[ "${FAILS}" -gt 0 ]]; then
  log "verify-resource-ownership: ${FAILS} check(s) failed"
  exit 1
fi
log "verify-resource-ownership: OK"
exit 0
