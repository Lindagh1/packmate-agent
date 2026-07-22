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
