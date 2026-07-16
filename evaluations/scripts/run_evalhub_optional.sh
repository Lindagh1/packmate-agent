#!/usr/bin/env bash
# Optional Level 2 EvalHub runner — never applies manifests.
# Exits 0 with SKIP when EvalHub CRD or instances are absent.
set -euo pipefail

NAMESPACE="${EVALHUB_NAMESPACE:-}"
SKIP_MSG="EvalHub not available on cluster; skipping Level 2 eval (preparatory assets only)."

if ! command -v oc >/dev/null 2>&1; then
  echo "SKIP: oc CLI not found. ${SKIP_MSG}"
  exit 0
fi

if ! oc api-resources --api-group=trustyai.opendatahub.io --namespaced=true -o name 2>/dev/null | grep -q '^evalhubs\.trustyai\.opendatahub\.io$'; then
  echo "SKIP: EvalHub CRD not found. ${SKIP_MSG}"
  exit 0
fi

if [[ -n "${NAMESPACE}" ]]; then
  INSTANCES="$(oc get evalhubs -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l | tr -d ' ')"
else
  INSTANCES="$(oc get evalhubs -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
fi

if [[ "${INSTANCES}" == "0" ]]; then
  echo "SKIP: No EvalHub instances found. ${SKIP_MSG}"
  echo "See evaluations/evalhub/ for example CR (not applied in CI)."
  exit 0
fi

echo "EvalHub CRD and instance(s) detected."
echo "Level 2 EvalHub execution is instructor-defined; this script does not apply or trigger jobs."
echo "Configure your EvalHub instance to use evaluations/datasets/packmate_eval_dataset.jsonl."
exit 0
