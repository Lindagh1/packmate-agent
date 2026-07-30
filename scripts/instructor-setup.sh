#!/usr/bin/env bash
# Instructor setup: GitOps Operator (optional) → SSO/RBAC → AppProject → both Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && set -a && source "${ROOT}/config/sandbox.env" && set +a || true

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

INSTALL_OPENSHIFT_GITOPS_OPERATOR="${INSTALL_OPENSHIFT_GITOPS_OPERATOR:-false}"
REQUIRE_OPENSHIFT_GITOPS="${REQUIRE_OPENSHIFT_GITOPS:-true}"
CREATE_ARGOCD_RBAC="${CREATE_ARGOCD_RBAC:-true}"
PACKMATE_REQUIRE_PORTABLE_PROD_IMAGE="${PACKMATE_REQUIRE_PORTABLE_PROD_IMAGE:-true}"

log "=== Packmate instructor-setup ==="

if [[ "${INSTALL_OPENSHIFT_GITOPS_OPERATOR}" == "true" ]]; then
  bash "${ROOT}/scripts/install-openshift-gitops-operator.sh"
else
  log "==> Skipping Operator install (INSTALL_OPENSHIFT_GITOPS_OPERATOR=false)"
fi

log "==> GitOps prerequisite check"
if ! bash "${ROOT}/scripts/check-openshift-gitops.sh"; then
  if [[ "${REQUIRE_OPENSHIFT_GITOPS}" == "true" ]]; then
    die "GitOps not ready. Instructor: INSTALL_OPENSHIFT_GITOPS_OPERATOR=true make install-gitops-operator"
  fi
  die "GitOps check failed"
fi

log "==> Wait for GitOps (re-check)"
bash "${ROOT}/scripts/check-openshift-gitops.sh" >/dev/null

# Ensure SSO dex without overwriting valid config
SSO="$(oc -n openshift-gitops get argocd openshift-gitops -o jsonpath='{.spec.sso.provider}' 2>/dev/null || true)"
if [[ "${SSO}" != "dex" ]]; then
  log "==> Configuring spec.sso.provider=dex (OpenShift OAuth)"
  oc -n openshift-gitops patch argocd openshift-gitops --type merge -p \
    '{"spec":{"sso":{"provider":"dex","dex":{"openShiftOAuth":true}}}}' >/dev/null
fi

# Portable PROD baseline gate (before enabling Application sync)
if [[ "${PACKMATE_REQUIRE_PORTABLE_PROD_IMAGE}" == "true" ]]; then
  if grep -qE 'image-registry\.openshift-image-registry\.svc|default-route-openshift-image-registry' \
    "${ROOT}/deploy/overlays/prod/kustomization.yaml"; then
    die "BLOCKED_OLD_SANDBOX_PROD_IMAGE_REFERENCE: PROD overlay still references the internal registry"
  fi
fi

log "==> OpenShift participant group + Argo RBAC scopes"
if [[ "${CREATE_ARGOCD_RBAC}" == "true" ]]; then
  bash "${ROOT}/scripts/configure-argocd-lab-rbac.sh"
fi

log "==> AppProject + Applications (packmate-lab + packmate-prod)"
bash "${ROOT}/scripts/apply-packmate-argocd.sh"

# Optional: wait briefly for DEV auto-sync
log "==> Waiting for Application/packmate-lab sync (up to 180s)"
for _ in $(seq 1 36); do
  sync="$(oc -n openshift-gitops get application.argoproj.io packmate-lab -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  health="$(oc -n openshift-gitops get application.argoproj.io packmate-lab -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
  log "    packmate-lab sync=${sync:-?} health=${health:-?}"
  [[ "${sync}" == "Synced" && "${health}" == "Healthy" ]] && break
  oc -n openshift-gitops annotate application.argoproj.io/packmate-lab \
    argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
  sleep 5
done

log "==> Applications summary"
oc get applications.argoproj.io -n openshift-gitops \
  -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project,DEST:.spec.destination.namespace,SYNC:.status.sync.status,HEALTH:.status.health.status'

cat <<EOF

=== instructor-setup complete ===
Argo CD dashboard expected applications:
- packmate-lab
- packmate-prod

Manual UI validation (required):
1. Log out of Argo CD
2. Open Cluster Argo CD → Log in via OpenShift
3. User Info → confirm group packmate-lab-users
4. Applications → both packmate-lab and packmate-prod visible

Never share the local Argo CD admin password with participants.
Next: make verify-gitops
EOF
