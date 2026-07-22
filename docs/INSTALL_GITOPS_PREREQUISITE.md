# Install OpenShift GitOps (prerequisite — instructor only)

`GITOPS_OPERATOR_REQUIRED`

This Packmate lab treats **Argo CD as a visual introduction**. Participants never
install Operators and never use the Argo CD admin password.

## When you need this

If `make preflight` reports that the Argo CD Application CRD is absent, Module 10
(Argo CD Sync) cannot run live. Manifests under `argocd/` still validate with
`oc apply --dry-run=client`.

## Instructor install (outside the 120-minute participant path)

1. Install the **OpenShift GitOps** Operator from OperatorHub (cluster admin).
2. Wait until the `openshift-gitops` namespace and default Argo CD instance are Ready.
3. Confirm:

```bash
oc get crd applications.argoproj.io
oc get pods -n openshift-gitops
```

4. Re-run:

```bash
CREATE_ARGOCD_APPLICATION=true make bootstrap
# or
oc apply -f argocd/   # after substituting repo URL / revision / namespace
```

5. Participants open Argo CD via the OpenShift console link (SSO) — no admin login.

## What Packmate applies

| Resource | Purpose |
|----------|---------|
| `argocd/appproject-packmate.yaml` | AppProject limited to `packmate-lab` |
| `argocd/application-packmate-lab.yaml` | Manual sync Application (no prune, no self-heal) |

## If GitOps stays unavailable

Document the module as a walkthrough using screenshots from a prepared cluster,
and continue the lab with Modules 1–9 (OpenShift AI + Pipelines).

## Sandbox validation note (2026-07-22)

On the OpenTLC sandbox used for release validation, Red Hat OpenShift GitOps was
installed automatically after prechecks (admin user, ephemeral `*.sandbox*.opentlc.com`
API, PackageManifest `openshift-gitops-operator`, no prior Argo CRDs).

- Subscription namespace: `openshift-gitops-operator`
- Channel: PackageManifest `defaultChannel` = `latest`
- CSV: `openshift-gitops-operator.v1.21.1` **Succeeded**
- Instance namespace: `openshift-gitops`

A conflicting Manual InstallPlan in `openshift-operators` that bundled Service Mesh /
Pipelines upgrades was **not** approved. GitOps was installed via a dedicated
Operator namespace instead.
