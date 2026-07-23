# Packmate v2 — final report (lab finalization)

Date: 2026-07-22 (original); **updated 2026-07-23 for the DEV→PROD extension (see "DEV→PROD update" below)**
Branch: `packmate-v2`
Focus (2026-07-22): OpenShift AI first-touch lab (~120 min) + visual Pipelines/GitOps intro.
Focus (2026-07-23): extended to a full DEV (`packmate-lab`) → PROD (`packmate-prod`) promotion/rollback path (~150 min, Modules A–F).

## Validated product core (do not regress)

| Area | Status |
|------|--------|
| Backend FastAPI + 125 tests | Validated earlier |
| Frontend React | Validated |
| Weather / Baggage MCP | Validated |
| SSE + heartbeats | Validated on public Route |
| Bounded LLM retry | Validated |
| PackingResponse validation + MCP cache + metrics | Validated |
| Quality gate deterministic | **0.9559** ≥ 0.90 |
| Workbench + Playground + system prompt | Validated manually |

## Lab automation added

- `Makefile` + `scripts/preflight-sandbox.sh` + full `bootstrap-sandbox.sh` + `verify-sandbox.sh`
- `config/sandbox.env.example` with image placeholders
- GHCR workflow `.github/workflows/publish-lab-images.yml` (images **not** published until workflow runs)
- Tekton lab Pipeline `.tekton/lab/packmate-ci.yaml`
- Argo CD manifests `argocd/*` (manual sync; Operator may be absent)
- Participant guide rewritten for 120 minutes
- Instructor guide + setup checklist + reproduce docs

## Platform classification (reference sandbox, 2026-07-22 run)

| Flag | Result |
|------|--------|
| OPENSHIFT_AI_AVAILABLE | Yes (`rhods-operator.3.4.2`) |
| PIPELINES_AVAILABLE | Yes (`openshift-pipelines-operator-rh.v1.22.4`) |
| GITOPS_AVAILABLE | Yes — installed mid-engagement (see `docs/INSTALL_GITOPS_PREREQUISITE.md`); now a **hard requirement** for Modules D–F, not optional |
| ROLLOUTS_AVAILABLE | **No** — optional canary annex only (`deploy/overlays/prod-canary-annex/`) |
| EVALHUB_AVAILABLE | CRD only — `EVALHUB_OPTIONAL_NOT_CONFIGURED` |

## Custom model endpoint (current default)

Default (current `config/sandbox.env.example`): **automated**, `CREATE_MODEL_CUSTOM_ENDPOINT=true` and `ENABLE_CUSTOM_ENDPOINTS=true`. Bootstrap applies ConfigMap `gen-ai-aa-custom-model-endpoints` + Secret directly (same persistence as the UI) in `packmate-lab` only; participants never Create endpoint manually. `packmate-prod` never gets a custom model endpoint. Physical model remains in `my-first-model`.

## Honest gaps

- GHCR images persist only after the GitHub Actions workflow is executed and packages made public
- Modules D–F (promotion, production, rollback) need the OpenShift GitOps Operator — no screenshot fallback for the promotion PR review, but Sync itself can be documented from screenshots if the Operator is briefly unavailable
- EvalHub / Rollouts not part of the mandatory path

## Release validation (2026-07-22, DEV path)

- Tag **lab-v1.0.0**; GHCR four packages public; digests in `docs/REPRODUCE_SANDBOX.md`.
- Repro namespace **packmate-repro** from GHCR + shared model; verify OK.
- PipelineRun **packmate-ci-validate-20260722-123626** Succeeded; QG 0.9559; backend digest `sha256:d04468d3…` not promoted to live Deployments.
- OpenShift GitOps **installed**; Argo Application `packmate-lab` → `packmate-repro`.
- `packmate-lab` workloads preserved; `my-first-model` untouched.

## DEV→PROD update (2026-07-23)

Added since the 2026-07-22 run above: namespace `packmate-prod` (runtime only, no DSP labels), Secret `packmate-prod-llm`, cross-namespace image-pull RBAC, Argo CD `AppProject/packmate` + `Application/packmate-prod` (manual Sync, prune/self-heal off), OpenShift group `packmate-lab-users` with an AppProject **promoter** role (Sync-only on `packmate-prod`), `scripts/promote-backend-image.sh --create-pr` and `scripts/rollback-prod-image.sh --create-pr` (Git pull request promotion/rollback, never a direct cluster edit), and `deploy/overlays/prod-canary-annex/` (the former in-overlay canary/Rollout objects, now an explicit optional annex instead of the default PROD path).

Re-run in this docs pass (offline/local, no live cluster available): `make validate-prod` **passed**; backend pytest **125 passed**; deterministic quality gate **0.9559 PASS**; `scripts/security-check.sh` **all checks passed**. Frontend/MCP suites carried forward from the 2026-07-22 numbers below (not re-run here). A full live-cluster DEV→PROD→rollback cycle (Modules D–F) has **not** been re-executed since this automation was added — see `docs/implementation/LAB_ACCEPTANCE_REPORT.md` § 12 for the exact scope of what remains to verify on a live cluster before the next class.
