# Packmate v2 — final report (lab finalization)

Date: 2026-07-22
Branch: `packmate-v2`
Focus: OpenShift AI first-touch lab (~120 min) + visual Pipelines/GitOps intro.

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

## Platform classification (reference sandbox)

| Flag | Result |
|------|--------|
| OPENSHIFT_AI_AVAILABLE | Yes (`rhods-operator.3.4.2`) |
| PIPELINES_AVAILABLE | Yes (`openshift-pipelines-operator-rh.v1.22.4`) |
| GITOPS_AVAILABLE | **No** — `GITOPS_OPERATOR_REQUIRED` |
| ROLLOUTS_AVAILABLE | **No** — optional annex |
| EVALHUB_AVAILABLE | CRD only — `EVALHUB_OPTIONAL_NOT_CONFIGURED` |

## Custom model endpoint

Default: **ClickOps** (`CREATE_MODEL_CUSTOM_ENDPOINT=false`) with printed URL/Model ID.
Optional instructor CLI applies ConfigMap `gen-ai-aa-custom-model-endpoints` (same persistence as UI).
Physical model remains in `my-first-model`.

## Honest gaps

- GHCR images persist only after the GitHub Actions workflow is executed and packages made public
- Argo CD Module 10 needs OpenShift GitOps Operator
- EvalHub / Rollouts not part of the mandatory path

## Release validation (2026-07-22)

- Tag **lab-v1.0.0**; GHCR four packages public; digests in `docs/REPRODUCE_SANDBOX.md`.
- Repro namespace **packmate-repro** from GHCR + shared model; verify OK.
- PipelineRun **packmate-ci-validate-20260722-123626** Succeeded; QG 0.9559; backend digest `sha256:d04468d3…` not promoted to live Deployments.
- OpenShift GitOps **installed**; Argo Application `packmate-lab` → `packmate-repro`.
- `packmate-lab` workloads preserved; `my-first-model` untouched.
