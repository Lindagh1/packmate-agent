# Packmate v2 — Tekton Pipelines as Code

CI definitions for [OpenShift Pipelines](https://docs.openshift.com/pipelines/) and [Pipelines as Code (PAC)](https://pipelinesascode.com/).

## Files

| File | Trigger | Purpose |
|------|---------|---------|
| [`pull-request.yaml`](pull-request.yaml) | `pull_request` → `main` | Clone, test, lint, build, validate — **no image push** |
| [`push.yaml`](push.yaml) | `push` → `main` | All PR steps + build/push images, pin digests in GitOps, commit |

Setup guide: [`docs/TEKTON_SETUP.md`](../docs/TEKTON_SETUP.md).

## Parameters

| Parameter | Description |
|-----------|-------------|
| `git-url` | Application repository clone URL |
| `git-revision` | Branch, tag, or commit SHA to build |
| `output-image-backend` | Full backend image reference for push pipeline |
| `output-image-frontend` | Full frontend image reference for push pipeline |
| `output-image-weather-mcp` | Full weather MCP image reference for push pipeline |
| `output-image-baggage-policy-mcp` | Full baggage-policy MCP image reference for push pipeline |
| `gitops-branch` | Branch to update with digest-pinned manifests (push only) |
| `gitops-overlay` | Kustomize overlay (`dev` or `prod`) to patch (push only) |
| `evaluation-threshold` | Minimum deterministic eval score (default `0.90`) |

## Workspaces

| Workspace | Secret / volume | Used by |
|-----------|-----------------|---------|
| `source` | PVC | All tasks — cloned repo |
| `shared-data` | `emptyDir` | Push pipeline — captured image digests |
| `dockerconfig` | Secret **`registry-auth`** | Push pipeline — registry login |
| `git-auth` | Secret **`gitops-repo-auth`** | Push pipeline — Git push for GitOps commit |

Secrets are referenced **by name only**. Create them in the PAC/CI namespace before enabling pipelines:

```bash
# Registry push (type kubernetes.io/dockerconfigjson)
oc create secret docker-registry registry-auth \
  --docker-server=quay.io \
  --docker-username='...' \
  --docker-password='...' \
  -n packmate-ci

# GitOps repo push (basic-auth or token)
oc create secret generic gitops-repo-auth \
  --from-literal=username='...' \
  --from-literal=password='...' \
  -n packmate-ci
```

## Pipeline stages

### Pull request (`packmate-pull-request`)

1. **clone** — shallow clone at `git-revision`
2. **backend-tests** — `pytest` in `backend/`
3. **mcp-weather-tests** / **mcp-baggage-tests** — `pytest` in `mcp-servers/weather/` and `mcp-servers/baggage-policy/`
4. **quality-gate** — `python -m evals.runner --mode deterministic`
5. **evalhub-optional** — runs `evaluations/scripts/run_evalhub_optional.sh` when present; otherwise skips (non-fatal when EvalHub CRD or script absent)
6. **frontend-ci** — `npm run lint`, `test`, `build`
7. **validate-containerfiles** — `buildah bud` for backend, frontend, and both MCP Containerfiles (build only, no push)
8. **validate-manifests** — `scripts/render-manifests.sh` + `scripts/validate-manifests.sh`
9. **security-check** — `scripts/security-check.sh` (fails on `:latest` tags and plaintext secrets)

### Push (`packmate-push`)

Runs all PR stages (except **evalhub-optional**), then:

10. **build-push-backend** / **build-push-frontend** / **build-push-weather-mcp** / **build-push-baggage-policy-mcp** — buildah build + push, write digests to `shared-data`
11. **update-gitops** — patch `deploy/overlays/<overlay>/kustomization.yaml` with `digest:` fields for all four images, commit, push

Production promotion typically sets `gitops-overlay=prod` in a separate PAC Repository or manual PipelineRun.

## Security gates

Both pipelines fail closed on policy violations:

- **`scripts/validate-manifests.sh`** — schema/structure checks; rejects secrets in rendered output
- **`scripts/security-check.sh`** — repo-wide scan for `:latest` image tags and committed plaintext secrets

If `security-check.sh` is not yet present on a branch, the task fails until the script is merged.

## Notes

- Tasks use embedded `taskSpec` blocks (no ClusterTask dependency).
- Image tags should be content-addressed (e.g. `sha-<commit>`); GitOps updates prefer **digest pinning**.
- PR pipeline marks `dockerconfig` and `git-auth` workspaces optional; push pipeline requires both secrets.
