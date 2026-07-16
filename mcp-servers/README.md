# Packmate MCP servers

Real Model Context Protocol servers used by OpenShift AI Gen AI Playground and by the Packmate FastAPI backend in `PACKMATE_TOOL_MODE=mcp`.

| Server | Directory | Tools |
|--------|-----------|-------|
| weather-mcp | `weather/` | `get_weather` |
| baggage-policy-mcp | `baggage-policy/` | `check_baggage_rules`, `get_general_baggage_rules` |

Traveler profile is **not** an MCP server. Sensitive notes remain in-application only.

## Transport decision

OpenShift AI Self-Managed **3.4.2** registers MCP servers via the platform ConfigMap `gen-ai-aa-mcp-servers` (URL + description). Packmate implements **Streamable HTTP** at path `/mcp` as the primary transport. See `docs/implementation/DECISIONS.md`.

## Deploy

Kustomize resources: `deploy/base/mcp-weather/` and `deploy/base/mcp-baggage/`.  
Playground registration example (not applied by default): `deploy/examples/mcp-registration/`.
