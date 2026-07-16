# Demo script (20–30 minutes) — OpenShift AI story

## Narrative

Show Packmate as an OpenShift AI–native path: model assets → MCP tools → Playground prototype → FastAPI app → deterministic quality gate → (optional) GitOps/canary.

## Minute 0–5 — Dashboard and model

1. Open OpenShift AI dashboard → AI asset endpoints.  
   `[Screenshot: AI asset endpoints]`
2. Show `llama-32-3b-instruct` Ready.

## Minute 5–12 — MCP and Playground

1. Show weather-mcp / baggage-policy-mcp Routes or local MCP health.
2. Open Gen AI Playground; enable MCP tools.  
   `[Screenshot: Playground with MCP tools]`
3. Paste `playground/system-instructions.md`.
4. Run Rome weather + power-bank checked prompts from `playground/test-prompts.json`.

Expected: visible tool calls; baggage disclaimer; no chain-of-thought dump on reveal-reasoning.

## Minute 12–18 — Application

1. In Workbench or laptop compose: show FastAPI `PACKMATE_TOOL_MODE=mcp` ConfigMap keys.
2. Submit a trip in the React UI; point to daily weather + grouped packing list.

## Minute 18–22 — Quality gate

```bash
evaluations/scripts/run_deterministic_gate.sh
# or
cd backend && .venv/bin/python -m evals.runner --mode deterministic --threshold 0.90
```

Expected: PASS (~0.95). Optionally show EvalHub skip script if no instance.

## Minute 22–28 — Delivery story

1. Show `.tekton/push.yaml` builds four images.
2. Show `gitops/application-prod.yaml` and prod Rollout (honest if Operators absent).  
   `[Screenshot: Argo CD application]` / `[Screenshot: Argo Rollout]` when available.

## Closing line

Prototype in Playground with real MCP servers, industrialize with the same tools in FastAPI, gate with deterministic evals, promote with GitOps/canary when Operators exist.
