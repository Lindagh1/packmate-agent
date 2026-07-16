# Tekton / Pipelines as Code setup — Packmate v2

Guide for wiring `.tekton/` pipelines on OpenShift with Pipelines as Code (PAC).

## Prerequisites

- OpenShift cluster with **OpenShift Pipelines** operator installed
- **Pipelines as Code** controller (OpenShift GitOps or standalone PAC)
- Namespace for CI (example: `packmate-ci`)
- Quay (or other registry) repository for backend and frontend images
- GitHub/GitLab webhook access to the application repo

## 1. Create the CI namespace

```bash
oc new-project packmate-ci
```

Grant PAC service account permission to create PipelineRuns in this namespace (exact SA name depends on your PAC install; common value: `pipelines-as-code-controller` in `openshift-pipelines`).

## 2. Create secrets (names only — no values in git)

### Registry auth — `registry-auth`

Type: `kubernetes.io/dockerconfigjson`

```bash
oc create secret docker-registry registry-auth \
  --docker-server=quay.io \
  --docker-username='<robot-or-user>' \
  --docker-password='<token>' \
  -n packmate-ci
```

Used by workspace `dockerconfig` during image push.

### GitOps repo auth — `gitops-repo-auth`

Type: `Opaque` with keys `username` and `password` (or `.git-credentials` for credential-helper format).

```bash
oc create secret generic gitops-repo-auth \
  --from-literal=username='<git-user>' \
  --from-literal=password='<token-or-password>' \
  -n packmate-ci
```

Used by workspace `git-auth` when the push pipeline commits digest-pinned manifests.

## 3. Register the repository with PAC

Create a `Repository` CR (adjust URL, namespace, and provider settings):

```yaml
apiVersion: pipelinesascode.tekton.dev/v1alpha1
kind: Repository
metadata:
  name: packmate-agent
  namespace: packmate-ci
spec:
  url: https://github.com/example/packmate-agent.git
  git_provider:
    type: github
    secret:
      name: pac-webhook-secret
      key: provider.token
  webhook_secret:
    name: pac-webhook-secret
    key: webhook.secret
```

Apply pipeline definitions (PAC usually discovers `.tekton/*.yaml` on its own after webhook setup):

```bash
oc apply -f .tekton/pull-request.yaml -n packmate-ci
oc apply -f .tekton/push.yaml -n packmate-ci
```

Configure the GitHub/GitLab webhook to POST to your PAC ingress URL.

## 4. Pipeline parameters

Override defaults in the `Repository` CR or in PAC template expansion:

| Parameter | PR example | Push example |
|-----------|------------|--------------|
| `git-url` | `https://github.com/org/packmate-agent.git` | same |
| `git-revision` | PR head SHA (PAC: `{{ revision }}`) | commit SHA |
| `output-image-backend` | unused | `quay.io/org/packmate-backend:sha-abc1234` |
| `output-image-frontend` | unused | `quay.io/org/packmate-frontend:sha-abc1234` |
| `gitops-branch` | unused | `main` |
| `gitops-overlay` | unused | `dev` (use `prod` for production promotion runs) |
| `evaluation-threshold` | `0.90` | `0.90` |

PAC substitution example in `push.yaml` PipelineRun params:

```yaml
- name: git-revision
  value: "{{ revision }}"
- name: output-image-backend
  value: "quay.io/org/packmate-backend:sha-{{ revision_short }}"
```

## 5. Workspaces

| Workspace | Binding | Purpose |
|-----------|---------|---------|
| `source` | PVC (`volumeClaimTemplate`) | Clone and build |
| `shared-data` | `emptyDir` | Store `backend.digest` / `frontend.digest` between push tasks |
| `dockerconfig` | Secret `registry-auth` | Registry login for buildah push |
| `git-auth` | Secret `gitops-repo-auth` | Git push after GitOps manifest update |

## 6. What each pipeline runs

### Pull request

- Backend: `pytest`, deterministic evals (`evals.runner`)
- Frontend: `npm run lint`, `test`, `build`
- Containerfiles: buildah build (no push)
- Manifests: `scripts/render-manifests.sh`, `scripts/validate-manifests.sh`
- Security: `scripts/security-check.sh` — **fails** on `:latest` tags or plaintext secrets in tracked files

### Push to main

All PR steps, then:

1. Build and push backend/frontend images
2. Capture immutable digests
3. Update `deploy/overlays/<gitops-overlay>/kustomization.yaml` with `digest:` (not `:latest`)
4. Commit and push to `gitops-branch`

Argo CD (see `gitops/`) syncs the updated overlay.

## 7. Promoting to production

Recommended flow:

1. Merge to `main` — push pipeline updates `deploy/overlays/dev` with digests; Argo CD dev app auto-syncs.
2. Run a manual PipelineRun (or separate PAC event) with `gitops-overlay=prod` after review.
3. Sync `packmate-prod` Argo CD Application manually (prod has automated sync disabled).

```bash
oc create -f - <<EOF
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: packmate-promote-prod-
  namespace: packmate-ci
spec:
  pipelineRef:
    name: packmate-push
  params:
    - name: git-url
      value: https://github.com/example/packmate-agent.git
    - name: git-revision
      value: <approved-sha>
    - name: output-image-backend
      value: quay.io/org/packmate-backend:sha-<approved-sha>
    - name: output-image-frontend
      value: quay.io/org/packmate-frontend:sha-<approved-sha>
    - name: gitops-branch
      value: main
    - name: gitops-overlay
      value: prod
    - name: evaluation-threshold
      value: "0.90"
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 2Gi
    - name: shared-data
      emptyDir: {}
    - name: dockerconfig
      secret:
        secretName: registry-auth
    - name: git-auth
      secret:
        secretName: gitops-repo-auth
EOF
```

## 8. Troubleshooting

| Symptom | Check |
|---------|-------|
| Clone fails | `git-url`, PAC webhook token, network egress |
| buildah validate fails | Pipeline SA needs `privileged` for buildah tasks (or switch to Kaniko) |
| Registry push 401 | `registry-auth` secret and `dockerconfig` workspace |
| GitOps commit not pushed | `gitops-repo-auth`, branch protection, write access |
| security-check fails | Run `./scripts/security-check.sh` locally; remove `:latest` and committed secrets |
| validate-manifests fails | Run `./scripts/validate-manifests.sh` locally after `render-manifests.sh` |

## Related docs

- [`.tekton/README.md`](../.tekton/README.md) — pipeline file reference
- [`gitops/README.md`](../gitops/README.md) — Argo CD applications
- [`deploy/README.md`](../deploy/README.md) — Kustomize layout and digest pinning
