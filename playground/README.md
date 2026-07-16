# Gen AI Playground — Packmate lab steps

Manual participant guide for **OpenShift AI 3.4.x** Gen AI Playground with Packmate MCP tools and `llama-32-3b-instruct`.

> **Audit honesty (2026-07-16):** On the audited cluster, ConfigMap `gen-ai-aa-mcp-servers` in `redhat-ods-applications` was **not present**. MCP registration and Playground tool discovery were therefore **not verified end-to-end**. Steps below are manual; screenshots are placeholders for your lab workbook.

## Prerequisites

- OpenShift AI 3.4.x with Gen AI Playground enabled
- InferenceService **`llama-32-3b-instruct`** Ready (lab namespace e.g. `my-first-model`)
- Packmate **`weather-mcp`** and **`baggage-policy-mcp`** deployed with Routes (see `deploy/` manifests)
- Cluster admin (or instructor) to register MCP URLs — see [deploy/examples/mcp-registration/](../deploy/examples/mcp-registration/)

## 1. Find AI asset endpoints

1. Log in to the OpenShift AI dashboard.
2. Open **Applications → Gen AI Playground** (or **AI Hub → Playground**, depending on UI version).
3. Open **AI asset endpoints** / model catalog and locate **`llama-32-3b-instruct`**.

[Screenshot: AI asset endpoints]

Note the in-cluster predictor URL if you need it elsewhere (e.g. `http://llama-32-3b-instruct-predictor.my-first-model.svc.cluster.local:8080/v1`).

## 2. Register MCP servers (cluster admin)

Playground discovers MCP servers from ConfigMap **`gen-ai-aa-mcp-servers`** in namespace **`redhat-ods-applications`**.

1. Obtain Route hosts:

   ```bash
   oc get route weather-mcp baggage-policy-mcp -n packmate-lab
   ```

2. Edit the example ConfigMap: [deploy/examples/mcp-registration/gen-ai-aa-mcp-servers.yaml](../deploy/examples/mcp-registration/gen-ai-aa-mcp-servers.yaml) — set `https://<route-host>/mcp` for each server.
3. A cluster administrator applies the ConfigMap (**outside** normal participant scope in most labs).

Full registration notes: [deploy/examples/mcp-registration/README.md](../deploy/examples/mcp-registration/README.md).

## 3. Configure Playground

1. In Gen AI Playground, select model **`llama-32-3b-instruct`**.
2. Enable / authorize MCP tools when prompted (Weather and Baggage Policy servers).
3. Paste system instructions from [system-instructions.md](./system-instructions.md).
4. Confirm **traveler profile is not listed** as an MCP tool — profile details belong in the user prompt only.

[Screenshot: Playground with MCP tools]

## 4. Run test prompts

Use prompts from [test-prompts.json](./test-prompts.json). Compare tool calls against patterns in [expected-tool-calls.json](./expected-tool-calls.json).

Suggested checks:

| Prompt id | What to verify |
|-----------|----------------|
| `rome-weather` | `get_weather` for Rome |
| `power-bank-checked` | `check_baggage_rules` + demo disclaimer in reply |
| `reveal-reasoning` | Refusal to expose chain-of-thought |
| `weather-unavailable` | Graceful handling if weather MCP fails |

## 5. Export configuration

Use Playground **Export** (or equivalent) to save model + MCP + system instruction settings for lab submission.

[Screenshot: Export Playground configuration]

## Related assets

| File | Purpose |
|------|---------|
| [system-instructions.md](./system-instructions.md) | Packmate system prompt for Playground |
| [test-prompts.json](./test-prompts.json) | Scenario prompts |
| [expected-tool-calls.json](./expected-tool-calls.json) | Expected MCP tool patterns |

Deterministic quality gates live under [backend/evals/](../backend/evals/) and [evaluations/](../evaluations/) — Playground runs are manual Level 2 exploration, not CI blockers.
