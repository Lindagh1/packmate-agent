#!/usr/bin/env bash
# Non-destructive PROD verification (packmate-prod after Argo CD Sync).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh"

packmate_require_oc
if [[ -f "${ROOT}/config/sandbox.env" ]]; then
  packmate_load_config "${ROOT}" || exit 1
fi
NS="${PACKMATE_PROD_NAMESPACE:-packmate-prod}"
FAILS=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; FAILS=$((FAILS + 1)); }
info() { printf 'INFO  %s\n' "$*"; }

printf '=== Packmate verify-prod (%s) ===\n' "${NS}"

oc get project "${NS}" >/dev/null 2>&1 && pass "namespace ${NS} exists" || fail "namespace ${NS} missing"

# Must NOT look like a DSP / lab project
labels="$(oc get namespace "${NS}" -o jsonpath='{.metadata.labels}' 2>/dev/null || true)"
printf '%s' "${labels}" | grep -q 'packmate.io/environment.:prod\|packmate.io/environment=prod\|"packmate.io/environment":"prod"' \
  && pass "prod environment label" || info "prod label not detected (may still be valid)"
if printf '%s' "${labels}" | grep -q 'opendatahub.io/dashboard'; then
  fail "PROD must not be a Data Science Project (opendatahub dashboard label)"
else
  pass "PROD is not labeled as Data Science Project"
fi

# No lab-only kinds
for kind in notebook.kubeflow.org pipeline.tekton.dev pipelinerun.tekton.dev; do
  if oc -n "${NS}" get "${kind}" --no-headers 2>/dev/null | grep -q .; then
    fail "unexpected ${kind} in PROD"
  else
    pass "no ${kind} in PROD"
  fi
done

if oc -n "${NS}" get cm gen-ai-aa-custom-model-endpoints >/dev/null 2>&1; then
  fail "custom model endpoint ConfigMap must not exist in PROD"
else
  pass "no custom model endpoint in PROD"
fi

oc -n "${NS}" get secret packmate-prod-llm >/dev/null 2>&1 \
  && pass "Secret packmate-prod-llm present (values not shown)" \
  || fail "Secret packmate-prod-llm missing"

for d in weather-mcp baggage-policy-mcp packmate-backend packmate-frontend; do
  avail="$(oc -n "${NS}" get deploy "${d}" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)"
  [[ "${avail}" != "" && "${avail}" != "0" ]] && pass "deploy/${d} available=${avail}" || fail "deploy/${d} not available"
done

# No Llama InferenceService in PROD
if oc -n "${NS}" get inferenceservice 2>/dev/null | grep -qi llama; then
  fail "No Llama InferenceService in PROD"
else
  pass "No Llama InferenceService in PROD"
fi

ROUTE_HOST="$(oc -n "${NS}" get route packmate-frontend -o jsonpath='{.spec.host}' 2>/dev/null || true)"
if [[ -n "${ROUTE_HOST}" ]]; then
  code="$(curl -sk -o /dev/null -w '%{http_code}' -m 30 "https://${ROUTE_HOST}/" || echo 000)"
  [[ "${code}" == "200" ]] && pass "PROD frontend Route HTTP ${code}" || fail "PROD frontend Route HTTP ${code}"
  export PACKMATE_API="https://${ROUTE_HOST}"
  if bash "${ROOT}/scripts/test-streaming-smoke.sh" >/tmp/packmate-verify-prod-sse.txt 2>&1; then
    pass "PROD SSE smoke OK"
  else
    fail "PROD SSE smoke failed"
  fi
else
  fail "PROD frontend Route missing"
fi

# Images digest-pinned / no latest
imgs="$(oc -n "${NS}" get deploy -o jsonpath='{range .items[*]}{.spec.template.spec.containers[*].image}{"\n"}{end}' 2>/dev/null || true)"
if printf '%s' "${imgs}" | grep -q ':latest'; then
  fail "PROD Deployment uses :latest"
else
  pass "No :latest on PROD Deployments"
fi

printf '\n'
if [[ "${FAILS}" -gt 0 ]]; then
  printf 'verify-prod: %s check(s) failed\n' "${FAILS}"
  exit 1
fi
printf 'verify-prod: OK\n'
exit 0
