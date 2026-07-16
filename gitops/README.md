# Packmate v2 — Argo CD GitOps

Argo CD `Application` and `AppProject` manifests for deploying Packmate from this repository.

## Layout

| File | Kind | Purpose |
|------|------|---------|
| [`project.yaml`](project.yaml) | AppProject | Restrict sources and destinations to `packmate-dev` / `packmate-prod` |
| [`application-dev.yaml`](application-dev.yaml) | Application | Auto-sync from `deploy/overlays/dev` |
| [`application-prod.yaml`](application-prod.yaml) | Application | Manual sync from `deploy/overlays/prod` |
| [`rbac-dev.yaml`](rbac-dev.yaml) | Role + RoleBinding | Argo CD controller access in `packmate-dev` |
| [`rbac-prod.yaml`](rbac-prod.yaml) | Role + RoleBinding | Argo CD controller access in `packmate-prod` |

## Before you apply

1. Replace `https://github.com/example/packmate-agent.git` with your repository URL in all manifests.
2. Confirm the Argo CD namespace (`openshift-gitops` by default) and controller ServiceAccount names match your cluster.
3. Create target namespaces and the LLM secret **outside** GitOps:

```bash
oc new-project packmate-dev
oc create secret generic packmate-llm \
  --from-literal=LITELLM_API_KEY='<key>' \
  -n packmate-dev
```

Repeat for `packmate-prod` when promoting.

## Apply order

```bash
# 1. AppProject (cluster-scoped within Argo CD)
oc apply -f gitops/project.yaml

# 2. Namespace RBAC for the Argo CD controller
oc apply -f gitops/rbac-dev.yaml
oc apply -f gitops/rbac-prod.yaml

# 3. Applications
oc apply -f gitops/application-dev.yaml
oc apply -f gitops/application-prod.yaml
```

## Sync policy

| App | Overlay | Sync |
|-----|---------|------|
| `packmate-dev` | `deploy/overlays/dev` | **Automated** — prune + selfHeal |
| `packmate-prod` | `deploy/overlays/prod` | **Manual** — operator sync after review |

Dev receives digest updates from the Tekton push pipeline (`gitops-overlay=dev`). Prod updates require a deliberate promotion run and manual Argo CD sync.

## Security

- No secrets in this directory or in `deploy/` manifests — only secret **references** (`packmate-llm`).
- AppProject denies cluster-scoped resources and limits destinations to the two Packmate namespaces.
- RBAC grants namespace-scoped permissions only — **no cluster-admin**.

## Related

- CI pipelines: [`.tekton/`](../.tekton/)
- Setup: [`docs/TEKTON_SETUP.md`](../docs/TEKTON_SETUP.md)
- Manifests: [`deploy/`](../deploy/)
