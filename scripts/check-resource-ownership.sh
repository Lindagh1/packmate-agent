#!/usr/bin/env bash
# Fail if bootstrap scripts still directly apply Git-tracked DEV/PROD runtime resources.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*" >&2; FAILS=$((FAILS + 1)); }
FAILS=0

log() { printf '%s\n' "$*"; }

render_names() {
  local overlay="$1"
  python3 - <<PY
import subprocess, yaml
out = subprocess.check_output(["oc", "kustomize", "deploy/overlays/${overlay}"], text=True)
for d in yaml.safe_load_all(out):
  if not d:
    continue
  kind = d.get("kind")
  name = (d.get("metadata") or {}).get("name")
  if kind and name:
    print(f"{kind}/{name}")
PY
}

log "=== Packmate resource ownership check ==="

DEV_RES="$(render_names dev)"
PROD_RES="$(render_names prod)"

log "DEV overlay resources:"
printf '%s\n' "${DEV_RES}" | sed 's/^/  - /'
log "PROD overlay resources:"
printf '%s\n' "${PROD_RES}" | sed 's/^/  - /'

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
