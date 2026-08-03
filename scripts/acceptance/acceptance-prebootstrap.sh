#!/usr/bin/env bash
# Pre-bootstrap acceptance: local fork checks + auth discovery (non-destructive).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT}/.generated/acceptance"
mkdir -p "${OUT}"
REPORT="${OUT}/prebootstrap-$(date +%Y%m%dT%H%M%S).txt"
{
  echo "=== acceptance-prebootstrap ==="
  bash "${ROOT}/scripts/verify-demo-fork.sh" || true
  if command -v oc >/dev/null 2>&1; then
    if oc whoami >/dev/null 2>&1; then
      echo "PASS    oc authenticated as $(oc whoami 2>/dev/null)"
      bash "${ROOT}/scripts/discover-packmate-resources.sh" || true
    else
      echo "BLOCKED_OPENSHIFT_AUTHENTICATION"
      echo "ACTION  oc login --web"
    fi
  else
    echo "INFO    oc not installed — skip cluster discovery"
  fi
  bash "${ROOT}/scripts/verify-github-write-readiness.sh" || true
  echo "acceptance-prebootstrap: complete (see FAIL/BLOCKED lines above)"
} 2>&1 | tee "${REPORT}"
