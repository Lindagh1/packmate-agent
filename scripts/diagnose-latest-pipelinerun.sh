#!/usr/bin/env bash
# Diagnose the latest (or named) Packmate PipelineRun — non-destructive.
# Emphasizes Pending / FailedMount / missing GHCR Secret conditions.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && set -a && source "${ROOT}/config/sandbox.env" && set +a || true
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/report.sh" 2>/dev/null || true

NS="${PACKMATE_NAMESPACE:-packmate-lab}"
PUSH_SECRET="${PACKMATE_PROMOTION_PUSH_SECRET:-packmate-ghcr-push}"
PR="${1:-}"

if ! command -v oc >/dev/null 2>&1 || ! oc whoami >/dev/null 2>&1; then
  printf 'BLOCKED_OPENSHIFT_AUTHENTICATION\n'
  printf 'ACTION  oc login --web\n'
  exit 2
fi

if [[ -z "${PR}" ]]; then
  PR="$(oc get pipelinerun -n "${NS}" -l tekton.dev/pipeline=packmate-ci \
    --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || true)"
fi
[[ -n "${PR}" ]] || {
  printf 'FAIL    No packmate-ci PipelineRun found in %s\n' "${NS}"
  printf 'ACTION  Start a PipelineRun from the UI or: oc create -n %s -f .tekton/lab/packmate-ci-run.yaml\n' "${NS}"
  exit 1
}

printf '=== Packmate diagnose-latest-pipelinerun ===\n'
printf 'namespace=%s pipelinerun=%s\n\n' "${NS}" "${PR}"

oc get pipelinerun "${PR}" -n "${NS}" -o wide 2>&1 || true
printf '\n'
oc get taskrun -n "${NS}" -l tekton.dev/pipelineRun="${PR}" \
  -o custom-columns='NAME:.metadata.name,REASON:.status.conditions[0].reason,MSG:.status.conditions[0].message' 2>&1 || true

printf '\n--- Promotion Secret ---\n'
if oc -n "${NS}" get secret "${PUSH_SECRET}" >/dev/null 2>&1; then
  printf 'PASS    Secret/%s present in %s\n' "${PUSH_SECRET}" "${NS}"
else
  printf 'FAIL    Secret/%s missing in %s\n' "${PUSH_SECRET}" "${NS}"
  printf 'DETAIL  publish-candidate mounts this Secret; absence causes FailedMount and PodReadyToStartContainers=False\n'
  printf 'ACTION  make configure-promotion-registry && make verify-promotion-registry\n'
fi

# Pending publish-candidate diagnostics
PEND="$(oc get taskrun -n "${NS}" -l tekton.dev/pipelineRun="${PR}",tekton.dev/pipelineTask=publish-candidate \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "${PEND}" ]]; then
  reason="$(oc get taskrun "${PEND}" -n "${NS}" -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || true)"
  pod="$(oc get pods -n "${NS}" -l tekton.dev/taskRun="${PEND}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  printf '\n--- publish-candidate ---\n'
  printf 'taskrun=%s reason=%s pod=%s\n' "${PEND}" "${reason}" "${pod:-none}"
  if [[ -n "${pod}" ]]; then
    oc get pod "${pod}" -n "${NS}" -o wide 2>&1 || true
    printf '\nPod conditions:\n'
    oc get pod "${pod}" -n "${NS}" \
      -o jsonpath='{range .status.conditions[*]}{"TYPE="}{.type}{" STATUS="}{.status}{" REASON="}{.reason}{" MESSAGE="}{.message}{"\n"}{end}' 2>&1 || true
    printf '\nRecent pod events:\n'
    oc get events -n "${NS}" --field-selector "involvedObject.name=${pod}" --sort-by=.lastTimestamp 2>&1 | tail -20 || true
    if oc get events -n "${NS}" --field-selector "involvedObject.name=${pod}" 2>/dev/null \
      | grep -q 'secret.*packmate-ghcr-push.*not found\|FailedMount.*ghcr-push'; then
      printf '\nFAIL    FailedMount on volume ghcr-push (Secret packmate-ghcr-push)\n'
      printf 'DETAIL  PodReadyToStartContainers stays False until the Secret exists\n'
      printf 'ACTION  make configure-promotion-registry; then start a new PipelineRun (do not delete evidence runs)\n'
    fi
  fi
fi

printf '\n--- Pipeline results (if any) ---\n'
oc get pipelinerun "${PR}" -n "${NS}" -o jsonpath='{range .status.results[*]}{.name}={.value}{"\n"}{end}' 2>&1 || true
printf '\ndiagnose-latest-pipelinerun: done\n'
