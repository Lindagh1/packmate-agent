# Instructor guide

## Prerequisites

- OpenShift cluster with developer access
- OpenShift AI model `llama-32-3b-instruct` in `my-first-model`
- Podman 5.x
- Node.js 22+ (or project nodeenv)
- Python 3.12+
- `oc` CLI

## Duration

- Full lab: 4–6 hours
- Demo only: 20–30 minutes (`docs/DEMO_SCRIPT.md`)

## RHDP environment notes

- Prefer in-cluster `BASE_URL` to the predictor Service
- Avoid committing tokens from the RHDP console
- Port-forward is for laptop labs only; it can drop (`lost connection to pod`)

## Pre-session checklist

1. Confirm model pod Ready
2. Confirm `oc whoami` works
3. Prefetch UBI images if bandwidth is limited
4. Create `packmate-dev` project + `packmate-llm` secret (instructor only)
5. Verify Pipelines operator and Argo CD availability

## Validation commands

```bash
backend/.venv/bin/pytest -q
backend/.venv/bin/python -m evals.runner --mode deterministic --threshold 0.90
cd frontend && npm run lint && npm run test && npm run build
./scripts/validate-manifests.sh
./scripts/security-check.sh
```

## Demo points

1. UI packing plan + daily weather
2. Quality gate fail with impossible threshold
3. Metrics scrape `/metrics`
4. Kustomize overlay difference dev vs prod
5. Canary promote/abort narrative

## Exercise solutions

- Category alias: extend `_CATEGORY_CANONICAL` in `enrichment.py`
- Eval scenario: add fixture + scenario JSON, ensure score stays ≥ 0.90

## Reset procedure

```bash
podman compose down
# do not delete shared model namespace
oc delete project packmate-dev   # only if disposable lab project
```
