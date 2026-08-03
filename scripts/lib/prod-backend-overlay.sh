#!/usr/bin/env bash
# Shared helpers for reading/updating the PROD backend image entry.
# shellcheck shell=bash

PACKMATE_PROD_BACKEND_IMAGE_KEY="${PACKMATE_PROD_BACKEND_IMAGE_KEY:-quay.io/example/packmate-backend}"
PACKMATE_DEFAULT_DEMO_BASELINE_DIGEST="${PACKMATE_DEFAULT_DEMO_BASELINE_DIGEST:-sha256:03beee2d3dd9a16ae065a2844b9bb1e9eb9e7820877d7196aa24cfbdb241c2d5}"
PACKMATE_DEFAULT_DEMO_BASELINE_IMAGE="${PACKMATE_DEFAULT_DEMO_BASELINE_IMAGE:-ghcr.io/lindagh1/packmate-backend}"

packmate_normalize_digest() {
  local d="$1"
  d="${d#sha256:}"
  d="$(printf '%s' "${d}" | tr 'A-F' 'a-f')"
  printf 'sha256:%s' "${d}"
}

packmate_short_digest() {
  local d="${1#sha256:}"
  printf '%s' "${d:0:12}"
}

# Resolve configured demo baseline image@digest (never invents digests).
# Priority:
#   1) PACKMATE_DEMO_BASELINE_IMAGE_REFERENCE (full ref)
#   2) PACKMATE_DEMO_BASELINE_DIGEST (+ optional PACKMATE_DEMO_BASELINE_IMAGE)
#   3) PACKMATE_INITIAL_PROD_IMAGE_REFERENCE
#   4) lab-v2.0.0 / durable default (03beee2d…)
packmate_resolve_demo_baseline_ref() {
  local ref image digest
  if [[ -n "${PACKMATE_DEMO_BASELINE_IMAGE_REFERENCE:-}" ]]; then
    ref="${PACKMATE_DEMO_BASELINE_IMAGE_REFERENCE}"
  elif [[ -n "${PACKMATE_DEMO_BASELINE_DIGEST:-}" ]]; then
    image="${PACKMATE_DEMO_BASELINE_IMAGE:-${PACKMATE_DEFAULT_DEMO_BASELINE_IMAGE}}"
    digest="$(packmate_normalize_digest "${PACKMATE_DEMO_BASELINE_DIGEST}")"
    ref="${image}@${digest}"
  elif [[ -n "${PACKMATE_INITIAL_PROD_IMAGE_REFERENCE:-}" ]]; then
    ref="${PACKMATE_INITIAL_PROD_IMAGE_REFERENCE}"
  else
    ref="${PACKMATE_DEFAULT_DEMO_BASELINE_IMAGE}@${PACKMATE_DEFAULT_DEMO_BASELINE_DIGEST}"
  fi
  [[ "${ref}" == *@sha256:* ]] || return 1
  [[ "${ref}" != *:latest* ]] || return 1
  if [[ "${ref}" == image-registry.openshift-image-registry.svc:* ]] \
    || [[ "${ref}" == *default-route-openshift-image-registry* ]] \
    || [[ "${ref}" == *.svc:* ]] \
    || [[ "${ref}" == *.svc.cluster.local:* ]]; then
    return 2
  fi
  printf '%s\n' "${ref}"
}

packmate_read_prod_backend_ref() {
  local path="${1:?path required}"
  python3 - "${path}" "${PACKMATE_PROD_BACKEND_IMAGE_KEY}" <<'PY'
import re
import sys
from pathlib import Path

path, target_key = sys.argv[1], sys.argv[2]
text = Path(path).read_text()
block_re = re.compile(
    r"^(?P<indent>[ \t]*)- name: " + re.escape(target_key) + r"[ \t]*\n"
    r"(?P<block>.*?)(?=^(?P=indent)- name:|^[^\s#]|\Z)",
    re.DOTALL | re.MULTILINE,
)
matches = list(block_re.finditer(text))
if len(matches) != 1:
    sys.exit(1)
block = matches[0].group("block")
name_m = re.search(r"newName:\s*(\S+)", block)
digest_m = re.search(r"digest:\s*(sha256:[0-9a-f]+)", block)
if not name_m or not digest_m:
    sys.exit(1)
print(f"{name_m.group(1)}@{digest_m.group(1)}")
PY
}

packmate_read_prod_backend_digest() {
  local path="${1:?path required}"
  local ref
  ref="$(packmate_read_prod_backend_ref "${path}")" || return 1
  printf '%s\n' "${ref##*@}"
}

packmate_set_prod_backend_ref() {
  local path="${1:?}" image_name="${2:?}" digest="${3:?}"
  python3 - "${path}" "${image_name}" "${digest}" "${PACKMATE_PROD_BACKEND_IMAGE_KEY}" <<'PY'
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
if len(matches) != 1:
    sys.exit(f"ERROR: expected one '{target_key}' entry in {path}")
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
        f"ERROR: expected exactly one newName/digest replacement "
        f"(newName={n_name}, digest={n_digest})"
    )
text = text[: m.start("block")] + new_block + text[m.end("block") :]
p.write_text(text)
print(f"Updated {path}: {target_key} -> newName={image_name} digest={digest}")
PY
}

# Best-effort pullability check. Never prints credentials.
# Returns 0 if inspect succeeds, 1 if unavailable, 2 if tool missing.
packmate_verify_image_ref_pullable() {
  local ref="${1:?}"
  local authfile="${PACKMATE_REGISTRY_AUTHFILE:-}"
  if command -v skopeo >/dev/null 2>&1; then
    if [[ -n "${authfile}" && -f "${authfile}" ]]; then
      skopeo inspect --authfile "${authfile}" "docker://${ref}" >/dev/null 2>&1 && return 0
    fi
    skopeo inspect "docker://${ref}" >/dev/null 2>&1 && return 0
    return 1
  fi
  return 2
}
