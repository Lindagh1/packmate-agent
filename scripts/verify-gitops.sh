#!/usr/bin/env bash
# Verify Argo CD AppProject / Application / participant RBAC for Packmate PROD.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh"

packmate_require_oc
if [[ -f "${ROOT}/config/sandbox.env" ]]; then
  packmate_load_config "${ROOT}" || true
fi

ARGO_NS="${ARGOCD_NAMESPACE:-openshift-gitops}"
GROUP="${PACKMATE_ARGO_GROUP:-packmate-lab-users}"
FAILS=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; FAILS=$((FAILS + 1)); }
info() { printf 'INFO  %s\n' "$*"; }

printf '=== Packmate verify-gitops ===\n'

oc get crd applications.argoproj.io >/dev/null 2>&1 \
  && pass "Argo CD Application CRD present" \
  || fail "Argo CD Application CRD missing"

oc -n "${ARGO_NS}" get appproject.argoproj.io packmate >/dev/null 2>&1 \
  && pass "AppProject/packmate present" \
  || fail "AppProject/packmate missing"

dest="$(oc -n "${ARGO_NS}" get appproject.argoproj.io packmate -o jsonpath='{.spec.destinations[*].namespace}' 2>/dev/null || true)"
[[ "${dest}" == *"packmate-prod"* ]] && pass "AppProject destination includes packmate-prod" || fail "AppProject destination"
[[ "${dest}" == *"*"* ]] && fail "AppProject must not use wildcard destinations" || pass "AppProject has no wildcard destinations"

oc -n "${ARGO_NS}" get application.argoproj.io packmate-prod >/dev/null 2>&1 \
  && pass "Application/packmate-prod present" \
  || fail "Application/packmate-prod missing"

sync="$(oc -n "${ARGO_NS}" get application.argoproj.io packmate-prod -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
health="$(oc -n "${ARGO_NS}" get application.argoproj.io packmate-prod -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
info "Application sync=${sync:-unknown} health=${health:-unknown}"

auto="$(oc -n "${ARGO_NS}" get application.argoproj.io packmate-prod -o jsonpath='{.spec.syncPolicy.automated}' 2>/dev/null || true)"
[[ -z "${auto}" ]] && pass "Application sync is manual (no automated)" || fail "Application must not use automated sync"

# Participant group
if oc get group "${GROUP}" >/dev/null 2>&1; then
  pass "OpenShift group ${GROUP} exists"
else
  fail "OpenShift group ${GROUP} missing"
fi

# Policies: promoter has get+sync only (presence check)
policies="$(oc -n "${ARGO_NS}" get appproject.argoproj.io packmate -o jsonpath='{.spec.roles}' 2>/dev/null || true)"
printf '%s' "${policies}" | grep -q promoter && pass "AppProject role promoter present" || fail "AppProject role promoter missing"
if printf '%s' "${policies}" | grep -qE 'sync'; then
  pass "promoter sync policy present"
else
  fail "promoter sync policy missing"
fi
if printf '%s' "${policies}" | grep -qiE 'applications, delete|, delete,'; then
  fail "promoter must not have delete"
else
  pass "promoter has no delete permission in policies text"
fi

printf '\n'
if [[ "${FAILS}" -gt 0 ]]; then
  printf 'verify-gitops: %s check(s) failed\n' "${FAILS}"
  exit 1
fi
printf 'verify-gitops: OK\n'
exit 0
