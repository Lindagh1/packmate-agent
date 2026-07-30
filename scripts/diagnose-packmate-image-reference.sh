#!/usr/bin/env bash
# Diagnose why a Packmate image reference fails to pull (no secrets printed).
set -euo pipefail

IMAGE_REF=""
SOURCE_NS="packmate-lab"
TARGET_NS="packmate-prod"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image-reference) IMAGE_REF="${2:?}"; shift 2 ;;
    --source-namespace) SOURCE_NS="${2:?}"; shift 2 ;;
    --target-namespace) TARGET_NS="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -n "${IMAGE_REF}" ]] || { echo "ERROR: --image-reference required" >&2; exit 1; }

ROOT_CAUSE="UNKNOWN"
MANIFEST_EXISTS="false"
PULL_PERMISSION="unknown"
ACTION_REQUIRED="INVESTIGATE"

is_internal() {
  [[ "${IMAGE_REF}" == image-registry.openshift-image-registry.svc:* ]] \
    || [[ "${IMAGE_REF}" == *default-route-openshift-image-registry* ]] \
    || [[ "${IMAGE_REF}" == 172.30.* ]] \
    || [[ "${IMAGE_REF}" == *.svc:* ]] \
    || [[ "${IMAGE_REF}" == *.svc.cluster.local:* ]]
}

DIGEST=""
if [[ "${IMAGE_REF}" == *@sha256:* ]]; then
  DIGEST="sha256:${IMAGE_REF##*@sha256:}"
  DIGEST="sha256:${DIGEST#sha256:}"
elif [[ "${IMAGE_REF}" != *@* ]]; then
  ROOT_CAUSE="INVALID_IMAGE_REFERENCE"
  ACTION_REQUIRED="USE_IMMUTABLE_DIGEST"
fi

if [[ "${IMAGE_REF}" == *:latest ]] || [[ "${IMAGE_REF}" == */latest ]]; then
  ROOT_CAUSE="INVALID_IMAGE_REFERENCE"
  ACTION_REQUIRED="REMOVE_LATEST"
fi

REPO_PATH=""
if [[ "${IMAGE_REF}" == image-registry.openshift-image-registry.svc:5000/* ]]; then
  REST="${IMAGE_REF#image-registry.openshift-image-registry.svc:5000/}"
  REPO_PATH="${REST%%@*}"
  REPO_PATH="${REPO_PATH%%:*}"
fi

printf 'IMAGE_REFERENCE=%s\n' "${IMAGE_REF}"
printf 'SOURCE_NAMESPACE=%s\n' "${SOURCE_NS}"
printf 'TARGET_NAMESPACE=%s\n' "${TARGET_NS}"

# Live Deployment image
LIVE="$(oc -n "${TARGET_NS}" get deploy packmate-backend -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
[[ -n "${LIVE}" ]] && printf 'LIVE_DEPLOYMENT_IMAGE=%s\n' "${LIVE}"

# ImageStream
if oc -n "${SOURCE_NS}" get imagestream packmate-backend >/dev/null 2>&1; then
  printf 'IMAGESTREAM=present\n'
  TAGS="$(oc -n "${SOURCE_NS}" get imagestreamtag -o name 2>/dev/null | grep packmate-backend || true)"
  printf 'IMAGESTREAMTAGS=%s\n' "$(echo "${TAGS}" | tr '\n' ' ')"
else
  printf 'IMAGESTREAM=missing\n'
  if is_internal; then
    ROOT_CAUSE="IMAGESTREAM_MISSING"
    ACTION_REQUIRED="RUN_PIPELINE_OR_PUBLISH_EXTERNAL"
  fi
fi

# Image resource / digest existence
if [[ -n "${DIGEST}" && "${DIGEST}" == sha256:* ]]; then
  if oc get image "${DIGEST}" >/dev/null 2>&1; then
    MANIFEST_EXISTS="true"
  else
    MANIFEST_EXISTS="false"
  fi
fi

# Cross-namespace pull permission for PROD SAs
PULL_OK=true
for sa in packmate-backend packmate-frontend weather-mcp baggage-policy-mcp default; do
  sub="system:serviceaccount:${TARGET_NS}:${sa}"
  if oc -n "${SOURCE_NS}" auth can-i get imagestreams/layers --as="${sub}" >/dev/null 2>&1; then
    printf 'PULL_OK sa=%s\n' "${sa}"
  else
    printf 'PULL_DENIED sa=%s\n' "${sa}"
    PULL_OK=false
  fi
done
PULL_PERMISSION="${PULL_OK}"

# Classify
if [[ "${ROOT_CAUSE}" == "UNKNOWN" ]]; then
  if is_internal && [[ "${MANIFEST_EXISTS}" == "false" ]]; then
    ROOT_CAUSE="OLD_SANDBOX_REFERENCE"
    ACTION_REQUIRED="PUBLISH_TO_DURABLE_REGISTRY"
  elif [[ "${MANIFEST_EXISTS}" == "false" ]]; then
    ROOT_CAUSE="MANIFEST_MISSING"
    ACTION_REQUIRED="PUBLISH_TO_DURABLE_REGISTRY"
  elif [[ "${PULL_PERMISSION}" != "true" ]]; then
    ROOT_CAUSE="CROSS_NAMESPACE_PULL_DENIED"
    ACTION_REQUIRED="GRANT_SYSTEM_IMAGE_PULLER"
  else
    ROOT_CAUSE="MANIFEST_EXISTS"
    ACTION_REQUIRED="NONE"
  fi
fi

# Events hint (no secrets)
if oc -n "${TARGET_NS}" get events --sort-by=.lastTimestamp 2>/dev/null | tail -20 | grep -qiE 'manifest unknown|ErrImagePull|ImagePullBackOff|unauthorized|denied'; then
  printf 'RECENT_PULL_ERRORS=true\n'
fi

printf 'MANIFEST_EXISTS=%s\n' "${MANIFEST_EXISTS}"
printf 'PULL_PERMISSION=%s\n' "${PULL_PERMISSION}"
printf 'ROOT_CAUSE=%s\n' "${ROOT_CAUSE}"
printf 'ACTION_REQUIRED=%s\n' "${ACTION_REQUIRED}"
