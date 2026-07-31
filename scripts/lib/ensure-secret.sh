#!/usr/bin/env bash
# Idempotent Opaque / docker-registry Secret helpers.
# Never print Secret values. Compare desired vs live data in-process only.
#
# Usage (after sourcing):
#   packmate_ensure_opaque_secret <namespace> <name> KEY=value KEY2=value2 ...
#   packmate_ensure_docker_registry_secret <namespace> <name> <server> <username> <password>
#
# Env:
#   PACKMATE_SECRET_ALLOW_ROTATION=true  — permit updating when desired data differs
#   ROTATE_PACKMATE_PROD_LLM_SECRET     — alias checked by callers for prod LLM
set -euo pipefail

packmate_ensure_opaque_secret() {
  local ns="$1" name="$2"
  shift 2
  [[ $# -ge 1 ]] || { printf 'ERROR: packmate_ensure_opaque_secret requires KEY=value pairs\n' >&2; return 1; }

  local -a literals=()
  local pair key
  for pair in "$@"; do
    key="${pair%%=*}"
    [[ -n "${key}" && "${pair}" == *"="* ]] || {
      printf 'ERROR: invalid secret literal %s\n' "${pair}" >&2
      return 1
    }
    literals+=(--from-literal="${pair}")
  done

  if ! oc -n "${ns}" get secret "${name}" >/dev/null 2>&1; then
    oc -n "${ns}" create secret generic "${name}" "${literals[@]}" >/dev/null
    printf 'OK: created Secret/%s in %s (values not shown)\n' "${name}" "${ns}"
    return 0
  fi

  local before_rv desired_b64 live_b64
  before_rv="$(oc -n "${ns}" get secret "${name}" -o jsonpath='{.metadata.resourceVersion}')"

  # Build desired data map (base64) without printing plaintext.
  desired_b64="$(
    oc -n "${ns}" create secret generic "${name}" "${literals[@]}" \
      --dry-run=client -o json \
      | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data") or {}; print(json.dumps(d, sort_keys=True, separators=(",",":")))'
  )"
  live_b64="$(
    oc -n "${ns}" get secret "${name}" -o json \
      | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data") or {}; print(json.dumps(d, sort_keys=True, separators=(",",":")))'
  )"

  if [[ "${desired_b64}" == "${live_b64}" ]]; then
    printf 'OK: Secret/%s unchanged in %s (resourceVersion=%s)\n' "${name}" "${ns}" "${before_rv}"
    return 0
  fi

  # Missing keys only? Detect via key set comparison (no value output).
  local missing
  missing="$(
    DESIRED_JSON="${desired_b64}" LIVE_JSON="${live_b64}" python3 - <<'PY'
import json, os
want = json.loads(os.environ["DESIRED_JSON"])
have = json.loads(os.environ["LIVE_JSON"])
missing = sorted(set(want) - set(have))
changed = sorted(k for k in set(want) & set(have) if want[k] != have[k])
print("missing=" + ",".join(missing) + ";changed=" + ",".join(changed))
PY
  )"

  if [[ "${PACKMATE_SECRET_ALLOW_ROTATION:-false}" != "true" ]]; then
    printf 'BLOCKED_SECRET_ROTATION_REQUIRED: Secret/%s in %s differs from desired data (%s).\n' \
      "${name}" "${ns}" "${missing}" >&2
    printf 'Ordinary bootstrap will not rotate it. Instructor: ROTATE_PACKMATE_PROD_LLM_SECRET=true make rotate-prod-llm-secret\n' >&2
    return 2
  fi

  oc -n "${ns}" create secret generic "${name}" "${literals[@]}" \
    --dry-run=client -o yaml | oc apply -f - >/dev/null
  local after_rv
  after_rv="$(oc -n "${ns}" get secret "${name}" -o jsonpath='{.metadata.resourceVersion}')"
  printf 'OK: rotated Secret/%s in %s (resourceVersion %s -> %s; values not shown)\n' \
    "${name}" "${ns}" "${before_rv}" "${after_rv}"
  return 0
}

packmate_ensure_docker_registry_secret() {
  local ns="$1" name="$2" server="$3" username="$4" password="$5"
  if ! oc -n "${ns}" get secret "${name}" >/dev/null 2>&1; then
    oc -n "${ns}" create secret docker-registry "${name}" \
      --docker-server="${server}" \
      --docker-username="${username}" \
      --docker-password="${password}" >/dev/null
    printf 'OK: created Secret/%s in %s (value not shown)\n' "${name}" "${ns}"
    return 0
  fi

  local before_rv desired_b64 live_b64
  before_rv="$(oc -n "${ns}" get secret "${name}" -o jsonpath='{.metadata.resourceVersion}')"
  desired_b64="$(
    oc -n "${ns}" create secret docker-registry "${name}" \
      --docker-server="${server}" \
      --docker-username="${username}" \
      --docker-password="${password}" \
      --dry-run=client -o json \
      | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data") or {}; print(json.dumps(d, sort_keys=True, separators=(",",":")))'
  )"
  live_b64="$(
    oc -n "${ns}" get secret "${name}" -o json \
      | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data") or {}; print(json.dumps(d, sort_keys=True, separators=(",",":")))'
  )"

  if [[ "${desired_b64}" == "${live_b64}" ]]; then
    printf 'OK: Secret/%s unchanged in %s (resourceVersion=%s)\n' "${name}" "${ns}" "${before_rv}"
    return 0
  fi

  if [[ "${PACKMATE_SECRET_ALLOW_ROTATION:-false}" != "true" ]]; then
    printf 'BLOCKED_SECRET_ROTATION_REQUIRED: Secret/%s in %s differs. Re-run with PACKMATE_SECRET_ALLOW_ROTATION=true (instructor).\n' \
      "${name}" "${ns}" >&2
    return 2
  fi

  oc -n "${ns}" create secret docker-registry "${name}" \
    --docker-server="${server}" \
    --docker-username="${username}" \
    --docker-password="${password}" \
    --dry-run=client -o yaml | oc apply -f - >/dev/null
  local after_rv
  after_rv="$(oc -n "${ns}" get secret "${name}" -o jsonpath='{.metadata.resourceVersion}')"
  printf 'OK: rotated Secret/%s in %s (resourceVersion %s -> %s; value not shown)\n' \
    "${name}" "${ns}" "${before_rv}" "${after_rv}"
  return 0
}
