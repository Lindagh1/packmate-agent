#!/usr/bin/env bash
# Roll the Packmate PRODUCTION backend image back to the previous digest found
# in the git history of deploy/overlays/prod/kustomization.yaml.
#
# Never touches the cluster (no `oc` calls). Never modifies the dev overlay,
# frontend image, MCP images, or application code. Never pushes to
# packmate-v2 directly — always via a rollback/backend-<digest> branch.
#
# Usage:
#   scripts/rollback-prod-image.sh
#   scripts/rollback-prod-image.sh --create-pr
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

OVERLAY_REL="deploy/overlays/prod/kustomization.yaml"
OVERLAY="${ROOT}/${OVERLAY_REL}"
TARGET_IMAGE_KEY="quay.io/example/packmate-backend"
BASE_BRANCH="packmate-v2"

log()  { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

CREATE_PR="false"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --create-pr) CREATE_PR="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

[[ -f "${OVERLAY}" ]] || die "${OVERLAY_REL} not found"

# ---------------------------------------------------------------------------
# Extract the backend image entry (newName + digest) for packmate-backend
# from a given kustomization.yaml text blob (read on stdin). Anchored to
# real (non-comment) YAML list entries only.
#
# NOTE: the extractor script is written to a temp file (not a heredoc) so
# that stdin is free to carry the actual YAML content when this function is
# called as `extract_backend_ref < file` or `... | extract_backend_ref`.
# ---------------------------------------------------------------------------
EXTRACT_PY="$(mktemp)"
cat > "${EXTRACT_PY}" <<'PY'
import re
import sys

target_key = sys.argv[1]
text = sys.stdin.read()

block_re = re.compile(
    r"^(?P<indent>[ \t]*)- name: " + re.escape(target_key) + r"[ \t]*\n"
    r"(?P<block>.*?)(?=^(?P=indent)- name:|^[^\s#]|\Z)",
    re.DOTALL | re.MULTILINE,
)
matches = list(block_re.finditer(text))
if not matches:
    sys.exit(0)
block = matches[0].group("block")
name_m = re.search(r"newName:\s*(\S+)", block)
digest_m = re.search(r"digest:\s*(sha256:[0-9a-f]+)", block)
if not name_m or not digest_m:
    sys.exit(0)
print(f"{name_m.group(1)} {digest_m.group(1)}")
PY

extract_backend_ref() {
  python3 "${EXTRACT_PY}" "${TARGET_IMAGE_KEY}"
}

# ---------------------------------------------------------------------------
# Current (working-tree) backend reference
# ---------------------------------------------------------------------------
CURRENT_REF="$(extract_backend_ref < "${OVERLAY}")"
[[ -n "${CURRENT_REF}" ]] || die "could not read current backend image/digest from ${OVERLAY_REL}"
CURRENT_NAME="${CURRENT_REF% *}"
CURRENT_DIGEST="${CURRENT_REF#* }"
log "Current prod backend: ${CURRENT_NAME}@${CURRENT_DIGEST}"

# ---------------------------------------------------------------------------
# Walk git history of the overlay file (newest first) to find the most
# recent commit whose backend digest differs from the current one.
# ---------------------------------------------------------------------------
PREV_NAME=""
PREV_DIGEST=""
PREV_COMMIT=""

while IFS= read -r commit; do
  content="$(git show "${commit}:${OVERLAY_REL}" 2>/dev/null || true)"
  [[ -n "${content}" ]] || continue
  ref="$(printf '%s' "${content}" | extract_backend_ref)"
  [[ -n "${ref}" ]] || continue
  name="${ref% *}"
  digest="${ref#* }"
  if [[ "${digest}" != "${CURRENT_DIGEST}" ]]; then
    PREV_NAME="${name}"
    PREV_DIGEST="${digest}"
    PREV_COMMIT="${commit}"
    break
  fi
done < <(git log --format=%H -- "${OVERLAY_REL}")

if [[ -z "${PREV_DIGEST}" ]]; then
  die "no previous backend digest found in git history of ${OVERLAY_REL} — nothing to roll back to"
fi

log "Previous prod backend: ${PREV_NAME}@${PREV_DIGEST} (commit ${PREV_COMMIT:0:12})"

SHORT="${PREV_DIGEST#sha256:}"
SHORT="${SHORT:0:12}"
BRANCH="rollback/backend-${SHORT}"

# ---------------------------------------------------------------------------
# Branch, edit, diff, commit
# ---------------------------------------------------------------------------
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${CURRENT_BRANCH}" != "${BASE_BRANCH}" ]]; then
  warn "current branch is '${CURRENT_BRANCH}', expected '${BASE_BRANCH}' — branching from HEAD anyway"
fi

if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  git checkout "${BRANCH}"
else
  git checkout -b "${BRANCH}"
fi

python3 - "${OVERLAY}" "${PREV_NAME}" "${PREV_DIGEST}" "${TARGET_IMAGE_KEY}" <<'PY'
import re
import sys
from pathlib import Path

path, image_name, digest, target_key = sys.argv[1:5]
p = Path(path)
text = p.read_text()

block_re = re.compile(
    r"^(?P<indent>[ \t]*)- name: " + re.escape(target_key) + r"[ \t]*\n"
    r"(?P<block>.*?)(?=^(?P=indent)- name:|^[^\s#]|\Z)",
    re.DOTALL | re.MULTILINE,
)
matches = list(block_re.finditer(text))
if not matches:
    sys.exit(f"ERROR: image entry '{target_key}' not found in {path}")
if len(matches) > 1:
    sys.exit(f"ERROR: image entry '{target_key}' matched {len(matches)} times in {path} (expected 1)")
m = matches[0]

block = m.group("block")
new_block, n_name = re.subn(
    r"(newName: )\S+", lambda mo: mo.group(1) + image_name, block, count=1
)
new_block, n_digest = re.subn(
    r"(digest: )sha256:[0-9a-f]+", lambda mo: mo.group(1) + digest, new_block, count=1
)
if n_name != 1 or n_digest != 1:
    sys.exit(
        f"ERROR: expected exactly one newName/digest replacement in {path} "
        f"(newName matches={n_name}, digest matches={n_digest})"
    )

text = text[: m.start("block")] + new_block + text[m.end("block"):]
p.write_text(text)
print(f"Updated {path}: {target_key} -> newName={image_name} digest={digest}")
PY

echo
echo "--- git diff (${OVERLAY_REL}) ---"
git --no-pager diff -- "${OVERLAY_REL}" || true
echo "--- end diff ---"
echo

if git diff --quiet -- "${OVERLAY_REL}" && git diff --cached --quiet -- "${OVERLAY_REL}"; then
  log "No changes to ${OVERLAY_REL} — nothing to roll back."
  git checkout "${CURRENT_BRANCH}" >/dev/null 2>&1 || true
  if [[ "${CURRENT_BRANCH}" != "${BRANCH}" ]] && git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git branch -d "${BRANCH}" >/dev/null 2>&1 || true
  fi
  exit 0
fi

git add "${OVERLAY_REL}"
git commit -m "Rollback Packmate backend to ${SHORT} (previous digest)"
log "OK: committed on branch ${BRANCH} (no push to ${BASE_BRANCH})"

# ---------------------------------------------------------------------------
# Push + optional PR (never push to packmate-v2 directly, never touch cluster)
# ---------------------------------------------------------------------------
github_compare_url() {
  local branch="$1"
  local remote_url repo_path
  remote_url="$(git config --get remote.origin.url || true)"
  [[ -n "${remote_url}" ]] || return 0
  repo_path="$(printf '%s' "${remote_url}" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
  [[ -n "${repo_path}" ]] || return 0
  printf 'https://github.com/%s/compare/%s...%s?expand=1\n' "${repo_path}" "${BASE_BRANCH}" "${branch}"
}

print_manual_push_instructions() {
  local branch="$1"
  cat <<EOF

Manual push required (no gh auth / push not completed automatically):
  git push -u origin ${branch}

Then open a PR to ${BASE_BRANCH}:
$(github_compare_url "${branch}")
EOF
}

PUSHED="false"
if git push -u origin "${BRANCH}:${BRANCH}" 2>/tmp/rollback-push.log; then
  PUSHED="true"
  log "OK: pushed ${BRANCH}"
else
  warn "push failed (see below) — commit is safe locally"
  cat /tmp/rollback-push.log >&2 || true
fi
rm -f /tmp/rollback-push.log

PR_BODY_FILE="$(mktemp)"
trap 'rm -f "${EXTRACT_PY}" "${PR_BODY_FILE}"' EXIT
cat > "${PR_BODY_FILE}" <<EOF
## Packmate backend rollback

| Field | Value |
|---|---|
| Rolling back from | \`${CURRENT_NAME}@${CURRENT_DIGEST}\` |
| Rolling back to | \`${PREV_NAME}@${PREV_DIGEST}\` |
| Source commit of previous digest | ${PREV_COMMIT} |

This PR updates **only** \`deploy/overlays/prod/kustomization.yaml\` (backend \`newName\`/\`digest\`).
No changes to the dev overlay, frontend image, MCP images, or application code.
This script never touches the cluster — Argo CD Application \`packmate-prod\` still requires a
manual Sync after merge (prune=false, selfHeal=false).
EOF

if [[ "${CREATE_PR}" == "true" ]]; then
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if [[ "${PUSHED}" != "true" ]]; then
      warn "cannot create PR: branch was not pushed"
      print_manual_push_instructions "${BRANCH}"
      exit 0
    fi
    PR_URL="$(gh pr create \
      --base "${BASE_BRANCH}" \
      --head "${BRANCH}" \
      --title "Rollback Packmate backend to ${SHORT}" \
      --body-file "${PR_BODY_FILE}")"
    log "OK: opened PR ${PR_URL}"
  else
    warn "gh not authenticated — cannot create PR automatically"
    print_manual_push_instructions "${BRANCH}"
  fi
else
  if [[ "${PUSHED}" != "true" ]]; then
    print_manual_push_instructions "${BRANCH}"
  else
    log "Branch pushed. Open a PR to ${BASE_BRANCH} when ready:"
    github_compare_url "${BRANCH}"
  fi
fi

exit 0
