#!/usr/bin/env bash
# Promote a backend image digest into deploy/overlays/dev (local Git change only).
# Never pushes to remote. Asks for confirmation before writing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="${ROOT}/deploy/overlays/dev/kustomization.yaml"

DIGEST="${1:-${BACKEND_DIGEST:-}}"
IMAGE_NAME="${BACKEND_IMAGE_NAME:-image-registry.openshift-image-registry.svc:5000/packmate-lab/packmate-backend}"

if [[ -z "${DIGEST}" ]]; then
  echo "Usage: $0 <sha256:digest>"
  echo "Or set BACKEND_DIGEST=sha256:..."
  exit 1
fi
DIGEST="${DIGEST#sha256:}"
DIGEST="sha256:${DIGEST}"

echo "Will update ${OVERLAY}"
echo "  packmate-backend → ${IMAGE_NAME}@${DIGEST}"
echo
grep -A2 'name:.*packmate-backend\|newName:.*packmate-backend\|digest:' "${OVERLAY}" | head -20 || true
echo
read -r -p "Apply this digest to the overlay? [y/N] " ans
[[ "${ans}" == "y" || "${ans}" == "Y" ]] || { echo "Aborted"; exit 0; }

python3 - <<PY
from pathlib import Path
import re
path = Path("${OVERLAY}")
text = path.read_text()
# Replace digest for backend image block
pattern = r"(- name: quay\.io/example/packmate-backend\n  newName: )([^\n]+)(\n  digest: )(sha256:[0-9a-f]+)"
repl = r"\g<1>${IMAGE_NAME}\g<3>${DIGEST}"
text2, n = re.subn(pattern, repl, text, count=1)
if n != 1:
    # Fallback: replace any digest line following packmate-backend newName
    pattern2 = r"(newName: .*/packmate-backend\n  digest: )(sha256:[0-9a-f]+)"
    text2, n = re.subn(pattern2, r"\g<1>${DIGEST}", text, count=1)
if n != 1:
    raise SystemExit(f"Could not uniquely update backend digest (matches={n})")
path.write_text(text2)
print("Updated", path)
PY

echo
git -C "${ROOT}" diff -- "${OVERLAY}" || true
echo
read -r -p "Create a local git commit for this digest bump? [y/N] " cans
if [[ "${cans}" == "y" || "${cans}" == "Y" ]]; then
  git -C "${ROOT}" add "${OVERLAY}"
  git -C "${ROOT}" commit -m "Promote packmate-backend digest from lab pipeline"
  echo "Local commit created (no push)."
else
  echo "Left as unstaged/staged working tree change only."
fi
echo "Push from the Workbench when ready: git push"
