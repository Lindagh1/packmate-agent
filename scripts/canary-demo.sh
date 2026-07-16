#!/usr/bin/env bash
# Argo Rollouts canary demo helpers for packmate-backend (prod overlay).
# Requires: kubectl + argo rollouts plugin (kubectl argo rollouts).
# Does NOT apply manifests — operate on an already-deployed Rollout.
set -euo pipefail

NAMESPACE="${NAMESPACE:-packmate-prod}"
ROLLOUT="${ROLLOUT:-packmate-backend}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  status              Show rollout status and step progress
  watch               Watch rollout until stable/paused/degraded
  promote             Promote past the current pause (or full promote with --full)
  pause               Pause an in-progress rollout
  resume              Resume a paused rollout
  abort               Abort the canary and rollback to stable
  retry               Retry a failed analysis run
  rollback            Undo rollout to the previous ReplicaSet revision
  history             List revision history
  demo                Print the expected canary step sequence

Environment:
  NAMESPACE           Target namespace (default: packmate-prod)
  ROLLOUT             Rollout name (default: packmate-backend)

Examples:
  $(basename "$0") status
  $(basename "$0") promote
  $(basename "$0") promote --full
  $(basename "$0") abort
EOF
}

require_plugin() {
  if ! kubectl argo rollouts version >/dev/null 2>&1; then
    echo "error: kubectl argo rollouts plugin is required" >&2
    echo "  https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation" >&2
    exit 1
  fi
}

cmd_status() {
  kubectl argo rollouts get rollout "${ROLLOUT}" -n "${NAMESPACE}"
  echo
  kubectl argo rollouts status "${ROLLOUT}" -n "${NAMESPACE}" --timeout 5s || true
}

cmd_watch() {
  kubectl argo rollouts status "${ROLLOUT}" -n "${NAMESPACE}" --watch
}

cmd_promote() {
  if [[ "${1:-}" == "--full" ]]; then
    kubectl argo rollouts promote "${ROLLOUT}" -n "${NAMESPACE}" --full
  else
    kubectl argo rollouts promote "${ROLLOUT}" -n "${NAMESPACE}"
  fi
}

cmd_pause() {
  kubectl argo rollouts pause "${ROLLOUT}" -n "${NAMESPACE}"
}

cmd_resume() {
  kubectl argo rollouts resume "${ROLLOUT}" -n "${NAMESPACE}"
}

cmd_abort() {
  kubectl argo rollouts abort "${ROLLOUT}" -n "${NAMESPACE}"
}

cmd_retry() {
  kubectl argo rollouts retry rollout "${ROLLOUT}" -n "${NAMESPACE}"
}

cmd_rollback() {
  kubectl argo rollouts undo "${ROLLOUT}" -n "${NAMESPACE}"
}

cmd_history() {
  kubectl argo rollouts history rollout "${ROLLOUT}" -n "${NAMESPACE}"
}

cmd_demo() {
  cat <<'EOF'
Expected prod backend canary sequence (deploy/overlays/prod/rollout-backend.yaml):

  1. setWeight: 10%
  2. analysis: packmate-backend-smoke (/health + /ready via canary Service)
  3. pause (manual promote or ./scripts/canary-demo.sh promote)
  4. setWeight: 50%
  5. analysis: packmate-backend-smoke
  6. pause (manual promote)
  7. setWeight: 100%

During pauses, inspect:
  kubectl argo rollouts get rollout packmate-backend -n packmate-prod
  kubectl argo rollouts status packmate-backend -n packmate-prod --watch

Optional Prometheus analysis template: packmate-backend-prometheus
Wire it into rollout steps when Prometheus is reachable (see analysis-prometheus.yaml).
EOF
}

main() {
  require_plugin
  local cmd="${1:-}"
  shift || true

  case "${cmd}" in
    status) cmd_status "$@" ;;
    watch) cmd_watch "$@" ;;
    promote) cmd_promote "$@" ;;
    pause) cmd_pause "$@" ;;
    resume) cmd_resume "$@" ;;
    abort) cmd_abort "$@" ;;
    retry) cmd_retry "$@" ;;
    rollback) cmd_rollback "$@" ;;
    history) cmd_history "$@" ;;
    demo) cmd_demo "$@" ;;
    -h|--help|help|"") usage ;;
    *)
      echo "error: unknown command: ${cmd}" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
