#!/usr/bin/env bash
# Read-only discovery of Packmate-related resources after partial teardown.
# Never prints Secret data. Classifies EXPECTED_SHARED / PACKMATE_EXCLUSIVE /
# STALE_PACKMATE / UNKNOWN_REVIEW_REQUIRED.
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

report() {
  # class | api | kind | ns | name | note
  printf '%-24s %-28s %-22s %-28s %-40s %s\n' "$1" "$2" "$3" "$4" "$5" "$6"
}

printf '=== Packmate discover-packmate-resources (read-only) ===\n'
printf 'lab=%s prod=%s argo=%s group=%s model=%s\n\n' \
  "${LAB_NS}" "${PROD_NS}" "${ARGO_NS}" "${GROUP}" "${MODEL_NS}"

if ! command -v oc >/dev/null 2>&1; then
  printf 'BLOCKED oc CLI not found\n'
  printf 'ACTION  Install oc and re-run\n'
  exit 2
fi
if ! oc whoami >/dev/null 2>&1; then
  printf 'BLOCKED_OPENSHIFT_AUTHENTICATION\n'
  printf 'DETAIL  oc whoami failed\n'
  printf 'ACTION  Log in again: oc login --web   (or your cluster login command)\n'
  exit 2
fi
if ! oc get --raw=/readyz >/dev/null 2>&1; then
  printf 'BLOCKED OpenShift API /readyz unavailable\n'
  printf 'ACTION  Check cluster health / VPN; do not run bootstrap\n'
  exit 2
fi

printf '%-24s %-28s %-22s %-28s %-40s %s\n' \
  "CLASS" "API" "KIND" "NAMESPACE" "NAME" "NOTE"
printf '%s\n' "------------------------------------------------------------------------------------------------------------------------------------------"

STALE=0
EXCLUSIVE=0
SHARED=0
UNKNOWN=0

emit() {
  local class="$1"
  report "$@"
  case "${class}" in
    STALE_PACKMATE) STALE=$((STALE + 1)) ;;
    PACKMATE_EXCLUSIVE) EXCLUSIVE=$((EXCLUSIVE + 1)) ;;
    EXPECTED_SHARED) SHARED=$((SHARED + 1)) ;;
    UNKNOWN_REVIEW_REQUIRED) UNKNOWN=$((UNKNOWN + 1)) ;;
  esac
}

lab_exists=false
prod_exists=false
oc get ns "${LAB_NS}" >/dev/null 2>&1 && lab_exists=true
oc get ns "${PROD_NS}" >/dev/null 2>&1 && prod_exists=true

if [[ "${lab_exists}" == "true" ]]; then
  phase="$(oc get ns "${LAB_NS}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  emit PACKMATE_EXCLUSIVE "(core)" Namespace "-" "${LAB_NS}" "phase=${phase}"
else
  printf 'INFO    namespace/%s absent\n' "${LAB_NS}"
fi
if [[ "${prod_exists}" == "true" ]]; then
  phase="$(oc get ns "${PROD_NS}" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  emit PACKMATE_EXCLUSIVE "(core)" Namespace "-" "${PROD_NS}" "phase=${phase}"
else
  printf 'INFO    namespace/%s absent\n' "${PROD_NS}"
fi

if oc get ns "${MODEL_NS}" >/dev/null 2>&1; then
  emit EXPECTED_SHARED "(core)" Namespace "-" "${MODEL_NS}" "must never be deleted by Packmate"
fi
if oc get ns "${ARGO_NS}" >/dev/null 2>&1; then
  emit EXPECTED_SHARED "(core)" Namespace "-" "${ARGO_NS}" "shared GitOps namespace"
fi

# Argo objects
if oc -n "${ARGO_NS}" get appproject.argoproj.io packmate >/dev/null 2>&1; then
  class=PACKMATE_EXCLUSIVE
  if [[ "${lab_exists}" != "true" && "${prod_exists}" != "true" ]]; then
    class=STALE_PACKMATE
  fi
  emit "${class}" argoproj.io AppProject "${ARGO_NS}" packmate "sourceRepos/roles for Packmate"
fi

for app in packmate-lab packmate-prod; do
  if oc -n "${ARGO_NS}" get application.argoproj.io "${app}" >/dev/null 2>&1; then
    repo="$(oc -n "${ARGO_NS}" get application.argoproj.io "${app}" -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || true)"
    rev="$(oc -n "${ARGO_NS}" get application.argoproj.io "${app}" -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || true)"
    sync="$(oc -n "${ARGO_NS}" get application.argoproj.io "${app}" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health="$(oc -n "${ARGO_NS}" get application.argoproj.io "${app}" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    dest="$(oc -n "${ARGO_NS}" get application.argoproj.io "${app}" -o jsonpath='{.spec.destination.namespace}' 2>/dev/null || true)"
    class=PACKMATE_EXCLUSIVE
    note="repo=${repo} rev=${rev} sync=${sync} health=${health} dest=${dest}"
    if [[ "${lab_exists}" != "true" && "${prod_exists}" != "true" ]]; then
      class=STALE_PACKMATE
      note="${note} | namespaces deleted — Application residue"
    elif [[ "${app}" == "packmate-lab" && "${lab_exists}" != "true" ]]; then
      class=STALE_PACKMATE
      note="${note} | lab namespace missing"
    elif [[ "${app}" == "packmate-prod" && "${prod_exists}" != "true" ]]; then
      class=STALE_PACKMATE
      note="${note} | prod namespace missing"
    fi
    emit "${class}" argoproj.io Application "${ARGO_NS}" "${app}" "${note}"
  fi
done

# Group
if oc get group "${GROUP}" >/dev/null 2>&1; then
  class=PACKMATE_EXCLUSIVE
  if [[ "${lab_exists}" != "true" && "${prod_exists}" != "true" ]]; then
    class=STALE_PACKMATE
  fi
  users="$(oc get group "${GROUP}" -o jsonpath='{.users[*]}' 2>/dev/null || true)"
  emit "${class}" user.openshift.io Group cluster-scoped "${GROUP}" "users=${users}"
fi

# Lab namespaced inventory (names only for Secrets)
if [[ "${lab_exists}" == "true" ]]; then
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    kind="${line%%|*}"
    name="${line##*|}"
    emit PACKMATE_EXCLUSIVE mixed "${kind}" "${LAB_NS}" "${name}" "live in lab"
  done < <(oc -n "${LAB_NS}" get deploy,svc,route,cm,sa,pvc,pipeline,pipelinerun,is,bc \
    -o jsonpath='{range .items[*]}{.kind}|{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    emit PACKMATE_EXCLUSIVE "(core)" Secret "${LAB_NS}" "${name}" "name only — data not printed"
  done < <(oc -n "${LAB_NS}" get secret -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -E 'packmate|endpoint-api-key|ghcr' || true)
fi

if [[ "${prod_exists}" == "true" ]]; then
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    kind="${line%%|*}"
    name="${line##*|}"
    emit PACKMATE_EXCLUSIVE mixed "${kind}" "${PROD_NS}" "${name}" "live in prod"
  done < <(oc -n "${PROD_NS}" get deploy,svc,route,cm,sa,pvc \
    -o jsonpath='{range .items[*]}{.kind}|{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    emit PACKMATE_EXCLUSIVE "(core)" Secret "${PROD_NS}" "${name}" "name only — data not printed"
  done < <(oc -n "${PROD_NS}" get secret -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | grep -E 'packmate|ghcr' || true)
fi

# Shared ODH MCP keys (detect Packmate entries without dumping full CM)
if oc -n "${ODH_NS}" get configmap gen-ai-aa-mcp-servers >/dev/null 2>&1; then
  keys="$(oc -n "${ODH_NS}" get configmap gen-ai-aa-mcp-servers -o jsonpath='{.data}' 2>/dev/null || true)"
  if printf '%s' "${keys}" | grep -q 'Packmate'; then
    class=STALE_PACKMATE
    [[ "${lab_exists}" == "true" ]] && class=PACKMATE_EXCLUSIVE
    emit "${class}" "(core)" ConfigMap "${ODH_NS}" gen-ai-aa-mcp-servers "contains Packmate-* MCP keys (shared CM)"
  else
    emit EXPECTED_SHARED "(core)" ConfigMap "${ODH_NS}" gen-ai-aa-mcp-servers "no Packmate keys detected"
  fi
fi

# Custom endpoints in lab
if [[ "${lab_exists}" == "true" ]] && oc -n "${LAB_NS}" get configmap gen-ai-aa-custom-model-endpoints >/dev/null 2>&1; then
  emit PACKMATE_EXCLUSIVE "(core)" ConfigMap "${LAB_NS}" gen-ai-aa-custom-model-endpoints "custom model endpoint registration"
fi

# Accidental model in lab
if [[ "${lab_exists}" == "true" ]] && oc -n "${LAB_NS}" get inferenceservice.serving.kserve.io >/dev/null 2>&1; then
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    emit UNKNOWN_REVIEW_REQUIRED serving.kserve.io InferenceService "${LAB_NS}" "${name}" "lab must not host Llama — investigate"
  done < <(oc -n "${LAB_NS}" get inferenceservice.serving.kserve.io -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
fi

# Shared model presence
if oc -n "${MODEL_NS}" get inferenceservice.serving.kserve.io llama-32-3b-instruct >/dev/null 2>&1; then
  ready="$(oc -n "${MODEL_NS}" get inferenceservice.serving.kserve.io llama-32-3b-instruct -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  emit EXPECTED_SHARED serving.kserve.io InferenceService "${MODEL_NS}" llama-32-3b-instruct "Ready=${ready}"
fi

printf '\n=== Summary ===\n'
printf 'EXPECTED_SHARED=%s PACKMATE_EXCLUSIVE=%s STALE_PACKMATE=%s UNKNOWN_REVIEW_REQUIRED=%s\n' \
  "${SHARED}" "${EXCLUSIVE}" "${STALE}" "${UNKNOWN}"

if [[ "${lab_exists}" != "true" && "${prod_exists}" != "true" && "${STALE}" -gt 0 ]]; then
  printf '\nINFO    Common state detected: namespaces deleted but Argo/Group residue remains\n'
  printf 'ACTION  Review STALE_PACKMATE rows, then run a dry-run reset:\n'
  printf 'ACTION  make reset-lab\n'
  printf 'ACTION  Destructive only with: CONFIRM_PACKMATE_RESET=packmate-lab-and-prod make reset-lab\n'
fi

printf '\ndiscover-packmate-resources: OK (read-only)\n'
exit 0
