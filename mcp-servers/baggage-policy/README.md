# Packmate baggage-policy MCP server

Streamable HTTP MCP server exposing deterministic demonstration baggage tools.

## Tools

| Tool | Parameters | Notes |
|------|------------|-------|
| `check_baggage_rules` | `baggage_type`, optional `item`, `category` | Warnings + disclaimer |
| `get_general_baggage_rules` | `baggage_type` | General limits + disclaimer |

No external network calls. Rules are versioned under `data/baggage_rules.json`.

**Privacy:** Do not send medical notes or sensitive traveler profile fields to this server. Traveler profile stays inside the Packmate application.

## Transport

Primary: **Streamable HTTP** at `/mcp`.

Health: `GET /health`, `GET /ready`.

## Local run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
export PYTHONPATH=src
uvicorn baggage_policy_mcp.app:app --host 0.0.0.0 --port 8081
```

## Tests

```bash
pytest -v
```

## Container

```bash
podman build -t localhost/packmate-baggage-policy-mcp:dev -f Containerfile .
```
