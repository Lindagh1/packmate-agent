#!/usr/bin/env bash
# Promote a validated Packmate backend image digest from packmate-lab into the
# PRODUCTION overlay ONLY (deploy/overlays/prod/kustomization.yaml).
#
# Never modifies: deploy/overlays/dev, frontend image, MCP images, application code.
# Never pushes to packmate-v2 directly — always via a promote/backend-<digest> branch.
#
# Modes:
#   scripts/promote-backend-image.sh --pipelinerun <name> --namespace packmate-lab
#   scripts/promote-backend-image.sh --pipelinerun <name> --namespace packmate-lab --create-pr
#   scripts/promote-backend-image.sh --pipelinerun <name> --namespace packmate-lab --create-pr --merge-pr
#   scripts/promote-backend-image.sh sha256:<digest>                # legacy positional (updates PROD, asks to confirm)
#
# Flags:
#   --pipelinerun NAME    Tekton PipelineRun to read results from (packmate-ci)
#   --namespace NS        Namespace of the PipelineRun / ImageStream (default: packmate-lab)
#   --threshold VALUE     Minimum AI quality score (default: 0.90)
#   --create-pr           Open a PR to packmate-v2 via `gh` after commit+push
#   --merge-pr            Merge the PR immediately — automated Cursor validation ONLY, default off
#   -h|--help             Show usage
#
# Env overrides:
#   IMAGE_NAME             Registry path of the backend image (default derived from --namespace)
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
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# Argument parsing (supports legacy positional digest + flag-based mode)
# ---------------------------------------------------------------------------
PIPELINERUN=""
NAMESPACE="packmate-lab"
THRESHOLD="0.90"
CREATE_PR="false"
MERGE_PR="false"
LEGACY_DIGEST=""

if [[ $# -gt 0 && "${1}" != -* ]]; then
  LEGACY_DIGEST="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pipelinerun)
      PIPELINERUN="${2:?--pipelinerun requires a value}"
      shift 2
      ;;
    --namespace)
      NAMESPACE="${2:?--namespace requires a value}"
      shift 2
      ;;
    --threshold)
      THRESHOLD="${2:?--threshold requires a value}"
      shift 2
      ;;
    --create-pr)
      CREATE_PR="true"
      shift
      ;;
    --merge-pr)
      MERGE_PR="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1 (see --help)"
      ;;
  esac
done

if [[ -z "${LEGACY_DIGEST}" && -z "${PIPELINERUN}" ]]; then
  usage
  die "Provide --pipelinerun <name> or a legacy sha256 digest as \$1"
fi

IMAGE_NAME="${IMAGE_NAME:-image-registry.openshift-image-registry.svc:5000/${NAMESPACE}/packmate-backend}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

require_oc() {
  command -v oc >/dev/null 2>&1 || die "oc CLI not found (required for --pipelinerun mode)"
  oc whoami >/dev/null 2>&1 || die "not logged in to OpenShift (oc whoami failed)"
}

normalize_digest() {
  # Strip any accidental duplicate "sha256:" prefix and lower-case the hex.
  local d="$1"
  d="${d#sha256:}"
  d="$(printf '%s' "${d}" | tr 'A-F' 'a-f')"
  printf 'sha256:%s' "${d}"
}

short_digest() {
  local d="${1#sha256:}"
  printf '%s' "${d:0:12}"
}

# Best-effort ImageStream verification. Never fails the run — offline/RBAC
# gaps only produce a warning.
verify_image_exists() {
  local ns="$1" digest="$2"
  if ! command -v oc >/dev/null 2>&1; then
    warn "oc CLI not found; skipping ImageStream verification (offline)"
    return 0
  fi
  if ! oc get imagestream packmate-backend -n "${ns}" >/dev/null 2>&1; then
    warn "could not read imagestream/packmate-backend in ${ns} (offline, RBAC, or not yet built) — continuing"
    return 0
  fi
  if oc get imagestream packmate-backend -n "${ns}" -o json 2>/dev/null | grep -q "${digest#sha256:}"; then
    log "OK: digest ${digest} present in imagestream/packmate-backend (${ns})"
  else
    warn "digest ${digest} not found in imagestream/packmate-backend status (${ns}) — continuing"
  fi
}

# Extract PipelineRun status + TaskRun results (ai-quality-gate, build-backend)
# via a single python3/oc round-trip. Emits shell-safe KEY=VALUE lines on
# stdout for `eval`; diagnostics go to stderr.
extract_pipeline_data() {
  local ns="$1" name="$2"
  python3 - "${ns}" "${name}" <<'PY'
import json
import shlex
import subprocess
import sys

ns, name = sys.argv[1], sys.argv[2]


def oc_json(*args):
    r = subprocess.run(["oc", *args, "-o", "json"], capture_output=True, text=True)
    if r.returncode != 0:
        return None, r.stderr.strip()
    try:
        return json.loads(r.stdout), None
    except json.JSONDecodeError as exc:
        return None, str(exc)


def emit(key, value):
    print(f"{key}={shlex.quote('' if value is None else str(value))}")


pr, err = oc_json("get", "pipelinerun", name, "-n", ns)
if pr is None:
    print(f"ERROR: cannot read PipelineRun {name} in {ns}: {err}", file=sys.stderr)
    emit("PR_SUCCEEDED", "Unknown")
    sys.exit(0)

status = pr.get("status", {}) or {}
conditions = status.get("conditions", []) or []
succeeded = next((c for c in conditions if c.get("type") == "Succeeded"), None)
emit("PR_SUCCEEDED", (succeeded or {}).get("status", "Unknown"))
emit("PR_REASON", (succeeded or {}).get("reason", ""))
emit("PR_MESSAGE", (succeeded or {}).get("message", ""))


def result_value(v):
    if isinstance(v, dict):
        return v.get("stringVal", v)
    return v


# Pipeline-level results (only present if the Pipeline spec declares top-level
# `results:` that surface task results). Preferred when present.
pipeline_results = {}
for item in status.get("results", []) or []:
    n = item.get("name")
    if n:
        pipeline_results[n] = result_value(item.get("value"))


def find_taskrun_name(pipeline_task_name):
    for ref in status.get("childReferences", []) or []:
        if ref.get("pipelineTaskName") == pipeline_task_name:
            return ref.get("name")
    # Older Tekton versions without childReferences (v1beta1 status.taskRuns map).
    for tr_name, tr in (status.get("taskRuns") or {}).items():
        if tr.get("pipelineTaskName") == pipeline_task_name:
            return tr_name
    return None


def task_results(pipeline_task_name):
    tr_name = find_taskrun_name(pipeline_task_name)
    if not tr_name:
        return {}, f"no TaskRun found for pipelineTask {pipeline_task_name}"
    tr, terr = oc_json("get", "taskrun", tr_name, "-n", ns)
    if tr is None:
        return {}, terr
    out = {}
    for item in (tr.get("status", {}) or {}).get("results", []) or []:
        n = item.get("name")
        if n:
            out[n] = result_value(item.get("value"))
    return out, None


gate_results, gate_err = task_results("ai-quality-gate")
build_results, build_err = task_results("build-backend")

score = pipeline_results.get("score", gate_results.get("score", ""))
status_val = pipeline_results.get("status", gate_results.get("status", ""))
digest = pipeline_results.get("digest", build_results.get("digest", ""))

emit("QUALITY_SCORE", score)
emit("QUALITY_STATUS", status_val)
emit("BUILD_DIGEST", digest)

if gate_err:
    print(f"WARN: ai-quality-gate TaskRun lookup: {gate_err}", file=sys.stderr)
if build_err:
    print(f"WARN: build-backend TaskRun lookup: {build_err}", file=sys.stderr)
PY
}

# Edit deploy/overlays/prod/kustomization.yaml — packmate-backend image entry
# ONLY (newName + digest). Never touches other images or dev overlay.
edit_prod_overlay() {
  local path="$1" image_name="$2" digest="$3"
  python3 - "${path}" "${image_name}" "${digest}" "${TARGET_IMAGE_KEY}" <<'PY'
import re
import sys
from pathlib import Path

path, image_name, digest, target_key = sys.argv[1:5]
p = Path(path)
text = p.read_text()

# Bound the backend image entry between its own "- name:" line and the next
# list item at the same indent / next top-level key, so only this real (not
# commented-out) block is ever touched. Anchored to line-start so commented
# example lines such as "#   - name: ...digest: sha256:0123..." never match.
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
}

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

# ---------------------------------------------------------------------------
# Gather promotion data (pipeline mode or legacy mode)
# ---------------------------------------------------------------------------
QUALITY_SCORE=""
QUALITY_STATUS=""
BUILD_DIGEST=""
PROMO_KIND=""

if [[ -n "${PIPELINERUN}" ]]; then
  PROMO_KIND="pipelinerun"
  require_oc

  log "=== Packmate backend promotion (PipelineRun mode) ==="
  log "namespace=${NAMESPACE} pipelinerun=${PIPELINERUN} threshold=${THRESHOLD}"

  eval "$(extract_pipeline_data "${NAMESPACE}" "${PIPELINERUN}")"

  [[ "${PR_SUCCEEDED:-}" == "True" ]] \
    || die "PipelineRun ${PIPELINERUN} did not succeed (Succeeded=${PR_SUCCEEDED:-Unknown}${PR_REASON:+, reason=${PR_REASON}})"
  log "OK: PipelineRun ${PIPELINERUN} Succeeded=True"

  [[ -n "${QUALITY_STATUS}" ]] || die "could not read ai-quality-gate 'status' result"
  [[ -n "${QUALITY_SCORE}" ]] || die "could not read ai-quality-gate 'score' result"
  [[ -n "${BUILD_DIGEST}" ]] || die "could not read build-backend 'digest' result"

  [[ "${QUALITY_STATUS}" == "PASS" ]] \
    || die "AI quality gate status=${QUALITY_STATUS} (must be PASS)"

  if ! awk -v s="${QUALITY_SCORE}" -v t="${THRESHOLD}" 'BEGIN{exit !(s+0 >= t+0)}'; then
    die "AI quality score ${QUALITY_SCORE} below threshold ${THRESHOLD}"
  fi
  log "OK: quality gate status=${QUALITY_STATUS} score=${QUALITY_SCORE} (threshold ${THRESHOLD})"

  DIGEST="$(normalize_digest "${BUILD_DIGEST}")"
else
  PROMO_KIND="legacy"
  DIGEST="$(normalize_digest "${LEGACY_DIGEST}")"

  log "=== Packmate backend promotion (legacy digest mode) ==="
  log "namespace=${NAMESPACE}"
  warn "legacy mode skips PipelineRun / AI quality gate verification — promoting on operator confirmation only"
fi

[[ "${DIGEST}" =~ ^sha256:[0-9a-f]{64}$ ]] || die "invalid digest format: ${DIGEST}"

IMAGE_REFERENCE="${IMAGE_NAME}@${DIGEST}"
SHORT="$(short_digest "${DIGEST}")"
BRANCH="promote/backend-${SHORT}"

log "image_reference=${IMAGE_REFERENCE}"

verify_image_exists "${NAMESPACE}" "${DIGEST}"

if [[ "${PROMO_KIND}" == "legacy" ]]; then
  echo
  echo "Will update ${OVERLAY_REL} (PRODUCTION overlay ONLY):"
  echo "  packmate-backend -> ${IMAGE_REFERENCE}"
  echo
  read -r -p "Apply this digest to the PRODUCTION overlay? [y/N] " ans
  [[ "${ans}" == "y" || "${ans}" == "Y" ]] || { log "Aborted by user"; exit 0; }
fi

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

edit_prod_overlay "${OVERLAY}" "${IMAGE_NAME}" "${DIGEST}"

echo
echo "--- git diff (${OVERLAY_REL}) ---"
git --no-pager diff -- "${OVERLAY_REL}" || true
echo "--- end diff ---"
echo

if git diff --quiet -- "${OVERLAY_REL}" && git diff --cached --quiet -- "${OVERLAY_REL}"; then
  log "No changes to ${OVERLAY_REL} — production already pinned to ${DIGEST}. Nothing to promote."
  git checkout "${CURRENT_BRANCH}" >/dev/null 2>&1 || true
  if [[ "${CURRENT_BRANCH}" != "${BRANCH}" ]] && git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git branch -d "${BRANCH}" >/dev/null 2>&1 || true
  fi
  exit 0
fi

git add "${OVERLAY_REL}"
git commit -m "Promote validated Packmate backend ${SHORT}"
log "OK: committed on branch ${BRANCH} (no push to ${BASE_BRANCH})"

# ---------------------------------------------------------------------------
# Push + optional PR (never push to packmate-v2 directly)
# ---------------------------------------------------------------------------
PUSHED="false"
if git push -u origin "${BRANCH}:${BRANCH}" 2>/tmp/promote-push.log; then
  PUSHED="true"
  log "OK: pushed ${BRANCH}"
else
  warn "push failed (see below) — commit is safe locally"
  cat /tmp/promote-push.log >&2 || true
fi
rm -f /tmp/promote-push.log

PR_BODY_FILE="$(mktemp)"
trap 'rm -f "${PR_BODY_FILE}"' EXIT
cat > "${PR_BODY_FILE}" <<EOF
## Packmate backend promotion

| Field | Value |
|---|---|
| Source | ${PROMO_KIND} |
| PipelineRun | ${PIPELINERUN:-N/A (legacy digest promotion)} |
| Namespace | ${NAMESPACE} |
| AI quality status | ${QUALITY_STATUS:-N/A} |
| AI quality score | ${QUALITY_SCORE:-N/A} (threshold ${THRESHOLD}) |
| Image reference | \`${IMAGE_REFERENCE}\` |

This PR updates **only** \`deploy/overlays/prod/kustomization.yaml\` (backend \`newName\`/\`digest\`).
No changes to the dev overlay, frontend image, MCP images, or application code.

### Rollback procedure

If this promotion causes issues in packmate-prod:

\`\`\`bash
./scripts/rollback-prod-image.sh --create-pr
\`\`\`

This restores the previous backend digest from git history of the prod overlay and opens a
rollback PR the same way. Argo CD Application \`packmate-prod\` still requires a manual Sync
after merge (prune=false, selfHeal=false).
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
      --title "Promote validated Packmate backend ${SHORT}" \
      --body-file "${PR_BODY_FILE}")"
    log "OK: opened PR ${PR_URL}"

    if [[ "${MERGE_PR}" == "true" ]]; then
      warn "--merge-pr set: merging PR automatically (automated Cursor validation mode only)"
      gh pr merge "${BRANCH}" --merge --delete-branch=false \
        || warn "automatic PR merge failed — merge manually: ${PR_URL}"
    fi
  else
    warn "gh not authenticated — cannot create PR automatically"
    print_manual_push_instructions "${BRANCH}"
  fi
else
  if [[ "${MERGE_PR}" == "true" ]]; then
    warn "--merge-pr ignored without --create-pr"
  fi
  if [[ "${PUSHED}" != "true" ]]; then
    print_manual_push_instructions "${BRANCH}"
  else
    log "Branch pushed. Open a PR to ${BASE_BRANCH} when ready:"
    github_compare_url "${BRANCH}"
  fi
fi

exit 0
