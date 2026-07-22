#!/usr/bin/env bash
# Packmate sandbox bootstrap — idempotent deploy of lab workloads from prebuilt images.
# Does NOT redeploy the shared model in MODEL_NAMESPACE. Does NOT install Operators.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh"

packmate_require_oc
packmate_load_config "${ROOT}" || exit 1

log() { packmate_log "$*"; }
die() { packmate_die "$*"; }

log "=== Packmate bootstrap ==="
log "user=$(oc whoami)"
log "context=$(oc config current-context)"
log "namespace=${PACKMATE_NAMESPACE}"
log "model=${MODEL_NAMESPACE}/${MODEL_ID}"
log "images:"
log "  backend=${BACKEND_IMAGE:-<overlay default>}"
log "  frontend=${FRONTEND_IMAGE:-<overlay default>}"
log "  weather=${WEATHER_MCP_IMAGE:-<overlay default>}"
log "  baggage=${BAGGAGE_POLICY_MCP_IMAGE:-<overlay default>}"
log "flags: REGISTER_MCP=${REGISTER_MCP} CREATE_PIPELINE=${CREATE_PIPELINE} CREATE_ARGOCD=${CREATE_ARGOCD_APPLICATION} CREATE_MODEL_ENDPOINT=${CREATE_MODEL_CUSTOM_ENDPOINT}"

if [[ "${SKIP_CONFIRM}" != "true" ]]; then
  read -r -p "Continue with bootstrap in ${PACKMATE_NAMESPACE}? [y/N] " ans
  [[ "${ans}" == "y" || "${ans}" == "Y" ]] || die "Aborted by user"
fi

# Namespace
if ! oc get project "${PACKMATE_NAMESPACE}" >/dev/null 2>&1; then
  if [[ "${ALLOW_CREATE_NAMESPACE}" == "true" ]]; then
    log "ALLOW_CREATE_NAMESPACE=true — creating project ${PACKMATE_NAMESPACE}"
    oc new-project "${PACKMATE_NAMESPACE}" --display-name="Packmate Lab" >/dev/null
    # DSP-compatible labels so the project is discoverable in OpenShift AI
    oc label namespace "${PACKMATE_NAMESPACE}" \
      opendatahub.io/dashboard=true \
      modelmesh-enabled=false \
      --overwrite >/dev/null
  else
    cat <<EOF
MANUAL STEP REQUIRED:
Create the Data Science Project from the OpenShift AI dashboard.

Suggested name: ${PACKMATE_NAMESPACE}
Then re-run: make bootstrap
EOF
    exit 1
  fi
fi

# Model must already exist
READY="$(oc get inferenceservice "${MODEL_ID}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
[[ "${READY}" == "True" ]] || die "Model ${MODEL_ID} not Ready in ${MODEL_NAMESPACE}"
packmate_discover_model_url || die "Cannot discover model Service URL"
log "model_url=${PACKMATE_MODEL_BASE_URL}"

# Secrets (no values printed)
log "==> Ensuring Secret packmate-llm"
oc -n "${PACKMATE_NAMESPACE}" create secret generic packmate-llm \
  --from-literal=BASE_URL="${LLM_BASE_URL}" \
  --from-literal=MODEL="${LLM_MODEL}" \
  --from-literal=LITELLM_API_KEY="${LITELLM_API_KEY}" \
  --dry-run=client -o yaml | oc apply -f - >/dev/null
log "    Secret/packmate-llm applied (values not shown)"

# Render overlay with optional image overrides
log "==> Applying deploy/overlays/dev (idempotent)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
oc kustomize "${ROOT}/deploy/overlays/dev" > "${TMP}/all.yaml"

# Retarget overlay namespace (dev defaults to packmate-lab) without touching packmate-lab live.
python3 - <<'PY' "${TMP}/all.yaml" "${PACKMATE_NAMESPACE}"
import sys
from pathlib import Path
try:
  import yaml
except ImportError:
  text = Path(sys.argv[1]).read_text().replace("namespace: packmate-lab", f"namespace: {sys.argv[2]}")
  Path(sys.argv[1]).write_text(text)
  raise SystemExit(0)
ns = sys.argv[2]
docs = list(yaml.safe_load_all(Path(sys.argv[1]).read_text()))
out = []
for d in docs:
  if not d:
    continue
  md = d.setdefault("metadata", {})
  if md.get("namespace") == "packmate-lab" or ns != "packmate-lab":
    md["namespace"] = ns
  out.append(d)
Path(sys.argv[1]).write_text(yaml.safe_dump_all(out, sort_keys=False))
PY

# Optional image overrides from sandbox.env (digest-pinned) — YAML-aware
python3 - <<'PY' "${TMP}/all.yaml" \
  "${BACKEND_IMAGE:-}" "${FRONTEND_IMAGE:-}" "${WEATHER_MCP_IMAGE:-}" "${BAGGAGE_POLICY_MCP_IMAGE:-}"
import sys
from pathlib import Path
try:
  import yaml
except ImportError:
  raise SystemExit(0)
path = Path(sys.argv[1])
be, fe, wx, bg = sys.argv[2:6]
# Map deployment name -> desired image
want = {}
if be:
  want["packmate-backend"] = be
if fe:
  want["packmate-frontend"] = fe
if wx:
  want["weather-mcp"] = wx
if bg:
  want["baggage-policy-mcp"] = bg
if not want:
  raise SystemExit(0)
docs = list(yaml.safe_load_all(path.read_text()))
out = []
for d in docs:
  if not d:
    continue
  if d.get("kind") == "Deployment":
    name = d.get("metadata", {}).get("name")
    img = want.get(name)
    if img:
      for c in d.get("spec", {}).get("template", {}).get("spec", {}).get("containers", []):
        c["image"] = img
  out.append(d)
path.write_text(yaml.safe_dump_all(out, sort_keys=False))
PY

# Split: apply non-Deployment first, then create-or-set-image Deployments
# (existing lab Deployments may have immutable selectors that differ from base).
python3 - <<'PY' "${TMP}/all.yaml" "${TMP}"
import sys
from pathlib import Path
try:
  import yaml
except ImportError:
  # Fallback: write whole file for non-deploy path only
  Path(sys.argv[2], 'nondeploy.yaml').write_text(Path(sys.argv[1]).read_text())
  Path(sys.argv[2], 'deploys.yaml').write_text('')
  raise SystemExit(0)
docs = list(yaml.safe_load_all(Path(sys.argv[1]).read_text()))
non, deps = [], []
for d in docs:
  if not d:
    continue
  if d.get('kind') == 'Deployment':
    deps.append(d)
  else:
    non.append(d)
Path(sys.argv[2], 'nondeploy.yaml').write_text(yaml.safe_dump_all(non, sort_keys=False))
Path(sys.argv[2], 'deploys.yaml').write_text(yaml.safe_dump_all(deps, sort_keys=False))
PY

oc apply -f "${TMP}/nondeploy.yaml" >/dev/null

# Deployments: create if missing; otherwise only update container images (preserve selectors).
if [[ -s "${TMP}/deploys.yaml" ]]; then
  python3 - <<'PY' "${TMP}/deploys.yaml" "${PACKMATE_NAMESPACE}"
import json, subprocess, sys, yaml
ns = sys.argv[2]
for doc in yaml.safe_load_all(open(sys.argv[1])):
  if not doc:
    continue
  name = doc['metadata']['name']
  containers = doc['spec']['template']['spec']['containers']
  exists = subprocess.run(['oc','-n',ns,'get','deploy',name], capture_output=True).returncode == 0
  if not exists:
    subprocess.run(['oc','apply','-f','-'], input=yaml.safe_dump(doc).encode(), check=True)
    print(f'    created deploy/{name}')
    continue
  for c in containers:
    img = c['image']
    cname = c['name']
    subprocess.run(['oc','-n',ns,'set','image',f'deploy/{name}',f'{cname}={img}'], check=True)
    print(f'    set image deploy/{name} {cname}')
PY
else
  # No PyYAML: fall back to oc apply and tolerate selector errors for existing deps
  oc apply -f "${TMP}/all.yaml" >/dev/null 2>"${TMP}/apply.err" || true
  if grep -q 'field is immutable' "${TMP}/apply.err" 2>/dev/null; then
    log "    NOTE: some Deployment selectors immutable — images left as currently running"
  elif [[ -s "${TMP}/apply.err" ]]; then
    cat "${TMP}/apply.err" >&2
    die "oc apply failed"
  fi
fi
log "    manifests applied"

wait_deploy() {
  local name="$1"
  log "    waiting for deploy/${name}"
  oc -n "${PACKMATE_NAMESPACE}" rollout status "deploy/${name}" --timeout=300s
}

wait_deploy weather-mcp
wait_deploy baggage-policy-mcp
wait_deploy packmate-backend
wait_deploy packmate-frontend

# Health checks: prefer Route (NetworkPolicies may block arbitrary probe pods → ClusterIP)
log "==> Health checks"
check_route_health() {
  local route="$1" label="$2"
  local host code
  host="$(oc -n "${PACKMATE_NAMESPACE}" get route "${route}" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
  [[ -n "${host}" ]] || die "Route ${route} missing"
  code="$(curl -sk -o /dev/null -w '%{http_code}' -m 30 "https://${host}/health" || echo 000)"
  [[ "${code}" == "200" ]] || die "${label} returned HTTP ${code} for https://${host}/health"
  log "    OK ${label} (${code})"
}

check_route_health weather-mcp "weather /health"
check_route_health baggage-policy-mcp "baggage /health"

if oc -n "${PACKMATE_NAMESPACE}" exec deploy/packmate-backend -- \
    curl -sf -m 20 http://127.0.0.1:8080/health >/dev/null \
 && oc -n "${PACKMATE_NAMESPACE}" exec deploy/packmate-backend -- \
    curl -sf -m 20 http://127.0.0.1:8080/ready >/dev/null \
 && oc -n "${PACKMATE_NAMESPACE}" exec deploy/packmate-backend -- \
    curl -sf -m 20 http://127.0.0.1:8080/metrics >/dev/null; then
  log "    OK backend /health /ready /metrics via pod"
else
  die "backend health/ready/metrics failed via pod exec"
fi

ROUTE_HOST="$(oc -n "${PACKMATE_NAMESPACE}" get route packmate-frontend -o jsonpath='{.spec.host}' 2>/dev/null || true)"
if [[ -n "${ROUTE_HOST}" ]]; then
  code="$(curl -sk -o /dev/null -w '%{http_code}' -m 30 "https://${ROUTE_HOST}/" || echo 000)"
  [[ "${code}" == "200" ]] || die "Frontend Route returned HTTP ${code}"
  log "    OK Route https://${ROUTE_HOST}/ (${code})"
  export PACKMATE_API="https://${ROUTE_HOST}"
  bash "${ROOT}/scripts/test-streaming-smoke.sh" || die "SSE smoke failed"
else
  die "Route packmate-frontend missing"
fi

# MCP registration (preserve existing keys)
if [[ "${REGISTER_MCP}" == "true" ]]; then
  log "==> Registering MCP servers in ${ODH_APPLICATIONS_NS}"
  W_HOST="$(oc -n "${PACKMATE_NAMESPACE}" get route weather-mcp -o jsonpath='{.spec.host}')"
  B_HOST="$(oc -n "${PACKMATE_NAMESPACE}" get route baggage-policy-mcp -o jsonpath='{.spec.host}')"
  python3 - <<PY
import json, subprocess, tempfile, os
ns = "${ODH_APPLICATIONS_NS}"
name = "gen-ai-aa-mcp-servers"
weather = {
  "url": f"https://${W_HOST}/mcp",
  "description": "Packmate demonstration weather MCP server (Open-Meteo). Tool: get_weather. No credentials required.",
}
baggage = {
  "url": f"https://${B_HOST}/mcp",
  "description": "Packmate demonstration baggage policy MCP server. Tools: check_baggage_rules, get_general_baggage_rules. Deterministic demo rules with mandatory disclaimer.",
}
data = {}
r = subprocess.run(["oc", "get", "cm", name, "-n", ns, "-o", "json"], capture_output=True, text=True)
if r.returncode == 0:
  doc = json.loads(r.stdout)
  data = dict(doc.get("data") or {})
data["Packmate-Weather-MCP"] = json.dumps(weather, indent=2)
data["Packmate-Baggage-Policy-MCP"] = json.dumps(baggage, indent=2)
cm = {
  "apiVersion": "v1",
  "kind": "ConfigMap",
  "metadata": {"name": name, "namespace": ns},
  "data": data,
}
path = tempfile.mktemp(suffix=".json")
open(path, "w").write(json.dumps(cm))
subprocess.check_call(["oc", "apply", "-f", path])
os.unlink(path)
print("    MCP ConfigMap applied (existing keys preserved)")
PY
fi

# Pipelines
if [[ "${CREATE_PIPELINE}" == "true" ]]; then
  if packmate_api_has '^pipelines[[:space:]].*tekton\.dev'; then
    log "==> Applying lab Pipeline packmate-ci"
    oc apply -n "${PACKMATE_NAMESPACE}" -f "${ROOT}/.tekton/lab/packmate-ci.yaml" >/dev/null
    # Ensure BuildConfig + ImageStream exist for the build-backend task (namespace-scoped).
    if ! oc -n "${PACKMATE_NAMESPACE}" get bc packmate-backend >/dev/null 2>&1; then
      oc -n "${PACKMATE_NAMESPACE}" apply -f - <<EOF
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: packmate-backend
  labels:
    app.kubernetes.io/part-of: packmate
spec:
  lookupPolicy:
    local: false
---
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: packmate-backend
  labels:
    app.kubernetes.io/part-of: packmate
spec:
  output:
    to:
      kind: ImageStreamTag
      name: packmate-backend:pipeline
  runPolicy: Serial
  source:
    type: Binary
    binary: {}
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Containerfile
EOF
      log "    BuildConfig/ImageStream packmate-backend created"
    fi
    log "    Pipeline/packmate-ci ready — Start from OpenShift Pipelines UI"
  else
    log "    WARNING: Pipelines API absent — skip CREATE_PIPELINE"
  fi
fi

# Argo CD
if [[ "${CREATE_ARGOCD_APPLICATION}" == "true" ]]; then
  if oc get crd applications.argoproj.io >/dev/null 2>&1; then
    log "==> Applying Argo CD AppProject + Application (manual sync)"
    # Render placeholders
    sed -e "s|__GIT_REPO_URL__|${GIT_REPO_URL}|g" \
        -e "s|__GIT_REVISION__|${GIT_REVISION}|g" \
        -e "s|__PACKMATE_NAMESPACE__|${PACKMATE_NAMESPACE}|g" \
        "${ROOT}/argocd/appproject-packmate.yaml" | oc apply -f - >/dev/null
    sed -e "s|__GIT_REPO_URL__|${GIT_REPO_URL}|g" \
        -e "s|__GIT_REVISION__|${GIT_REVISION}|g" \
        -e "s|__PACKMATE_NAMESPACE__|${PACKMATE_NAMESPACE}|g" \
        "${ROOT}/argocd/application-packmate-lab.yaml" | oc apply -f - >/dev/null
    log "    Argo CD resources applied"
  else
    log "    GITOPS_OPERATOR_REQUIRED — see docs/INSTALL_GITOPS_PREREQUISITE.md"
    oc apply --dry-run=client -f "${ROOT}/argocd/" >/dev/null 2>&1 || true
  fi
fi

# Model custom endpoint — ClickOps by default
log "==> Model endpoint helper"
CREATE_MODEL_CUSTOM_ENDPOINT="${CREATE_MODEL_CUSTOM_ENDPOINT}" \
  bash "${ROOT}/scripts/create-packmate-model-endpoint.sh"

cat <<EOF

=== Bootstrap complete ===
Route: https://${ROUTE_HOST}/

Remaining UI steps:
1. Gen AI studio → AI asset endpoints → Project: Packmate Lab (and/or my-first-model)
2. Playground → paste playground/system-instructions.md → enable MCP → test prompts
3. Pipelines → packmate-ci → Start
4. Argo CD → packmate-lab → Sync (if GitOps installed)

Next: make verify
EOF
