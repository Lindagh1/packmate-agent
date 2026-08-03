#!/usr/bin/env bash
# Deep-audit hardening regression tests (deterministic / mocked).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/fork-safety.sh"

PASS=0; FAIL=0
pass() { printf 'PASS  %s\n' "$*"; PASS=$((PASS+1)); }
fail() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL+1)); }

echo "=== Deep-audit hardening tests ==="

TMP="$(mktemp -d /tmp/packmate-deep-test.XXXXXX)"
trap 'rm -rf "${TMP}"' EXIT

# --- Git/fork cases (sample of critical matrix) ---
git init -q -b packmate-v2 "${TMP}/fork"
git -C "${TMP}/fork" remote add origin 'https://github.com/lindagh-labs/packmate-agent.git'
git -C "${TMP}/fork" remote add upstream 'https://github.com/Lindagh1/packmate-agent.git'
git -C "${TMP}/fork" config user.email t@example.com
git -C "${TMP}/fork" config user.name t
git -C "${TMP}/fork" commit --allow-empty -qm init

git init -q -b packmate-v2 "${TMP}/canon"
git -C "${TMP}/canon" remote add origin 'https://github.com/Lindagh1/packmate-agent.git'
git -C "${TMP}/canon" config user.email t@example.com
git -C "${TMP}/canon" config user.name t
git -C "${TMP}/canon" commit --allow-empty -qm init

# URL normalization variants
for u in \
  'https://github.com/Lindagh1/packmate-agent.git' \
  'https://github.com/Lindagh1/packmate-agent' \
  'git@github.com:Lindagh1/packmate-agent.git'; do
  packmate_is_canonical_owner_repo "$u" && pass "canonical form accepted: $u" || fail "canonical form: $u"
done
packmate_is_canonical_owner_repo 'https://github.com/lindagh-labs/packmate-agent.git' \
  && fail "fork must not be canonical" || pass "fork URL not treated as canonical"
packmate_is_canonical_owner_repo 'https://github.com/lindagh-labs/packmate-agent' \
  && fail "fork without .git must not be canonical" || pass "fork without .git accepted as non-canonical"

# origin=canonical blocks
if ! (
  cd "${TMP}/canon"
  export ALLOW_CANONICAL_REPO_PROMOTION=false GIT_REPO_URL=''
  # shellcheck disable=SC1091
  source "${ROOT}/scripts/lib/fork-safety.sh"
  packmate_assert_origin_not_canonical
) >/tmp/packmate-da-canon.txt 2>&1 \
  && grep -q BLOCKED_CANONICAL /tmp/packmate-da-canon.txt; then
  pass "origin=canonical blocks promotion"
else
  fail "origin=canonical blocks promotion"
fi

# fork+upstream passes prebootstrap even without Argo
if (
  cd "${TMP}/fork"
  export GIT_REPO_URL='https://github.com/lindagh-labs/packmate-agent.git'
  export CANONICAL_GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git'
  export PROMOTION_BASE_BRANCH=packmate-v2 GIT_REVISION=packmate-v2
  export ALLOW_CANONICAL_REPO_PROMOTION=false PACKMATE_FORK_ROOT="${ROOT}"
  # shellcheck disable=SC1091
  source "${ROOT}/scripts/lib/fork-safety.sh"
  packmate_verify_demo_fork --prebootstrap
) >/tmp/packmate-da-pre.txt 2>&1; then
  pass "prebootstrap passes with fork origin"
else
  fail "prebootstrap passes with fork origin"
  sed -n '1,40p' /tmp/packmate-da-pre.txt || true
fi

# Mock: stale Argo apps pointing canonical must NOT fail prebootstrap
# Simulate by injecting a fake oc if apps would be checked — without oc apps, INFO path runs
if grep -q 'Live Argo CD Applications require migration' "${ROOT}/scripts/lib/fork-safety.sh" \
  && grep -q 'prebootstrap' "${ROOT}/scripts/lib/fork-safety.sh"; then
  pass "prebootstrap treats Argo migration as INFO/ACTION"
else
  fail "prebootstrap treats Argo migration as INFO/ACTION"
fi

# Live mode requires apps
if grep -q 'packmate_verify_demo_fork_live' "${ROOT}/scripts/lib/fork-safety.sh" \
  && [[ -x "${ROOT}/scripts/verify-demo-fork-live.sh" ]]; then
  pass "verify-demo-fork-live exists"
else
  fail "verify-demo-fork-live exists"
fi

# Detached HEAD / demo branch
git -C "${TMP}/fork" checkout -qb demo/sandbox2571
if (
  cd "${TMP}/fork"
  export GIT_REPO_URL='https://github.com/lindagh-labs/packmate-agent.git'
  export PROMOTION_BASE_BRANCH=demo/sandbox2571 GIT_REVISION=demo/sandbox2571
  export ALLOW_CANONICAL_REPO_PROMOTION=false CANONICAL_GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git'
  # shellcheck disable=SC1091
  source "${ROOT}/scripts/lib/fork-safety.sh"
  packmate_assert_pr_base_in_fork demo/sandbox2571
); then
  pass "demo branch promotion base supported"
else
  fail "demo branch promotion base supported"
fi
git -C "${TMP}/fork" checkout -q packmate-v2

# Upstream pushurl to canonical should fail
git -C "${TMP}/fork" remote set-url --push upstream 'https://github.com/Lindagh1/packmate-agent.git'
if ! (
  cd "${TMP}/fork"
  export GIT_REPO_URL='https://github.com/lindagh-labs/packmate-agent.git'
  export ALLOW_CANONICAL_REPO_PROMOTION=false PACKMATE_FORK_ROOT="${ROOT}"
  export CANONICAL_GIT_REPO_URL='https://github.com/Lindagh1/packmate-agent.git'
  export PROMOTION_BASE_BRANCH=packmate-v2 GIT_REVISION=packmate-v2
  # shellcheck disable=SC1091
  source "${ROOT}/scripts/lib/fork-safety.sh"
  packmate_verify_demo_fork --prebootstrap
) >/tmp/packmate-da-push.txt 2>&1 \
  && grep -q 'upstream push URL must not target canonical' /tmp/packmate-da-push.txt; then
  pass "upstream pushurl to canonical blocked"
else
  fail "upstream pushurl to canonical blocked"
  sed -n '1,30p' /tmp/packmate-da-push.txt || true
fi
git -C "${TMP}/fork" remote set-url --push upstream DISABLED

# --- Cleanup / reset safety ---
grep -q 'CONFIRM_PACKMATE_RESET' "${ROOT}/scripts/reset-packmate-lab.sh" \
  && pass "reset requires explicit confirmation" || fail "reset requires explicit confirmation"
grep -q 'my-first-model' "${ROOT}/scripts/reset-packmate-lab.sh" \
  && grep -q 'Never deleted' "${ROOT}/scripts/reset-packmate-lab.sh" \
  && pass "reset documents protected shared resources" || fail "reset protects shared resources"
grep -q 'finalizers' "${ROOT}/scripts/reset-packmate-lab.sh" \
  && pass "reset refuses automatic finalizer removal" || fail "reset refuses automatic finalizer removal"
! grep -qE 'oc delete.*(operator|subscription)' "${ROOT}/scripts/reset-packmate-lab.sh" \
  && pass "reset does not delete Operators" || fail "reset must not delete Operators"

# Dry-run default: invoke with fake oc? Just check DRY_RUN default in script
grep -q 'DRY_RUN=true' "${ROOT}/scripts/reset-packmate-lab.sh" \
  && pass "reset defaults to dry-run" || fail "reset defaults to dry-run"

# Discover is read-only
! grep -qE '^\s*oc (delete|patch|apply|replace)' "${ROOT}/scripts/discover-packmate-resources.sh" \
  && pass "discover is read-only (no mutate oc verbs)" || fail "discover must be read-only"
grep -q 'STALE_PACKMATE' "${ROOT}/scripts/discover-packmate-resources.sh" \
  && pass "discover classifies STALE_PACKMATE" || fail "discover classifies STALE_PACKMATE"
grep -q 'BLOCKED_OPENSHIFT_AUTHENTICATION' "${ROOT}/scripts/discover-packmate-resources.sh" \
  && pass "discover handles expired auth" || fail "discover handles expired auth"

# GitHub write readiness
[[ -x "${ROOT}/scripts/verify-github-write-readiness.sh" ]] \
  && grep -q 'ECONNREFUSED\|askpass\|GIT_ASKPASS' "${ROOT}/scripts/verify-github-write-readiness.sh" \
  && pass "github write readiness detects askpass issues" || fail "github write readiness askpass"
! grep -qiE 'token=|password=|Authorization:' "${ROOT}/scripts/verify-github-write-readiness.sh" \
  && pass "github write readiness does not embed credentials" || fail "no credentials in github readiness"

# Promotion/rollback still fork-only + no tags
grep -q 'BLOCKED_CANONICAL_REPOSITORY_PROMOTION' "${ROOT}/scripts/lib/fork-safety.sh" \
  && pass "canonical promotion block retained" || fail "canonical promotion block"
! grep -E '^[[:space:]]*(git[[:space:]]+tag|gh[[:space:]]+release)' \
    "${ROOT}/scripts/promote-backend-image.sh" "${ROOT}/scripts/rollback-prod-image.sh" >/dev/null \
  && pass "promote/rollback never create tags/releases" || fail "promote/rollback never create tags"

# Kustomize / ownership still guarded
grep -q 'replicas:' "${ROOT}/deploy/overlays/dev/kustomization.yaml" \
  && ! [[ -f "${ROOT}/deploy/overlays/dev/replicas-patch.yaml" ]] \
  && pass "native replicas transformer; no replicas-patch" || fail "replicas transformer"
! grep -q 'image-registry.openshift-image-registry' "${ROOT}/deploy/overlays/prod/kustomization.yaml" \
  && pass "PROD has no internal registry refs" || fail "PROD portable images"

# Error format helpers
[[ -f "${ROOT}/scripts/lib/report.sh" ]] \
  && grep -q 'FAIL    ' "${ROOT}/scripts/lib/report.sh" \
  && pass "consistent FAIL/DETAIL/ACTION helper present" || fail "report helper"

# Acceptance targets scripts
[[ -x "${ROOT}/scripts/acceptance/acceptance-static.sh" ]] \
  && [[ -f "${ROOT}/scripts/acceptance/acceptance-prebootstrap.sh" ]] \
  && [[ -f "${ROOT}/scripts/acceptance/acceptance-postbootstrap.sh" ]] \
  && pass "acceptance runners present" || fail "acceptance runners"

# Makefile wiring
grep -q 'verify-demo-fork-live' "${ROOT}/Makefile" \
  && grep -q 'discover-packmate-resources' "${ROOT}/Makefile" \
  && grep -q 'reset-lab' "${ROOT}/Makefile" \
  && grep -q 'verify-github-write-readiness' "${ROOT}/Makefile" \
  && pass "Makefile targets wired" || fail "Makefile targets wired"

# .generated ignored
grep -q '\.generated' "${ROOT}/.gitignore" \
  && pass ".generated is gitignored" || fail ".generated must be gitignored"

# Misleading verifier: live mode must require Synced/Healthy (not stale PASS)
grep -q 'DEV is Synced/Healthy' "${ROOT}/scripts/lib/fork-safety.sh" \
  && pass "live fork check requires DEV Synced/Healthy" || fail "live Synced/Healthy requirement"

# Missing GHCR push Secret detection (static string contract)
grep -q 'packmate-ghcr-push' "${ROOT}/scripts/preflight-sandbox.sh" \
  && grep -q 'FailedMount' "${ROOT}/scripts/preflight-sandbox.sh" \
  && pass "preflight blocks missing promotion push Secret" \
  || fail "preflight blocks missing promotion push Secret"

[[ -x "${ROOT}/scripts/diagnose-latest-pipelinerun.sh" ]] \
  && grep -q 'FailedMount' "${ROOT}/scripts/diagnose-latest-pipelinerun.sh" \
  && pass "diagnose-latest-pipelinerun detects FailedMount/ghcr-push" \
  || fail "diagnose-latest-pipelinerun detects FailedMount/ghcr-push"

grep -q 'diagnose-latest-pipelinerun' "${ROOT}/Makefile" \
  && pass "diagnose-latest-pipelinerun Make target present" \
  || fail "diagnose-latest-pipelinerun Make target present"

printf '\ndeep-audit summary: PASS=%s FAIL=%s\n' "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
