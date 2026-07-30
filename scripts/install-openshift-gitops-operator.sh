#!/usr/bin/env bash
# Instructor-only: install official Red Hat OpenShift GitOps Operator (idempotent).
# Never installs Community Argo CD. Never prints admin passwords.
#
# Requires: INSTALL_OPENSHIFT_GITOPS_OPERATOR=true
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/scripts/lib/sandbox-common.sh" ]] && source "${ROOT}/scripts/lib/sandbox-common.sh" || true
[[ -f "${ROOT}/config/sandbox.env" ]] && set -a && # shellcheck disable=SC1091
  source "${ROOT}/config/sandbox.env" && set +a || true

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARN  %s\n' "$*" >&2; }

INSTALL_OPENSHIFT_GITOPS_OPERATOR="${INSTALL_OPENSHIFT_GITOPS_OPERATOR:-false}"
CREATE_DEFAULT_ARGOCD_INSTANCE="${CREATE_DEFAULT_ARGOCD_INSTANCE:-true}"
GITOPS_INSTALL_TIMEOUT_SECONDS="${GITOPS_INSTALL_TIMEOUT_SECONDS:-900}"
PKG="openshift-gitops-operator"
CATALOG="redhat-operators"
OP_NS="openshift-gitops-operator"

if [[ "${INSTALL_OPENSHIFT_GITOPS_OPERATOR}" != "true" ]]; then
  die "Refusing to install: set INSTALL_OPENSHIFT_GITOPS_OPERATOR=true (instructor only)"
fi

command -v oc >/dev/null 2>&1 || die "oc CLI not found"
oc whoami >/dev/null 2>&1 || die "not logged in"

# Capability checks
for verb_res in "create namespaces" "create operatorgroups" "create subscriptions"; do
  verb="${verb_res%% *}"
  res="${verb_res#* }"
  oc auth can-i "${verb}" "${res}" >/dev/null 2>&1 \
    || die "Current user cannot ${verb} ${res} — cluster-admin required for instructor install"
done

# Conflict: community Argo CD
if oc get subscription -A -o jsonpath='{range .items[*]}{.spec.name}{"\n"}{end}' 2>/dev/null \
  | grep -qiE '^argocd-operator$|^argo-cd$'; then
  die "Conflicting Community Argo CD Operator Subscription detected — aborting"
fi

# Already installed?
if bash "${ROOT}/scripts/check-openshift-gitops.sh" >/tmp/packmate-gitops-check.txt 2>&1; then
  log "OK: Red Hat OpenShift GitOps already ready — nothing to install"
  cat /tmp/packmate-gitops-check.txt
  exit 0
fi
# If only instance missing, we may still need to create ArgoCD CR — continue carefully.

# Discover package + channel
oc get packagemanifest "${PKG}" -n openshift-marketplace >/dev/null 2>&1 \
  || die "PackageManifest ${PKG} not found (catalog ${CATALOG} required)"
SRC="$(oc get packagemanifest "${PKG}" -n openshift-marketplace -o jsonpath='{.status.catalogSource}')"
[[ "${SRC}" == "${CATALOG}" ]] || warn "catalogSource=${SRC} (expected ${CATALOG})"
CHANNEL="$(oc get packagemanifest "${PKG}" -n openshift-marketplace -o jsonpath='{.status.defaultChannel}')"
[[ -n "${CHANNEL}" ]] || die "Unable to discover defaultChannel for ${PKG}"
log "package=${PKG} catalog=${SRC} channel=${CHANNEL}"

# Existing official Subscription?
EXISTING="$(oc get subscription -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.spec.name}{"\n"}{end}' \
  | awk -F= -v p="${PKG}" '$2==p{print $1; exit}')"
if [[ -n "${EXISTING}" ]]; then
  log "OK: preserving existing Subscription ${EXISTING}"
else
  # Create operator namespace + OperatorGroup if needed
  if ! oc get project "${OP_NS}" >/dev/null 2>&1; then
    oc create namespace "${OP_NS}" >/dev/null
    log "created namespace/${OP_NS}"
  fi
  if ! oc -n "${OP_NS}" get operatorgroup >/dev/null 2>&1; then
    oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-gitops-operator
  namespace: ${OP_NS}
spec: {}
EOF
    log "created OperatorGroup/${OP_NS}"
  fi
  oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: ${OP_NS}
spec:
  channel: ${CHANNEL}
  name: ${PKG}
  source: ${SRC}
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF
  log "created Subscription/${OP_NS}/openshift-gitops-operator"
fi

# Wait for CSV Succeeded
deadline=$((SECONDS + GITOPS_INSTALL_TIMEOUT_SECONDS))
while (( SECONDS < deadline )); do
  SUB_LINE="$(oc get subscription -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}={.spec.name}{"\n"}{end}' \
    | awk -F= -v p="${PKG}" '$2==p{print $1; exit}')"
  if [[ -n "${SUB_LINE}" ]]; then
    SNS="${SUB_LINE%%/*}"
    SNAME="${SUB_LINE#*/}"
    CSV="$(oc -n "${SNS}" get subscription "${SNAME}" -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)"
    if [[ -n "${CSV}" ]]; then
      PHASE="$(oc -n "${SNS}" get csv "${CSV}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
      log "CSV=${CSV} phase=${PHASE:-pending}"
      [[ "${PHASE}" == "Succeeded" ]] && break
      [[ "${PHASE}" == "Failed" ]] && die "CSV ${CSV} Failed"
    fi
  fi
  sleep 10
done
[[ "${PHASE:-}" == "Succeeded" ]] || die "Timed out waiting for GitOps CSV Succeeded"

# Wait for CRDs
while (( SECONDS < deadline )); do
  oc get crd argocds.argoproj.io applications.argoproj.io appprojects.argoproj.io >/dev/null 2>&1 && break
  sleep 5
done
oc get crd argocds.argoproj.io >/dev/null 2>&1 || die "Argo CD CRDs not available"

# Default instance
if ! oc get project openshift-gitops >/dev/null 2>&1; then
  oc create namespace openshift-gitops >/dev/null || true
fi

if ! oc -n openshift-gitops get argocd openshift-gitops >/dev/null 2>&1; then
  if [[ "${CREATE_DEFAULT_ARGOCD_INSTANCE}" != "true" ]]; then
    die "Default ArgoCD instance missing and CREATE_DEFAULT_ARGOCD_INSTANCE=false"
  fi
  # Do not create a duplicate if any ArgoCD exists in the namespace
  if oc -n openshift-gitops get argocd -o name 2>/dev/null | grep -q .; then
    warn "An ArgoCD instance already exists in openshift-gitops — not creating openshift-gitops"
  else
    log "Creating supported ArgoCD/openshift-gitops instance"
    oc apply -f - <<'EOF'
apiVersion: argoproj.io/v1beta1
kind: ArgoCD
metadata:
  name: openshift-gitops
  namespace: openshift-gitops
spec:
  server:
    route:
      enabled: true
  sso:
    provider: dex
    dex:
      openShiftOAuth: true
  rbac:
    defaultPolicy: ""
    scopes: "[groups]"
EOF
  fi
fi

# Wait for deployments + route
while (( SECONDS < deadline )); do
  if bash "${ROOT}/scripts/check-openshift-gitops.sh" >/tmp/packmate-gitops-check.txt 2>&1; then
    cat /tmp/packmate-gitops-check.txt
    log "install-openshift-gitops-operator: OK"
    exit 0
  fi
  sleep 10
done
cat /tmp/packmate-gitops-check.txt || true
die "Timed out waiting for GitOps readiness"
