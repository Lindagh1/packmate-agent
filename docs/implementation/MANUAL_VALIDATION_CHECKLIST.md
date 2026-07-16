# Manual validation checklist — Packmate on OpenShift AI

Status: **MANUAL_REQUIRED** for Workbench UI and Playground session.  
Automated cluster deploy + public Route performance are documented in
`CLUSTER_DEPLOYMENT_REPORT.md`.

Use this checklist with `docs/PARTICIPANT_GUIDE.md`, `WORKBENCH_MANUAL.md`, and
`PLAYGROUND_MANUAL.md`. Do not commit secrets. Do not paste medical notes into
logs or screenshots.

---

## A. Create Data Science Project `packmate-lab`

| Field | Value |
|-------|--------|
| Action UI | OpenShift AI → **Data Science Projects** → **Create project** |
| Value | Name: `packmate-lab` |
| Expected | Project appears; namespace labeled as DSP |
| Validation | `oc get project packmate-lab` and `oc get ns packmate-lab --show-labels` show `opendatahub.io/dashboard=true` |
| Common issue | Project already exists from instructor deploy — reuse it |
| Screenshot | `[Screenshot required: Data Science Project packmate-lab created]` |

---

## B. Create Workbench code-server

| Field | Value |
|-------|--------|
| Action UI | Project `packmate-lab` → **Workbenches** → **Create workbench** |
| Value | Name: `packmate-code-server`; Image: **Code Server \| Data Science \| CPU \| Python 3.12** (`2025.2` / `3.4`); CPU req `500m` limit `2`; Memory req `2Gi` limit `4Gi`; Storage `20Gi`; no Git/LLM secrets |
| Expected | Workbench status **Running** |
| Validation | Open Workbench; terminal available |
| Common issue | Image pull / quota — ask instructor; do not invent Notebook CR YAML |
| Screenshot | `[Screenshot required: Workbench packmate-code-server Running]` |

---

## C. Clone repository and select `packmate-v2`

| Field | Value |
|-------|--------|
| Action UI | Workbench terminal |
| Value | `git clone https://github.com/Lindagh1/packmate-agent.git && cd packmate-agent && git switch packmate-v2` |
| Expected | Branch `packmate-v2`; dirs `backend`, `frontend`, `mcp-servers`, `playground` |
| Validation | `git rev-parse --abbrev-ref HEAD` → `packmate-v2` |
| Common issue | Auth required for private fork — use HTTPS PAT in Workbench, never commit token |
| Screenshot | `[Screenshot required: git branch packmate-v2 in Workbench terminal]` |

---

## D. Run tests in the Workbench

| Field | Value |
|-------|--------|
| Action UI | Workbench terminal |
| Value | Backend: `cd backend && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements-dev.txt && pytest -q` ; MCP: pytest in `mcp-servers/weather` and `mcp-servers/baggage-policy` ; Frontend if Node available: `npm ci && npm run lint && npm run test && npm run build` |
| Expected | Backend ~96 passed; MCP suites green; frontend lint/test/build OK when Node present |
| Validation | Exit code 0 for each suite run |
| Common issue | Missing system packages in image — use instructor-approved Workbench image |
| Screenshot | `[Screenshot required: pytest summary green in Workbench]` |

---

## E. Find model in AI asset endpoints

| Field | Value |
|-------|--------|
| Action UI | OpenShift AI → **AI asset endpoints** (or Gen AI catalog) |
| Value | Locate `llama-32-3b-instruct` in `my-first-model` |
| Expected | Model Ready; in-cluster URL uses predictor Service `:8080/v1` |
| Validation | Endpoint visible Ready (read-only `oc get inferenceservice -n my-first-model` if allowed) |
| Common issue | Predictor not Ready — wait / instructor capacity check |
| Screenshot | `[Screenshot required: AI asset endpoints showing llama-32-3b-instruct Ready]` |

---

## F. Verify both MCP servers

| Field | Value |
|-------|--------|
| Action UI | OpenShift console or Workbench terminal (read-only) |
| Value | `oc get pods,svc,route -n packmate-lab` ; health via Services / Routes `/health` |
| Expected | `weather-mcp` and `baggage-policy-mcp` Running; Routes HTTPS with `/mcp` |
| Validation | Pods Ready; ConfigMap keys `Packmate-Weather-MCP` and `Packmate-Baggage-Policy-MCP` in `gen-ai-aa-mcp-servers` (instructor) |
| Common issue | Playground empty if ConfigMap missing — see instructor / `deploy/examples/mcp-registration/` |
| Screenshot | `[Screenshot required: MCP pods Ready and Routes listed]` |

---

## G. Open Gen AI Playground

| Field | Value |
|-------|--------|
| Action UI | OpenShift AI → **Gen AI Playground** (or **AI Hub → Playground**) |
| Value | Prefer project context with access to registered MCP |
| Expected | Playground UI loads |
| Validation | Model picker and MCP / tools panel visible |
| Common issue | Feature flag / RBAC — ask instructor |
| Screenshot | `[Screenshot required: Gen AI Playground home]` |

---

## H. Select `llama-32-3b-instruct`

| Field | Value |
|-------|--------|
| Action UI | Playground model selector |
| Value | `llama-32-3b-instruct` |
| Expected | Model selected for the session |
| Validation | Model name shown in session header |
| Common issue | Model not listed — check AI asset endpoints readiness |
| Screenshot | `[Screenshot required: Playground model llama-32-3b-instruct selected]` |

---

## I. Enable weather MCP and baggage-policy MCP

| Field | Value |
|-------|--------|
| Action UI | Playground tools / MCP authorize |
| Value | Enable **Packmate Weather MCP** and **Packmate Baggage Policy MCP** |
| Expected | Both servers authorized; traveler profile is **not** an MCP tool |
| Validation | Tool list shows weather + baggage tools only from MCP |
| Common issue | Authorize fails — Route TLS or ConfigMap URL must end with `/mcp` |
| Screenshot | `[Screenshot required: Playground with both MCP servers enabled]` |

---

## J. Use `playground/system-instructions.md`

| Field | Value |
|-------|--------|
| Action UI | Playground system instructions field |
| Value | Paste full content of `playground/system-instructions.md` |
| Expected | Instructions saved for the session |
| Validation | Instructions visible / applied before prompts |
| Common issue | Truncation — paste entire file |
| Screenshot | `[Screenshot required: system instructions pasted in Playground]` |

---

## K. Run test prompts

| Field | Value |
|-------|--------|
| Action UI | Playground chat |
| Value | Prompts from `playground/test-prompts.json` (at least Rome, power-bank, liquids, reveal-reasoning) |
| Expected | Useful packing / policy answers with demo disclaimer when citing baggage |
| Validation | ≥5 prompts exercised; no chain-of-thought dump on reveal-reasoning |
| Common issue | Small model skips tools — retry / lower temperature if available |
| Screenshot | `[Screenshot required: Playground reply for Rome weather prompt]` |

---

## L. Observe tool calls

| Field | Value |
|-------|--------|
| Action UI | Playground tool-call / trace panel |
| Value | Compare to `playground/expected-tool-calls.json` |
| Expected | `get_weather` for destinations; `check_baggage_rules` / general rules for baggage items |
| Validation | Tool names match expected patterns; no sensitive notes sent to baggage MCP |
| Common issue | No tool calls → MCP not authorized or instructions weak |
| Screenshot | `[Screenshot required: Playground tool calls for weather and baggage]` |

---

## M. Export Playground configuration

| Field | Value |
|-------|--------|
| Action UI | Playground **Export** (or equivalent) |
| Value | Save model + MCP + system instructions locally (non-sensitive folder) |
| Expected | Export file without secrets |
| Validation | File opens; no API keys / tokens inside |
| Common issue | Export includes credentials — strip before sharing |
| Screenshot | `[Screenshot required: Playground export dialog]` |

---

## N. Verify Packmate Route

| Field | Value |
|-------|--------|
| Action UI | Browser or Workbench curl |
| Value | Frontend Route host from `oc get route packmate-frontend -n packmate-lab` ; GET `/` and **SSE** `POST /api/v1/chat/stream` |
| Expected | GET 200; stream emits `started` quickly, optional `progress`/`heartbeat`, then `completed` PackingResponse (total time may exceed 60s) |
| Validation | Destination + weather + packing items; baggage warnings/disclaimer when cabin/liquids/battery apply; no think tags in stream |
| Common issue | Missing heartbeats → check Nginx stream location buffering; sync `/api/v1/chat` can still idle-out on ELB |
| Screenshot | `[Screenshot required: SSE started/completed via public Route]` |

---

## Sign-off

| Area | Status |
|------|--------|
| Workbench creation | `MANUAL_REQUIRED` |
| Playground session | `MANUAL_REQUIRED` |
| MCP ConfigMap registration | Applied on this cluster (instructor/admin) — still verify in UI |
| Public Route automated performance | See `CLUSTER_DEPLOYMENT_REPORT.md` |
