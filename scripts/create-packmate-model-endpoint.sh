#!/usr/bin/env bash
# Register Packmate Lab custom AI asset endpoint → existing model in MODEL_NAMESPACE.
# Does NOT redeploy the model, create Routes, or enable external providers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && source "${ROOT}/config/sandbox.env"

PACKMATE_NS="${PACKMATE_NS:-packmate-lab}"
PACKMATE_MODEL_ENDPOINT_NAME="${PACKMATE_MODEL_ENDPOINT_NAME:-packmate-llama-32-3b}"
PACKMATE_MODEL_DISPLAY_NAME="${PACKMATE_MODEL_DISPLAY_NAME:-Packmate Llama 3.2 3B}"
PACKMATE_MODEL_USE_CASE="${PACKMATE_MODEL_USE_CASE:-Packmate travel planning, weather and baggage tool calling}"
MODEL_NAMESPACE="${MODEL_NAMESPACE:-my-first-model}"
MODEL_SERVICE="${MODEL_SERVICE:-llama-32-3b-instruct-predictor}"
MODEL_ID="${MODEL_ID:-llama-32-3b-instruct}"
MODEL_TOKEN="${MODEL_TOKEN:-}"
ODH_NS="${ODH_APPLICATIONS_NS:-redhat-ods-applications}"
CM_NAME="gen-ai-aa-custom-model-endpoints"
SECRET_NAME="endpoint-api-key-1"
PROVIDER_ID="endpoint-1"

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v oc >/dev/null || die "oc not found"
oc whoami >/dev/null || die "not logged in to OpenShift"

oc get project "${PACKMATE_NS}" >/dev/null || die "project ${PACKMATE_NS} missing"
oc get project "${MODEL_NAMESPACE}" >/dev/null || die "project ${MODEL_NAMESPACE} missing"

log "==> Checking InferenceService ${MODEL_ID} in ${MODEL_NAMESPACE}"
READY="$(oc get inferenceservice "${MODEL_ID}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
[[ "${READY}" == "True" ]] || die "InferenceService ${MODEL_ID} is not Ready (got: ${READY:-missing})"

log "==> Discovering Service ${MODEL_SERVICE}"
oc get svc "${MODEL_SERVICE}" -n "${MODEL_NAMESPACE}" >/dev/null || die "Service ${MODEL_SERVICE} not found"

SVC_PORT="$(oc get svc "${MODEL_SERVICE}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.spec.ports[0].port}')"
TARGET_PORT="$(oc get svc "${MODEL_SERVICE}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.spec.ports[0].targetPort}')"
CLUSTER_IP="$(oc get svc "${MODEL_SERVICE}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.spec.clusterIP}')"
AUTH_ANN="$(oc get svc "${MODEL_SERVICE}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.metadata.annotations.security\.opendatahub\.io/enable-auth}')"

# Headless Services (clusterIP None) often answer on the pod targetPort, not the Service port.
PROBE_PORT="${SVC_PORT}"
if [[ "${CLUSTER_IP}" == "None" || -z "${CLUSTER_IP}" ]]; then
  PROBE_PORT="${TARGET_PORT}"
fi

BASE_URL="http://${MODEL_SERVICE}.${MODEL_NAMESPACE}.svc.cluster.local:${PROBE_PORT}/v1"
log "    service_port=${SVC_PORT} targetPort=${TARGET_PORT} clusterIP=${CLUSTER_IP:-empty}"
log "    auth_annotation=${AUTH_ANN:-absent}"
log "    base_url=${BASE_URL}"

log "==> Probing ${BASE_URL}/models from a temporary pod"
PROBE_POD="packmate-model-endpoint-probe-$$"
oc -n "${PACKMATE_NS}" delete pod "${PROBE_POD}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
oc -n "${PACKMATE_NS}" run "${PROBE_POD}" \
  --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  --restart=Never \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"probe","image":"registry.access.redhat.com/ubi9/ubi-minimal:latest","command":["sleep","90"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsNonRoot":true}}]}}' \
  --command -- sleep 90 >/dev/null
oc -n "${PACKMATE_NS}" wait --for=condition=Ready "pod/${PROBE_POD}" --timeout=90s >/dev/null
MODELS_JSON="$(oc -n "${PACKMATE_NS}" exec "${PROBE_POD}" -- curl -sS -m 30 "${BASE_URL}/models" || true)"
oc -n "${PACKMATE_NS}" delete pod "${PROBE_POD}" --wait=false >/dev/null 2>&1 || true
printf '%s' "${MODELS_JSON}" | grep -q "${MODEL_ID}" || die "/v1/models did not list ${MODEL_ID} (check port ${PROBE_PORT})"
log "    /v1/models OK (contains ${MODEL_ID})"

log "==> Enabling dashboardConfig.aiAssetCustomEndpoints (preserve other fields)"
if oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" >/dev/null 2>&1; then
  CURRENT="$(oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" -o jsonpath='{.spec.dashboardConfig.aiAssetCustomEndpoints}')"
  if [[ "${CURRENT}" != "true" ]]; then
    oc patch odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" --type=merge \
      -p '{"spec":{"dashboardConfig":{"aiAssetCustomEndpoints":true}}}' >/dev/null
    log "    set aiAssetCustomEndpoints=true (was: ${CURRENT:-absent})"
  else
    log "    already true"
  fi
  # Do not enable genAiStudioConfig.aiAssetCustomEndpoints.externalProviders
else
  log "    WARNING: OdhDashboardConfig not found in ${ODH_NS}; skip flag"
fi

# Token: real value from env if provided; otherwise fictive only when auth disabled.
TOKEN_VALUE="${MODEL_TOKEN}"
if [[ -z "${TOKEN_VALUE}" ]]; then
  if [[ "${AUTH_ANN}" == "false" ]]; then
    TOKEN_VALUE="not-required"
    log "==> Predictor auth disabled; using fictive Secret value (not printed)"
  else
    die "MODEL_TOKEN is empty and Service auth is not disabled (security.opendatahub.io/enable-auth=${AUTH_ANN:-absent})"
  fi
else
  log "==> Using MODEL_TOKEN from environment (value not printed)"
fi

log "==> Ensuring Secret ${SECRET_NAME} in ${PACKMATE_NS}"
oc -n "${PACKMATE_NS}" create secret generic "${SECRET_NAME}" \
  --from-literal=api_key="${TOKEN_VALUE}" \
  --dry-run=client -o yaml | oc apply -f - >/dev/null
unset TOKEN_VALUE MODEL_TOKEN

log "==> Creating/updating ConfigMap ${CM_NAME} (idempotent; single Packmate endpoint)"
# Persistence mechanism confirmed for OAI 3.4.x Gen AI BFF (installed binary + OpenAPI):
# ConfigMap gen-ai-aa-custom-model-endpoints with data.config.yaml
# (+ Secret endpoint-api-key-<n> referenced by secretRef). Same as UI Create endpoint.
CONFIG_YAML="$(cat <<EOF
providers:
  inference:
    - provider_id: ${PROVIDER_ID}
      provider_type: remote::openai
      config:
        base_url: ${BASE_URL}
        allowed_models:
          - ${MODEL_ID}
        custom_gen_ai:
          api_key:
            secretRef:
              name: ${SECRET_NAME}
              key: api_key
registered_resources:
  models:
    - provider_id: ${PROVIDER_ID}
      model_id: ${MODEL_ID}
      model_type: llm
      metadata:
        display_name: ${PACKMATE_MODEL_DISPLAY_NAME}
        custom_gen_ai:
          use_cases: ${PACKMATE_MODEL_USE_CASE}
EOF
)"

NEED_APPLY=1
if oc -n "${PACKMATE_NS}" get cm "${CM_NAME}" >/dev/null 2>&1; then
  EXISTING="$(oc -n "${PACKMATE_NS}" get cm "${CM_NAME}" -o jsonpath='{.data.config\.yaml}')"
  if printf '%s' "${EXISTING}" | grep -Fq "model_id: ${MODEL_ID}" \
    && printf '%s' "${EXISTING}" | grep -Fq "display_name: ${PACKMATE_MODEL_DISPLAY_NAME}" \
    && printf '%s' "${EXISTING}" | grep -Fq "base_url: ${BASE_URL}"; then
    log "    ConfigMap already up to date for ${MODEL_ID}"
    NEED_APPLY=0
  fi
fi

if [[ "${NEED_APPLY}" -eq 1 ]]; then
  # Write ConfigMap manifest (same schema as Gen AI BFF CreateExternalModel).
  CM_FILE="$(mktemp)"
  cat > "${CM_FILE}" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CM_NAME}
  namespace: ${PACKMATE_NS}
  labels:
    app.kubernetes.io/part-of: packmate
    packmate.io/model-endpoint: ${PACKMATE_MODEL_ENDPOINT_NAME}
data:
  config.yaml: |
$(printf '%s\n' "${CONFIG_YAML}" | sed 's/^/    /')
EOF
  oc apply -f "${CM_FILE}" >/dev/null
  rm -f "${CM_FILE}"
  log "    ConfigMap applied"
fi

log "==> Done"
log "    ConfigMap/${CM_NAME} + Secret/${SECRET_NAME} in ${PACKMATE_NS}"
log "    Points to ${BASE_URL} (model stays in ${MODEL_NAMESPACE})"
log "    Refresh UI: Gen AI studio → AI asset endpoints → Project: Packmate Lab → Models"
log "    Then: Gen AI studio → Playground → Project: Packmate Lab"
