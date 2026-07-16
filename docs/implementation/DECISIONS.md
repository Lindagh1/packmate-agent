# Technical decisions

## Phase 5 — Evaluations

- Deterministic fixtures are the CI source of truth; live mode is opt-in only.
- Weighted scoring favors structure, baggage safety, and privacy.
- Invalid-date scenarios assert schema rejection rather than forcing a valid PackingResponse.
- Evidence payloads redact medical/message/token-like keys.
- Evaluation reports under `backend/evals/reports/` are gitignored except `.gitkeep`.

## Phase 6 — Observability

- Prometheus metrics always enabled via `/metrics`.
- OpenTelemetry tracing is optional and disabled by default (`OTEL_TRACES_EXPORTER=none`).
- Spans and metrics never include user messages, medical notes, or LLM payloads.
- `/ready` does not depend on external LLM availability.

## Phase 7 — OpenShift manifests

- Kustomize overlays for packmate-dev and packmate-prod.
- LLM credentials via Secret reference packmate-llm/LITELLM_API_KEY only.
- Images use PLACEHOLDER tags (never latest); digests expected in prod GitOps updates.
- Public Route targets frontend only; backend remains ClusterIP.

## Phase 10 — Argo Rollouts (prod backend)

- Prod replaces `Deployment/packmate-backend` with a canary `Rollout`; dev keeps a plain Deployment.
- Stable Service remains `packmate-backend` (frontend Nginx upstream unchanged); canary Service is `packmate-backend-canary`.
- Canary steps: 10% → smoke analysis → pause → 50% → smoke analysis → pause → 100%.
- Optional `AnalysisTemplate/packmate-backend-prometheus` is shipped but not wired into default steps.
- `scripts/canary-demo.sh` wraps promote/pause/resume/abort/retry/rollback for demos — does not apply manifests.

## Phase 11 — Security

- `scripts/security-check.sh` runs offline checks (tags, privileges, non-root, secrets-in-git, cluster-admin, key patterns).
- OAuth proxy component stays optional and disabled by default in overlays.
- Optional dev `LimitRange` example documents namespace default requests/limits; not enabled unless added to dev kustomization.
