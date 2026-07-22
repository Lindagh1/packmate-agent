# Instructor guide — Packmate v2 (OpenShift AI first touch)

Lab duration for participants: **≈120 minutes**.
Your prep: **45–90 minutes** on a ready cluster (longer the first time you publish images).

## Platform matrix (audit this cluster before class)

| Component | Status on reference sandbox (2026-07) | Lab impact |
|-----------|----------------------------------------|------------|
| OpenShift AI (`rhods-operator` 3.4.x) | **Required** | Blocks lab if absent |
| Model `llama-32-3b-instruct` in `my-first-model` | **Required** | Shared; never redeploy for Packmate |
| OpenShift Pipelines 1.22.x | **Required for Module 9** | Warn + screenshots if absent |
| OpenShift GitOps / Argo CD | **Optional Module 10** (validated install on 2026-07-22 sandbox) | `GITOPS_OPERATOR_REQUIRED` if absent |
| Argo Rollouts | Optional annex | Not in main path |
| EvalHub instance | Optional annex | `EVALHUB_OPTIONAL_NOT_CONFIGURED` |

Classification helpers: `make preflight` prints PASS / WARNING / BLOCKED / OPTIONAL_UNAVAILABLE.

## What participants must ClickOps

- Create Data Science Project (`packmate-lab`)
- Create code-server Workbench
- Clone repo → `make preflight` / `make bootstrap` / `make verify`
- Playground in **Packmate Lab** (select model + enable MCP + paste system prompt + test)
- Start Pipeline `packmate-ci`
- Argo CD Sync (if GitOps present)

Participants must **not** create the custom model endpoint, enter model URLs/tokens, or switch to `my-first-model` for the Playground path.

## What bootstrap automates

- Secrets from env (values never printed)
- Enable Gen AI **custom endpoints** feature (`aiAssetCustomEndpoints=true`) when needed
- Discover/test the shared model Service in `my-first-model`
- Weather + Baggage MCP, backend, frontend, Routes, NetworkPolicies
- MCP ConfigMap registration (preserves other keys)
- **Automatic** Packmate custom model endpoint in `packmate-lab` (ConfigMap + Secret)
- Tekton `packmate-ci` resources
- Argo CD manifests when CRDs exist

## What participants must NOT do

- Install Operators
- Build four images at lab start
- Deploy or modify the Llama InferenceService
- Commit Secrets / `config/sandbox.env`
- Use Argo CD admin password
- Port-forward for the main path

## Persistent vs ephemeral

### PERSISTANT

- Git repository + branch `packmate-v2`
- GitHub Actions workflow `.github/workflows/publish-lab-images.yml`
- Images on **GHCR or Quay** (digest-pinned)
- Manifests, system prompt, test prompts, datasets, documentation

### ÉPHÉMÈRE

- Data Science Project / Workbench / PVC
- Secrets, Deployments, Routes
- MCP registration ConfigMap entries
- PipelineRuns
- Argo CD Application
- Custom model endpoint ConfigMap/Secret in `packmate-lab`
- EvalHub instance (if any)

## Images (critical)

Internal OpenShift registry dies with the sandbox. Publish once:

1. Tag `lab-v1.0.0` or run **workflow_dispatch** on `publish-lab-images`.
2. Wait for four digests in the job summary.
3. GitHub → Packages → each image → **Change visibility → Public**.
4. Put refs into the class `config/sandbox.env` template (not in Git).

Bootstrap accepts **Quay or GHCR**; it does not hard-code a registry.

## Pre-session checklist

See `docs/INSTRUCTOR_SETUP_CHECKLIST.md`.

Minimum:

```bash
cp config/sandbox.env.example /tmp/packmate-class.env
# fill *_IMAGE digests + dummy LLM key
export PACKMATE_CONFIG=/tmp/packmate-class.env
# on a smoke project:
SKIP_CONFIRM=true make preflight
SKIP_CONFIRM=true make bootstrap
make verify
```

## Shared model + custom endpoint (official lab)

- The physical Llama InferenceService stays only in **`my-first-model`** (one GPU allocation).
- Bootstrap creates a **custom model endpoint** in each lab project (`packmate-lab`) that points at the shared cluster-local Service URL.
- Defaults: `ENABLE_CUSTOM_ENDPOINTS=true`, `CREATE_MODEL_CUSTOM_ENDPOINT=true`.
- Custom endpoints are a **Technology Preview** feature in OpenShift AI 3.4.
- Persistence matches Gen AI Studio: ConfigMap `gen-ai-aa-custom-model-endpoints` + Secret `endpoint-api-key-<n>` (never print Secret values).
- Do **not** enable `externalProviders` for `.svc.cluster.local` URLs.
- Never create a second vLLM / InferenceService for Packmate.

## Pipelines

Apply via bootstrap (`CREATE_PIPELINE=true`). Participants only **Start** `packmate-ci`.
Pipeline builds **backend only**. Promote digest with `scripts/promote-backend-image.sh` (confirm + optional local commit, **no push**).

## GitOps

If Operator missing: share `docs/INSTALL_GITOPS_PREREQUISITE.md` and skip live Sync.
If present: Application uses **manual sync**, prune off, self-heal off, destination `packmate-lab` only.

## Evaluation

Mandatory: deterministic quality gate (threshold **0.90**, reference score **0.9559**).
EvalHub: optional annex only.

## Reset / cleanup

```bash
make cleanup   # interactive; types DELETE-PACKMATE-LAB
```

Does not touch `my-first-model` or Operators.

## Cluster unavailable

Fall back to screenshots + local `make test` / Compose. Do not invent “validated” cluster features.

## Duration guide

| Phase | Time |
|-------|------|
| Instructor image publish (once) | 30–60 min |
| Instructor cluster smoke | 30 min |
| Participant lab | 120 min |

## Participant handout (Word)

Participant Markdown source (historical lab *style*, Packmate v2 *content*):

`docs/PARTICIPANT_GUIDE.md`

Assembly instructions for editors (cover, TOC, captions, page breaks — **no** auto-generated DOCX):

`docs/DOCX_ASSEMBLY_PLAN.md`
