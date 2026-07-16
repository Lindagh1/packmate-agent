#!/usr/bin/env bash
# Validate rendered Packmate manifests (render first if missing).
# Offline-first: does not apply to a cluster or require live API access.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="${ROOT}/deploy"
OUT="${DEPLOY}/rendered"
SCHEMAS="${DEPLOY}/schemas"

render_if_needed() {
  if [[ ! -f "${OUT}/dev.yaml" || ! -f "${OUT}/prod.yaml" ]]; then
    echo "Rendered manifests not found; running render-manifests.sh ..."
    "${ROOT}/scripts/render-manifests.sh"
  fi
}

validate_with_kubeconform() {
  local overlay="$1"
  local file="${OUT}/${overlay}.yaml"
  echo "Validating ${file} (kubeconform) ..."
  kubeconform -summary -output text \
    -schema-location default \
    -schema-location "${SCHEMAS}/{{.ResourceKind}}{{.KindSuffix}}.json" \
    -schema-location "${SCHEMAS}/openshift/{{.ResourceKind}}{{.KindSuffix}}.json" \
    -ignore-missing-schemas \
    "${file}"
}

validate_with_python() {
  local overlay="$1"
  local file="${OUT}/${overlay}.yaml"
  echo "Validating ${file} (YAML structure) ..."
  python3 - "${overlay}" "${file}" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("error: PyYAML is required for offline validation (pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

overlay, path = sys.argv[1], Path(sys.argv[2])
docs = [d for d in yaml.safe_load_all(path.read_text()) if d]
if not docs:
    raise SystemExit(f"{path}: no documents found")


def meta_name(doc):
    return (doc.get("metadata") or {}).get("name")


kinds = {d.get("kind") for d in docs}
required = {
    "ServiceAccount",
    "ConfigMap",
    "Service",
    "Deployment",
    "NetworkPolicy",
    "Route",
}
missing = required - kinds
if missing:
    raise SystemExit(f"{path}: missing kinds: {sorted(missing)}")

if overlay == "prod" and "PodDisruptionBudget" not in kinds:
    raise SystemExit(f"{path}: prod overlay must include PodDisruptionBudget")

expected_ns = f"packmate-{overlay}"
for doc in docs:
    meta = doc.get("metadata") or {}
    ns = meta.get("namespace")
    if ns and ns != expected_ns:
        raise SystemExit(
            f"{path}: unexpected namespace {ns} on {doc.get('kind')}/{meta.get('name')}"
        )
    if doc.get("kind") == "Secret":
        raise SystemExit(f"{path}: secrets must not be committed in rendered output")

frontend = next(d for d in docs if d.get("kind") == "Deployment" and meta_name(d) == "packmate-frontend")
if overlay == "prod":
    backend = next(
        d for d in docs if d.get("kind") == "Rollout" and meta_name(d) == "packmate-backend"
    )
    if "AnalysisTemplate" not in kinds:
        raise SystemExit(f"{path}: prod overlay must include AnalysisTemplate")
    if any(d.get("kind") == "Deployment" and meta_name(d) == "packmate-backend" for d in docs):
        raise SystemExit(f"{path}: prod must not include Deployment/packmate-backend")
else:
    backend = next(
        d for d in docs if d.get("kind") == "Deployment" and meta_name(d) == "packmate-backend"
    )
if backend["spec"]["replicas"] != (2 if overlay == "prod" else 1):
    raise SystemExit(f"{path}: unexpected backend replica count")
if frontend["spec"]["replicas"] != (2 if overlay == "prod" else 1):
    raise SystemExit(f"{path}: unexpected frontend replica count")

routes = [d for d in docs if d.get("kind") == "Route"]
route_names = {d["metadata"]["name"] for d in routes}
if "packmate-frontend" not in route_names:
    raise SystemExit(f"{path}: expected public Route named packmate-frontend")
# MCP Routes are intentional for Gen AI Playground registration (HTTPS URLs).
allowed_extra = {"weather-mcp", "baggage-policy-mcp"}
unexpected = route_names - {"packmate-frontend"} - allowed_extra
if unexpected:
    raise SystemExit(f"{path}: unexpected Route names: {sorted(unexpected)}")

print(f"  {len(docs)} documents OK")
PY
}

main() {
  render_if_needed

  local failed=0
  for overlay in dev prod; do
    if command -v kubeconform >/dev/null 2>&1; then
      validate_with_kubeconform "${overlay}" || failed=1
    fi
    validate_with_python "${overlay}" || failed=1
  done

  if [[ "${failed}" -ne 0 ]]; then
    echo "Validation failed." >&2
    exit 1
  fi

  echo "All overlays validated successfully."
}

main "$@"
