# Instructor setup checklist

Use before each Packmate v2 session.

## Operators and platform

- [ ] OpenShift AI 3.4.x Ready (`rhods-operator`)
- [ ] OpenShift Pipelines installed (Module 9)
- [ ] OpenShift GitOps installed **or** Module 10 marked screenshot-only
- [ ] GPU / model serving healthy for `llama-32-3b-instruct`
- [ ] User can create Data Science Projects and Workbenches

## Model

- [ ] InferenceService `llama-32-3b-instruct` Ready in `my-first-model`
- [ ] Service `llama-32-3b-instruct-predictor` exists
- [ ] In-cluster `/v1/models` lists `llama-32-3b-instruct`
- [ ] **No** plan to redeploy the model for Packmate

## Images (persistent)

- [ ] GitHub Actions `publish-lab-images` ran for this class version
- [ ] Four packages public on GHCR (or mirrored to Quay)
- [ ] Digest refs ready for `BACKEND_IMAGE`, `FRONTEND_IMAGE`, `WEATHER_MCP_IMAGE`, `BAGGAGE_POLICY_MCP_IMAGE`
- [ ] No `:latest` tags

## Config pack for participants

- [ ] `config/sandbox.env` template with image digests (distributed out-of-band)
- [ ] `LITELLM_API_KEY=dummy` (or lab token policy documented)
- [ ] `CREATE_MODEL_CUSTOM_ENDPOINT=false` (ClickOps Mode B)
- [ ] `ALLOW_CREATE_NAMESPACE=false`

## Smoke on instructor project

- [ ] `make preflight` → no BLOCKED
- [ ] `SKIP_CONFIRM=true make bootstrap`
- [ ] `make verify` → OK
- [ ] Playground Mode A works with `playground/system-instructions.md`
- [ ] Both MCP tools authorize
- [ ] Frontend Route serves UI
- [ ] Pipeline `packmate-ci` visible (if Pipelines present)

## Day-of

- [ ] Dashboard URL shared
- [ ] Branch `packmate-v2` shared
- [ ] Screenshot fallbacks ready if GitOps/Pipelines flaky
- [ ] Cleanup policy explained (`make cleanup` only after class)

## Optional (not blocking)

- [ ] EvalHub instance — else `EVALHUB_OPTIONAL_NOT_CONFIGURED`
- [ ] Argo Rollouts — annex only
