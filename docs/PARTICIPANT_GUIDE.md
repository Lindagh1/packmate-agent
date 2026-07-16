# Participant guide

Estimated time: half-day lab.

## 1. Understand the application

Read `README.md` and `docs/ARCHITECTURE.md`. Open the UI and identify:

- trip form
- packing plan report
- daily weather table
- baggage guidance callouts

## 2. Run Packmate locally

```bash
cd backend && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --port 8000
```

In another terminal:

```bash
cd frontend && npm ci && npm run dev
```

Or:

```bash
podman compose up --build -d
```

## 3. Inspect agentic tools

Explore:

- `backend/app/agent/tools.py`
- `backend/app/tools/weather.py`
- `backend/app/tools/baggage.py`
- `backend/app/agent/enrichment.py`

## 4. Run evaluations

```bash
cd backend
.venv/bin/python -m evals.runner --mode deterministic --threshold 0.90
```

## 5. Modify a feature

Suggested exercise: add a packing category alias in `enrichment.py`, add a fixture assertion, re-run evals.

## 6. Trigger the pipeline

Open a PR against `packmate-v2` / `main` once Pipelines as Code is wired. Observe `.tekton/pull-request.yaml` tasks.

## 7. Observe Argo CD

Inspect `gitops/application-dev.yaml`. After images are updated by digest, confirm Synced/Healthy in Argo CD UI.

## 8. Launch a canary

Follow `docs/CANARY_DEMO.md` in prod overlay (requires Argo Rollouts operator).

## 9. Observe promotion or rollback

Use `scripts/canary-demo.sh` helpers to promote or abort.
