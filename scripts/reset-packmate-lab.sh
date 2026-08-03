#!/usr/bin/env bash
# Safe Packmate lab reset. Default is dry-run only.
# Destructive mode requires:
#   CONFIRM_PACKMATE_RESET=packmate-lab-and-prod make reset-lab
#
# Never deletes: my-first-model, Operators, shared openshift-gitops instance,
# unrelated Argo RBAC, GHCR images, Git tags/releases, or canonical repo resources.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && set -a && source "${ROOT}/config/sandbox.env" && set +a || true

LAB_NS="${PACKMATE_DEV_NAMESPACE:-${PACKMATE_NAMESPACE:-packmate-lab}}"
PROD_NS="${PACKMATE_PROD_NAMESPACE:-packmate-prod}"
ARGO_NS="${ARGOCD_NAMESPACE:-openshift-gitops}"
GROUP="${PACKMATE_ARGO_GROUP:-packmate-lab-users}"
ODH_NS="${ODH_APPLICATIONS_NS:-redhat-ods-applications}"
MODEL_NS="${MODEL_NAMESPACE:-my-first-model}"
CONFIRM_REQUIRED="packmate-lab-and-prod"
TIMEOUT_SECONDS="${PACKMATE_RESET_TIMEOUT_SECONDS:-300}"
REMOVE_MCP_KEYS=false
if oc -n "${ODH_NS}" get configmap gen-ai-aa-mcp-servers -o jsonpath='{.data}' 2>/dev/null | grep -q 'Packmate'; then
  REMOVE_MCP_KEYS=true
fi

DRY_RUN=true
if [[ "${CONFIRM_PACKMATE_RESET:-}" == "${CONFIRM_REQUIRED}" ]]; then
  DRY_RUN=false
fi

die() { printf 'FAIL    %s\n' "$1" >&2; [[ -n "${2:-}" ]] && printf 'DETAIL  %s\n' "$2" >&2; [[ -n "${3:-}" ]] && printf 'ACTION  %s\n' "$3" >&2; exit 1; }

printf '=== Packmate reset-lab ===\n'
printf 'mode=%s lab=%s prod=%s argo=%s group=%s\n\n' \
  "$([[ "${DRY_RUN}" == "true" ]] && echo DRY-RUN || echo DESTRUCTIVE)" \
  "${LAB_NS}" "${PROD_NS}" "${ARGO_NS}" "${GROUP}"

# Safety guards
[[ "${LAB_NS}" != "${MODEL_NS}" ]] || die "Refusing to target model namespace"
[[ "${PROD_NS}" != "${MODEL_NS}" ]] || die "Refusing to target model namespace"
[[ "${LAB_NS}" == "packmate-lab" ]] || die "LAB_NS must be packmate-lab" "got ${LAB_NS}" "Unset PACKMATE_DEV_NAMESPACE overrides for reset"
[[ "${PROD_NS}" == "packmate-prod" ]] || die "PROD_NS must be packmate-prod" "got ${PROD_NS}" "Unset PACKMATE_PROD_NAMESPACE overrides for reset"

command -v oc >/dev/null 2>&1 || die "oc CLI not found"
oc whoami >/dev/null 2>&1 || die "BLOCKED_OPENSHIFT_AUTHENTICATION" "oc whoami failed" "oc login --web"

plan=()
add() { plan+=("$1"); printf 'PLAN    %s\n' "$1"; }

printf '%s\n' '--- Allowlisted deletion plan ---'
if oc -n "${ARGO_NS}" get application.argoproj.io packmate-lab >/dev/null 2>&1; then
  add "delete Application/packmate-lab -n ${ARGO_NS}"
fi
if oc -n "${ARGO_NS}" get application.argoproj.io packmate-prod >/dev/null 2>&1; then
  add "delete Application/packmate-prod -n ${ARGO_NS}"
fi
if oc -n "${ARGO_NS}" get appproject.argoproj.io packmate >/dev/null 2>&1; then
  add "delete AppProject/packmate -n ${ARGO_NS}"
fi
if oc get group "${GROUP}" >/dev/null 2>&1; then
  add "delete Group/${GROUP} (Packmate-only group)"
fi
if oc get ns "${LAB_NS}" >/dev/null 2>&1; then
  add "delete namespace/${LAB_NS}"
fi
if oc get ns "${PROD_NS}" >/dev/null 2>&1; then
  add "delete namespace/${PROD_NS}"
fi
if [[ -d "${ROOT}/.generated" ]]; then
  add "remove local ${ROOT}/.generated (generated Pipeline/acceptance artifacts)"
fi
if [[ "${REMOVE_MCP_KEYS}" == "true" ]]; then
  add "remove only Packmate-* keys from ConfigMap/gen-ai-aa-mcp-servers in ${ODH_NS} (preserve all other keys)"
fi

printf '\n%s\n' '--- Never deleted ---'
printf 'KEEP    namespace/%s (shared model)\n' "${MODEL_NS}"
printf 'KEEP    InferenceService/llama-32-3b-instruct\n'
printf 'KEEP    Operators (AI / Pipelines / GitOps)\n'
printf 'KEEP    namespace/%s and ArgoCD instance\n' "${ARGO_NS}"
printf 'KEEP    unrelated Argo CD rbac.policy lines\n'
printf 'KEEP    ConfigMap/gen-ai-aa-mcp-servers itself and non-Packmate keys\n'
printf 'KEEP    GHCR images, Git tags, GitHub Releases, canonical repository\n'
printf 'KEEP    Git branches on forks (manual cleanup if desired)\n'

if [[ "${#plan[@]}" -eq 0 ]]; then
  printf '\nINFO    Nothing Packmate-exclusive found to delete\n'
  printf 'reset-lab: OK (no-op)\n'
  exit 0
fi

if [[ "${DRY_RUN}" == "true" ]]; then
  printf '\nINFO    Dry-run only — no deletions performed\n'
  printf 'ACTION  To execute: CONFIRM_PACKMATE_RESET=%s make reset-lab\n' "${CONFIRM_REQUIRED}"
  printf 'reset-lab: DRY-RUN complete\n'
  exit 0
fi

printf '\nWARN    Executing destructive Packmate reset\n'
# Delete Applications first so they stop recreating namespaces/resources
for app in packmate-lab packmate-prod; do
  if oc -n "${ARGO_NS}" get application.argoproj.io "${app}" >/dev/null 2>&1; then
    oc -n "${ARGO_NS}" delete application.argoproj.io "${app}" --wait=false
    printf 'OK      deleted Application/%s\n' "${app}"
  fi
done
if oc -n "${ARGO_NS}" get appproject.argoproj.io packmate >/dev/null 2>&1; then
  oc -n "${ARGO_NS}" delete appproject.argoproj.io packmate --wait=false
  printf 'OK      deleted AppProject/packmate\n'
fi
if oc get group "${GROUP}" >/dev/null 2>&1; then
  oc delete group "${GROUP}"
  printf 'OK      deleted Group/%s\n' "${GROUP}"
fi

for ns in "${LAB_NS}" "${PROD_NS}"; do
  if oc get ns "${ns}" >/dev/null 2>&1; then
    phase="$(oc get ns "${ns}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "${phase}" == "Terminating" ]]; then
      die "Namespace ${ns} stuck Terminating" \
        "Will not remove finalizers automatically" \
        "Inspect: oc get ns ${ns} -o yaml | grep -A20 finalizers; oc get all -n ${ns}"
    fi
    oc delete project "${ns}" --wait=false
    printf 'OK      delete requested for namespace/%s\n' "${ns}"
  fi
done

# Wait for namespaces
deadline=$((SECONDS + TIMEOUT_SECONDS))
for ns in "${LAB_NS}" "${PROD_NS}"; do
  while oc get ns "${ns}" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      phase="$(oc get ns "${ns}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
      die "Timed out waiting for namespace/${ns} deletion" \
        "phase=${phase}" \
        "Do not remove finalizers automatically; inspect blocking resources"
    fi
    sleep 5
  done
  printf 'OK      namespace/%s gone\n' "${ns}"
done

if [[ -d "${ROOT}/.generated" ]]; then
  rm -rf "${ROOT}/.generated"
  printf 'OK      removed .generated/\n'
fi

# Remove only Packmate-* keys from shared MCP ConfigMap
if [[ "${REMOVE_MCP_KEYS}" == "true" ]]; then
  python3 - "${ODH_NS}" <<'PY'
import json, subprocess, sys
ns = sys.argv[1]
r = subprocess.run(["oc", "-n", ns, "get", "configmap", "gen-ai-aa-mcp-servers", "-o", "json"],
                   capture_output=True, text=True, check=True)
cm = json.loads(r.stdout)
data = cm.get("data") or {}
removed = [k for k in list(data) if k.startswith("Packmate")]
for k in removed:
    del data[k]
if not removed:
    print("OK      no Packmate MCP keys to remove")
    sys.exit(0)
patch = {"data": {k: None for k in removed}}
# Use strategic merge with null to delete keys via oc patch
subprocess.run(
    ["oc", "-n", ns, "patch", "configmap", "gen-ai-aa-mcp-servers", "--type", "merge",
     "-p", json.dumps({"data": {k: None for k in removed}})],
    check=False,
)
# Merge patch may not delete keys; fall back to replace data map
r2 = subprocess.run(["oc", "-n", ns, "get", "configmap", "gen-ai-aa-mcp-servers", "-o", "json"],
                    capture_output=True, text=True, check=True)
cm2 = json.loads(r2.stdout)
cm2["data"] = {k: v for k, v in (cm2.get("data") or {}).items() if not k.startswith("Packmate")}
subprocess.run(["oc", "-n", ns, "apply", "-f", "-"], input=json.dumps(cm2), text=True, check=True)
print(f"OK      removed Packmate MCP keys: {', '.join(removed)}")
PY
fi

# Verify shared model untouched
if ! oc -n "${MODEL_NS}" get inferenceservice.serving.kserve.io llama-32-3b-instruct >/dev/null 2>&1; then
  printf 'WARN    Shared model InferenceService not found — investigate platform separately (Packmate did not delete it by design)\n'
else
  printf 'OK      shared model InferenceService still present\n'
fi

printf '\nreset-lab: OK (destructive)\n'
printf 'ACTION  Re-create Data Science Project packmate-lab and Workbench before the next participant run\n'
exit 0
