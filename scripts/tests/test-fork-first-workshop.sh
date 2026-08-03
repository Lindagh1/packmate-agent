#!/usr/bin/env bash
# Automated checks for the fork-first workshop model.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/fork-safety.sh"

PASS=0
FAIL=0
pass() { printf 'PASS  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL + 1)); }

echo "=== Fork-first workshop tests ==="

# 1. Canonical HTTPS
if out="$(packmate_normalize_github_owner_repo 'https://github.com/Lindagh1/packmate-agent.git')" \
  && [[ "${out}" == "lindagh1/packmate-agent" ]] \
  && packmate_is_canonical_owner_repo 'https://github.com/Lindagh1/packmate-agent.git'; then
  pass "canonical upstream URL recognized (HTTPS)"
else
  fail "canonical upstream URL recognized (HTTPS)"
fi

# 2. Canonical SSH
if packmate_is_canonical_owner_repo 'git@github.com:Lindagh1/packmate-agent.git'; then
  pass "canonical upstream URL recognized (SSH)"
else
  fail "canonical upstream URL recognized (SSH)"
fi

# 3. Fork URL accepted
if ! packmate_is_canonical_owner_repo 'https://github.com/demo-user/packmate-agent.git' \
  && out="$(packmate_normalize_github_owner_repo 'https://github.com/demo-user/packmate-agent')" \
  && [[ "${out}" == "demo-user/packmate-agent" ]]; then
  pass "fork URL is accepted"
else
  fail "fork URL is accepted"
fi

TMP="$(mktemp -d /tmp/packmate-fork-test.XXXXXX)"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

# Isolated git repo simulating a fork clone
git init -q -b packmate-v2 "${TMP}/fork"
git -C "${TMP}/fork" remote add origin 'https://github.com/demo-user/packmate-agent.git'
git -C "${TMP}/fork" remote add upstream 'https://github.com/Lindagh1/packmate-agent.git'
git -C "${TMP}/fork" config user.email 'test@example.com'
git -C "${TMP}/fork" config user.name 'test'
git -C "${TMP}/fork" commit --allow-empty -qm 'init'

# Isolated git repo simulating accidental canonical clone
git init -q -b packmate-v2 "${TMP}/canonical"
git -C "${TMP}/canonical" remote add origin 'https://github.com/Lindagh1/packmate-agent.git'
git -C "${TMP}/canonical" config user.email 'test@example.com'
git -C "${TMP}/canonical" config user.name 'test'
git -C "${TMP}/canonical" commit --allow-empty -qm 'init'

run_in() {
  local dir="$1"
  shift
  (
    cd "${dir}"
    # shellcheck disable=SC1091
    source "${ROOT}/scripts/lib/fork-safety.sh"
    "$@"
  )
}

# 4. origin pointing to canonical blocks promotion
CANONICAL_GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git'
ALLOW_CANONICAL_REPO_PROMOTION=false
GIT_REPO_URL=''
export CANONICAL_GIT_REPO_URL ALLOW_CANONICAL_REPO_PROMOTION GIT_REPO_URL
if ! run_in "${TMP}/canonical" packmate_assert_origin_not_canonical >/tmp/packmate-ff-4.txt 2>&1 \
  && grep -q 'BLOCKED_CANONICAL_REPOSITORY_PROMOTION' /tmp/packmate-ff-4.txt; then
  pass "origin pointing to canonical upstream blocks promotion"
else
  fail "origin pointing to canonical upstream blocks promotion"
  sed -n '1,20p' /tmp/packmate-ff-4.txt || true
fi

# 5. GIT_REPO_URL pointing to canonical blocks promotion
GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git'
export GIT_REPO_URL
if ! run_in "${TMP}/fork" env GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git' \
    ALLOW_CANONICAL_REPO_PROMOTION=false \
    bash -c 'source "'"${ROOT}"'/scripts/lib/fork-safety.sh"; packmate_assert_promotion_repo_allowed' \
    >/tmp/packmate-ff-5.txt 2>&1 \
  && grep -q 'BLOCKED_CANONICAL_REPOSITORY_PROMOTION' /tmp/packmate-ff-5.txt; then
  pass "GIT_REPO_URL pointing to canonical upstream blocks promotion"
else
  fail "GIT_REPO_URL pointing to canonical upstream blocks promotion"
  sed -n '1,20p' /tmp/packmate-ff-5.txt || true
fi

# 6. fork origin + canonical upstream passes
GIT_REPO_URL='https://github.com/demo-user/packmate-agent.git'
PROMOTION_BASE_BRANCH=packmate-v2
GIT_REVISION=packmate-v2
ALLOW_CANONICAL_REPO_PROMOTION=false
export GIT_REPO_URL PROMOTION_BASE_BRANCH GIT_REVISION ALLOW_CANONICAL_REPO_PROMOTION
if run_in "${TMP}/fork" env \
    GIT_REPO_URL='https://github.com/demo-user/packmate-agent.git' \
    CANONICAL_GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git' \
    PROMOTION_BASE_BRANCH=packmate-v2 \
    GIT_REVISION=packmate-v2 \
    ALLOW_CANONICAL_REPO_PROMOTION=false \
    PACKMATE_FORK_ROOT="${ROOT}" \
    bash -c 'source "'"${ROOT}"'/scripts/lib/fork-safety.sh"; packmate_assert_origin_not_canonical && packmate_assert_promotion_repo_allowed && packmate_assert_pr_base_in_fork packmate-v2' \
    >/tmp/packmate-ff-6.txt 2>&1; then
  pass "fork origin plus canonical upstream remote passes"
else
  fail "fork origin plus canonical upstream remote passes"
  sed -n '1,40p' /tmp/packmate-ff-6.txt || true
fi

# 7. promotion PR base remains inside the fork (script uses --repo FORK_REPO)
if grep -q -- '--repo "${FORK_REPO}"' "${ROOT}/scripts/promote-backend-image.sh" \
  && grep -q 'packmate_assert_pr_base_in_fork' "${ROOT}/scripts/promote-backend-image.sh" \
  && grep -q 'assert_fork_promotion_safe' "${ROOT}/scripts/promote-backend-image.sh"; then
  pass "promotion PR base remains inside the fork"
else
  fail "promotion PR base remains inside the fork"
fi

# 8. rollback PR base remains inside the fork
if grep -q -- '--repo "${FORK_REPO}"' "${ROOT}/scripts/rollback-prod-image.sh" \
  && grep -q 'packmate_assert_pr_base_in_fork' "${ROOT}/scripts/rollback-prod-image.sh" \
  && grep -q 'Fork-first rollback safety' "${ROOT}/scripts/rollback-prod-image.sh"; then
  pass "rollback PR base remains inside the fork"
else
  fail "rollback PR base remains inside the fork"
fi

# 9–11. Argo CD Applications use placeholders / configured fork+revision
if grep -q 'repoURL: __GIT_REPO_URL__' "${ROOT}/argocd/application-packmate-lab.yaml" \
  && ! grep -q 'https://github.com/Lindagh1/packmate-agent.git' "${ROOT}/argocd/application-packmate-lab.yaml"; then
  pass "Argo CD DEV uses configured fork URL (placeholder)"
else
  fail "Argo CD DEV uses configured fork URL (placeholder)"
fi

if grep -q 'repoURL: __GIT_REPO_URL__' "${ROOT}/argocd/application-packmate-prod.yaml" \
  && ! grep -q 'https://github.com/Lindagh1/packmate-agent.git' "${ROOT}/argocd/application-packmate-prod.yaml"; then
  pass "Argo CD PROD uses configured fork URL (placeholder)"
else
  fail "Argo CD PROD uses configured fork URL (placeholder)"
fi

if grep -q 'targetRevision: __GIT_REVISION__' "${ROOT}/argocd/application-packmate-lab.yaml" \
  && grep -q 'targetRevision: __GIT_REVISION__' "${ROOT}/argocd/application-packmate-prod.yaml"; then
  pass "both Applications use configured revision (placeholder)"
else
  fail "both Applications use configured revision (placeholder)"
fi

# apply script substitutes GIT_REPO_URL / GIT_REVISION
if grep -q '__GIT_REPO_URL__|${GIT_REPO_URL}' "${ROOT}/scripts/apply-packmate-argocd.sh" \
  && grep -q '__GIT_REVISION__|${GIT_REVISION}' "${ROOT}/scripts/apply-packmate-argocd.sh"; then
  pass "apply-packmate-argocd substitutes fork URL and revision"
else
  fail "apply-packmate-argocd substitutes fork URL and revision"
fi

# 12. promotion scripts never create Git tags (ignore documentation comments)
if ! grep -E '^[[:space:]]*(git[[:space:]]+tag|gh[[:space:]]+release)' \
      "${ROOT}/scripts/promote-backend-image.sh" \
      "${ROOT}/scripts/rollback-prod-image.sh" >/dev/null 2>&1; then
  pass "promotion/rollback scripts never create Git tags"
else
  fail "promotion/rollback scripts never create Git tags"
fi

# 13. Pipeline never creates Git tags or GitHub Releases
if ! grep -RInE 'git tag|gh release create|gh release' "${ROOT}/.tekton" >/dev/null 2>&1; then
  pass "Pipeline never creates Git tags or GitHub Releases"
else
  fail "Pipeline never creates Git tags or GitHub Releases"
fi

# 14. demo branch supported via PROMOTION_BASE_BRANCH / GIT_REVISION
git -C "${TMP}/fork" checkout -qb demo/sandbox2571
if run_in "${TMP}/fork" env \
    GIT_REPO_URL='https://github.com/demo-user/packmate-agent.git' \
    CANONICAL_GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git' \
    PROMOTION_BASE_BRANCH=demo/sandbox2571 \
    GIT_REVISION=demo/sandbox2571 \
    ALLOW_CANONICAL_REPO_PROMOTION=false \
    bash -c 'source "'"${ROOT}"'/scripts/lib/fork-safety.sh"; packmate_assert_pr_base_in_fork demo/sandbox2571' \
    >/tmp/packmate-ff-14.txt 2>&1; then
  pass "demo branch is supported"
else
  fail "demo branch is supported"
  sed -n '1,20p' /tmp/packmate-ff-14.txt || true
fi
git -C "${TMP}/fork" checkout -q packmate-v2

# 15. mocked promotion does not touch canonical (block when GIT_REPO_URL canonical)
MOCK_CANONICAL_HEAD="$(git -C "${TMP}/canonical" rev-parse HEAD)"
if ! (
  cd "${TMP}/fork"
  export GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git'
  export ALLOW_CANONICAL_REPO_PROMOTION=false
  # shellcheck disable=SC1091
  source "${ROOT}/scripts/lib/fork-safety.sh"
  packmate_assert_promotion_repo_allowed
) >/tmp/packmate-ff-15.txt 2>&1 \
  && [[ "$(git -C "${TMP}/canonical" rev-parse HEAD)" == "${MOCK_CANONICAL_HEAD}" ]] \
  && grep -q 'BLOCKED_CANONICAL_REPOSITORY_PROMOTION' /tmp/packmate-ff-15.txt; then
  pass "canonical branch remains untouched during mocked promotion"
else
  fail "canonical branch remains untouched during mocked promotion"
fi

# Config example must not enable canonical promotion / must use fork placeholder
if grep -q 'ALLOW_CANONICAL_REPO_PROMOTION=false' "${ROOT}/config/sandbox.env.example" \
  && grep -q 'YOUR_GITHUB_USERNAME' "${ROOT}/config/sandbox.env.example" \
  && grep -q 'CANONICAL_GIT_REPO_URL=' "${ROOT}/config/sandbox.env.example"; then
  pass "sandbox.env.example is fork-first"
else
  fail "sandbox.env.example is fork-first"
fi

# verify-demo-fork Make target + script exist
if [[ -x "${ROOT}/scripts/verify-demo-fork.sh" ]] \
  && grep -q 'verify-demo-fork' "${ROOT}/Makefile"; then
  pass "verify-demo-fork target and script present"
else
  fail "verify-demo-fork target and script present"
fi

printf '\nfork-first summary: PASS=%s FAIL=%s\n' "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
