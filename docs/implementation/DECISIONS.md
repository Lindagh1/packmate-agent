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
