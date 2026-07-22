# Reproduce the Packmate OpenShift AI sandbox

Target: a **new ephemeral sandbox** where participants ClickOps the Data Science
Project + Workbench, then run:

```bash
make preflight
make bootstrap
make verify
```

Bootstrap deploys from **prebuilt images** (GHCR/Quay/internal digests). It does
**not** rebuild four images and does **not** redeploy the Llama model.

## Architecture split

| Layer | Responsibility |
|-------|----------------|
| Participant ClickOps | DSP, Workbench, AI assets, Playground, Pipeline Start, Argo Sync |
| Bootstrap automation | MCP, backend/frontend, Secrets, Routes, MCP registration, Tekton/Argo manifests |
| Platform prerequisites | OpenShift AI, Pipelines, (GitOps), GPU model in `my-first-model` |

## Persist vs ephemeral

**Persistent:** Git repo, GHCR/Quay images, manifests, system prompt, docs.
**Ephemeral:** Project, Workbench, Secrets, Deployments, Routes, MCP registration, PipelineRuns, Argo Application, custom endpoint objects.

## Configure

```bash
cp config/sandbox.env.example config/sandbox.env
# Set digest-pinned *_IMAGE values from the publish-lab-images workflow summary.
# Never commit config/sandbox.env.
```

## Commands

```bash
make preflight    # PASS/WARNING/BLOCKED/OPTIONAL_UNAVAILABLE
make bootstrap    # confirmation prompt; SKIP_CONFIRM=true for CI-like smoke
make verify       # non-destructive; exit 0 = lab core ready
make cleanup      # interactive only
```

### Namespace policy

Default: participant creates the Data Science Project in the UI.
If missing, bootstrap prints:

```text
MANUAL STEP REQUIRED:
Create the Data Science Project from the OpenShift AI dashboard.
```

Instructor-only: `ALLOW_CREATE_NAMESPACE=true`.

### Model endpoint

Default `CREATE_MODEL_CUSTOM_ENDPOINT=false` prints **MANUAL STEP REQUIRED** with
exact URL / Model ID / display name for Create endpoint ClickOps.
Mode A: use Playground in `my-first-model`.

## Publish images (instructor, once per version)

1. Actions → **publish-lab-images** → workflow_dispatch **or** push tag `lab-v*`.
2. Copy four digest refs from the job summary.
3. Make each GHCR package **Public**.
4. Distribute refs via `sandbox.env` (out of band).

Internal registry images vanish when the sandbox is deleted; GHCR/Quay do not.

## GitOps absent

See `docs/INSTALL_GITOPS_PREREQUISITE.md` (`GITOPS_OPERATOR_REQUIRED`).

## Safety

- No Secrets in Git
- No `:latest`
- No model redeploy
- No Operator install from lab scripts
- Destructive cleanup requires typing `DELETE-PACKMATE-LAB`

## Validated release evidence (2026-07-22)

| Item | Value |
|------|-------|
| Tag | `lab-v1.0.0` |
| Workflow | `publish-lab-images` run [29910810996](https://github.com/Lindagh1/packmate-agent/actions/runs/29910810996) **success** |
| GHCR owner | `lindagh1` (packages **public**, linked to repo) |
| Backend | `ghcr.io/lindagh1/packmate-backend@sha256:c10fbeb6fbd63ca478e1b8231ddf874ec7ee1c80663b641d802ffca6e826849f` |
| Frontend | `ghcr.io/lindagh1/packmate-frontend@sha256:d6ade3f968a8e1057cb7e846a6dbded4c0f45f8b1780d16d5dd9d76b55d08305` |
| Weather MCP | `ghcr.io/lindagh1/packmate-weather-mcp@sha256:f4a8dcb5407e3bf9dfbb2e494ccb7fc478a377ce074ef2b3f219b55d57443006` |
| Baggage MCP | `ghcr.io/lindagh1/packmate-baggage-policy-mcp@sha256:17432265c056241b6ce89368f9cd1fe0ff5165d3316ef80116285b78b9d58d1a` |
| Repro namespace | `packmate-repro` (`ALLOW_CREATE_NAMESPACE=true`) |
| preflight / bootstrap / verify | **OK** (SSE + heartbeats on repro Route) |
| PipelineRun | `packmate-ci-validate-20260722-123626` **Succeeded** |
| Quality gate (in Pipeline) | score **0.9559**, scenarios **16**, threshold 0.90, **PASS** |
| Pipeline backend digest | `sha256:d04468d34593a2d9c76f30a318ace2fcbc97e9c4d483b8271497e1dd59a2ca84` (ImageStream `packmate-backend:pipeline` in `packmate-repro` only — live Deployments not auto-promoted) |
| OpenShift GitOps | Installed on this sandbox (`openshift-gitops-operator.v1.21.1`, channel `latest`) |
| Argo CD Application | `packmate-lab` → destination `packmate-repro`, manual sync, prune/selfHeal off |
| Rollouts / EvalHub | Optional / not configured |
