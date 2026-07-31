#!/usr/bin/env bash
# Wait for an Argo CD Application to become Synced / Healthy.
# If OutOfSync, trigger a prune=false sync (Argo owns reconciliation — never oc apply overlays).
set -euo pipefail

APP="${1:-}"
NS="${2:-openshift-gitops}"
TIMEOUT_SECS="${ARGOCD_WAIT_TIMEOUT_SECS:-600}"
ALLOW_SYNC="${ARGOCD_WAIT_ALLOW_SYNC:-true}"

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -n "${APP}" ]] || die "usage: wait-for-argocd-app.sh <app-name> [namespace]"

oc get applications.argoproj.io "${APP}" -n "${NS}" >/dev/null 2>&1 \
  || die "Application/${APP} missing in ${NS}"

deadline=$((SECONDS + TIMEOUT_SECS))
synced_once=0

while (( SECONDS < deadline )); do
  sync="$(oc -n "${NS}" get applications.argoproj.io "${APP}" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo Unknown)"
  health="$(oc -n "${NS}" get applications.argoproj.io "${APP}" -o jsonpath='{.status.health.status}' 2>/dev/null || echo Unknown)"
  phase="$(oc -n "${NS}" get applications.argoproj.io "${APP}" -o jsonpath='{.status.operationState.phase}' 2>/dev/null || true)"

  if [[ "${sync}" == "Synced" && "${health}" == "Healthy" ]]; then
    log "OK: Application/${APP} Synced / Healthy"
    exit 0
  fi

  if [[ "${ALLOW_SYNC}" == "true" && "${sync}" == "OutOfSync" && "${synced_once}" -eq 0 && "${phase}" != "Running" ]]; then
    log "==> Application/${APP} is OutOfSync — requesting Argo CD sync (prune=false)"
    oc -n "${NS}" patch applications.argoproj.io "${APP}" --type merge -p \
      "{\"operation\":{\"initiatedBy\":{\"username\":\"packmate-bootstrap\"},\"sync\":{\"prune\":false,\"syncStrategy\":{\"hook\":{}}}}}" \
      >/dev/null
    synced_once=1
  fi

  log "    waiting Application/${APP} sync=${sync} health=${health} phase=${phase:-none}"
  sleep 5
done

log "DIAG: Application/${APP} timed out after ${TIMEOUT_SECS}s"
oc -n "${NS}" get applications.argoproj.io "${APP}" \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REV:.status.sync.revision' >&2 || true
oc -n "${NS}" get applications.argoproj.io "${APP}" -o jsonpath='{range .status.resources[?(@.status!="Synced")]}{.kind}/{.name}={.status}{"\n"}{end}' >&2 || true
die "Application/${APP} did not become Synced/Healthy within ${TIMEOUT_SECS}s"
