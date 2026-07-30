#!/usr/bin/env bash
# Render .tekton/lab/packmate-ci.yaml.tpl with current-sandbox image digests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL="${ROOT}/.tekton/lab/packmate-ci.yaml.tpl"
OUT_DIR="${ROOT}/.tekton/lab/generated"
OUT="${PACKMATE_RENDERED_PIPELINE:-${OUT_DIR}/packmate-ci.rendered.yaml}"
OBSOLETE_PY_DIGEST="sha256:ae2c1317fa423c188c408d81e61b87dbc5b559577272ac189bea4eede92661cb"
OBSOLETE_CLI_DIGEST="sha256:dd7dab5b6ec92b6eecefec17f84bb3df525692f39a44f3d8c22b4469e420f0f3"
PY_PLACEHOLDER="__PACKMATE_PIPELINE_PYTHON_IMAGE__"
CLI_PLACEHOLDER="__PACKMATE_PIPELINE_CLI_IMAGE__"

log() { printf '%s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ -f "${TPL}" ]] || die "Missing template: ${TPL}"

RESOLVE="${ROOT}/scripts/resolve-pipeline-python-image.sh"
[[ -f "${RESOLVE}" ]] || die "Missing ${RESOLVE}"

if [[ -n "${PACKMATE_PIPELINE_PYTHON_IMAGE:-}" ]]; then
  PY_IMG="${PACKMATE_PIPELINE_PYTHON_IMAGE}"
else
  PY_IMG="$(bash "${RESOLVE}")"
fi
[[ -n "${PY_IMG}" ]] || die "Resolved Python image is empty"
[[ "${PY_IMG}" != *":latest"* ]] || die "Resolved Python image must not use :latest"
[[ "${PY_IMG}" == *"@sha256:"* ]] || die "Resolved Python image must be digest-pinned"

if [[ -n "${PACKMATE_PIPELINE_CLI_IMAGE:-}" ]]; then
  CLI_IMG="${PACKMATE_PIPELINE_CLI_IMAGE}"
else
  CLI_IMG="$(
    PACKMATE_PIPELINE_PYTHON_IMAGE= \
    PACKMATE_PIPELINE_IMAGE_OVERRIDE= \
    PACKMATE_PIPELINE_ISTREAM_NAME=cli \
    PACKMATE_PIPELINE_ISTREAM_TAG=latest \
    PACKMATE_PIPELINE_IMAGE_PROBE=oc \
    PACKMATE_SKIP_PYTHON_IMAGE_PULL_PROBE="${PACKMATE_SKIP_PYTHON_IMAGE_PULL_PROBE:-false}" \
    PACKMATE_NAMESPACE="${PACKMATE_NAMESPACE:-packmate-lab}" \
      bash "${RESOLVE}"
  )"
fi
[[ -n "${CLI_IMG}" ]] || die "Resolved CLI image is empty"
[[ "${CLI_IMG}" != *":latest"* ]] || die "Resolved CLI image must not use :latest"
[[ "${CLI_IMG}" == *"@sha256:"* ]] || die "Resolved CLI image must be digest-pinned"

mkdir -p "$(dirname "${OUT}")"
python3 - "${TPL}" "${OUT}" "${PY_PLACEHOLDER}" "${PY_IMG}" "${CLI_PLACEHOLDER}" "${CLI_IMG}" <<'PY'
import sys
tpl, out, py_ph, py_img, cli_ph, cli_img = sys.argv[1:7]
text = open(tpl, encoding="utf-8").read()
for ph in (py_ph, cli_ph):
    if ph not in text:
        raise SystemExit(f"placeholder {ph} not found in template")
text = text.replace(py_ph, py_img).replace(cli_ph, cli_img)
open(out, "w", encoding="utf-8").write(text)
PY

for ph in "${PY_PLACEHOLDER}" "${CLI_PLACEHOLDER}"; do
  grep -q "${ph}" "${OUT}" && die "Unresolved placeholder ${ph} remains in ${OUT}"
done
grep -q "${OBSOLETE_PY_DIGEST}" "${OUT}" && die "Obsolete sandbox Python digest remains in ${OUT}"
grep -q "${OBSOLETE_CLI_DIGEST}" "${OUT}" && die "Obsolete sandbox CLI digest remains in ${OUT}"
grep -q "${OBSOLETE_PY_DIGEST}" "${TPL}" && die "Obsolete sandbox Python digest remains in template"
grep -q "${OBSOLETE_CLI_DIGEST}" "${TPL}" && die "Obsolete sandbox CLI digest remains in template"

python3 - "${OUT}" "${PY_IMG}" "${CLI_IMG}" <<'PY'
import re, sys
path, py_expected, cli_expected = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
images = re.findall(r'^\s+image:\s+(\S+)\s*$', text, flags=re.M)
py_images = [i for i in images if "/python@" in i]
cli_images = [i for i in images if "/cli@" in i]
if not py_images:
    raise SystemExit("No python images found in rendered Pipeline")
if not cli_images:
    raise SystemExit("No cli images found in rendered Pipeline")
bad_py = [i for i in py_images if i != py_expected]
bad_cli = [i for i in cli_images if i != cli_expected]
if bad_py:
    raise SystemExit(f"Unexpected python image(s): {bad_py}; expected {py_expected}")
if bad_cli:
    raise SystemExit(f"Unexpected cli image(s): {bad_cli}; expected {cli_expected}")
latest = [i for i in images if i.endswith(":latest") or ":latest@" in i]
if latest:
    raise SystemExit(f":latest forbidden: {latest}")
print(f"python_images={len(py_images)} cli_images={len(cli_images)}", file=sys.stderr)
PY

if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
  oc apply --dry-run=client -f "${OUT}" >/dev/null \
    || die "oc apply --dry-run=client failed for rendered Pipeline"
  NS="${PACKMATE_NAMESPACE:-packmate-lab}"
  if oc get project "${NS}" >/dev/null 2>&1; then
    oc apply --dry-run=server -n "${NS}" -f "${OUT}" >/dev/null 2>&1 \
      || log "WARNING: oc apply --dry-run=server unavailable or failed (client dry-run OK)"
  fi
else
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
