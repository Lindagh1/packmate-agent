#!/usr/bin/env bash
# Render Packmate Kustomize overlays to deploy/rendered/*.yaml
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="${ROOT}/deploy"
OUT="${DEPLOY}/rendered"

if command -v kustomize >/dev/null 2>&1; then
  render_overlay() {
    kustomize build "$1"
  }
elif command -v oc >/dev/null 2>&1; then
  render_overlay() {
    oc kustomize "$1"
  }
else
  echo "error: kustomize or oc is required" >&2
  exit 1
fi

mkdir -p "${OUT}"

for overlay in dev prod; do
  target="${OUT}/${overlay}.yaml"
  echo "Rendering ${overlay} -> ${target}"
  render_overlay "${DEPLOY}/overlays/${overlay}" >"${target}"
done

echo "Done. Rendered manifests in ${OUT}/"
