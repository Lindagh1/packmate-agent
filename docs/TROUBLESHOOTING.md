# Troubleshooting

## `oc: command not found`

Install the official OpenShift client into `~/.local/bin` from `mirror.openshift.com`.

## OpenShift login issues

Use the console “Copy login command”. Never commit the token.

## Port-forward lost connection

```text
error: lost connection to pod
```

Restart:

```bash
oc port-forward --address 0.0.0.0 -n my-first-model \
  pod/<ready-predictor-pod> 9000:8080
```

Use `--address 0.0.0.0` so Podman containers can reach the host.

## Model inaccessible from compose

Confirm:

```bash
curl -s http://127.0.0.1:9000/v1/models
podman exec <backend> python -c "import urllib.request;print(urllib.request.urlopen('http://host.containers.internal:9000/v1/models').status)"
```

## HTTP 503 credentials

Backend missing `BASE_URL`, `MODEL`, or `LITELLM_API_KEY`.

## Podman Compose DNS / 502 via Nginx

After recreating backend, restart frontend so Nginx re-resolves `packmate-backend`.

## Service port-forward maps to pod port 80

Prefer forwarding the pod container port 8080 directly.

## Argo CD OutOfSync

Usually image digest drift. Check GitOps commit from Tekton push pipeline.

## Tekton permissions

Ensure `registry-auth` and `gitops-repo-auth` Secrets exist in the pipeline namespace. No tokens in YAML.

## Rollout blocked / CRD missing

```bash
oc api-resources | grep -i rollout
```

If absent, install Argo Rollouts operator before applying prod overlay Rollout objects.

## Quality gate failed

```bash
.venv/bin/python -m evals.runner --mode deterministic --threshold 0.90
```

Inspect failing scenario evaluator messages; fixtures must stay schema-valid.

## Gen AI Playground shows no MCP servers

1. Confirm Routes for `weather-mcp` and `baggage-policy-mcp`.
2. Confirm admin ConfigMap `gen-ai-aa-mcp-servers` in `redhat-ods-applications` with `https://…/mcp` URLs.
3. Authorize tools in the Playground UI after registration.

## MCP calls fail from backend (`PACKMATE_TOOL_MODE=mcp`)

1. Check `PACKMATE_WEATHER_MCP_URL` / `PACKMATE_BAGGAGE_MCP_URL` end with `/mcp`.
2. `curl` in-cluster Service: `http://weather-mcp:8080/health`.
3. Review NetworkPolicy egress from backend to MCP pods.
4. Increase `PACKMATE_MCP_TIMEOUT_SECONDS` if cold starts are slow.

## EvalHub optional step skipped

Expected when no EvalHub CRD/instance exists. Deterministic gate must still pass. See `evaluations/README.md`.

## Workbench cannot reach model Service

Workbench must run in a project/network that can reach `my-first-model`. Prefer in-cluster URLs over laptop port-forward.

## Public Route chat times out around 60 seconds

Symptoms:

- `POST https://<frontend-route>/api/v1/chat` fails near **~60s** (504 / TLS EOF)
- Same request succeeds from inside the cluster (frontend pod → backend) in 30–90s
- Route already has `haproxy.router.openshift.io/timeout: 180s`
- Nginx `proxy_*_timeout` is already 180s

Root cause on RHDP / AWS Classic Load Balancer sandboxes:

1. The OpenShift router is behind an **AWS Classic ELB** whose default **idle timeout is ~60s**.
2. That idle timeout applies to the whole connection while waiting for the full response body.
3. Raising only the Route HAProxy annotation **does not** change the AWS ELB idle timeout (cluster-wide IngressController / LB setting — out of participant scope).

What Packmate does instead (compatible with the participant guide):

- Keep Route annotation `haproxy.router.openshift.io/timeout: 180s` and Nginx proxy timeouts at 180s.
- **Public UI uses `POST /api/v1/chat/stream` (SSE)** with heartbeats ≤10s so the AWS ELB idle timer never fires during long LLM/tool runs.
- Sync `POST /api/v1/chat` remains for tests, evals, and in-cluster scripts (can still hit ELB idle if called publicly on slow runs).
- Agent loop still caches tools, omits unused profile tool, and forces JSON after weather + baggage.

Verify streaming through the public Route:

```bash
curl -sS -N --max-time 180 \
  -H 'Content-Type: application/json' -H 'Accept: text/event-stream' \
  -X POST "https://$(oc -n packmate-lab get route packmate-frontend -o jsonpath='{.spec.host}')/api/v1/chat/stream" \
  -d '{"message":"Je pars a Rome pendant quatre jours avec un bagage cabine."}' | head -40
```

Expect `event: started` quickly, optional `progress` / `heartbeat`, then `completed` with PackingResponse JSON. Total duration may exceed 60s as long as heartbeats continue.

If heartbeats are missing, check Nginx `proxy_buffering off` for `/api/v1/chat/stream` and response headers `X-Accel-Buffering: no`.

## Public stream ends with `agent_error` (transport OK)

Symptoms:

- SSE shows `started` / `progress` / `heartbeat`, then `event: error` with `agent_error`
- No ELB EOF / 504; heartbeats keep the connection alive
- Same scenario may succeed intermittently

Typical causes on `llama-32-3b-instruct` (Packmate lab):

1. **Multi tool-calls in one assistant turn** — gateway returns 400 (`This model only supports single tool-calls at once`) on the next completion once multi-tool history is present. Fix: process **one** tool call per round and rewrite history accordingly.
2. **Truncated final JSON** — `finish_reason=length` at the completion budget. Fix: higher final `max_tokens`, truncation retry, recover `weather_summary` from tool context when omitted.
3. **Malformed JSON** — missing commas / prose wrappers. Fix: deterministic JSON repair in the parser, then Pydantic validation (never skip validation).

Do **not** disable baggage rules, MCP, or Pydantic validation, and do not return a hardcoded packing list.

Reproduce without logging raw model output:

```bash
oc -n packmate-lab exec deploy/packmate-backend -- python -c '
import asyncio, time
from app.agent.service import AgentService
async def main():
  r = await AgentService().chat("Weekend in Oslo in February, cabin bag only, expect snow.")
  print(r.destination, len(r.packing_items), len(r.baggage_warnings))
asyncio.run(main())
'
```

