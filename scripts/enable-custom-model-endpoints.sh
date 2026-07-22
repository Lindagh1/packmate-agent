#!/usr/bin/env bash
# Enable OpenShift AI Gen AI custom model endpoints (Technology Preview in 3.4.x).
# Idempotent: only sets dashboardConfig.aiAssetCustomEndpoints=true.
# Does NOT enable externalProviders (cluster-local .svc.cluster.local URLs do not need it).
# Does NOT modify other OdhDashboardConfig fields beyond that one boolean.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh"

packmate_require_oc
if [[ -f "${ROOT}/config/sandbox.env" ]]; then
  packmate_load_config "${ROOT}" || exit 1
fi

ODH_NS="${ODH_APPLICATIONS_NS:-redhat-ods-applications}"
ENABLE_CUSTOM_ENDPOINTS="${ENABLE_CUSTOM_ENDPOINTS:-true}"
BACKUP="${ODH_DASHBOARD_CONFIG_BACKUP:-/tmp/odh-dashboard-config-before-packmate-endpoint.yaml}"

log() { packmate_log "$*"; }
die() { packmate_die "$*"; }

if [[ "${ENABLE_CUSTOM_ENDPOINTS}" != "true" ]]; then
  log "==> ENABLE_CUSTOM_ENDPOINTS=${ENABLE_CUSTOM_ENDPOINTS} — skipping OdhDashboardConfig patch"
  exit 0
fi

oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" >/dev/null \
  || die "OdhDashboardConfig/odh-dashboard-config missing in ${ODH_NS}"

# Best-effort backup (never overwrite a prior backup from this session if present and non-empty)
if [[ ! -s "${BACKUP}" ]]; then
  oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" -o yaml > "${BACKUP}"
  log "==> Saved OdhDashboardConfig backup to ${BACKUP}"
fi

CUR="$(oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" \
  -o jsonpath='{.spec.dashboardConfig.aiAssetCustomEndpoints}' 2>/dev/null || true)"

if [[ "${CUR}" == "true" ]]; then
  log "==> aiAssetCustomEndpoints already true (idempotent)"
  exit 0
fi

oc patch odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" --type=merge \
  -p '{"spec":{"dashboardConfig":{"aiAssetCustomEndpoints":true}}}' >/dev/null

AFTER="$(oc get odhdashboardconfig odh-dashboard-config -n "${ODH_NS}" \
  -o jsonpath='{.spec.dashboardConfig.aiAssetCustomEndpoints}' 2>/dev/null || true)"
[[ "${AFTER}" == "true" ]] || die "failed to set aiAssetCustomEndpoints=true"
log "==> Enabled dashboardConfig.aiAssetCustomEndpoints=true (other fields preserved)"
