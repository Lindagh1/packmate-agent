#!/usr/bin/env bash
# Non-destructive GitHub write-readiness check for workshop promotion.
# Never prints tokens. Never commits. Distinguishes read vs write access.
#
# Optional write probe (creates and deletes a temporary remote ref) requires:
#   CONFIRM_GITHUB_WRITE_PROBE=fork-only
#
# Never runs git credential store with a plaintext token.
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

# --- Askpass / VS Code socket detection ------------------------------------
ASKPASS_ISSUE="false"
askpass="${GIT_ASKPASS:-${SSH_ASKPASS:-}}"
if [[ -n "${askpass}" ]]; then
  if [[ "${askpass}" == *".cursor-server"* ]] || [[ "${askpass}" == *"code"*askpass* ]] || [[ "${askpass}" == *"vscode"* ]]; then
    ASKPASS_ISSUE="true"
    printf 'INFO    GIT_ASKPASS appears to be a VS Code/Cursor askpass helper: %s\n' "${askpass}"
    printf 'DETAIL  HTTPS git push often fails with: 403 Missing or invalid credentials / askpass ECONNREFUSED\n'
    printf 'ACTION  Open a Workbench/system terminal and: unset GIT_ASKPASS SSH_ASKPASS VSCODE_GIT_ASKPASS_NODE VSCODE_GIT_IPC_HANDLE\n'
  fi
fi
if [[ -n "${VSCODE_GIT_ASKPASS_NODE:-}" || -n "${VSCODE_GIT_IPC_HANDLE:-}" ]]; then
  ASKPASS_ISSUE="true"
  printf 'INFO    VS Code Git IPC environment detected\n'
  printf 'ACTION  Prefer a plain terminal for git push / gh pr create during Module D\n'
fi
if [[ "${ASKPASS_ISSUE}" == "true" ]]; then
  fail "VS Code askpass helper is safe for HTTPS push" \
    "askpass/IPC helpers frequently return ECONNREFUSED in this Workbench" \
    "Unset askpass vars in a system terminal before git push"
fi

# --- Repository read access ------------------------------------------------
if git ls-remote --heads origin "${base}" >/dev/null 2>&1; then
  pass "Repository read access to origin"
  pass "Promotion base branch exists on origin (${base})"
else
  if git ls-remote origin HEAD >/dev/null 2>&1; then
    fail "Promotion base branch exists on origin" \
      "origin is reachable but refs/heads/${base} is missing" \
      "On GitHub: ensure the branch was forked (disable 'Copy the main branch only'), or: git push origin ${base}"
  else
    fail "Repository read access to origin" \
      "git ls-remote origin failed" \
      "Check network/VPN and repository visibility"
  fi
fi

# --- gh CLI ----------------------------------------------------------------
GH_OK="false"
if command -v gh >/dev/null 2>&1; then
  pass "gh CLI is installed"
  if gh auth status >/dev/null 2>&1; then
    pass "gh CLI is authenticated"
    GH_OK="true"
  else
    fail "gh CLI is authenticated" \
      "gh auth status failed" \
      "Run: gh auth login -h github.com -p https -w   (fine-grained token with Contents: Read and Write on the fork). Never paste tokens into sandbox.env or screenshots."
  fi
else
  printf 'INFO    gh CLI not installed — browser-only PR creation is required after git push\n'
  printf 'ACTION  After pushing a promote/* branch, open the compare URL printed by the promote script\n'
  printf 'INFO    Browser-only PR creation: supported when git push succeeds\n'
fi

# --- Authenticated write permission ----------------------------------------
WRITE_VERIFIED="false"
if [[ "${GH_OK}" == "true" && -n "${writable_norm}" ]]; then
  perm="$(gh api "repos/${writable_norm}" --jq '.permissions.push // .permissions.admin // false' 2>/dev/null || true)"
  if [[ "${perm}" == "true" ]]; then
    pass "Authenticated write permission on fork (API)"
    WRITE_VERIFIED="true"
  else
    printf 'INFO    Could not confirm push permission via API (got: %s)\n' "${perm:-empty}"
    printf 'ACTION  Ensure your GitHub identity can push to %s\n' "${writable_norm}"
  fi
else
  printf 'INFO    Skipping API write-permission probe (gh unauthenticated or unavailable)\n'
fi

# --- SSH remote ------------------------------------------------------------
if [[ "${origin}" == git@* ]]; then
  if ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com >/dev/null 2>&1; then
    pass "SSH authentication to github.com works"
    WRITE_VERIFIED="true"
  else
    fail "SSH authentication to github.com" \
      "origin uses SSH but BatchMode ssh failed" \
      "Option C failed — switch origin to HTTPS or load an SSH key: git remote set-url origin https://github.com/${writable_norm}.git"
  fi
fi

# --- Optional explicit write probe (fork only) -----------------------------
if [[ "${CONFIRM_GITHUB_WRITE_PROBE:-}" == "fork-only" ]]; then
  if [[ -z "${writable_norm}" ]] || packmate_is_canonical_owner_repo "${writable_norm}"; then
    blocked "Write probe only on participant fork" \
      "refusing probe against canonical or unset fork" \
      "Point origin at the fork"
  else
    probe="packmate-write-probe-$(date -u +%Y%m%d%H%M%S)-$$"
    if git push origin "HEAD:refs/heads/${probe}" >/tmp/packmate-write-probe.log 2>&1; then
      git push origin --delete "${probe}" >/dev/null 2>&1 || true
      pass "Explicit fork write probe succeeded (temporary ref created and deleted)"
      WRITE_VERIFIED="true"
    else
      fail "Explicit fork write probe" \
        "git push of temporary ref failed" \
        "Fix HTTPS/SSH auth (options A–C below); do not store tokens in Git"
      sed -n '1,8p' /tmp/packmate-write-probe.log >&2 || true
    fi
    rm -f /tmp/packmate-write-probe.log
  fi
else
  if [[ "${WRITE_VERIFIED}" != "true" ]]; then
    printf 'INFO    Authenticated write remains UNVERIFIED (no destructive probe)\n'
    printf 'ACTION  To probe safely: CONFIRM_GITHUB_WRITE_PROBE=fork-only make verify-github-write-readiness\n'
  fi
fi

printf '\n'
printf 'Supported write options (never put tokens in Git, sandbox.env, scripts, or docs):\n'
printf '  A) Fine-grained GitHub token at the interactive HTTPS password prompt\n'
printf '  B) Git credential helper configured by you per organization policy\n'
printf '  C) SSH remote when a valid SSH key is already available\n'
printf 'Do NOT run: git credential store with a plaintext token from this workshop.\n'
printf '\n'

if [[ "${FAILS}" -gt 0 ]]; then
  printf 'verify-github-write-readiness: FAILED (%s)\n' "${FAILS}" >&2
  exit 1
fi
printf 'verify-github-write-readiness: OK\n'
if [[ "${WRITE_VERIFIED}" == "true" ]]; then
  printf 'WRITE_STATUS=verified\n'
else
  printf 'WRITE_STATUS=unverified\n'
fi
printf 'NOTE: This check does not create commits on packmate-v2 or the canonical repository.\n'
exit 0
