#!/usr/bin/env bash
# Publish an internal OpenShift candidate image to the durable external registry.
# Copies by digest — never rebuilds. Never prints credentials.
#
# Env:
#   INTERNAL_IMAGE_REFERENCE   required (…@sha256:…)
#   PACKMATE_PROMOTION_*       registry settings
#   PIPELINE_RUN_NAME, GIT_COMMIT
set -euo pipefail

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

INTERNAL_IMAGE_REFERENCE="${INTERNAL_IMAGE_REFERENCE:?INTERNAL_IMAGE_REFERENCE required}"
PACKMATE_PROMOTION_REGISTRY_MODE="${PACKMATE_PROMOTION_REGISTRY_MODE:-external}"
PACKMATE_PROMOTION_REGISTRY="${PACKMATE_PROMOTION_REGISTRY:-ghcr.io}"
PACKMATE_PROMOTION_REGISTRY_OWNER="${PACKMATE_PROMOTION_REGISTRY_OWNER:-lindagh1}"
PACKMATE_PROMOTION_IMAGE_NAME="${PACKMATE_PROMOTION_IMAGE_NAME:-packmate-backend}"
PACKMATE_REQUIRE_PORTABLE_PROD_IMAGE="${PACKMATE_REQUIRE_PORTABLE_PROD_IMAGE:-true}"
AUTHFILE="${REGISTRY_AUTH_FILE:-${XDG_RUNTIME_DIR:-/tmp}/.packmate-promotion-auth.json}"

GIT_COMMIT="${GIT_COMMIT:-unknown}"
GIT_SHORT="$(printf '%s' "${GIT_COMMIT}" | cut -c1-7)"
PIPELINE_RUN_NAME="${PIPELINE_RUN_NAME:-manual}"
EXT_TAG="${GIT_SHORT}-${PIPELINE_RUN_NAME}"
EXT_REPO="${PACKMATE_PROMOTION_REGISTRY}/$(printf '%s' "${PACKMATE_PROMOTION_REGISTRY_OWNER}" | tr '[:upper:]' '[:lower:]')/${PACKMATE_PROMOTION_IMAGE_NAME}"
EXT_TAG_REF="${EXT_REPO}:${EXT_TAG}"

cleanup() { rm -f "${AUTHFILE}" 2>/dev/null || true; }
trap cleanup EXIT

if [[ "${PACKMATE_PROMOTION_REGISTRY_MODE}" == "internal" ]]; then
  log "WARN  Sandbox-local promotion is not portable across clusters."
  if [[ "${PACKMATE_ALLOW_INTERNAL_PROD_IMAGE:-false}" != "true" ]]; then
    die "BLOCKED_NON_PORTABLE_PROD_IMAGE_REFERENCE: internal mode requires PACKMATE_ALLOW_INTERNAL_PROD_IMAGE=true"
  fi
  printf 'PROMOTION_IMAGE_REFERENCE=%s\n' "${INTERNAL_IMAGE_REFERENCE}"
  exit 0
fi

[[ "${INTERNAL_IMAGE_REFERENCE}" == *@sha256:* ]] || die "Internal reference must be digest-pinned"
[[ "${INTERNAL_IMAGE_REFERENCE}" != *:latest ]] || die "Refuse :latest"

command -v skopeo >/dev/null 2>&1 || die "skopeo required for external publication"
command -v oc >/dev/null 2>&1 || true

# Auth file from mounted dockerconfig if present
if [[ -f /var/run/secrets/packmate-ghcr-push/.dockerconfigjson ]]; then
  cp /var/run/secrets/packmate-ghcr-push/.dockerconfigjson "${AUTHFILE}"
elif [[ -f "${HOME}/.docker/config.json" ]]; then
  cp "${HOME}/.docker/config.json" "${AUTHFILE}"
elif [[ -n "${REGISTRY_AUTH_FILE:-}" && -f "${REGISTRY_AUTH_FILE}" ]]; then
  :
else
  if [[ "${PACKMATE_REQUIRE_PORTABLE_PROD_IMAGE}" == "true" ]]; then
    die "Push credentials missing (mount Secret packmate-ghcr-push)"
  fi
fi
chmod 600 "${AUTHFILE}" 2>/dev/null || true

SRC="docker://${INTERNAL_IMAGE_REFERENCE}"
# OpenShift internal refs need the cluster registry form
if [[ "${INTERNAL_IMAGE_REFERENCE}" == image-registry.openshift-image-registry.svc:5000/* ]]; then
  SRC="docker://${INTERNAL_IMAGE_REFERENCE}"
fi

log "Copying ${INTERNAL_IMAGE_REFERENCE} → ${EXT_TAG_REF}"
skopeo copy --authfile "${AUTHFILE}" --all "${SRC}" "docker://${EXT_TAG_REF}"

DIGEST="$(skopeo inspect --authfile "${AUTHFILE}" "docker://${EXT_TAG_REF}" --format '{{.Digest}}')"
[[ "${DIGEST}" == sha256:* ]] || die "Destination digest missing"
EXT_REF="${EXT_REPO}@${DIGEST}"

# Verify pullable
skopeo inspect --authfile "${AUTHFILE}" "docker://${EXT_REF}" >/dev/null

printf 'PROMOTION_IMAGE_URL=%s\n' "${EXT_REPO}"
printf 'PROMOTION_IMAGE_TAG=%s\n' "${EXT_TAG}"
printf 'PROMOTION_IMAGE_DIGEST=%s\n' "${DIGEST}"
printf 'PROMOTION_IMAGE_REFERENCE=%s\n' "${EXT_REF}"
printf 'PROMOTION_REGISTRY_MODE=%s\n' "${PACKMATE_PROMOTION_REGISTRY_MODE}"
printf 'PROMOTION_REGISTRY_VERIFIED=true\n' 
log "Published ${EXT_REF}"
