#!/usr/bin/env bash
# Verify promotion registry configuration and baseline pullability (no tokens printed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
[[ -f "${ROOT}/config/sandbox.env" ]] && set -a && source "${ROOT}/config/sandbox.env" && set +a || true

PACKMATE_PROMOTION_REGISTRY="${PACKMATE_PROMOTION_REGISTRY:-ghcr.io}"
PACKMATE_PROMOTION_REGISTRY_OWNER="${PACKMATE_PROMOTION_REGISTRY_OWNER:-Lindagh1}"
PACKMATE_PROMOTION_IMAGE_NAME="${PACKMATE_PROMOTION_IMAGE_NAME:-packmate-backend}"
PUSH_SECRET="${PACKMATE_PROMOTION_PUSH_SECRET:-packmate-ghcr-push}"
LAB_NS="${PACKMATE_NAMESPACE:-packmate-lab}"
BASELINE="ghcr.io/lindagh1/packmate-backend@sha256:c10fbeb6fbd63ca478e1b8231ddf874ec7ee1c80663b641d802ffca6e826849f"

pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; exit 1; }

REPO="${PACKMATE_PROMOTION_REGISTRY}/${PACKMATE_PROMOTION_REGISTRY_OWNER}/${PACKMATE_PROMOTION_IMAGE_NAME}"
pass "Promotion repository configured (${REPO})"

if oc -n "${LAB_NS}" get secret "${PUSH_SECRET}" >/dev/null 2>&1; then
  pass "Push Secret ${PUSH_SECRET} present in ${LAB_NS}"
else
  fail "Push Secret ${PUSH_SECRET} missing — run make configure-promotion-registry"
fi

if command -v skopeo >/dev/null 2>&1; then
  skopeo inspect "docker://${BASELINE}" >/dev/null 2>&1 \
    && pass "Baseline GHCR image pullable (${BASELINE%%@*}@…)" \
    || fail "Baseline GHCR image not pullable"
else
  CODE="$(curl -sI -o /dev/null -w '%{http_code}' \
    "https://ghcr.io/v2/lindagh1/packmate-backend/manifests/sha256:c10fbeb6fbd63ca478e1b8231ddf874ec7ee1c80663b641d802ffca6e826849f" || echo 000)"
  [[ "${CODE}" == "200" ]] && pass "Baseline GHCR manifest HTTP 200" || fail "Baseline GHCR manifest HTTP ${CODE}"
fi

# PROD overlay must not contain internal registry
if grep -qE 'image-registry\.openshift-image-registry\.svc' "${ROOT}/deploy/overlays/prod/kustomization.yaml"; then
  fail "PROD overlay contains internal OpenShift registry reference"
fi
pass "PROD overlay has no internal registry reference"

echo "verify-promotion-registry: OK"
