#!/usr/bin/env bash
# Post-bootstrap live acceptance (requires oc auth + bootstrapped cluster).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT}/.generated/acceptance"
mkdir -p "${OUT}"
REPORT="${OUT}/postbootstrap-$(date +%Y%m%dT%H%M%S).txt"
FAIL=0
{
  echo "=== acceptance-postbootstrap ==="
  if ! oc whoami >/dev/null 2>&1; then
    echo "BLOCKED_OPENSHIFT_AUTHENTICATION"
    echo "ACTION  oc login --web"
    exit 2
  fi
  bash "${ROOT}/scripts/verify-demo-fork-live.sh" || FAIL=1
  bash "${ROOT}/scripts/verify-sandbox.sh" || FAIL=1
  bash "${ROOT}/scripts/verify-gitops.sh" || FAIL=1
  bash "${ROOT}/scripts/verify-prod.sh" || true
  if [[ "${FAIL}" -eq 0 ]]; then
    echo "acceptance-postbootstrap: OK"
  else
    echo "acceptance-postbootstrap: FAILED"
    exit 1
  fi
} 2>&1 | tee "${REPORT}"
