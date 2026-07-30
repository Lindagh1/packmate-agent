#!/usr/bin/env bash
# Render .tekton/lab/packmate-ci.yaml.tpl with the current sandbox Python digest.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL="${ROOT}/.tekton/lab/packmate-ci.yaml.tpl"
OUT_DIR="${ROOT}/.tekton/lab/generated"
OUT="${PACKMATE_RENDERED_PIPELINE:-${OUT_DIR}/packmate-ci.rendered.yaml}"
OBSOLETE_DIGEST="sha256:ae2c1317fa423c188c408d81e61b87dbc5b559577272ac189bea4eede92661cb"
PLACEHOLDER="__PACKMATE_PIPELINE_PYTHON_IMAGE__"

log() { printf '%s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -f "${TPL}" ]] || die "Missing template: ${TPL}"

RESOLVE="${ROOT}/scripts/resolve-pipeline-python-image.sh"
[[ -x "${RESOLVE}" || -f "${RESOLVE}" ]] || die "Missing ${RESOLVE}"

if [[ -n "${PACKMATE_PIPELINE_PYTHON_IMAGE:-}" ]]; then
  IMG="${PACKMATE_PIPELINE_PYTHON_IMAGE}"
else
  IMG="$(bash "${RESOLVE}")"
fi
[[ -n "${IMG}" ]] || die "Resolved Python image is empty"
[[ "${IMG}" != *":latest"* ]] || die "Resolved Python image must not use :latest"
[[ "${IMG}" == *"@sha256:"* ]] || die "Resolved Python image must be digest-pinned"

mkdir -p "$(dirname "${OUT}")"
# portable replace without relying on GNU sed -i
python3 - "${TPL}" "${OUT}" "${PLACEHOLDER}" "${IMG}" <<'PY'
import sys
tpl, out, placeholder, image = sys.argv[1:5]
text = open(tpl, encoding="utf-8").read()
if placeholder not in text:
    raise SystemExit(f"placeholder {placeholder} not found in template")
open(out, "w", encoding="utf-8").write(text.replace(placeholder, image))
PY

grep -q "${PLACEHOLDER}" "${OUT}" && die "Unresolved placeholder remains in ${OUT}"
grep -q "${OBSOLETE_DIGEST}" "${OUT}" && die "Obsolete sandbox Python digest remains in ${OUT}"
grep -q "${OBSOLETE_DIGEST}" "${TPL}" && die "Obsolete sandbox Python digest remains in template"

# Every Python task step image must equal the resolved image.
python3 - "${OUT}" "${IMG}" <<'PY'
import re, sys
path, expected = sys.argv[1:3]
text = open(path, encoding="utf-8").read()
# Collect image: lines under steps that look like registry python images or placeholders
images = re.findall(r'^\s+image:\s+(\S+)\s*$', text, flags=re.M)
py_images = [i for i in images if "/python@" in i or i.endswith("/python") or ":python" in i]
if not py_images:
    raise SystemExit("No python images found in rendered Pipeline")
bad = [i for i in py_images if i != expected]
if bad:
    raise SystemExit(f"Unexpected python image(s): {bad}; expected {expected}")
latest = [i for i in images if i.endswith(":latest") or ":latest@" in i]
if latest:
    raise SystemExit(f":latest forbidden: {latest}")
print(f"python_images={len(py_images)}", file=sys.stderr)
PY

# YAML / client dry-run validation
if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
  oc apply --dry-run=client -f "${OUT}" >/dev/null \
    || die "oc apply --dry-run=client failed for rendered Pipeline"
  NS="${PACKMATE_NAMESPACE:-packmate-lab}"
  if oc get project "${NS}" >/dev/null 2>&1; then
    oc apply --dry-run=server -n "${NS}" -f "${OUT}" >/dev/null 2>&1 \
      || log "WARNING: oc apply --dry-run=server unavailable or failed (client dry-run OK)"
  fi
else
  # Minimal YAML sanity when oc is absent
  python3 - "${OUT}" <<'PY'
import sys
text=open(sys.argv[1], encoding='utf-8').read()
assert 'kind: Pipeline' in text
assert 'name: packmate-ci' in text
print('yaml_sanity_ok')
PY
fi

log "PASS  Pipeline rendered without unresolved placeholders"
log "Rendered Pipeline: ${OUT}"
printf '%s\n' "${OUT}"
