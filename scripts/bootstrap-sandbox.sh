#!/usr/bin/env bash
# Bootstrap Packmate sandbox prerequisites (idempotent helpers).
# Does not redeploy the shared model in MODEL_NAMESPACE.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && source "${ROOT}/config/sandbox.env"

PACKMATE_NS="${PACKMATE_NS:-packmate-lab}"

log() { printf '%s\n' "$*"; }

log "==> Packmate sandbox bootstrap"
log "    namespace=${PACKMATE_NS}"

if ! oc get project "${PACKMATE_NS}" >/dev/null 2>&1; then
  log "Create Data Science Project ${PACKMATE_NS} from the OpenShift AI dashboard first."
  exit 1
fi

log "==> Register custom model endpoint (reuse existing InferenceService)"
bash "${ROOT}/scripts/create-packmate-model-endpoint.sh"

log "==> Bootstrap complete"
log "    Next: bash scripts/verify-sandbox.sh"
log "    UI: Gen AI studio → AI asset endpoints → Project: Packmate Lab"
