# Packmate weather MCP server

Streamable HTTP MCP server exposing `get_weather` for OpenShift AI Gen AI Playground and the Packmate backend (`PACKMATE_TOOL_MODE=mcp`).

## Tools

| Tool | Parameters | Notes |
|------|------------|-------|
| `get_weather` | `city` (string), `days` (1–14) | Structured forecast or `{error, error_code}` |

No credentials required. Uses the public Open-Meteo API.

## Transport

Primary: **Streamable HTTP** at `/mcp` (OpenShift AI 3.4 Playground ConfigMap URL target).

Health: `GET /health`, `GET /ready`.

## Local run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
export PYTHONPATH=src
uvicorn weather_mcp.app:app --host 0.0.0.0 --port 8080
```

## Tests

```bash
pip install -r requirements-dev.txt
pytest -v
```

## Container

```bash
podman build -t localhost/packmate-weather-mcp:dev -f Containerfile .
```

## OpenShift

Manifests live under `deploy/base/mcp-weather/`. Do not apply from this README during the lab unless instructed; prefer GitOps / dry-run validation.
