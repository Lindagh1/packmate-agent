#!/usr/bin/env bash
# Post-bootstrap fork verification: Applications must follow the participant fork.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
PACKMATE_FORK_ROOT="${ROOT}"
export PACKMATE_FORK_ROOT

# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/fork-safety.sh"

packmate_load_fork_config "${ROOT}"

printf '=== Packmate verify-demo-fork-live (post-bootstrap) ===\n'
printf 'GIT_REPO_URL=%s\n' "${GIT_REPO_URL:-"(unset — using origin)"}"
printf 'GIT_REVISION=%s\n' "${GIT_REVISION}"
printf '\n'

if packmate_verify_demo_fork_live; then
  printf '\nverify-demo-fork-live: OK\n'
  exit 0
fi
printf '\nverify-demo-fork-live: FAILED\n' >&2
exit 1
