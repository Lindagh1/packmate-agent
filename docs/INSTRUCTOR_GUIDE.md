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

- Create Data Science Project
- Create code-server Workbench
- AI asset endpoints / Playground / system prompt / MCP / export
- Start Pipeline `packmate-ci`
- Argo CD Sync (if GitOps present)

## What bootstrap automates

- Secrets from env (values never printed)
- Weather + Baggage MCP, backend, frontend, Routes, NetworkPolicies
- MCP ConfigMap registration (preserves other keys)
- Tekton `packmate-ci` resources
- Argo CD manifests when CRDs exist
- Model endpoint **helper** (default: print ClickOps values; optional CLI apply)

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

## Model modes

- **Mode A:** Playground in `my-first-model` (always works if model Ready).
- **Mode B:** Custom endpoint in `packmate-lab` — participant ClickOps using printed URL/Model ID (default). Optional `CREATE_MODEL_CUSTOM_ENDPOINT=true` for instructor automation.

Never create a second vLLM / InferenceService for Packmate.

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
