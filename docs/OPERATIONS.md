# Operations

## Health endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Liveness |
| `GET /ready` | Readiness (no LLM dependency) |
| `GET /metrics` | Prometheus metrics |

## Environment variables

| Variable | Default | Notes |
|----------|---------|-------|
| `BASE_URL` | empty | OpenAI-compatible base URL |
| `MODEL` | empty | Model id |
| `LITELLM_API_KEY` | from Secret | Never in Git |
| `OTEL_SERVICE_NAME` | `packmate-backend` | |
| `OTEL_TRACES_EXPORTER` | `none` | |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | empty | Optional |
| `PACKMATE_VERSION` | `dev` | |

## Local compose

```bash
podman compose up --build -d
podman compose ps
podman compose logs --no-color
podman compose down
```

## Image builds

```bash
podman build -t packmate-backend:dev -f backend/Containerfile backend
podman build -t packmate-frontend:dev -f frontend/Containerfile frontend
```

## GitOps expectations

- Dev auto-sync
- Prod manual sync
- Prod images by digest after Tekton push pipeline

## Incident checklist

1. `/ready` and `/health`
2. Predictor Service endpoints
3. Secret `packmate-llm` present
4. Recent Argo sync / Rollout status
5. Quality gate on last commit
