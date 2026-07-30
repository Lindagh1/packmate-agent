#!/usr/bin/env bash
# Configure repository-local Git identity for Packmate commits.
# Does NOT set --global identity by default.
# Does NOT store GitHub tokens or passwords.
# Does NOT require the gh CLI.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PACKMATE_GIT_NAME="${PACKMATE_GIT_NAME:-}"
PACKMATE_GIT_EMAIL="${PACKMATE_GIT_EMAIL:-}"
SCOPE="${PACKMATE_GIT_CONFIG_SCOPE:-local}" # local | global (global requires explicit opt-in)

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '%s\n' "$*"; }

[[ -n "${PACKMATE_GIT_NAME}" ]] || die "PACKMATE_GIT_NAME is required (your display name for commits)"
[[ -n "${PACKMATE_GIT_EMAIL}" ]] || die "PACKMATE_GIT_EMAIL is required (your email for commits — not invented by this script)"

if [[ "${SCOPE}" != "local" && "${SCOPE}" != "global" ]]; then
  die "PACKMATE_GIT_CONFIG_SCOPE must be 'local' or 'global' (default: local)"
fi

if [[ "${SCOPE}" == "global" && "${PACKMATE_ALLOW_GLOBAL_GIT_IDENTITY:-false}" != "true" ]]; then
  die "Refusing global Git identity unless PACKMATE_ALLOW_GLOBAL_GIT_IDENTITY=true"
fi

command -v git >/dev/null 2>&1 || die "git is not available"
[[ -d "${ROOT}/.git" ]] || die "Not a Git repository: ${ROOT} (clone into packmate-agent first)"

cd "${ROOT}"
if [[ "${SCOPE}" == "local" ]]; then
  git config --local user.name "${PACKMATE_GIT_NAME}"
  git config --local user.email "${PACKMATE_GIT_EMAIL}"
else
  git config --global user.name "${PACKMATE_GIT_NAME}"
  git config --global user.email "${PACKMATE_GIT_EMAIL}"
fi

log "Configured Git ${SCOPE} identity:"
log "  user.name=$(git config --${SCOPE} --get user.name)"
log "  user.email=$(git config --${SCOPE} --get user.email)"
log
log "Notes:"
log "  - Cloning a public repo does not require authentication."
log "  - Commit identity is separate from GitHub push authentication."
log "  - Push may require GitHub SSO / PAT; this script never stores tokens."
log "  - The gh CLI is optional and not required for bootstrap or the Pipeline."
