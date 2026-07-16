#!/usr/bin/env bash
# Interactive cleanup for the Packmate lab namespace ONLY.
# Never run this from automation without an explicit human confirmation.
set -euo pipefail

NAMESPACE="${PACKMATE_CLEANUP_NAMESPACE:-packmate-lab}"
PROTECTED_MODEL_NS="my-first-model"

if [[ "${NAMESPACE}" != "packmate-lab" ]]; then
  echo "Refusing to run: namespace must be packmate-lab (got: ${NAMESPACE})" >&2
  exit 1
fi

if [[ "${NAMESPACE}" == "${PROTECTED_MODEL_NS}" ]]; then
  echo "Refusing to touch model namespace ${PROTECTED_MODEL_NS}" >&2
  exit 1
fi

echo "=== Packmate cleanup preview ==="
echo "Target namespace: ${NAMESPACE}"
echo "Will NOT touch: ${PROTECTED_MODEL_NS}, Operators, ClusterRoles, or other projects."
echo
echo "Resources currently in ${NAMESPACE}:"
oc get all,route,networkpolicy,configmap,secret,sa,pvc,bc,is -n "${NAMESPACE}" 2>/dev/null || true
echo
echo "Optional platform ConfigMap entries (NOT deleted by default):"
echo "  ConfigMap/gen-ai-aa-mcp-servers in redhat-ods-applications"
echo "  (contains Packmate MCP registration; remove manually if desired)"
echo

read -r -p "Type DELETE-PACKMATE-LAB to permanently delete project ${NAMESPACE}: " CONFIRM
if [[ "${CONFIRM}" != "DELETE-PACKMATE-LAB" ]]; then
  echo "Aborted. No changes made."
  exit 0
fi

echo "Deleting project ${NAMESPACE}..."
oc delete project "${NAMESPACE}"
echo "Done. Model namespace ${PROTECTED_MODEL_NS} was not modified."
echo "Remember: MCP ConfigMap in redhat-ods-applications was left intact."
