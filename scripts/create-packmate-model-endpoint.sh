#!/usr/bin/env bash
# Discover the shared Llama predictor and create/update the Packmate custom model
# endpoint in the lab namespace (same persistence as Gen AI Studio "Create endpoint").
#
# Confirmed mechanism (OpenShift AI 3.4.2 / odh-mod-arch-gen-ai BFF):
#   ConfigMap gen-ai-aa-custom-model-endpoints  key: config.yaml
#   Secret    endpoint-api-key-<n>              key: api_key
# Schema: models.ExternalModelsConfig (providers.inference + registered_resources.models)
#
# Never redeploys the model. Never creates an InferenceService. Never prints tokens.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/scripts/lib/sandbox-common.sh"

packmate_require_oc
command -v python3 >/dev/null || packmate_die "python3 required"
if [[ -f "${ROOT}/config/sandbox.env" ]]; then
  packmate_load_config "${ROOT}" || exit 1
fi

PACKMATE_NAMESPACE="${PACKMATE_NAMESPACE:-packmate-lab}"
MODEL_NAMESPACE="${MODEL_NAMESPACE:-my-first-model}"
MODEL_SERVICE="${MODEL_SERVICE:-llama-32-3b-instruct-predictor}"
MODEL_ID="${MODEL_ID:-llama-32-3b-instruct}"
CREATE_MODEL_CUSTOM_ENDPOINT="${CREATE_MODEL_CUSTOM_ENDPOINT:-true}"
DISPLAY_NAME="${PACKMATE_MODEL_DISPLAY_NAME:-Packmate Llama 3.2 3B}"
USE_CASE="${PACKMATE_MODEL_USE_CASE:-Packmate travel planning, weather and baggage tool calling}"
CM_NAME="gen-ai-aa-custom-model-endpoints"

log() { packmate_log "$*"; }
die() { packmate_die "$*"; }

if [[ "${CREATE_MODEL_CUSTOM_ENDPOINT}" != "true" ]]; then
  log "==> CREATE_MODEL_CUSTOM_ENDPOINT=${CREATE_MODEL_CUSTOM_ENDPOINT} — skipping custom endpoint creation"
  exit 0
fi

oc get project "${PACKMATE_NAMESPACE}" >/dev/null || die "project ${PACKMATE_NAMESPACE} missing"
oc get project "${MODEL_NAMESPACE}" >/dev/null || die "project ${MODEL_NAMESPACE} missing"
READY="$(oc get inferenceservice "${MODEL_ID}" -n "${MODEL_NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
[[ "${READY}" == "True" ]] || die "InferenceService ${MODEL_ID} not Ready in ${MODEL_NAMESPACE}"

# Refuse accidental second model in the lab namespace
if oc -n "${PACKMATE_NAMESPACE}" get inferenceservice "${MODEL_ID}" >/dev/null 2>&1; then
  die "InferenceService ${MODEL_ID} must not exist in ${PACKMATE_NAMESPACE} (shared model stays in ${MODEL_NAMESPACE})"
fi

packmate_discover_model_url || die "Service discovery failed"

log "==> Model discovery"
log "    service_port=${PACKMATE_MODEL_SVC_PORT} targetPort=${PACKMATE_MODEL_TARGET_PORT} probe_port=${PACKMATE_MODEL_PROBE_PORT}"
log "    auth_annotation=${PACKMATE_MODEL_AUTH:-absent}"
log "    base_url=${PACKMATE_MODEL_BASE_URL}"
log "    model_id=${MODEL_ID}"

# Probe from a temporary non-privileged pod in the lab namespace
POD="packmate-model-endpoint-probe-$$"
cleanup_probe() { oc -n "${PACKMATE_NAMESPACE}" delete pod "${POD}" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup_probe EXIT

oc -n "${PACKMATE_NAMESPACE}" delete pod "${POD}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
oc -n "${PACKMATE_NAMESPACE}" run "${POD}" --image=registry.access.redhat.com/ubi9/ubi-minimal:9.4 \
  --restart=Never --quiet \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"probe","image":"registry.access.redhat.com/ubi9/ubi-minimal:9.4","command":["sleep","120"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"runAsNonRoot":true}}]}}' \
  --command -- sleep 120 >/dev/null
oc -n "${PACKMATE_NAMESPACE}" wait --for=condition=Ready "pod/${POD}" --timeout=90s >/dev/null

BODY="$(oc -n "${PACKMATE_NAMESPACE}" exec "${POD}" -- \
  curl -sS -m 30 -w '\n%{http_code}' "${PACKMATE_MODEL_BASE_URL}/models" || true)"
HTTP_CODE="$(printf '%s\n' "${BODY}" | tail -n1)"
MODELS_BODY="$(printf '%s\n' "${BODY}" | sed '$d')"
[[ "${HTTP_CODE}" == "200" ]] || die "/v1/models returned HTTP ${HTTP_CODE} (expected 200)"
printf '%s' "${MODELS_BODY}" | grep -q "${MODEL_ID}" || die "/v1/models did not list ${MODEL_ID}"
log "    /v1/models OK (HTTP 200)"

# Minimal chat completion (auth header only if predictor requires it)
CHAT_HDR=()
if [[ "${PACKMATE_MODEL_AUTH}" == "true" ]]; then
  [[ -n "${MODEL_TOKEN:-}" ]] || die "predictor auth enabled but MODEL_TOKEN is empty"
  CHAT_HDR=(-H "Authorization: Bearer ${MODEL_TOKEN}")
fi
CHAT_PAYLOAD="$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"messages":[{"role":"user","content":"ping"}],"max_tokens":1}))' "${MODEL_ID}")"
CHAT_OUT="$(oc -n "${PACKMATE_NAMESPACE}" exec "${POD}" -- \
  curl -sS -m 60 -w '\n%{http_code}' "${CHAT_HDR[@]}" \
  -H 'Content-Type: application/json' \
  -d "${CHAT_PAYLOAD}" \
  "${PACKMATE_MODEL_BASE_URL}/chat/completions" || true)"
CHAT_CODE="$(printf '%s\n' "${CHAT_OUT}" | tail -n1)"
[[ "${CHAT_CODE}" == "200" ]] || die "/v1/chat/completions returned HTTP ${CHAT_CODE} (expected 200)"
log "    /v1/chat/completions OK (HTTP 200)"
cleanup_probe
trap - EXIT

# Credential value: dummy only when auth is disabled; otherwise Secret holds MODEL_TOKEN (never printed)
if [[ "${PACKMATE_MODEL_AUTH}" == "true" ]]; then
  SECRET_VALUE="${MODEL_TOKEN}"
  log "    auth: enabled — credential stored in namespace Secret (value not shown)"
else
  SECRET_VALUE="${MODEL_TOKEN:-not-required}"
  log "    auth: disabled — using placeholder Secret value (never printed)"
fi

log "==> Applying custom model endpoint (ConfigMap + Secret, BFF-compatible)"
python3 - <<'PY' "${PACKMATE_NAMESPACE}" "${CM_NAME}" "${PACKMATE_MODEL_BASE_URL}" \
  "${MODEL_ID}" "${DISPLAY_NAME}" "${USE_CASE}" "${SECRET_VALUE}"
import json, subprocess, sys, tempfile

ns, cm_name, base_url, model_id, display_name, use_case, secret_value = sys.argv[1:8]

def oc_json(args):
    r = subprocess.run(["oc", *args], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return json.loads(r.stdout)

def apply_obj(obj):
    path = tempfile.mktemp(suffix=".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f)
    subprocess.check_call(["oc", "apply", "-f", path], stdout=subprocess.DEVNULL)
    # scrub
    open(path, "w").close()
    subprocess.run(["rm", "-f", path], check=False)

existing = oc_json(["get", "cm", cm_name, "-n", ns, "-o", "json"])
config = {"providers": {"inference": []}, "registered_resources": {"models": []}}
if existing and existing.get("data", {}).get("config.yaml"):
    try:
        import yaml
        parsed = yaml.safe_load(existing["data"]["config.yaml"]) or {}
        if isinstance(parsed, dict):
            config = parsed
    except Exception as e:
        raise SystemExit(f"failed to parse existing {cm_name} config.yaml: {e}")

providers = list((config.get("providers") or {}).get("inference") or [])
models = list((config.get("registered_resources") or {}).get("models") or [])

# Find existing Packmate model by model_id
existing_provider_id = None
for m in models:
    if m.get("model_id") == model_id:
        existing_provider_id = m.get("provider_id")
        break

if existing_provider_id:
    provider_id = existing_provider_id
    numeric = provider_id.removeprefix("endpoint-") if provider_id.startswith("endpoint-") else "1"
else:
    max_id = 0
    for p in providers:
        pid = str(p.get("provider_id") or "")
        if pid.startswith("endpoint-"):
            try:
                max_id = max(max_id, int(pid.split("-", 1)[1]))
            except ValueError:
                pass
    numeric = str(max_id + 1)
    provider_id = f"endpoint-{numeric}"

secret_name = f"endpoint-api-key-{numeric}"

desired_provider = {
    "provider_id": provider_id,
    "provider_type": "remote::openai",
    "config": {
        "base_url": base_url,
        "allowed_models": [model_id],
        "custom_gen_ai": {
            "api_key": {"secretRef": {"name": secret_name, "key": "api_key"}}
        },
    },
}
desired_model = {
    "provider_id": provider_id,
    "model_id": model_id,
    "model_type": "llm",
    "metadata": {
        "display_name": display_name,
        "custom_gen_ai": {"use_cases": use_case},
    },
}

# Replace Packmate provider/model; preserve all other entries
new_providers = [p for p in providers if p.get("provider_id") != provider_id]
new_providers.append(desired_provider)
new_models = [m for m in models if m.get("model_id") != model_id]
new_models.append(desired_model)

config["providers"] = {"inference": new_providers}
config["registered_resources"] = {"models": new_models}

try:
    import yaml
    config_yaml = yaml.safe_dump(config, sort_keys=False)
except ImportError:
    # Minimal YAML emitter for this fixed schema
    def emit(obj, indent=0):
        sp = "  " * indent
        if isinstance(obj, dict):
            lines = []
            for k, v in obj.items():
                if isinstance(v, (dict, list)):
                    lines.append(f"{sp}{k}:")
                    lines.append(emit(v, indent + 1))
                else:
                    if isinstance(v, str) and (":" in v or "," in v or " " in v or v == ""):
                        lines.append(f'{sp}{k}: "{v}"')
                    else:
                        lines.append(f"{sp}{k}: {v}")
            return "\n".join(lines)
        if isinstance(obj, list):
            lines = []
            for item in obj:
                if isinstance(item, dict):
                    first = True
                    for k, v in item.items():
                        prefix = "- " if first else "  "
                        first = False
                        if isinstance(v, (dict, list)):
                            lines.append(f"{sp}{prefix}{k}:")
                            lines.append(emit(v, indent + 2))
                        else:
                            if isinstance(v, str) and (":" in v or "," in v or " " in v or v == ""):
                                lines.append(f'{sp}{prefix}{k}: "{v}"')
                            else:
                                lines.append(f"{sp}{prefix}{k}: {v}")
                else:
                    lines.append(f"{sp}- {item}")
            return "\n".join(lines)
        return f"{sp}{obj}"
    config_yaml = emit(config) + "\n"

# Secret first (never print value)
secret_obj = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": secret_name, "namespace": ns},
    "type": "Opaque",
    "stringData": {"api_key": secret_value},
}
apply_obj(secret_obj)

cm_obj = {
    "apiVersion": "v1",
    "kind": "ConfigMap",
    "metadata": {
        "name": cm_name,
        "namespace": ns,
        "labels": {"app.kubernetes.io/part-of": "packmate"},
    },
    "data": {"config.yaml": config_yaml},
}
apply_obj(cm_obj)

# Verification (no secret dump)
cm = oc_json(["get", "cm", cm_name, "-n", ns, "-o", "json"])
assert cm and cm.get("data", {}).get("config.yaml"), "ConfigMap missing config.yaml"
body = cm["data"]["config.yaml"]
for needle in (model_id, display_name, base_url, provider_id, secret_name):
    if needle not in body:
        raise SystemExit(f"ConfigMap verification failed: missing {needle!r}")
sec = oc_json(["get", "secret", secret_name, "-n", ns, "-o", "json"])
assert sec and "api_key" in (sec.get("data") or {}), f"Secret {secret_name} missing api_key key"
print(f"    ConfigMap/{cm_name} ready (provider_id={provider_id})")
print(f"    Secret/{secret_name} ready (key=api_key, value not shown)")
PY

unset SECRET_VALUE MODEL_TOKEN
log "    UI_REFRESH_REQUIRED — refresh Gen AI studio to see Packmate Llama 3.2 3B in ${PACKMATE_NAMESPACE}"
log "==> Custom model endpoint created and verified"
