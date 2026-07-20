#!/usr/bin/env bash
# Verify Packmate sandbox model endpoint registration (read-mostly).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && source "${ROOT}/config/sandbox.env"

PACKMATE_NS="${PACKMATE_NS:-packmate-lab}"
MODEL_NAMESPACE="${MODEL_NAMESPACE:-my-first-model}"
MODEL_SERVICE="${MODEL_SERVICE:-llama-32-3b-instruct-predictor}"
MODEL_ID="${MODEL_ID:-llama-32-3b-instruct}"
DISPLAY_NAME="${PACKMATE_MODEL_DISPLAY_NAME:-Packmate Llama 3.2 3B}"
CM_NAME="gen-ai-aa-custom-model-endpoints"
SECRET_NAME="endpoint-api-key-1"
ODH_NS="${ODH_APPLICATIONS_NS:-redhat-ods-applications}"
FAILS=0

pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; FAILS=$((FAILS + 1)); }

command -v oc >/dev/null || { echo "oc missing"; exit 1; }
oc whoami >/dev/null || { echo "not logged in"; exit 1; }

READY="$(oc get inferenceservice "${MODEL_ID}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
[[ "${READY}" == "True" ]] && pass "InferenceService ${MODEL_ID} Ready" || fail "InferenceService not Ready"

oc get svc "${MODEL_SERVICE}" -n "${MODEL_NAMESPACE}" >/dev/null 2>&1 \
  && pass "Service ${MODEL_SERVICE} exists" || fail "Service missing"

FLAG="$(oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" -o jsonpath='{.spec.dashboardConfig.aiAssetCustomEndpoints}' 2>/dev/null || true)"
[[ "${FLAG}" == "true" ]] && pass "aiAssetCustomEndpoints=true" || fail "aiAssetCustomEndpoints not true (got: ${FLAG:-absent})"

oc -n "${PACKMATE_NS}" get cm "${CM_NAME}" >/dev/null 2>&1 \
  && pass "ConfigMap/${CM_NAME} in ${PACKMATE_NS}" || fail "ConfigMap missing"

CFG="$(oc -n "${PACKMATE_NS}" get cm "${CM_NAME}" -o jsonpath='{.data.config\.yaml}' 2>/dev/null || true)"
printf '%s' "${CFG}" | grep -Fq "display_name: ${DISPLAY_NAME}" \
  && pass "display_name=${DISPLAY_NAME}" || fail "display_name missing"
printf '%s' "${CFG}" | grep -Fq "${MODEL_NAMESPACE}.svc.cluster.local" \
  && pass "URL points at ${MODEL_NAMESPACE}" || fail "URL does not reference ${MODEL_NAMESPACE}"
printf '%s' "${CFG}" | grep -Fq "model_id: ${MODEL_ID}" \
  && pass "model_id=${MODEL_ID}" || fail "model_id missing"

oc -n "${PACKMATE_NS}" get secret "${SECRET_NAME}" >/dev/null 2>&1 \
  && pass "Secret/${SECRET_NAME} present (value not printed)" || fail "Secret missing"

# MCP registration (platform ConfigMap) — expect Packmate keys when lab is fully bootstrapped
if oc get cm gen-ai-aa-mcp-servers -n "${ODH_NS}" >/dev/null 2>&1; then
  MCP_DATA="$(oc get cm gen-ai-aa-mcp-servers -n "${ODH_NS}" -o json)"
  printf '%s' "${MCP_DATA}" | grep -q 'Packmate-Weather-MCP' \
    && pass "MCP Packmate-Weather-MCP registered" || fail "Packmate-Weather-MCP missing"
  printf '%s' "${MCP_DATA}" | grep -q 'Packmate-Baggage-Policy-MCP' \
    && pass "MCP Packmate-Baggage-Policy-MCP registered" || fail "Packmate-Baggage-Policy-MCP missing"
else
  fail "ConfigMap gen-ai-aa-mcp-servers absent in ${ODH_NS}"
fi

# No model Route should exist in the model namespace
if oc get route -n "${MODEL_NAMESPACE}" 2>/dev/null | grep -qi llama; then
  fail "Unexpected llama Route in ${MODEL_NAMESPACE}"
else
  pass "No llama Route in ${MODEL_NAMESPACE}"
fi

RUNNING="$(oc get pods -n "${MODEL_NAMESPACE}" -l "serving.kserve.io/inferenceservice=${MODEL_ID}" \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')"
[[ "${RUNNING}" -ge 1 ]] && pass "At least one Running predictor pod (${RUNNING})" \
  || fail "No Running predictor pod"

echo
echo "UI_REFRESH_REQUIRED"
echo "Gen AI studio → AI asset endpoints → Project: Packmate Lab → Models"
echo "Gen AI studio → Playground → Project: Packmate Lab"
echo

if [[ "${FAILS}" -gt 0 ]]; then
  echo "verify-sandbox: ${FAILS} check(s) failed"
  exit 1
fi
echo "verify-sandbox: OK"
