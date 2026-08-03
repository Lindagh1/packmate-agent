#!/usr/bin/env bash
# Non-destructive GitHub write-readiness check for workshop promotion.
# Never prints tokens. Never commits. Distinguishes read vs write access.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/fork-safety.sh"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/report.sh"

packmate_load_fork_config "${ROOT}"

FAILS=0
pass() { packmate_pass "$*"; }
fail() { packmate_fail "$1" "${2:-}" "${3:-}"; FAILS=$((FAILS + 1)); }
blocked() { packmate_blocked "$1" "${2:-}" "${3:-}"; FAILS=$((FAILS + 1)); }

printf '=== Packmate verify-github-write-readiness ===\n'

writable="$(packmate_writable_repo_url 2>/dev/null || true)"
origin="$(packmate_remote_url origin)"
[[ -n "${writable}" ]] || blocked "Writable repository configured" \
  "GIT_REPO_URL and origin are empty" \
  "Set GIT_REPO_URL to your fork and ensure git remote origin points at the fork"

writable_norm="$(packmate_normalize_github_owner_repo "${writable}" 2>/dev/null || true)"
origin_norm="$(packmate_normalize_github_owner_repo "${origin}" 2>/dev/null || true)"

if [[ -n "${writable_norm}" ]]; then
  if packmate_is_canonical_owner_repo "${writable_norm}"; then
    blocked "Writable repository is a fork" \
      "GIT_REPO_URL/origin points at Lindagh1/packmate-agent" \
      "Use https://github.com/YOUR_USER/packmate-agent.git and re-run make verify-demo-fork"
  else
    pass "Configured writable repository is a fork (${writable_norm})"
  fi
fi

if [[ -n "${origin_norm}" && "${origin_norm}" == "${writable_norm}" ]]; then
  pass "origin matches configured writable repository"
else
  fail "origin matches configured writable repository" \
    "origin=${origin} GIT_REPO_URL=${writable}" \
    "git remote set-url origin <fork-url>"
fi

base="${PROMOTION_BASE_BRANCH:-packmate-v2}"

# Askpass / VS Code socket detection
askpass="${GIT_ASKPASS:-${SSH_ASKPASS:-}}"
if [[ -n "${askpass}" ]]; then
  if [[ "${askpass}" == *".cursor-server"* ]] || [[ "${askpass}" == *"code"*askpass* ]] || [[ "${askpass}" == *"vscode"* ]]; then
    printf 'INFO    GIT_ASKPASS appears to be a VS Code/Cursor askpass helper: %s\n' "${askpass}"
    printf 'ACTION  If git push fails with ECONNREFUSED, open a Workbench/system terminal and unset GIT_ASKPASS SSH_ASKPASS\n'
    printf 'ACTION  Then authenticate with: gh auth login  OR  git credential store / HTTPS token prompt\n'
  fi
fi
if [[ -n "${VSCODE_GIT_ASKPASS_NODE:-}" || -n "${VSCODE_GIT_IPC_HANDLE:-}" ]]; then
  printf 'INFO    VS Code Git IPC environment detected\n'
  printf 'ACTION  Prefer a plain terminal for git push / gh pr create during Module D\n'
fi

# Read access: ls-remote
if git ls-remote --heads origin "${base}" >/dev/null 2>&1; then
  pass "Read access to origin/${base}"
  pass "Promotion base branch exists on origin (${base})"
else
  # Distinguish missing branch vs auth
  if git ls-remote origin HEAD >/dev/null 2>&1; then
    fail "Promotion base branch exists on origin" \
      "origin is reachable but refs/heads/${base} is missing" \
      "On GitHub: Settings → ensure packmate-v2 was copied (disable 'Copy the main branch only'), or: git push origin packmate-v2"
  else
    fail "Read access to origin" \
      "git ls-remote origin failed" \
      "Check network/VPN and repository visibility; for private forks configure Argo CD + local credentials separately"
  fi
fi

# gh presence
if command -v gh >/dev/null 2>&1; then
  pass "gh CLI is installed"
  if gh auth status >/dev/null 2>&1; then
    pass "gh CLI is authenticated"
  else
    fail "gh CLI is authenticated" \
      "gh auth status failed" \
      "Run: gh auth login -h github.com -p https -w   (use a fine-grained token with Contents: Read/Write on the fork)"
  fi
else
  printf 'INFO    gh CLI not installed — browser PR creation is required after git push\n'
  printf 'ACTION  After pushing a promote/* branch, open the compare URL printed by the promote script\n'
fi

# Authenticated write probe without committing: dry-run push of an empty local tip
# Prefer: git push --dry-run origin HEAD:refs/heads/packmate-write-probe-<random> then refuse to leave it
# Safer approach: use gh api to check push permission if authenticated
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 && [[ -n "${writable_norm}" ]]; then
  perm="$(gh api "repos/${writable_norm}" --jq '.permissions.push // .permissions.admin // false' 2>/dev/null || true)"
  if [[ "${perm}" == "true" ]]; then
    pass "Authenticated write permission on fork (API)"
  else
    # Some tokens hide permissions; fall back to info
    printf 'INFO    Could not confirm push permission via API (got: %s)\n' "${perm:-empty}"
    printf 'ACTION  Ensure your GitHub identity can push to %s\n' "${writable_norm}"
  fi
else
  printf 'INFO    Skipping API write-permission probe (gh unauthenticated or unavailable)\n'
fi

# SSH remote without key
if [[ "${origin}" == git@* ]]; then
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com >/dev/null 2>&1; then
    pass "SSH authentication to github.com works"
  else
    fail "SSH authentication to github.com" \
      "origin uses SSH but BatchMode ssh failed" \
      "Switch origin to HTTPS or load an SSH key: git remote set-url origin https://github.com/${writable_norm}.git"
  fi
fi

printf '\n'
if [[ "${FAILS}" -gt 0 ]]; then
  printf 'verify-github-write-readiness: FAILED (%s)\n' "${FAILS}" >&2
  exit 1
fi
printf 'verify-github-write-readiness: OK\n'
printf 'NOTE: This check does not create commits or branches on the canonical repository.\n'
exit 0
