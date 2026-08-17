# Manual validation checklist — Packmate on OpenShift AI (DEV → PROD)

Status (2026-08-13): the complete technical path was live-validated. Manual UI
capture remains required only for the nine authenticated console states listed
in `docs/SCREENSHOT_REUSE_AUDIT.md`; Playground UI interaction itself remains
PARTIAL. Cluster, protocol, GitHub PR, application, and GitOps results are in
`LAB_ACCEPTANCE_REPORT.md`.

Sections A–N below cover **DEV** (`packmate-lab`, current Modules 2–7 of
`docs/PARTICIPANT_GUIDE.md`). Section O covers **PROD** (`packmate-prod`,
the earlier Pipeline/Promotion/Production split) — added 2026-07-23; see the
honest-status note in that section before treating it as validated.

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
| Value | Name: `packmate-workbench`; Image: **Code Server \| Data Science \| CPU \| Python 3.12** (`3.4`); CPU req `500m` limit `2`; Memory req `2Gi` limit `4Gi`; Storage `20Gi`; no Git/LLM secrets |
| Expected | Workbench status **Running** |
| Validation | Open Workbench; terminal available |
| Common issue | Image pull / quota — ask instructor; do not invent Notebook CR YAML |
| Screenshot | `[Screenshot required: packmate-workbench Running and ready to open]` |

---

## C. Clone repository and select `packmate-v2`

| Field | Value |
|-------|--------|
| Action UI | Workbench terminal |
| Value | Fork first: `git clone https://github.com/YOUR_GITHUB_USERNAME/packmate-agent.git && cd packmate-agent && git switch packmate-v2 && git remote add upstream https://github.com/Lindagh1/packmate-agent.git` |
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
| Expected | Backend, both MCP suites, frontend lint/tests/build, and AI gate exit 0 (`make test`) |
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

---

## O. Production path (DEV → PROD, added 2026-07-23)

| Field | Value |
|-------|-------|
| Action UI | OpenShift console → Pipelines (Start `packmate-ci`, 2Gi VolumeClaimTemplate) → Workbench terminal (`promote-backend-image.sh --create-pr`) → GitHub (review/merge PR) → Argo CD UI (Sync `packmate-prod`) → browser (PROD Route) |
| Value | Candidate digest from a Succeeded PipelineRun with AI quality gate PASS ≥0.90; PR touching only `deploy/overlays/prod/kustomization.yaml`; Argo CD Application `packmate-prod` Synced/Healthy after merge |
| Expected | `packmate-prod` serves the promoted backend on its own Route with no Workbench/Pipeline/Playground/custom endpoint in that namespace |
| Validation | `make verify-prod` passes; PR diff limited to the backend image entry; Argo CD shows Prune/self-heal disabled |
| Common issue | Argo CD `promoter` role not yet effective — participant must log out/in to Argo CD after being added to `packmate-lab-users` (see `docs/TROUBLESHOOTING.md`) |
| Participant evidence | PipelineRun name; seven succeeded tasks; 16 scenarios; PASS; score; threshold 0.90; full external GHCR digest; promotion pull request; Argo CD state transition; successful PROD result |

**Live status (2026-08-13):** PipelineRun `packmate-ci-whbrq`, participant-fork
PR #2, manual Argo CD Sync, exact-digest `make verify-prod`, and the PROD Rome
Route scenario all passed. Optional current authenticated Tekton/Argo CD UI
captures remain a maintainer wishlist and are not participant-guide blockers.

---

## Lab automation (updated 2026-07-23)

| Check | Status |
|-------|--------|
| `make preflight` / `bootstrap` / `verify` | Use in Module 4; bootstrap also prepares (not deploys) `packmate-prod` |
| Custom model endpoint | Automated by default (`CREATE_MODEL_CUSTOM_ENDPOINT=true`), DEV only — participants never Create endpoint |
| Pipeline `packmate-ci` | Start from UI with a 2Gi VolumeClaimTemplate; do not auto-promote backend |
| `packmate-prod` prep | Automated from bootstrap (`CREATE_PROD_NAMESPACE`/`CREATE_ARGOCD_APPLICATION`/`CREATE_ARGOCD_RBAC`, all default `true`) — namespace/Secret/RBAC/Argo objects only, no workload apply |
| Promotion | `make promote PIPELINERUN=packmate-ci-example` after replacing the example with the actual run name — Git pull request only, never a direct cluster edit |
| Argo CD | Required for Modules 4, 8, and 9 — else `GITOPS_OPERATOR_REQUIRED` |
| Screenshots | Zero participant-visible empty screenshot boxes; see `docs/SCREENSHOT_REUSE_AUDIT.md` for retained and rejected evidence |

## Sign-off

| Area | Status |
|------|--------|
| Workbench creation | Resulting Notebook/PVC/pod/code-server state validated; no screenshot is required in the participant guide |
| Playground session | `MANUAL_REQUIRED` |
| MCP ConfigMap registration | Applied on this cluster (instructor/admin) — still verify in UI |
| Public DEV Route automated performance | See `CLUSTER_DEPLOYMENT_REPORT.md` |
| PipelineRun validation | **PASS** — `packmate-ci-whbrq`; seven tasks, 16 scenarios, score 0.9559, threshold 0.90, and PASS recorded as text evidence |
| Argo CD DEV | **PASS** — Synced/Healthy and fork-owned |
| Promotion PR (Module 8) | **PASS** — participant-fork PR #2, exactly one PROD overlay file |
| PROD Sync + Route (Module 9) | **PASS** — manual Sync, exact digest, Route/SSE/Rome scenario |
