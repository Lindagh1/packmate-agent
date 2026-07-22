#!/usr/bin/env bash
# Discover the shared Llama model endpoint and either:
#   CREATE_MODEL_CUSTOM_ENDPOINT=false (default) → print ClickOps instructions
#   CREATE_MODEL_CUSTOM_ENDPOINT=true            → apply documented ConfigMap+Secret
# Never redeploys the model. Never creates an external Route for the model.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh"

packmate_require_oc
if [[ -f "${ROOT}/config/sandbox.env" ]]; then
  packmate_load_config "${ROOT}" || exit 1
fi
PACKMATE_NAMESPACE="${PACKMATE_NAMESPACE:-packmate-lab}"
MODEL_NAMESPACE="${MODEL_NAMESPACE:-my-first-model}"
MODEL_SERVICE="${MODEL_SERVICE:-llama-32-3b-instruct-predictor}"
MODEL_ID="${MODEL_ID:-llama-32-3b-instruct}"
CREATE_MODEL_CUSTOM_ENDPOINT="${CREATE_MODEL_CUSTOM_ENDPOINT:-false}"
DISPLAY_NAME="${PACKMATE_MODEL_DISPLAY_NAME:-Packmate Llama 3.2 3B}"
USE_CASE="${PACKMATE_MODEL_USE_CASE:-Packmate travel planning, weather and baggage tool calling}"
ODH_NS="${ODH_APPLICATIONS_NS:-redhat-ods-applications}"

log() { packmate_log "$*"; }
die() { packmate_die "$*"; }

oc get project "${PACKMATE_NAMESPACE}" >/dev/null || die "project ${PACKMATE_NAMESPACE} missing"
oc get project "${MODEL_NAMESPACE}" >/dev/null || die "project ${MODEL_NAMESPACE} missing"
READY="$(oc get inferenceservice "${MODEL_ID}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
[[ "${READY}" == "True" ]] || die "InferenceService ${MODEL_ID} not Ready"
packmate_discover_model_url || die "Service discovery failed"

log "==> Model discovery"
log "    service_port=${PACKMATE_MODEL_SVC_PORT} targetPort=${PACKMATE_MODEL_TARGET_PORT} probe_port=${PACKMATE_MODEL_PROBE_PORT}"
log "    auth_annotation=${PACKMATE_MODEL_AUTH:-absent}"
log "    base_url=${PACKMATE_MODEL_BASE_URL}"
log "    model_id=${MODEL_ID}"

# Probe /v1/models
POD="packmate-model-endpoint-probe-$$"
oc -n "${PACKMATE_NAMESPACE}" delete pod "${POD}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
oc -n "${PACKMATE_NAMESPACE}" run "${POD}" --image=registry.access.redhat.com/ubi9/ubi-minimal:9.4 \
  --restart=Never --quiet \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"probe","image":"registry.access.redhat.com/ubi9/ubi-minimal:9.4","command":["sleep","90"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsNonRoot":true}}]}}' \
  --command -- sleep 90 >/dev/null
oc -n "${PACKMATE_NAMESPACE}" wait --for=condition=Ready "pod/${POD}" --timeout=90s >/dev/null
BODY="$(oc -n "${PACKMATE_NAMESPACE}" exec "${POD}" -- curl -sS -m 30 "${PACKMATE_MODEL_BASE_URL}/models" || true)"
oc -n "${PACKMATE_NAMESPACE}" delete pod "${POD}" --wait=false >/dev/null 2>&1 || true
printf '%s' "${BODY}" | grep -q "${MODEL_ID}" || die "/v1/models did not list ${MODEL_ID}"
log "    /v1/models OK"

TOKEN_HINT="leave blank or use a fictive value (predictor auth disabled)"
if [[ "${PACKMATE_MODEL_AUTH}" != "false" ]]; then
  TOKEN_HINT="provide an authorized access token (not stored in Git)"
fi

# Ensure feature flag for custom endpoints (documented OdhDashboardConfig field)
if oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" >/dev/null 2>&1; then
  CUR="$(oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" -o jsonpath='{.spec.dashboardConfig.aiAssetCustomEndpoints}' 2>/dev/null || true)"
  if [[ "${CUR}" != "true" ]]; then
    oc patch odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" --type=merge \
      -p '{"spec":{"dashboardConfig":{"aiAssetCustomEndpoints":true}}}' >/dev/null
    log "    enabled dashboardConfig.aiAssetCustomEndpoints=true"
  fi
fi

if [[ "${CREATE_MODEL_CUSTOM_ENDPOINT}" == "true" ]]; then
  log "==> CREATE_MODEL_CUSTOM_ENDPOINT=true — applying ConfigMap/Secret (same persistence as UI Create endpoint)"
  SECRET_NAME="endpoint-api-key-1"
  FAKE="${MODEL_TOKEN:-not-required}"
  oc -n "${PACKMATE_NAMESPACE}" create secret generic "${SECRET_NAME}" \
    --from-literal=api_key="${FAKE}" --dry-run=client -o yaml | oc apply -f - >/dev/null
  unset FAKE MODEL_TOKEN
  CONFIG_YAML="$(cat <<EOF
providers:
  inference:
    - provider_id: endpoint-1
      provider_type: remote::openai
      config:
        base_url: ${PACKMATE_MODEL_BASE_URL}
        allowed_models:
          - ${MODEL_ID}
        custom_gen_ai:
          api_key:
            secretRef:
              name: ${SECRET_NAME}
              key: api_key
registered_resources:
  models:
    - provider_id: endpoint-1
      model_id: ${MODEL_ID}
      model_type: llm
      metadata:
        display_name: ${DISPLAY_NAME}
        custom_gen_ai:
          use_cases: ${USE_CASE}
EOF
)"
  CM_FILE="$(mktemp)"
  cat > "${CM_FILE}" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: gen-ai-aa-custom-model-endpoints
  namespace: ${PACKMATE_NAMESPACE}
data:
  config.yaml: |
$(printf '%s\n' "${CONFIG_YAML}" | sed 's/^/    /')
EOF
  oc apply -f "${CM_FILE}" >/dev/null
  rm -f "${CM_FILE}"
  log "    ConfigMap/gen-ai-aa-custom-model-endpoints applied"
  log "    UI_REFRESH_REQUIRED"
else
  cat <<EOF

MANUAL STEP REQUIRED — Create model endpoint

Mode A (simplest): open Playground in project my-first-model (model already there).

Mode B (single project Packmate Lab):
  Gen AI studio
  → AI asset endpoints
  → Project: Packmate Lab
  → Models
  → Create endpoint

Fill in:
  Model type:     Inferencing
  Model ID:       ${MODEL_ID}
  Display name:   ${DISPLAY_NAME}
  Use case:       ${USE_CASE}
  URL:            ${PACKMATE_MODEL_BASE_URL}
  Token:          ${TOKEN_HINT}

Then:
  Gen AI studio → Playground → Project: Packmate Lab

To apply the same resources via CLI (optional instructor):
  CREATE_MODEL_CUSTOM_ENDPOINT=true bash scripts/create-packmate-model-endpoint.sh
EOF
fi
