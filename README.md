# Packmate v2

AI-powered travel packing assistant built for Red Hat Demo Platform labs.

## What it is

Packmate helps travelers generate structured packing plans from a natural-language trip description. It combines:

- a React + PatternFly lab UI
- a FastAPI agent backend
- weather, baggage-rule, and traveler-profile tools
- deterministic enrichment and privacy hardening
- Podman containers and OpenShift GitOps delivery

## Architecture

```mermaid
flowchart LR
  User --> Route[OpenShift Route]
  Route --> FE[Nginx Frontend]
  FE -->|/api| BE[FastAPI Backend]
  BE --> Weather[Open-Meteo]
  BE --> LLM[OpenShift AI Model]
  BE --> Metrics[/metrics]
```

## Local quick start

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn app.main:app --reload --port 8000
```

### Frontend

```bash
cd frontend
npm ci
npm run dev
```

### Containers

```bash
podman compose up --build -d
# UI: http://localhost:8080
# API: http://localhost:8000
```

LLM env vars (never commit `.env`):

```bash
export BASE_URL=http://host.containers.internal:9000/v1
export MODEL=llama-32-3b-instruct
export LITELLM_API_KEY=dummy
```

For OpenShift AI locally, port-forward the predictor:

```bash
oc port-forward --address 0.0.0.0 \
  -n my-first-model \
  svc/llama-32-3b-instruct-predictor 9000:80
```

Prefer pod port `9000:8080` if service port-forward maps incorrectly.

## Tests

```bash
cd backend && .venv/bin/pytest -v
cd frontend && npm run lint && npm run test && npm run build
```

## Evaluations

```bash
cd backend
.venv/bin/python -m evals.runner --mode deterministic --threshold 0.90
```

Live mode is manual only and never required by CI.

## OpenShift

Manifests live in `deploy/` (Kustomize).

```bash
oc kustomize deploy/overlays/dev
./scripts/validate-manifests.sh
./scripts/security-check.sh
```

Create namespace/secret yourself before real apply:

```bash
oc new-project packmate-dev
oc create secret generic packmate-llm --from-literal=LITELLM_API_KEY='...' -n packmate-dev
# then apply after review
```

## CI/CD and GitOps

- Tekton Pipelines as Code: `.tekton/`
- Argo CD apps: `gitops/`
- Canary Rollouts (prod backend): see `docs/CANARY_DEMO.md`

## Documentation

| Doc | Purpose |
|-----|---------|
| [ARCHITECTURE](docs/ARCHITECTURE.md) | System design |
| [PARTICIPANT_GUIDE](docs/PARTICIPANT_GUIDE.md) | Hands-on lab path |
| [INSTRUCTOR_GUIDE](docs/INSTRUCTOR_GUIDE.md) | Session setup |
| [DEMO_SCRIPT](docs/DEMO_SCRIPT.md) | 15–30 min demo |
| [TROUBLESHOOTING](docs/TROUBLESHOOTING.md) | Common failures |
| [OPERATIONS](docs/OPERATIONS.md) | Day-2 ops |
| [SECURITY](docs/SECURITY.md) | Hardening |
| [MIGRATION_FROM_V1](docs/MIGRATION_FROM_V1.md) | Streamlit → v2 |

## Safety

- No secrets in Git
- Medical notes are not sent to the model by default
- Logs/spans omit user message bodies and sensitive notes
