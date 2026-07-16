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

