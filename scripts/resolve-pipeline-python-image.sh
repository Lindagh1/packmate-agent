#!/usr/bin/env bash
# Resolve openshift/python:3.12-ubi9 to an immutable internal digest reference.
# Prints ONLY the image reference on stdout. Diagnostics go to stderr.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh"

ISTREAM_NS="${PACKMATE_PYTHON_ISTREAM_NS:-openshift}"
ISTREAM_NAME="${PACKMATE_PYTHON_ISTREAM_NAME:-python}"
ISTREAM_TAG="${PACKMATE_PYTHON_ISTREAM_TAG:-3.12-ubi9}"
PROBE_NS="${PACKMATE_NAMESPACE:-packmate-lab}"
ALLOW_NON_DIGEST="${PACKMATE_ALLOW_NON_DIGEST_PYTHON_IMAGE:-false}"
PULL_TIMEOUT_SECS="${PACKMATE_PYTHON_IMAGE_PULL_TIMEOUT_SECS:-180}"
INTERNAL_REGISTRY="${PACKMATE_INTERNAL_REGISTRY:-image-registry.openshift-image-registry.svc:5000}"

log() { printf '%s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

redact() {
  sed -E \
    -e 's#(https?://[^/@[:space:]]*:)[^/@[:space:]]+@#\1***@#g' \
    -e 's/(token|password|passwd|secret|authorization)=[^[:space:]]+/\1=***/Ig'
}

validate_image_ref() {
  local img="$1"
  [[ -n "${img}" ]] || die "Python image reference is empty"
  if [[ "${img}" == *":latest" || "${img}" == *:latest@* ]]; then
    die "Python image must not use :latest (${img})"
  fi
  if [[ "${img}" != *"@"* ]]; then
    if [[ "${ALLOW_NON_DIGEST}" == "true" ]]; then
      log "WARNING: non-digest Python image allowed by PACKMATE_ALLOW_NON_DIGEST_PYTHON_IMAGE"
      return 0
    fi
    die "Python image must be digest-pinned (got: ${img})"
  fi
  local digest="${img##*@}"
  [[ "${digest}" == sha256:* ]] || die "Python image digest must start with sha256: (got: ${digest})"
  [[ "${#digest}" -gt 10 ]] || die "Python image digest looks empty/invalid"
}

pull_probe() {
  local img="$1"
  local ns="$2"
  local pod="packmate-pyimg-probe-$$"
  local deadline=$((SECONDS + PULL_TIMEOUT_SECS))
  local last=""

  if ! oc get project "${ns}" >/dev/null 2>&1; then
    die "Probe namespace ${ns} does not exist"
  fi

  oc -n "${ns}" delete pod "${pod}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  oc -n "${ns}" run "${pod}" --image="${img}" --restart=Never --quiet \
    --overrides="$(cat <<EOF
{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"probe","image":"${img}","command":["sleep","90"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsNonRoot":true}}]}}
EOF
)" --command -- sleep 90 >/dev/null

  while (( SECONDS < deadline )); do
    local phase ready
    phase="$(oc -n "${ns}" get pod "${pod}" -o jsonpath='{.status.phase}' 2>/dev/null || echo Unknown)"
    ready="$(oc -n "${ns}" get pod "${pod}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "${ready}" == "True" ]]; then
      local pyver
      pyver="$(oc -n "${ns}" exec "${pod}" -- python --version 2>&1 | redact || true)"
      printf '%s\n' "${pyver}" | grep -Eq 'Python 3\.12' || {
        oc -n "${ns}" delete pod "${pod}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
        die "Resolved image python version is not 3.12 (${pyver})"
      }
      log "PASS  Pipeline Python image pull verified (${pyver})"
      oc -n "${ns}" delete pod "${pod}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
      return 0
    fi
    if [[ "${phase}" == "Failed" ]]; then
      last="$(oc -n "${ns}" get pod "${pod}" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)"
      if [[ "${last}" == "ErrImagePull" || "${last}" == "ImagePullBackOff" ]]; then
        # Retry once by recreating the pod for transient registry blips.
        oc -n "${ns}" delete pod "${pod}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
        sleep 3
        oc -n "${ns}" run "${pod}" --image="${img}" --restart=Never --quiet \
          --overrides="$(cat <<EOF
{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"probe","image":"${img}","command":["sleep","90"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsNonRoot":true}}]}}
EOF
)" --command -- sleep 90 >/dev/null || true
        last="retrying after ${last}"
      fi
    fi
    sleep 3
  done

  last="$(oc -n "${ns}" describe pod "${pod}" 2>/dev/null | grep -E 'Failed|ErrImage|Back-off|error' | head -5 | redact || true)"
  oc -n "${ns}" delete pod "${pod}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  die "Unable to pull Pipeline Python image within ${PULL_TIMEOUT_SECS}s${last:+ (${last})}"
}

packmate_require_oc

if [[ -n "${PACKMATE_PIPELINE_PYTHON_IMAGE:-}" ]]; then
  IMG="${PACKMATE_PIPELINE_PYTHON_IMAGE}"
  log "Using PACKMATE_PIPELINE_PYTHON_IMAGE override"
  validate_image_ref "${IMG}"
  if [[ "${PACKMATE_SKIP_PYTHON_IMAGE_PULL_PROBE:-false}" != "true" ]]; then
    pull_probe "${IMG}" "${PROBE_NS}"
  fi
  printf '%s\n' "${IMG}"
  exit 0
fi

oc get imagestream "${ISTREAM_NAME}" -n "${ISTREAM_NS}" >/dev/null 2>&1 \
  || die "ImageStream ${ISTREAM_NS}/${ISTREAM_NAME} missing"
oc get istag "${ISTREAM_NAME}:${ISTREAM_TAG}" -n "${ISTREAM_NS}" >/dev/null 2>&1 \
  || die "ImageStreamTag ${ISTREAM_NS}/${ISTREAM_NAME}:${ISTREAM_TAG} missing"

DIGEST="$(oc get istag "${ISTREAM_NAME}:${ISTREAM_TAG}" -n "${ISTREAM_NS}" \
  -o jsonpath='{.image.metadata.name}' 2>/dev/null || true)"
[[ -n "${DIGEST}" ]] || die "ImageStreamTag ${ISTREAM_NAME}:${ISTREAM_TAG} has no resolved digest"
[[ "${DIGEST}" == sha256:* ]] || die "Resolved digest must start with sha256: (got: ${DIGEST})"

IMG="${INTERNAL_REGISTRY}/${ISTREAM_NS}/${ISTREAM_NAME}@${DIGEST}"
validate_image_ref "${IMG}"
log "Resolved ${ISTREAM_NS}/${ISTREAM_NAME}:${ISTREAM_TAG} -> ${IMG}"

if [[ "${PACKMATE_SKIP_PYTHON_IMAGE_PULL_PROBE:-false}" != "true" ]]; then
  pull_probe "${IMG}" "${PROBE_NS}"
fi

printf '%s\n' "${IMG}"
