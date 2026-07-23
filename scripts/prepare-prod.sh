#!/usr/bin/env bash
# Prepare the packmate-prod namespace for a GitOps-managed deploy — creates
# the namespace, the LLM secret, cross-namespace image-pull RBAC, and the
# Argo CD AppProject/Application. Idempotent.
#
# Does NOT `oc apply -k deploy/overlays/prod` (workloads are deployed only
# by Argo CD Application packmate-prod, manual Sync). Never prints secret
# values.
#
# Env vars:
#   LLM_BASE_URL, LLM_MODEL, LITELLM_API_KEY   Required — packmate-prod-llm Secret contents (never printed)
#   PACKMATE_LAB_NAMESPACE                     Source namespace for image pulls (default: packmate-lab)
#   PACKMATE_PROD_NAMESPACE                    Target namespace (default: packmate-prod)
#   GIT_REPO_URL, GIT_REVISION                 Substituted into argocd/*.yaml (defaults from config/sandbox.env if present)
#   PACKMATE_ARGO_GROUP                        Substituted into argocd/appproject-packmate.yaml (default: packmate-lab-users)
#   CREATE_ARGOCD_RBAC                         "true" to also run scripts/configure-argocd-lab-rbac.sh (default: false)
#   ARGOCD_RBAC_FALLBACK                       "true" to allow the minimal RoleBinding fallback documented in step 6 (default: false)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# shellcheck disable=SC1091
if [[ -f "${ROOT}/scripts/lib/sandbox-common.sh" ]]; then
  source "${ROOT}/scripts/lib/sandbox-common.sh"
fi

if declare -F packmate_log >/dev/null 2>&1; then
  log() { packmate_log "$*"; }
  die() { packmate_die "$*"; }
else
  log() { printf '%s\n' "$*"; }
  die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
fi
warn() { printf 'WARN: %s\n' "$*" >&2; }

if declare -F packmate_load_config >/dev/null 2>&1; then
  # Best-effort — only used for GIT_REPO_URL/GIT_REVISION/LLM_* defaults.
  packmate_load_config "${ROOT}" 2>/dev/null || true
fi

command -v oc >/dev/null 2>&1 || die "oc CLI not found"
oc whoami >/dev/null 2>&1 || die "not logged in to OpenShift (oc whoami failed)"

PACKMATE_LAB_NAMESPACE="${PACKMATE_LAB_NAMESPACE:-packmate-lab}"
PACKMATE_PROD_NAMESPACE="${PACKMATE_PROD_NAMESPACE:-packmate-prod}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/Lindagh1/packmate-agent.git}"
GIT_REVISION="${GIT_REVISION:-packmate-v2}"
PACKMATE_ARGO_GROUP="${PACKMATE_ARGO_GROUP:-packmate-lab-users}"
CREATE_ARGOCD_RBAC="${CREATE_ARGOCD_RBAC:-false}"
ARGOCD_RBAC_FALLBACK="${ARGOCD_RBAC_FALLBACK:-false}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-openshift-gitops}"

log "=== Packmate prepare-prod ==="
log "lab_namespace=${PACKMATE_LAB_NAMESPACE} prod_namespace=${PACKMATE_PROD_NAMESPACE}"

# ---------------------------------------------------------------------------
# 1) Namespace packmate-prod — labels: packmate.io/environment=prod only.
#    Deliberately NOT the DSP/lab labels (opendatahub.io/dashboard,
#    modelmesh-enabled) used for the packmate-lab Data Science Project.
# ---------------------------------------------------------------------------
if oc get project "${PACKMATE_PROD_NAMESPACE}" >/dev/null 2>&1; then
  log "OK: namespace/${PACKMATE_PROD_NAMESPACE} already exists"
else
  oc new-project "${PACKMATE_PROD_NAMESPACE}" --display-name="Packmate Production" >/dev/null
  log "OK: created namespace/${PACKMATE_PROD_NAMESPACE}"
fi
oc label namespace "${PACKMATE_PROD_NAMESPACE}" packmate.io/environment=prod --overwrite >/dev/null
log "OK: labeled namespace/${PACKMATE_PROD_NAMESPACE} packmate.io/environment=prod"

# ---------------------------------------------------------------------------
# 2) Secret packmate-prod-llm from LLM_* env — values never printed.
# ---------------------------------------------------------------------------
: "${LLM_BASE_URL:?LLM_BASE_URL must be set (never printed)}"
: "${LLM_MODEL:?LLM_MODEL must be set (never printed)}"
LLM_KEY="${LITELLM_API_KEY:-${LLM_API_KEY:-}}"
: "${LLM_KEY:?LITELLM_API_KEY (or LLM_API_KEY) must be set (never printed)}"

oc -n "${PACKMATE_PROD_NAMESPACE}" create secret generic packmate-prod-llm \
  --from-literal=BASE_URL="${LLM_BASE_URL}" \
  --from-literal=MODEL="${LLM_MODEL}" \
  --from-literal=LITELLM_API_KEY="${LLM_KEY}" \
  --dry-run=client -o yaml | oc apply -f - >/dev/null
log "OK: Secret/packmate-prod-llm applied in ${PACKMATE_PROD_NAMESPACE} (values not shown)"
unset LLM_KEY

# ---------------------------------------------------------------------------
# 3) Cross-namespace image pull: grant system:image-puller in packmate-lab
#    to the packmate-prod ServiceAccounts.
# ---------------------------------------------------------------------------
log "==> Granting system:image-puller in ${PACKMATE_LAB_NAMESPACE} to ${PACKMATE_PROD_NAMESPACE} SAs"
for sa in packmate-backend packmate-frontend weather-mcp baggage-policy-mcp; do
  subject="system:serviceaccount:${PACKMATE_PROD_NAMESPACE}:${sa}"
  if oc -n "${PACKMATE_LAB_NAMESPACE}" auth can-i get imagestreams/layers --as="${subject}" >/dev/null 2>&1; then
    log "    OK: ${subject} already has image-puller access in ${PACKMATE_LAB_NAMESPACE}"
    continue
  fi
  oc -n "${PACKMATE_LAB_NAMESPACE}" adm policy add-role-to-user system:image-puller "${subject}" >/dev/null
  log "    OK: granted system:image-puller to ${subject}"
done

# ---------------------------------------------------------------------------
# 4) Verify: packmate-backend SA can read imagestreams/layers in packmate-lab
# ---------------------------------------------------------------------------
BACKEND_SUBJECT="system:serviceaccount:${PACKMATE_PROD_NAMESPACE}:packmate-backend"
if oc -n "${PACKMATE_LAB_NAMESPACE}" auth can-i get imagestreams/layers --as="${BACKEND_SUBJECT}" >/dev/null 2>&1; then
  log "OK: verified ${BACKEND_SUBJECT} can get imagestreams/layers in ${PACKMATE_LAB_NAMESPACE}"
else
  warn "verification failed: ${BACKEND_SUBJECT} cannot get imagestreams/layers in ${PACKMATE_LAB_NAMESPACE} — image pulls from ${PACKMATE_LAB_NAMESPACE} may fail"
fi

# ---------------------------------------------------------------------------
# 5) Argo CD AppProject + Application (manifests only — never workloads)
# ---------------------------------------------------------------------------
if oc get crd applications.argoproj.io >/dev/null 2>&1; then
  log "==> Applying Argo CD AppProject + Application (manual sync, packmate-prod only)"
  sed -e "s|__GIT_REPO_URL__|${GIT_REPO_URL}|g" \
      -e "s|__PACKMATE_ARGO_GROUP__|${PACKMATE_ARGO_GROUP}|g" \
      "${ROOT}/argocd/appproject-packmate.yaml" | oc apply -f - >/dev/null
  sed -e "s|__GIT_REPO_URL__|${GIT_REPO_URL}|g" \
      -e "s|__GIT_REVISION__|${GIT_REVISION}|g" \
      "${ROOT}/argocd/application-packmate-prod.yaml" | oc apply -f - >/dev/null
  log "OK: AppProject/packmate and Application/packmate-prod applied (destination namespace ${PACKMATE_PROD_NAMESPACE}, manual Sync)"
else
  warn "ArgoCD CRDs not found — GitOps operator not installed. See docs/INSTALL_GITOPS_PREREQUISITE.md"
fi

# ---------------------------------------------------------------------------
# 6) Namespace GitOps management mechanism.
#    Preferred / official OpenShift GitOps 1.x mechanism: label the target
#    namespace so the cluster-scoped Argo CD instance's operator-managed
#    RBAC recognizes it as a "managed namespace" for the application
#    controller/server ServiceAccounts. This is minimal and does not create
#    any RoleBinding by hand.
# ---------------------------------------------------------------------------
oc label namespace "${PACKMATE_PROD_NAMESPACE}" argocd.argoproj.io/managed-by="${ARGOCD_NAMESPACE}" --overwrite >/dev/null
log "OK: labeled namespace/${PACKMATE_PROD_NAMESPACE} argocd.argoproj.io/managed-by=${ARGOCD_NAMESPACE}"
log "    (official OpenShift GitOps 1.x managed-namespace mechanism — operator generates the"
log "     application-controller/server RBAC automatically; no manual RoleBinding created)"

CONTROLLER_SUBJECT="system:serviceaccount:${ARGOCD_NAMESPACE}:${ARGOCD_NAMESPACE}-argocd-application-controller"
if oc -n "${PACKMATE_PROD_NAMESPACE}" auth can-i get deployments --as="${CONTROLLER_SUBJECT}" >/dev/null 2>&1; then
  log "OK: verified ${CONTROLLER_SUBJECT} has access in ${PACKMATE_PROD_NAMESPACE} — managed-by label was sufficient"
else
  warn "managed-by label access not yet visible for ${CONTROLLER_SUBJECT} in ${PACKMATE_PROD_NAMESPACE}"
  warn "(the operator may take a moment to reconcile RBAC after labeling; re-run 'oc auth can-i' to confirm before falling back)"
  if [[ "${ARGOCD_RBAC_FALLBACK}" == "true" ]]; then
    log "ARGOCD_RBAC_FALLBACK=true — applying minimal fallback RoleBinding (edit role) as documented"
    oc adm policy add-role-to-user edit "${CONTROLLER_SUBJECT}" -n "${PACKMATE_PROD_NAMESPACE}" >/dev/null
    log "OK: fallback used — bound 'edit' role for ${CONTROLLER_SUBJECT} in ${PACKMATE_PROD_NAMESPACE}"
    log "    DOCUMENTED FALLBACK: managed-by namespace label was insufficient at run time; a direct"
    log "    RoleBinding (edit) was created for the argocd-application-controller ServiceAccount."
  else
    log "    Not applying the manual RoleBinding fallback (ARGOCD_RBAC_FALLBACK=false, minimal by default)."
    log "    If Sync later fails with RBAC errors, re-run with ARGOCD_RBAC_FALLBACK=true."
  fi
fi

# ---------------------------------------------------------------------------
# 7) Optional: participant Argo CD RBAC (Sync-only on packmate-prod)
# ---------------------------------------------------------------------------
if [[ "${CREATE_ARGOCD_RBAC}" == "true" ]]; then
  log "==> CREATE_ARGOCD_RBAC=true — running scripts/configure-argocd-lab-rbac.sh"
  bash "${ROOT}/scripts/configure-argocd-lab-rbac.sh"
else
  log "SKIP: CREATE_ARGOCD_RBAC=false — not configuring participant Argo CD RBAC"
fi

cat <<EOF

=== prepare-prod complete ===
Namespace:        ${PACKMATE_PROD_NAMESPACE} (packmate.io/environment=prod)
Secret:            packmate-prod-llm (values not shown)
Image pull RBAC:   system:image-puller in ${PACKMATE_LAB_NAMESPACE} for packmate-prod SAs
GitOps namespace:  managed-by label = ${ARGOCD_NAMESPACE}
Argo CD:           AppProject/packmate, Application/packmate-prod (manual Sync)

This script did NOT deploy workloads (no 'oc apply -k deploy/overlays/prod').
Sync Application/packmate-prod manually (Argo CD UI, or via the 'promoter'
role after scripts/configure-argocd-lab-rbac.sh) once digests are promoted:
  ./scripts/promote-backend-image.sh --pipelinerun <name> --namespace ${PACKMATE_LAB_NAMESPACE} --create-pr
EOF
