#!/usr/bin/env bash
# Non-destructive Packmate sandbox verification.
# Exit 0 only if the mandatory lab core is ready.
# Absence of Rollouts / EvalHub / GitOps does not fail the verify.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh"

packmate_require_oc
if [[ -f "${ROOT}/config/sandbox.env" ]]; then
  packmate_load_config "${ROOT}" || exit 1
else
  PACKMATE_NAMESPACE="${PACKMATE_NAMESPACE:-packmate-lab}"
  MODEL_NAMESPACE="${MODEL_NAMESPACE:-my-first-model}"
  MODEL_SERVICE="${MODEL_SERVICE:-llama-32-3b-instruct-predictor}"
  MODEL_ID="${MODEL_ID:-llama-32-3b-instruct}"
  ODH_APPLICATIONS_NS="${ODH_APPLICATIONS_NS:-redhat-ods-applications}"
fi

FAILS=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; FAILS=$((FAILS + 1)); }
info() { printf 'INFO  %s\n' "$*"; }

printf '=== Packmate verify (%s) ===\n' "${PACKMATE_NAMESPACE}"

# DSP labels (best-effort)
if oc get project "${PACKMATE_NAMESPACE}" -o jsonpath='{.metadata.labels}' 2>/dev/null | grep -q opendatahub; then
  pass "Data Science Project labels present"
else
  info "opendatahub labels not detected on project (may still be valid DSP)"
fi

READY="$(oc get inferenceservice "${MODEL_ID}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
[[ "${READY}" == "True" ]] && pass "Model ${MODEL_ID} Ready" || fail "Model not Ready"

for d in weather-mcp baggage-policy-mcp packmate-backend packmate-frontend; do
  avail="$(oc -n "${PACKMATE_NAMESPACE}" get deploy "${d}" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo 0)"
  [[ "${avail}" != "" && "${avail}" != "0" ]] && pass "deploy/${d} available=${avail}" || fail "deploy/${d} not available"
done

ROUTE_HOST="$(oc -n "${PACKMATE_NAMESPACE}" get route packmate-frontend -o jsonpath='{.spec.host}' 2>/dev/null || true)"
if [[ -n "${ROUTE_HOST}" ]]; then
  code="$(curl -sk -o /dev/null -w '%{http_code}' -m 25 "https://${ROUTE_HOST}/" || echo 000)"
  [[ "${code}" == "200" ]] && pass "Frontend Route HTTP ${code}" || fail "Frontend Route HTTP ${code}"
else
  fail "Frontend Route missing"
fi

# Backend health + metrics in-cluster (Route /api/* preserves /api prefix; probes use Service)
if oc -n "${PACKMATE_NAMESPACE}" get deploy packmate-backend >/dev/null 2>&1; then
  if oc -n "${PACKMATE_NAMESPACE}" exec deploy/packmate-backend -- \
      curl -sf -m 15 http://127.0.0.1:8080/health >/dev/null 2>&1; then
    pass "Backend /health via pod"
  else
    fail "Backend /health via pod"
  fi
  if oc -n "${PACKMATE_NAMESPACE}" exec deploy/packmate-backend -- \
      curl -sf -m 15 http://127.0.0.1:8080/ready >/dev/null 2>&1; then
    pass "Backend /ready via pod"
  else
    fail "Backend /ready via pod"
  fi
  metrics="$(oc -n "${PACKMATE_NAMESPACE}" exec deploy/packmate-backend -- \
    curl -sf -m 15 http://127.0.0.1:8080/metrics 2>/dev/null || true)"
  printf '%s' "${metrics}" | grep -q 'packmate_' && pass "Metrics expose packmate_* series" || fail "Metrics missing packmate_*"
fi

# MCP routes
for r in weather-mcp baggage-policy-mcp; do
  h="$(oc -n "${PACKMATE_NAMESPACE}" get route "${r}" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
  if [[ -n "${h}" ]]; then
    code="$(curl -sk -o /dev/null -w '%{http_code}' -m 20 "https://${h}/health" || echo 000)"
    [[ "${code}" == "200" ]] && pass "Route ${r} /health ${code}" || fail "Route ${r} /health ${code}"
  else
    fail "Route ${r} missing"
  fi
done

# MCP ConfigMap
if oc get cm gen-ai-aa-mcp-servers -n "${ODH_APPLICATIONS_NS}" >/dev/null 2>&1; then
  data="$(oc get cm gen-ai-aa-mcp-servers -n "${ODH_APPLICATIONS_NS}" -o json)"
  printf '%s' "${data}" | grep -q Packmate-Weather-MCP && pass "MCP Packmate-Weather-MCP registered" || fail "Weather MCP not registered"
  printf '%s' "${data}" | grep -q Packmate-Baggage-Policy-MCP && pass "MCP Packmate-Baggage-Policy-MCP registered" || fail "Baggage MCP not registered"
else
  fail "gen-ai-aa-mcp-servers ConfigMap missing"
fi

# SSE + heartbeats
if [[ -n "${ROUTE_HOST}" ]]; then
  export PACKMATE_API="https://${ROUTE_HOST}"
  if bash "${ROOT}/scripts/test-streaming-smoke.sh" >/tmp/packmate-verify-sse.txt 2>&1; then
    pass "SSE smoke OK"
    grep -q 'heartbeats' /tmp/packmate-verify-sse.txt && pass "Heartbeats observed in SSE stream" || info "Heartbeat count not printed"
  else
    fail "SSE smoke failed (see /tmp/packmate-verify-sse.txt)"
  fi
fi

# Images without latest
imgs="$(oc -n "${PACKMATE_NAMESPACE}" get deploy -o jsonpath='{range .items[*]}{.spec.template.spec.containers[*].image}{"\n"}{end}' 2>/dev/null || true)"
if printf '%s' "${imgs}" | grep -q ':latest'; then
  fail "Deployment image uses :latest"
else
  pass "No :latest image tags on Deployments"
fi

# Secrets not in git
if git -C "${ROOT}" ls-files | grep -E '(^|/)\.env$|sandbox\.env$' >/dev/null; then
  fail "Secret-like env file tracked in git"
else
  pass "No sandbox.env/.env tracked in git"
fi

# Pipeline (optional for fail)
if oc -n "${PACKMATE_NAMESPACE}" get pipeline.tekton.dev packmate-ci >/dev/null 2>&1; then
  pass "Pipeline/packmate-ci present (tekton.dev)"
else
  info "Pipeline/packmate-ci absent (OK if Pipelines skipped)"
fi

# Argo CD
if oc get application.argoproj.io packmate-lab -n openshift-gitops >/dev/null 2>&1; then
  pass "Argo CD Application/packmate-lab present"
elif oc get crd applications.argoproj.io >/dev/null 2>&1; then
  info "GitOps CRD present but Application not applied"
else
  info "GITOPS_OPERATOR_REQUIRED — Argo CD module is documentation-only on this cluster"
fi

# Rollouts / EvalHub never fail verify
if oc get crd rollouts.argoproj.io >/dev/null 2>&1; then
  info "Rollouts available (optional annex)"
else
  info "ROLLOUTS OPTIONAL_UNAVAILABLE"
fi
if oc get evalhubs -A --no-headers 2>/dev/null | grep -q .; then
  info "EvalHub instance present"
else
  info "EVALHUB_OPTIONAL_NOT_CONFIGURED"
fi

# Quality gate + security (local)
if [[ -x "${ROOT}/backend/.venv/bin/python" ]] || [[ -d "${ROOT}/backend" ]]; then
  if bash "${ROOT}/evaluations/scripts/run_deterministic_gate.sh" >/tmp/packmate-verify-qg.txt 2>&1; then
    pass "Quality gate deterministic PASSED"
    grep -E 'Overall|score|QUALITY|0\.9' /tmp/packmate-verify-qg.txt | head -5 || true
  else
    fail "Quality gate failed"
  fi
fi
if bash "${ROOT}/scripts/security-check.sh" >/tmp/packmate-verify-sec.txt 2>&1; then
  pass "security-check passed"
else
  fail "security-check failed"
fi

printf '\n'
if [[ "${FAILS}" -gt 0 ]]; then
  printf 'verify-sandbox: %s mandatory check(s) failed\n' "${FAILS}"
  exit 1
fi
printf 'verify-sandbox: OK (lab core ready)\n'
exit 0
