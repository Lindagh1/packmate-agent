#!/usr/bin/env bash
# Apply Packmate AppProject + Applications (packmate-lab + packmate-prod). Idempotent.
# Prefer patching existing Applications to preserve history.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && set -a && source "${ROOT}/config/sandbox.env" && set +a || true

GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/Lindagh1/packmate-agent.git}"
GIT_REVISION="${GIT_REVISION:-packmate-v2}"
PACKMATE_ARGO_GROUP="${PACKMATE_ARGO_GROUP:-packmate-lab-users}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-openshift-gitops}"
PACKMATE_LAB_NAMESPACE="${PACKMATE_LAB_NAMESPACE:-${PACKMATE_NAMESPACE:-packmate-lab}}"
PACKMATE_PROD_NAMESPACE="${PACKMATE_PROD_NAMESPACE:-packmate-prod}"

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

oc get crd applications.argoproj.io >/dev/null 2>&1 || die "Argo CD Application CRD missing — run make check-gitops-prerequisites"

# Namespace management labels (official OpenShift GitOps mechanism)
for ns in "${PACKMATE_LAB_NAMESPACE}" "${PACKMATE_PROD_NAMESPACE}"; do
  oc get project "${ns}" >/dev/null 2>&1 || die "Namespace ${ns} missing"
  oc label namespace "${ns}" "argocd.argoproj.io/managed-by=${ARGOCD_NAMESPACE}" --overwrite >/dev/null
  log "OK: labeled namespace/${ns} managed-by=${ARGOCD_NAMESPACE}"
done

sed -e "s|__GIT_REPO_URL__|${GIT_REPO_URL}|g" \
    -e "s|__PACKMATE_ARGO_GROUP__|${PACKMATE_ARGO_GROUP}|g" \
    "${ROOT}/argocd/appproject-packmate.yaml" | oc apply -f - >/dev/null
log "OK: AppProject/packmate (destinations: ${PACKMATE_LAB_NAMESPACE}, ${PACKMATE_PROD_NAMESPACE})"

# Migrate Applications stuck on project default → packmate without delete when possible
for app in packmate-lab packmate-prod; do
  if oc -n "${ARGOCD_NAMESPACE}" get application "${app}" >/dev/null 2>&1; then
    cur="$(oc -n "${ARGOCD_NAMESPACE}" get application "${app}" -o jsonpath='{.spec.project}')"
    if [[ "${cur}" == "default" ]]; then
      oc -n "${ARGOCD_NAMESPACE}" patch application "${app}" --type merge -p '{"spec":{"project":"packmate"}}' >/dev/null
      log "OK: migrated Application/${app} from project default → packmate"
    fi
  fi
done

sed -e "s|__GIT_REPO_URL__|${GIT_REPO_URL}|g" \
    -e "s|__GIT_REVISION__|${GIT_REVISION}|g" \
    "${ROOT}/argocd/application-packmate-lab.yaml" | oc apply -f - >/dev/null
log "OK: Application/packmate-lab (path deploy/overlays/dev, prune=false)"

sed -e "s|__GIT_REPO_URL__|${GIT_REPO_URL}|g" \
    -e "s|__GIT_REVISION__|${GIT_REVISION}|g" \
    "${ROOT}/argocd/application-packmate-prod.yaml" | oc apply -f - >/dev/null
log "OK: Application/packmate-prod (path deploy/overlays/prod, manual sync)"

# Reject accidental alternate names
for bad in packmate-dev packmate-lab-dev packmate-production; do
  if oc -n "${ARGOCD_NAMESPACE}" get application "${bad}" >/dev/null 2>&1; then
    log "WARN: unexpected Application/${bad} exists — canonical names are packmate-lab and packmate-prod only"
  fi
done
