#!/usr/bin/env bash
# Verify the local clone and config are fork-first (writable fork, canonical upstream).
# Blocks promotion into Lindagh1/packmate-agent unless ALLOW_CANONICAL_REPO_PROMOTION=true.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
PACKMATE_FORK_ROOT="${ROOT}"
export PACKMATE_FORK_ROOT

# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/fork-safety.sh"

packmate_load_fork_config "${ROOT}"

printf '=== Packmate verify-demo-fork ===\n'
printf 'CANONICAL_GIT_REPO_URL=%s\n' "${CANONICAL_GIT_REPO_URL}"
printf 'GIT_REPO_URL=%s\n' "${GIT_REPO_URL:-"(unset — using origin)"}"
printf 'GIT_REVISION=%s\n' "${GIT_REVISION}"
printf 'PROMOTION_BASE_BRANCH=%s\n' "${PROMOTION_BASE_BRANCH}"
printf 'ALLOW_CANONICAL_REPO_PROMOTION=%s\n' "${ALLOW_CANONICAL_REPO_PROMOTION}"
printf 'origin=%s\n' "$(packmate_remote_url origin)"
printf 'upstream=%s\n' "$(packmate_remote_url upstream || true)"
printf '\n'

if packmate_verify_demo_fork "$@"; then
  printf '\nverify-demo-fork: OK\n'
  exit 0
fi
printf '\nverify-demo-fork: FAILED\n' >&2
exit 1
