# Reproduce the Packmate OpenShift AI sandbox

This guide recreates the **Packmate Lab** Data Science Project wiring against the
shared model already running in `my-first-model`. It does **not** redeploy vLLM.

## Prerequisites

- `oc` logged in as a user who can manage `packmate-lab` and read `my-first-model`
- OpenShift AI **3.4.x** with Gen AI studio
- InferenceService `llama-32-3b-instruct` Ready in `my-first-model`
- Optional local env: `cp config/sandbox.env.example config/sandbox.env`

## What gets created

| Resource | Namespace | Purpose |
|----------|-----------|---------|
| `OdhDashboardConfig` patch `aiAssetCustomEndpoints: true` | `redhat-ods-applications` | Enables UI **Create endpoint** |
| ConfigMap `gen-ai-aa-custom-model-endpoints` | `packmate-lab` | Same persistence as Gen AI **Create endpoint** |
| Secret `endpoint-api-key-1` | `packmate-lab` | Credential referenced by the ConfigMap |

MCP servers remain registered via platform ConfigMap `gen-ai-aa-mcp-servers`
(see `deploy/examples/mcp-registration/`).

## Steps

```bash
# 1) Optional env
cp config/sandbox.env.example config/sandbox.env
# edit MODEL_TOKEN only if the predictor requires auth

# 2) Register custom endpoint (discovers Service port, probes /v1/models)
bash scripts/create-packmate-model-endpoint.sh

# or full bootstrap helper
bash scripts/bootstrap-sandbox.sh

# 3) Verify
bash scripts/verify-sandbox.sh
```

## UI check

1. Gen AI studio → AI asset endpoints → Project: **Packmate Lab** → Models  
   Expect: **Packmate Llama 3.2 3B**, plus MCP tab entries when registered.
2. Gen AI studio → Playground → Project: **Packmate Lab**  
   Select the model and the two Packmate MCP servers.

## Internal URL

The script probes the live Service. On this lab the predictor is a **headless**
Service: clients must use the **pod targetPort** (typically `8080`), not Service
port `80`:

```text
http://llama-32-3b-instruct-predictor.my-first-model.svc.cluster.local:8080/v1
```

## Safety

- Never commit `config/sandbox.env` or real tokens
- Never create an external Route for the model
- Never modify the Deployment / InferenceService in `my-first-model`
- Do not set `genAiStudioConfig.aiAssetCustomEndpoints.externalProviders` to true
  unless you intentionally allow third-party providers
