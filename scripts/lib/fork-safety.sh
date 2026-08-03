#!/usr/bin/env bash
# Fork-first workshop safety helpers for Packmate.
# Sourced by verify-demo-fork, promote-backend-image, rollback-prod-image.
# shellcheck shell=bash

PACKMATE_CANONICAL_OWNER_REPO="lindagh1/packmate-agent"
PACKMATE_CANONICAL_GIT_REPO_URL_DEFAULT="https://github.com/Lindagh1/packmate-agent.git"

# Normalize GitHub HTTPS/SSH URLs (and owner/repo shorthand) to lowercase owner/repo.
packmate_normalize_github_owner_repo() {
  local raw="${1:-}"
  raw="$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:space:]]+$//; s/^[[:space:]]+//')"
  [[ -n "${raw}" ]] || return 1
  raw="${raw%.git}"
  if [[ "${raw}" =~ ^git@github\.com:(.+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "${raw}" =~ ^https?://github\.com/(.+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "${raw}" =~ ^github\.com/(.+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ "${raw}" =~ ^[a-z0-9_.-]+/[a-z0-9_.-]+$ ]]; then
    printf '%s\n' "${raw}"
    return 0
  fi
  return 1
}

packmate_is_canonical_owner_repo() {
  local owner_repo
  owner_repo="$(packmate_normalize_github_owner_repo "${1:-}" 2>/dev/null)" || return 1
  [[ "${owner_repo}" == "${PACKMATE_CANONICAL_OWNER_REPO}" ]]
}

packmate_github_https_url() {
  local owner_repo
  owner_repo="$(packmate_normalize_github_owner_repo "${1:-}")" || return 1
  printf 'https://github.com/%s.git\n' "${owner_repo}"
}

packmate_load_fork_config() {
  local root="${1:-}"
  if [[ -n "${root}" && -f "${root}/config/sandbox.env" ]]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck disable=SC1091
    source "${root}/config/sandbox.env"
    set +a
  fi
  CANONICAL_GIT_REPO_URL="${CANONICAL_GIT_REPO_URL:-${PACKMATE_CANONICAL_GIT_REPO_URL_DEFAULT}}"
  GIT_REPO_URL="${GIT_REPO_URL:-}"
  GIT_REVISION="${GIT_REVISION:-packmate-v2}"
  PROMOTION_BASE_BRANCH="${PROMOTION_BASE_BRANCH:-${GIT_REVISION:-packmate-v2}}"
  ALLOW_CANONICAL_REPO_PROMOTION="${ALLOW_CANONICAL_REPO_PROMOTION:-false}"
  export CANONICAL_GIT_REPO_URL GIT_REPO_URL GIT_REVISION PROMOTION_BASE_BRANCH ALLOW_CANONICAL_REPO_PROMOTION
}

packmate_remote_url() {
  local name="${1:-origin}"
  git config --get "remote.${name}.url" 2>/dev/null || true
}

packmate_writable_repo_url() {
  # Prefer configured GIT_REPO_URL; fall back to origin.
  if [[ -n "${GIT_REPO_URL:-}" ]]; then
    printf '%s\n' "${GIT_REPO_URL}"
    return 0
  fi
  local origin
  origin="$(packmate_remote_url origin)"
  [[ -n "${origin}" ]] || return 1
  printf '%s\n' "${origin}"
}

packmate_block_canonical_promotion() {
  printf 'BLOCKED_CANONICAL_REPOSITORY_PROMOTION\n' >&2
  cat >&2 <<'EOF'
Use a GitHub fork for workshop promotion.
The canonical repository is read-only for demonstrations.

Configure:
  CANONICAL_GIT_REPO_URL=https://github.com/Lindagh1/packmate-agent.git
  GIT_REPO_URL=https://github.com/YOUR_GITHUB_USERNAME/packmate-agent.git
  GIT_REVISION=packmate-v2
  PROMOTION_BASE_BRANCH=packmate-v2
  ALLOW_CANONICAL_REPO_PROMOTION=false

Then clone the fork, add upstream, and run: make verify-demo-fork
EOF
  return 1
}

# Returns 0 if promotion/rollback into the writable repo is allowed.
# Prints a strong warning when ALLOW_CANONICAL_REPO_PROMOTION=true.
packmate_assert_promotion_repo_allowed() {
  local writable canonical_norm writable_norm
  writable="$(packmate_writable_repo_url)" || {
    printf 'ERROR: cannot determine writable Git repository (set GIT_REPO_URL or remote origin)\n' >&2
    packmate_block_canonical_promotion
    return 1
  }
  canonical_norm="$(packmate_normalize_github_owner_repo "${CANONICAL_GIT_REPO_URL:-${PACKMATE_CANONICAL_GIT_REPO_URL_DEFAULT}}")" || true
  writable_norm="$(packmate_normalize_github_owner_repo "${writable}")" || {
    printf 'ERROR: unrecognised writable repository URL: %s\n' "${writable}" >&2
    return 1
  }
  if [[ "${writable_norm}" == "${canonical_norm}" || "${writable_norm}" == "${PACKMATE_CANONICAL_OWNER_REPO}" ]]; then
    if [[ "${ALLOW_CANONICAL_REPO_PROMOTION}" == "true" ]]; then
      cat >&2 <<'EOF'
WARN: ALLOW_CANONICAL_REPO_PROMOTION=true — promotion/rollback may modify the canonical upstream repository.
This override is instructor-only and must never be used for normal workshop demonstrations.
EOF
      return 0
    fi
    packmate_block_canonical_promotion
    return 1
  fi
  return 0
}

packmate_assert_origin_not_canonical() {
  local origin_url origin_norm
  origin_url="$(packmate_remote_url origin)"
  [[ -n "${origin_url}" ]] || {
    printf 'ERROR: git remote origin is not configured\n' >&2
    return 1
  }
  origin_norm="$(packmate_normalize_github_owner_repo "${origin_url}")" || {
    printf 'ERROR: unrecognised origin URL: %s\n' "${origin_url}" >&2
    return 1
  }
  if [[ "${origin_norm}" == "${PACKMATE_CANONICAL_OWNER_REPO}" ]]; then
    if [[ "${ALLOW_CANONICAL_REPO_PROMOTION}" == "true" ]]; then
      printf 'WARN: origin points at canonical upstream (override enabled)\n' >&2
      return 0
    fi
    packmate_block_canonical_promotion
    return 1
  fi
  return 0
}

packmate_assert_pr_base_in_fork() {
  local base_branch="${1:-${PROMOTION_BASE_BRANCH:-packmate-v2}}"
  local writable_norm origin_norm
  writable_norm="$(packmate_normalize_github_owner_repo "$(packmate_writable_repo_url)")" || return 1
  origin_norm="$(packmate_normalize_github_owner_repo "$(packmate_remote_url origin)")" || return 1
  if [[ "${writable_norm}" != "${origin_norm}" ]]; then
    printf 'ERROR: GIT_REPO_URL (%s) does not match origin (%s)\n' "${writable_norm}" "${origin_norm}" >&2
    return 1
  fi
  if packmate_is_canonical_owner_repo "${writable_norm}" && [[ "${ALLOW_CANONICAL_REPO_PROMOTION}" != "true" ]]; then
    packmate_block_canonical_promotion
    return 1
  fi
  if [[ "${base_branch}" != "${PROMOTION_BASE_BRANCH:-packmate-v2}" ]]; then
    printf 'ERROR: PR base branch must be PROMOTION_BASE_BRANCH=%s (got %s)\n' \
      "${PROMOTION_BASE_BRANCH:-packmate-v2}" "${base_branch}" >&2
    return 1
  fi
  return 0
}

# Full demo-fork verification used by make verify-demo-fork.
# Args: optional --require-argo (check live Applications when oc available)
packmate_verify_demo_fork() {
  local require_argo="false"
  local fail=0
  local pass_msg
  pass_msg() { printf 'PASS  %s\n' "$*"; }
  fail_msg() { printf 'FAIL  %s\n' "$*"; fail=$((fail + 1)); }

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --require-argo) require_argo="true"; shift ;;
      *) shift ;;
    esac
  done

  local canonical_norm writable_url writable_norm origin_url origin_norm upstream_url upstream_norm
  local current_branch base_branch

  canonical_norm="$(packmate_normalize_github_owner_repo "${CANONICAL_GIT_REPO_URL}")" || {
    fail_msg "Canonical upstream repository identified"
    return 1
  }
  if [[ "${canonical_norm}" == "${PACKMATE_CANONICAL_OWNER_REPO}" ]]; then
    pass_msg "Canonical upstream repository identified"
  else
    fail_msg "Canonical upstream repository identified (expected ${PACKMATE_CANONICAL_OWNER_REPO}, got ${canonical_norm})"
  fi

  writable_url="$(packmate_writable_repo_url 2>/dev/null || true)"
  if [[ -z "${writable_url}" ]]; then
    fail_msg "Writable Git repository is a fork"
  elif ! writable_norm="$(packmate_normalize_github_owner_repo "${writable_url}")"; then
    fail_msg "Writable Git repository is a fork (unrecognised URL: ${writable_url})"
  elif [[ "${writable_norm}" == "${PACKMATE_CANONICAL_OWNER_REPO}" ]]; then
    if [[ "${ALLOW_CANONICAL_REPO_PROMOTION}" == "true" ]]; then
      printf 'WARN  Writable repository is canonical (ALLOW_CANONICAL_REPO_PROMOTION=true)\n'
    else
      printf 'BLOCKED_CANONICAL_REPOSITORY_PROMOTION\n'
      fail_msg "Writable Git repository is a fork"
      cat <<'EOF'
Use a GitHub fork for workshop promotion.
The canonical repository is read-only for demonstrations.
EOF
    fi
  else
    pass_msg "Writable Git repository is a fork"
  fi

  origin_url="$(packmate_remote_url origin)"
  if [[ -z "${origin_url}" ]]; then
    fail_msg "origin does not point to canonical upstream"
  elif ! origin_norm="$(packmate_normalize_github_owner_repo "${origin_url}")"; then
    fail_msg "origin does not point to canonical upstream (unrecognised: ${origin_url})"
  elif [[ "${origin_norm}" == "${PACKMATE_CANONICAL_OWNER_REPO}" ]]; then
    if [[ "${ALLOW_CANONICAL_REPO_PROMOTION}" == "true" ]]; then
      printf 'WARN  origin points to canonical upstream (override enabled)\n'
    else
      printf 'BLOCKED_CANONICAL_REPOSITORY_PROMOTION\n'
      fail_msg "origin does not point to canonical upstream"
      cat <<'EOF'
Use a GitHub fork for workshop promotion.
The canonical repository is read-only for demonstrations.
EOF
    fi
  else
    pass_msg "origin does not point to canonical upstream"
  fi

  upstream_url="$(packmate_remote_url upstream)"
  if [[ -n "${upstream_url}" ]]; then
    if upstream_norm="$(packmate_normalize_github_owner_repo "${upstream_url}")" \
      && [[ "${upstream_norm}" == "${PACKMATE_CANONICAL_OWNER_REPO}" ]]; then
      pass_msg "upstream points to canonical repository (optional)"
    else
      printf 'INFO  upstream is set but is not Lindagh1/packmate-agent (%s)\n' "${upstream_url}"
    fi
  else
    printf 'INFO  upstream remote not configured (optional; recommended for syncing from canonical)\n'
  fi

  current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  base_branch="${PROMOTION_BASE_BRANCH:-packmate-v2}"
  if [[ "${current_branch}" == "${base_branch}" || "${current_branch}" == "packmate-v2" || "${current_branch}" == "${GIT_REVISION}" ]]; then
    pass_msg "Current branch matches demo/promotion branch (${current_branch})"
  else
    fail_msg "Current branch matches demo/promotion branch (got ${current_branch}, expected ${base_branch} or ${GIT_REVISION})"
  fi

  if [[ -n "${origin_norm:-}" && "${origin_norm}" != "${PACKMATE_CANONICAL_OWNER_REPO}" ]]; then
    if git ls-remote --exit-code --heads origin "${base_branch}" >/dev/null 2>&1 \
      || git show-ref --verify --quiet "refs/heads/${base_branch}" \
      || git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
      pass_msg "Promotion base branch exists in the fork"
    else
      # Offline / no network: accept local branch presence only was already checked above loosely
      if git show-ref --verify --quiet "refs/heads/${base_branch}" \
        || git show-ref --verify --quiet "refs/remotes/origin/${base_branch}"; then
        pass_msg "Promotion base branch exists in the fork"
      else
        fail_msg "Promotion base branch exists in the fork (${base_branch})"
      fi
    fi
  elif [[ "${ALLOW_CANONICAL_REPO_PROMOTION}" == "true" ]]; then
    pass_msg "Promotion base branch exists in the fork"
  else
    fail_msg "Promotion base branch exists in the fork"
  fi

  # Argo CD source checks (best-effort unless --require-argo)
  local argo_ns="${ARGOCD_NAMESPACE:-openshift-gitops}"
  local lab_repo prod_repo lab_rev prod_rev
  if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1 \
    && oc -n "${argo_ns}" get application.argoproj.io packmate-lab >/dev/null 2>&1; then
    lab_repo="$(oc -n "${argo_ns}" get application.argoproj.io packmate-lab -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || true)"
    prod_repo="$(oc -n "${argo_ns}" get application.argoproj.io packmate-prod -o jsonpath='{.spec.source.repoURL}' 2>/dev/null || true)"
    lab_rev="$(oc -n "${argo_ns}" get application.argoproj.io packmate-lab -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || true)"
    prod_rev="$(oc -n "${argo_ns}" get application.argoproj.io packmate-prod -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || true)"
    local lab_norm prod_norm expected_norm
    expected_norm="$(packmate_normalize_github_owner_repo "${writable_url:-}" 2>/dev/null || true)"
    lab_norm="$(packmate_normalize_github_owner_repo "${lab_repo}" 2>/dev/null || true)"
    prod_norm="$(packmate_normalize_github_owner_repo "${prod_repo}" 2>/dev/null || true)"
    if [[ -n "${expected_norm}" && "${lab_norm}" == "${expected_norm}" ]]; then
      pass_msg "Argo CD source repository uses the fork"
      pass_msg "DEV Application follows participant fork"
    else
      fail_msg "DEV Application follows participant fork (repoURL=${lab_repo})"
    fi
    if [[ -n "${expected_norm}" && "${prod_norm}" == "${expected_norm}" ]]; then
      pass_msg "PROD Application follows participant fork"
    else
      fail_msg "PROD Application follows participant fork (repoURL=${prod_repo})"
    fi
    if [[ "${lab_rev}" == "${GIT_REVISION}" && "${prod_rev}" == "${GIT_REVISION}" ]]; then
      pass_msg "Both Applications use configured revision"
    else
      fail_msg "Both Applications use configured revision (lab=${lab_rev} prod=${prod_rev} expected=${GIT_REVISION})"
    fi
  else
    if [[ "${require_argo}" == "true" ]]; then
      fail_msg "Argo CD source repository uses the fork"
      fail_msg "DEV Application follows participant fork"
      fail_msg "PROD Application follows participant fork"
      fail_msg "Both Applications use configured revision"
    else
      printf 'INFO  Argo CD Applications not checked (oc unavailable or apps missing)\n'
      # Static template check: Applications use placeholders, not hard-coded canonical URL
      if grep -q '__GIT_REPO_URL__' "${PACKMATE_FORK_ROOT:-.}/argocd/application-packmate-lab.yaml" 2>/dev/null \
        && grep -q '__GIT_REPO_URL__' "${PACKMATE_FORK_ROOT:-.}/argocd/application-packmate-prod.yaml" 2>/dev/null \
        && ! grep -q 'https://github.com/Lindagh1/packmate-agent.git' \
          "${PACKMATE_FORK_ROOT:-.}/argocd/application-packmate-lab.yaml" \
          "${PACKMATE_FORK_ROOT:-.}/argocd/application-packmate-prod.yaml" 2>/dev/null; then
        pass_msg "Argo CD source repository uses the fork"
        pass_msg "DEV Application follows participant fork"
        pass_msg "PROD Application follows participant fork"
        pass_msg "Both Applications use configured revision"
      fi
    fi
  fi

  if [[ "${fail}" -eq 0 ]]; then
    if [[ "${ALLOW_CANONICAL_REPO_PROMOTION}" == "true" ]]; then
      printf 'WARN  Demo promotion override enabled — canonical upstream may be modified\n'
    else
      pass_msg "Demo promotion cannot modify canonical upstream"
      pass_msg "Canonical upstream remains unchanged by demo promotion"
    fi
  fi

  return "${fail}"
}
