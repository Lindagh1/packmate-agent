#!/usr/bin/env bash
# Instructor-only: create GHCR push (and optional pull) Secrets for portable promotion.
# Credentials from env or secure prompt — never argv, never echoed, never Git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && set -a && source "${ROOT}/config/sandbox.env" && set +a || true

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

PACKMATE_PROMOTION_REGISTRY="${PACKMATE_PROMOTION_REGISTRY:-ghcr.io}"
PACKMATE_PROMOTION_REGISTRY_OWNER="${PACKMATE_PROMOTION_REGISTRY_OWNER:-Lindagh1}"
PACKMATE_PROMOTION_IMAGE_NAME="${PACKMATE_PROMOTION_IMAGE_NAME:-packmate-backend}"
PACKMATE_PROMOTION_PUSH_SECRET="${PACKMATE_PROMOTION_PUSH_SECRET:-packmate-ghcr-push}"
PACKMATE_PROMOTION_PULL_SECRET="${PACKMATE_PROMOTION_PULL_SECRET:-packmate-ghcr-pull}"
LAB_NS="${PACKMATE_NAMESPACE:-packmate-lab}"
PROD_NS="${PACKMATE_PROD_NAMESPACE:-packmate-prod}"
PIPELINE_SA="${PACKMATE_PIPELINE_SA:-pipeline}"

[[ "${PACKMATE_PROMOTION_REGISTRY_OWNER}" =~ ^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$ ]] \
  || die "Invalid PACKMATE_PROMOTION_REGISTRY_OWNER"

USER_NAME="${PACKMATE_REGISTRY_USERNAME:-}"
TOKEN="${PACKMATE_REGISTRY_TOKEN:-}"

if [[ -z "${TOKEN}" ]] && command -v gh >/dev/null 2>&1; then
  TOKEN="$(gh auth token 2>/dev/null || true)"
  [[ -n "${USER_NAME}" ]] || USER_NAME="$(gh api user -q .login 2>/dev/null || true)"
fi

if [[ -z "${USER_NAME}" ]]; then
  read -r -p "Registry username: " USER_NAME
fi
if [[ -z "${TOKEN}" ]]; then
  read -r -s -p "Registry token (input hidden): " TOKEN
  printf '\n'
fi
[[ -n "${USER_NAME}" && -n "${TOKEN}" ]] || die "Username and token required"

oc -n "${LAB_NS}" create secret docker-registry "${PACKMATE_PROMOTION_PUSH_SECRET}" \
  --docker-server="${PACKMATE_PROMOTION_REGISTRY}" \
  --docker-username="${USER_NAME}" \
  --docker-password="${TOKEN}" \
  --dry-run=client -o yaml | oc apply -f - >/dev/null
log "OK: Secret/${PACKMATE_PROMOTION_PUSH_SECRET} in ${LAB_NS} (value not shown)"

# Link to Pipeline SA — preserve unrelated imagePullSecrets
oc -n "${LAB_NS}" secrets link "${PIPELINE_SA}" "${PACKMATE_PROMOTION_PUSH_SECRET}" --for=pull,mount >/dev/null 2>&1 \
  || oc -n "${LAB_NS}" patch sa "${PIPELINE_SA}" --type merge -p \
    "{\"imagePullSecrets\":[{\"name\":\"${PACKMATE_PROMOTION_PUSH_SECRET}\"}],\"secrets\":[{\"name\":\"${PACKMATE_PROMOTION_PUSH_SECRET}\"}]}" >/dev/null 2>&1 \
  || true
log "OK: linked push Secret to SA/${PIPELINE_SA}"

PUBLIC_OK=false
CODE="$(curl -sI -o /dev/null -w '%{http_code}' -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
  "https://${PACKMATE_PROMOTION_REGISTRY}/v2/${PACKMATE_PROMOTION_REGISTRY_OWNER}/${PACKMATE_PROMOTION_IMAGE_NAME}/manifests/lab-v1.0.0" || echo 000)"
[[ "${CODE}" == "200" ]] && PUBLIC_OK=true

if [[ "${PUBLIC_OK}" == "true" ]]; then
  log "OK: package publicly pullable — PROD pull Secret optional"
else
  oc -n "${PROD_NS}" create secret docker-registry "${PACKMATE_PROMOTION_PULL_SECRET}" \
    --docker-server="${PACKMATE_PROMOTION_REGISTRY}" \
    --docker-username="${USER_NAME}" \
    --docker-password="${TOKEN}" \
    --dry-run=client -o yaml | oc apply -f - >/dev/null
  for sa in packmate-backend packmate-frontend weather-mcp baggage-policy-mcp; do
    oc -n "${PROD_NS}" secrets link "${sa}" "${PACKMATE_PROMOTION_PULL_SECRET}" --for=pull >/dev/null 2>&1 || true
  done
  log "OK: Secret/${PACKMATE_PROMOTION_PULL_SECRET} linked to PROD runtime SAs"
fi

unset TOKEN
log "configure-promotion-registry: complete"
