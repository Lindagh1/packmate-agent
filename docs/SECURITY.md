# Security guidelines (Packmate v2)

Security practices for manifests, secrets, and cluster operations. Complement with `./scripts/security-check.sh` in CI or before merge.

## Automated checks

```bash
./scripts/security-check.sh
```

The script flags (non-exhaustive):

| Check | What it detects |
|-------|-----------------|
| `:latest` tags | Mutable image references under `deploy/` |
| `privileged: true` | Privileged containers |
| `allowPrivilegeEscalation: true` | Escalation enabled on containers |
| Missing `runAsNonRoot` | Deployments/Rollouts/Jobs without non-root enforcement |
| Secrets in git | `Secret` kinds or `stringData`/`data` blocks in tracked YAML |
| `cluster-admin` | Cluster-admin bindings in manifests |
| Hardcoded keys | Common API key patterns (`sk-…`, `AKIA…`, inline `LITELLM_API_KEY=…`) |

## Pod and container hardening

Base manifests already set:

- Pod `securityContext.runAsNonRoot` and `seccompProfile: RuntimeDefault`
- Container `allowPrivilegeEscalation: false`, drop all capabilities, `readOnlyRootFilesystem: true`
- Writable `/tmp` via `emptyDir` where required
- `automountServiceAccountToken: false` on service accounts

Prod canary analysis jobs use the same constraints (`curlimages/curl` smoke tests).

## Secrets

- **Never** commit Secrets, `stringData`, or credential values to git.
- LLM credentials: create `packmate-llm` out of band with key `LITELLM_API_KEY`.
- OAuth proxy cookie/client secrets: create `packmate-oauth-proxy` when enabling the component (see `deploy/components/oauth-proxy/README.md`).

## Network exposure

- Public OpenShift `Route` targets **frontend only**.
- Backend is ClusterIP; frontend Nginx proxies `/api/` internally.
- NetworkPolicies restrict ingress/egress per workload (see `deploy/base/*/networkpolicy.yaml`).

## Optional OAuth gate

The Kustomize component at `deploy/components/oauth-proxy/` adds OpenShift oauth-proxy in front of the UI. It is **disabled by default** in both dev and prod overlays. Uncomment `components:` in the overlay `kustomization.yaml` to enable.

## RBAC

- Workloads use dedicated ServiceAccounts (`packmate-backend`, `packmate-frontend`).
- No `cluster-admin` bindings are defined in this repo.
- Grant additional RBAC only when a workload needs Kubernetes API access.

## Images

- Overlays pin tags (`sha-dev`, `sha-prod`); production should prefer **digest** pinning.
- Do not use `:latest` in any environment.

## Resource limits (dev example)

An optional `LimitRange` example lives at `deploy/overlays/dev/limitrange.yaml`. Add it to `overlays/dev/kustomization.yaml` if you want namespace default requests/limits:

```yaml
resources:
  - ../../base
  - limitrange.yaml
```

## Before production apply

1. Run `./scripts/security-check.sh` and `./scripts/validate-manifests.sh`.
2. Confirm secrets exist in the target namespace.
3. Review NetworkPolicies for your ingress controller and LLM namespace.
4. For prod canary, ensure Argo Rollouts controller is installed and analysis can reach the canary Service.

## Reporting issues

Treat suspected credential leaks as incidents: rotate keys, remove material from git history if committed, and re-run the security script after fixes.
