# Demo script (15–30 minutes)

## Narrative

Show Packmate as a production-minded agentic lab: UI → structured agent → quality gate → GitOps → canary.

## Minute 0–5 — App

1. Open `http://localhost:8080`
2. Submit a Rome summer trip with cabin baggage
3. Point to daily weather and grouped packing list

Expected: HTTP 200 packing plan, Clothing/Toiletries sections, baggage disclaimer.

## Minute 5–10 — Agent internals

```bash
sed -n '1,80p' backend/app/agent/prompts.py
sed -n '1,60p' backend/app/agent/enrichment.py
```

Show privacy defaults and deterministic baggage enrichment.

## Minute 10–15 — Quality gate

```bash
cd backend
.venv/bin/python -m evals.runner --mode deterministic --threshold 0.90
.venv/bin/python -m evals.runner --mode deterministic --threshold 0.999
```

Expected: pass then fail.

## Minute 15–20 — Metrics

```bash
curl -s localhost:8000/metrics | grep packmate_ | head
curl -s localhost:8000/ready
```

## Minute 20–25 — Manifests

```bash
oc kustomize deploy/overlays/dev | head
./scripts/security-check.sh
```

## Minute 25–30 — Canary story

Even if Rollouts operator is absent, walk through `docs/CANARY_DEMO.md` and show Rollout YAML:

- 10% → analyze → pause → 50% → analyze → pause → 100%
- abort/rollback commands in `scripts/canary-demo.sh`
