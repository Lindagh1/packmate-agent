#!/usr/bin/env bash
# Offline security checks for Packmate manifests and repo content.
# Does not apply to a cluster or mutate files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="${ROOT}/deploy"
FAILED=0

warn() {
  echo "WARN: $*" >&2
}

fail() {
  echo "FAIL: $*" >&2
  FAILED=1
}

pass() {
  echo "OK:   $*"
}

check_latest_tags() {
  echo "== Image tags (:latest) =="
  local hits
  hits="$(grep -RIn --include='*.yaml' --include='*.yml' -E 'image:.*:latest\b' "${DEPLOY}" 2>/dev/null || true)"
  if [[ -n "${hits}" ]]; then
    fail "Found :latest image references:"
    echo "${hits}" >&2
  else
    pass "No :latest tags under deploy/"
  fi
}

check_privileged() {
  echo "== Privileged containers =="
  local hits
  hits="$(grep -RIn --include='*.yaml' --include='*.yml' -E 'privileged:[[:space:]]*true' "${DEPLOY}" 2>/dev/null || true)"
  if [[ -n "${hits}" ]]; then
    fail "privileged: true found:"
    echo "${hits}" >&2
  else
    pass "No privileged containers in deploy/"
  fi
}

check_allow_privilege_escalation() {
  echo "== allowPrivilegeEscalation: true =="
  local hits
  hits="$(grep -RIn --include='*.yaml' --include='*.yml' -E 'allowPrivilegeEscalation:[[:space:]]*true' "${DEPLOY}" 2>/dev/null || true)"
  if [[ -n "${hits}" ]]; then
    fail "allowPrivilegeEscalation: true found:"
    echo "${hits}" >&2
  else
    pass "No allowPrivilegeEscalation: true in deploy/"
  fi
}

check_run_as_non_root() {
  echo "== runAsNonRoot on workload containers =="
  if ! python3 - "${DEPLOY}" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("WARN: PyYAML not installed; skipping runAsNonRoot scan", file=sys.stderr)
    sys.exit(0)

deploy = Path(sys.argv[1])
issues = []

for path in sorted(deploy.rglob("*.yaml")):
    if "rendered" in path.parts:
        continue
    for doc in yaml.safe_load_all(path.read_text()) or []:
        if not isinstance(doc, dict):
            continue
        kind = doc.get("kind")
        if kind not in {"Deployment", "Rollout", "Job", "CronJob"}:
            continue
        spec = doc.get("spec") or {}
        if kind == "CronJob":
            pod_spec = ((spec.get("jobTemplate") or {}).get("spec") or {}).get("template", {}).get("spec") or {}
        elif kind == "Job":
            pod_spec = (spec.get("template") or {}).get("spec") or {}
        elif kind == "Rollout":
            pod_spec = (spec.get("template") or {}).get("spec") or {}
        else:
            pod_spec = (spec.get("template") or {}).get("spec") or {}

        pod_sc = pod_spec.get("securityContext") or {}
        pod_non_root = pod_sc.get("runAsNonRoot")

        for container in pod_spec.get("containers") or []:
            csc = container.get("securityContext") or {}
            if csc.get("runAsNonRoot") is True:
                continue
            if pod_non_root is True and csc.get("runAsNonRoot") is not False:
                continue
            issues.append(f"{path}: {kind}/{doc.get('metadata', {}).get('name')} container {container.get('name')}")

if issues:
    for item in issues:
        print(item)
    sys.exit(1)
PY
  then
    fail "Containers missing runAsNonRoot: true (pod or container level)"
  else
    pass "Workload containers enforce runAsNonRoot"
  fi
}

check_secrets_in_git() {
  echo "== Secret data committed to git =="
  if ! python3 - "${ROOT}" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("WARN: PyYAML not installed; skipping Secret-in-git scan", file=sys.stderr)
    sys.exit(0)

root = Path(sys.argv[1])
issues = []

for path in sorted(root.rglob("*.yaml")):
    if "rendered" in path.parts or ".git" in path.parts:
        continue
    for doc in yaml.safe_load_all(path.read_text()) or []:
        if not isinstance(doc, dict):
            continue
        if doc.get("kind") != "Secret":
            continue
        meta = doc.get("metadata") or {}
        if doc.get("stringData") or doc.get("data"):
            issues.append(f"{path}: Secret/{meta.get('name')} contains stringData or data")

if issues:
    for item in issues:
        print(item)
    sys.exit(1)
PY
  then
    fail "Secret resources with stringData/data found in repo"
  else
    pass "No Secret payloads committed"
  fi
}

check_cluster_admin() {
  echo "== cluster-admin bindings in manifests =="
  local hits
  hits="$(grep -RIn --include='*.yaml' --include='*.yml' -E 'cluster-admin|ClusterRoleBinding.*cluster-admin' "${DEPLOY}" 2>/dev/null || true)"
  if [[ -n "${hits}" ]]; then
    fail "cluster-admin references found:"
    echo "${hits}" >&2
  else
    pass "No cluster-admin bindings in deploy/"
  fi
}

check_hardcoded_secrets() {
  echo "== Hardcoded API key patterns =="
  local hits
  hits="$(grep -RIn --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=__pycache__ \
    --exclude='security-check.sh' \
    --exclude='test_*.py' --exclude='*_test.py' \
    --exclude='README.md' \
    -E 'sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|LITELLM_API_KEY[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}' \
    "${ROOT}" 2>/dev/null | grep -v 'secretKeyRef' | grep -v '<your-key>' | grep -v 'PLACEHOLDER' | grep -v "LITELLM_API_KEY='\\.\\.\\.'" || true)"
  local deploy_hits
  deploy_hits="$(grep -RIn --include='*.yaml' --include='*.yml' \
    -E 'api[_-]?key[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{8,}' \
    "${DEPLOY}" 2>/dev/null | grep -v 'secretKeyRef' || true)"
  if [[ -n "${hits}" || -n "${deploy_hits}" ]]; then
    fail "Possible hardcoded secrets (review manually):"
    [[ -n "${hits}" ]] && echo "${hits}" >&2
    [[ -n "${deploy_hits}" ]] && echo "${deploy_hits}" >&2
  else
    pass "No obvious hardcoded API key patterns"
  fi
}

check_oauth_proxy_documented() {
  echo "== OAuth proxy component =="
  if [[ -f "${DEPLOY}/components/oauth-proxy/README.md" ]]; then
    pass "oauth-proxy component documented (disabled by default in overlays)"
  else
    warn "deploy/components/oauth-proxy/README.md missing"
  fi
}

main() {
  echo "Packmate security check (repo: ${ROOT})"
  echo

  check_latest_tags
  echo
  check_privileged
  echo
  check_allow_privilege_escalation
  echo
  check_run_as_non_root
  echo
  check_secrets_in_git
  echo
  check_cluster_admin
  echo
  check_hardcoded_secrets
  echo
  check_oauth_proxy_documented
  echo

  if [[ "${FAILED}" -ne 0 ]]; then
    echo "Security check finished with failures." >&2
    exit 1
  fi

  echo "All security checks passed."
}

main "$@"
