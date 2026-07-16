# Technical decisions

## Phase 5 — Evaluations

- Deterministic fixtures are the CI source of truth; live mode is opt-in only.
- Weighted scoring favors structure, baggage safety, and privacy.
- Invalid-date scenarios assert schema rejection rather than forcing a valid PackingResponse.
- Evidence payloads redact medical/message/token-like keys.
- Evaluation reports under `backend/evals/reports/` are gitignored except `.gitkeep`.
