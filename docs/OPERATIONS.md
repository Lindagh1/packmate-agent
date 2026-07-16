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
| `PACKMATE_TOOL_MODE` | `local` | `local` or `mcp` (OpenShift ConfigMap uses `mcp`) |
| `PACKMATE_WEATHER_MCP_URL` | `http://weather-mcp:8080/mcp` | Streamable HTTP |
| `PACKMATE_BAGGAGE_MCP_URL` | `http://baggage-policy-mcp:8080/mcp` | Streamable HTTP |
| `PACKMATE_MCP_TIMEOUT_SECONDS` | `10` | |
| `PACKMATE_MCP_MAX_RETRIES` | `2` | |

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
podman build -t packmate-weather-mcp:dev -f mcp-servers/weather/Containerfile mcp-servers/weather
podman build -t packmate-baggage-policy-mcp:dev -f mcp-servers/baggage-policy/Containerfile mcp-servers/baggage-policy
```

## MCP versioning

- MCP servers are Deployments pinned by digest in overlays (same GitOps flow as app images).
- They are **not** Argo Rollouts by default; change carefully and rely on deterministic + Playground regression checks.

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
