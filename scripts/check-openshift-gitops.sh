#!/usr/bin/env bash
# Verify Red Hat OpenShift GitOps is installed and the default Argo CD instance is ready.
# Never prints admin passwords. Does not create resources.
set -euo pipefail

PASS_N=0
BLOCKED=""

pass() { printf 'PASS  %s\n' "$*"; PASS_N=$((PASS_N + 1)); }
fail_blocked() {
  BLOCKED="$1"
  printf 'FAIL  %s\n' "$2" >&2
  printf '%s\n' "${BLOCKED}"
  exit 2
}
warn() { printf 'WARN  %s\n' "$*" >&2; }

command -v oc >/dev/null 2>&1 || fail_blocked "BLOCKED_GITOPS_OPERATOR_NOT_INSTALLED" "oc CLI not found"
oc whoami >/dev/null 2>&1 || fail_blocked "BLOCKED_GITOPS_OPERATOR_NOT_INSTALLED" "not logged in to OpenShift"

PKG="openshift-gitops-operator"
CATALOG="redhat-operators"

# Official package in OperatorHub
if oc get packagemanifest "${PKG}" -n openshift-marketplace >/dev/null 2>&1; then
  SRC="$(oc get packagemanifest "${PKG}" -n openshift-marketplace -o jsonpath='{.status.catalogSource}' 2>/dev/null || true)"
  if [[ "${SRC}" != "${CATALOG}" && -n "${SRC}" ]]; then
    warn "PackageManifest catalogSource=${SRC} (expected ${CATALOG})"
  fi
else
  fail_blocked "BLOCKED_GITOPS_OPERATOR_NOT_INSTALLED" "PackageManifest ${PKG} not found in OperatorHub"
fi

# Reject Community Argo CD Operator
if oc get subscription -A -o json 2>/dev/null | grep -qiE '"argocd-operator"|community-operators.*argo'; then
  if oc get subscription -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.spec.name}{"\n"}{end}' 2>/dev/null \
    | grep -qiE 'argocd-operator|argo-cd'; then
    # Allow openshift-gitops-operator only
    if oc get subscription -A -o jsonpath='{range .items[*]}{.spec.name}{"\n"}{end}' 2>/dev/null \
      | grep -qiE '^argocd-operator$|^argo-cd$'; then
      fail_blocked "BLOCKED_GITOPS_OPERATOR_NOT_INSTALLED" "Conflicting Community Argo CD Operator detected — use Red Hat OpenShift GitOps only"
    fi
  fi
fi

SUB_NS=""
SUB_NAME=""
while IFS= read -r line; do
  ns="${line%%/*}"
  rest="${line#*/}"
  name="${rest%%=*}"
  pkg="${rest#*=}"
  if [[ "${pkg}" == "${PKG}" ]]; then
    SUB_NS="${ns}"
    SUB_NAME="${name}"
    break
  fi
done < <(oc get subscription -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.spec.name}{"\n"}{end}' 2>/dev/null || true)

if [[ -z "${SUB_NAME}" ]]; then
  fail_blocked "BLOCKED_GITOPS_OPERATOR_NOT_INSTALLED" "Subscription for ${PKG} not found"
fi

pass "Red Hat OpenShift GitOps Operator installed"

CSV="$(oc -n "${SUB_NS}" get subscription "${SUB_NAME}" -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)"
if [[ -z "${CSV}" ]]; then
  fail_blocked "BLOCKED_GITOPS_INSTALLATION_PENDING" "Subscription ${SUB_NS}/${SUB_NAME} has no installedCSV yet"
fi
PHASE="$(oc -n "${SUB_NS}" get csv "${CSV}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
case "${PHASE}" in
  Succeeded) pass "GitOps CSV succeeded" ;;
  Failed|*)
    if [[ "${PHASE}" == "Failed" ]]; then
      fail_blocked "BLOCKED_GITOPS_CSV_FAILED" "CSV ${CSV} phase=${PHASE}"
    fi
    fail_blocked "BLOCKED_GITOPS_INSTALLATION_PENDING" "CSV ${CSV} phase=${PHASE:-unknown}"
    ;;
esac

for crd in applications.argoproj.io appprojects.argoproj.io argocds.argoproj.io; do
  oc get crd "${crd}" >/dev/null 2>&1 || fail_blocked "BLOCKED_GITOPS_INSTALLATION_PENDING" "CRD ${crd} missing"
done
pass "Argo CD CRDs available"

oc get project openshift-gitops >/dev/null 2>&1 \
  || fail_blocked "BLOCKED_ARGOCD_INSTANCE_MISSING" "Namespace openshift-gitops missing"

if ! oc -n openshift-gitops get argocd openshift-gitops >/dev/null 2>&1; then
  fail_blocked "BLOCKED_ARGOCD_INSTANCE_MISSING" "ArgoCD/openshift-gitops instance missing"
fi
pass "Default Argo CD instance available"

ready_deploy() {
  local d="$1"
  oc -n openshift-gitops get deploy "${d}" -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -qE '^[1-9]'
}

ready_controller() {
  # OpenShift GitOps runs application-controller as a StatefulSet
  local ready
  ready="$(oc -n openshift-gitops get statefulset openshift-gitops-application-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
  [[ -n "${ready}" && "${ready}" != "0" ]] && return 0
  ready_deploy openshift-gitops-application-controller
}

ready_deploy openshift-gitops-server \
  || fail_blocked "BLOCKED_ARGOCD_SERVER_UNAVAILABLE" "Argo CD server Deployment not Available"
pass "Argo CD server available"

ready_controller \
  || fail_blocked "BLOCKED_ARGOCD_SERVER_UNAVAILABLE" "Argo CD application-controller not Available"
pass "Argo CD application controller available"

ready_deploy openshift-gitops-repo-server \
  || fail_blocked "BLOCKED_ARGOCD_SERVER_UNAVAILABLE" "Argo CD repo-server not Available"
pass "Argo CD repository server available"

if oc -n openshift-gitops get route openshift-gitops-server >/dev/null 2>&1; then
  pass "Argo CD route available"
else
  fail_blocked "BLOCKED_ARGOCD_SERVER_UNAVAILABLE" "Argo CD Route openshift-gitops-server missing"
fi

SSO_PROVIDER="$(oc -n openshift-gitops get argocd openshift-gitops -o jsonpath='{.spec.sso.provider}' 2>/dev/null || true)"
if [[ "${SSO_PROVIDER}" == "dex" ]]; then
  pass "OpenShift SSO configured"
else
  # Operator default often injects dex; treat missing explicit field as pending
  fail_blocked "BLOCKED_ARGOCD_SERVER_UNAVAILABLE" "OpenShift SSO not configured (spec.sso.provider=${SSO_PROVIDER:-empty}; expected dex)"
fi

printf '\nGitOps prerequisites OK (%s PASS)\n' "${PASS_N}"
exit 0
