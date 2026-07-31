#!/usr/bin/env bash
# Instructor-only: rotate packmate-prod-llm Secret.
# Requires ROTATE_PACKMATE_PROD_LLM_SECRET=true. Never prints values.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/ensure-secret.sh"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && set -a && source "${ROOT}/config/sandbox.env" && set +a || true

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ "${ROTATE_PACKMATE_PROD_LLM_SECRET:-false}" == "true" ]] \
  || die "Refusing rotation. Set ROTATE_PACKMATE_PROD_LLM_SECRET=true"

: "${LLM_BASE_URL:?LLM_BASE_URL must be set}"
: "${LLM_MODEL:?LLM_MODEL must be set}"
LLM_KEY="${LITELLM_API_KEY:-${LLM_API_KEY:-}}"
: "${LLM_KEY:?LITELLM_API_KEY (or LLM_API_KEY) must be set}"

PROD_NS="${PACKMATE_PROD_NAMESPACE:-packmate-prod}"
BEFORE="$(oc -n "${PROD_NS}" get secret packmate-prod-llm -o jsonpath='{.metadata.resourceVersion}' 2>/dev/null || echo none)"

PACKMATE_SECRET_ALLOW_ROTATION=true \
  packmate_ensure_opaque_secret "${PROD_NS}" packmate-prod-llm \
    "BASE_URL=${LLM_BASE_URL}" \
    "MODEL=${LLM_MODEL}" \
    "LITELLM_API_KEY=${LLM_KEY}"

AFTER="$(oc -n "${PROD_NS}" get secret packmate-prod-llm -o jsonpath='{.metadata.resourceVersion}')"
log "rotate-prod-llm-secret: resourceVersion ${BEFORE} -> ${AFTER} (values not shown)"
log "NOTE: pods that already mounted the Secret may need a controlled restart."
log "This script does not restart workloads automatically."
unset LLM_KEY
