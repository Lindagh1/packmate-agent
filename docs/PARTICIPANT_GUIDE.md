# Packmate participant guide — OpenShift AI native path

This lab is designed to run primarily inside an **OpenShift AI Workbench**, not on a laptop IDE. Cursor is optional. Estimated total time: **4–6 hours**.

Repository: `https://github.com/Lindagh1/packmate-agent.git`  
Branch: `packmate-v2`

---

## Module 1 — Discover Packmate and OpenShift AI

**Objective:** Understand the Packmate architecture and why the lab uses OpenShift AI.  
**Duration:** 20 minutes  
**Prerequisites:** Access to the OpenShift AI dashboard.

### Steps

1. Open the OpenShift AI dashboard from your cluster console.
2. Read `docs/ARCHITECTURE.md` (clone later in Module 2 if you do not have the repo yet).
3. Identify the components:

| Layer | Components |
|-------|------------|
| UX | React + PatternFly frontend |
| App | FastAPI agent (`PACKMATE_TOOL_MODE=local` or `mcp`) |
| Tools | weather-mcp, baggage-policy-mcp (Streamable HTTP); traveler profile stays in-app |
| Model | `llama-32-3b-instruct` (KServe / AI asset endpoints) |
| Delivery | Tekton → GitOps → Argo CD → Argo Rollouts (canary backend) |

### Expected result

You can explain the packing use case and name the MCP vs in-app tools.

### Validation

- [ ] You can list weather-mcp, baggage-policy-mcp, and traveler_profile (local only).
- [ ] You know production backend canary uses Argo Rollouts when the Operator is installed.

### Troubleshooting

- Dashboard missing → ask the instructor; RHODS/OpenShift AI operator may be down.
- Architecture unclear → start from the diagram in `docs/ARCHITECTURE.md`.

### Business / technical value

Participants see a full path from Gen AI prototyping to hardened delivery, not a chatbot demo alone.

---

## Module 2 — Create the OpenShift AI project

**Objective:** Create Data Science Project `packmate-lab` and a code-server Workbench, then clone the repo.  
**Duration:** 30 minutes  
**Prerequisites:** OpenShift AI Workbenches component enabled (verified Managed on OAI 3.4.2).

### Steps

1. In OpenShift AI → **Data Science Projects** → Create project named `packmate-lab`.  
   `[Screenshot: Create Data Science Project]`
2. Create a **Workbench**:
   - Name: `packmate-code`
   - Image: code-server / VS Code compatible Python + web image (instructor may specify the catalog name)
   - CPU: 2, Memory: 4–8 Gi, Storage: 20–40 Gi  
   `[Screenshot: Workbench configuration]`
3. Open the Workbench terminal.
4. Clone and switch branch:

```bash
git clone https://github.com/Lindagh1/packmate-agent.git
cd packmate-agent
git switch packmate-v2
```

5. Optional declarative example (not applied by default): `deploy/workbench/`.

### Expected result

Repo checked out on `packmate-v2` inside the Workbench.

### Validation

```bash
git rev-parse --abbrev-ref HEAD   # packmate-v2
ls backend frontend mcp-servers playground
```

### Troubleshooting

- Clone denied → use HTTPS + personal access token in Workbench credentials, never commit the token.
- Image pull errors → ask instructor for the approved Workbench image.

### Business / technical value

The Workbench is the shared lab environment: reproducible, cluster-networked to the model and MCP Services.

---

## Module 3 — Explore the model

**Objective:** Locate `llama-32-3b-instruct` in AI asset endpoints and run a simple test.  
**Duration:** 20 minutes  
**Prerequisites:** Model deployed in `my-first-model` (instructor-prepared).

### Steps

1. Open **Gen AI studio → AI asset endpoints** and select project **Packmate Lab**.  
   `[Screenshot: AI asset endpoints]`
2. On the **Models** tab, confirm **Packmate Llama 3.2 3B** (custom endpoint to the shared model in `my-first-model`).
3. Also confirm MCP entries **Packmate-Weather-MCP** and **Packmate-Baggage-Policy-MCP** when the instructor has registered them.
4. In-cluster URL used by Packmate (headless Service → pod port `8080`):

```text
http://llama-32-3b-instruct-predictor.my-first-model.svc.cluster.local:8080/v1
```

5. Optional Workbench smoke test (requires network to the model namespace):

```bash
curl -sS "$BASE_URL/models" | head
```

Use instructor-provided env vars; **never commit keys**. Reproduction helper: `docs/REPRODUCE_SANDBOX.md` / `scripts/create-packmate-model-endpoint.sh`.

### Expected result

You can name the Packmate Lab model asset and its in-cluster endpoint.

### Validation

- [ ] **Packmate Llama 3.2 3B** appears under Packmate Lab AI asset endpoints (or `oc get cm gen-ai-aa-custom-model-endpoints -n packmate-lab`).
- [ ] Model Ready in `my-first-model`: `oc get inferenceservice -n my-first-model` (read-only).

### Troubleshooting

- 503 / not Ready → wait for predictor pods; instructor checks GPU/CPU capacity.
- Local laptop port-forward drops → prefer Workbench in-cluster access.

### Business / technical value

Model discovery is productized (AI assets), not a hidden Service URL only.

---

## Module 4 — Deploy and register MCP servers

**Objective:** Understand weather-mcp and baggage-policy-mcp, verify health, register for Playground.  
**Duration:** 40 minutes  
**Prerequisites:** Instructor/GitOps may deploy MCP manifests; participants may also run locally in Workbench.

### Steps

1. Read `mcp-servers/README.md`.
2. Local verification in Workbench (optional):

```bash
cd mcp-servers/weather && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt && pytest -v
```

```bash
cd mcp-servers/baggage-policy && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt && pytest -v
```

3. Cluster manifests: `deploy/base/mcp-weather/`, `deploy/base/mcp-baggage/` (ClusterIP + Route).
4. **Registration (cluster admin / instructor):** ConfigMap `gen-ai-aa-mcp-servers` in `redhat-ods-applications`. Example only: `deploy/examples/mcp-registration/`.  
   At audit time this ConfigMap was **absent** — without it, Playground cannot discover MCP servers.
5. Confirm URLs end with `/mcp` (Streamable HTTP).

### Expected result

MCP servers tested locally; registration path understood (even if admin applies ConfigMap).

### Validation

- [ ] Pytest passes for both MCP servers.
- [ ] You know traveler profile is **not** a shared MCP.

### Troubleshooting

- Playground lists no MCP → ConfigMap missing or wrong URL/path.
- Health 421 Host errors → Packmate servers disable DNS-rebinding Host checks for OpenShift Routes.

### Business / technical value

Tools become first-class platform assets reusable from Playground and from the FastAPI app.

---

## Module 5 — Prototype in Gen AI Playground

**Objective:** Prototype Packmate behaviour with model + MCP before coding the app integration.  
**Duration:** 45 minutes  
**Prerequisites:** Model visible; MCP registered if Playground tools are required.

### Steps

1. Open **Gen AI Playground** for project `packmate-lab` (or instructor project).
2. Select model `llama-32-3b-instruct`.
3. Enable Packmate Weather and Baggage Policy MCP servers; authorize tools.  
   `[Screenshot: Playground with MCP tools]`
4. Paste system instructions from `playground/system-instructions.md`.
5. Run prompts from `playground/test-prompts.json` (Rome weather, Oslo winter, power bank checked, liquids cabin, unknown baggage, business, hiking, weather down, reveal-reasoning, fictional sensitive notes).
6. Observe tool calls vs `playground/expected-tool-calls.json`.
7. Compare one prompt **with MCP disabled** vs enabled.
8. **Export** the Playground configuration for use in the Workbench.

### Expected result

Exported Playground config + confidence in tool-calling behaviour.

### Validation

- [ ] At least five prompts exercised.
- [ ] Reveal-reasoning prompt does not dump chain-of-thought.
- [ ] Sensitive notes are not sent to baggage MCP.

### Troubleshooting

- No tool calls → model too small / temperature high / instructions weak; retry with lower temperature.
- MCP authorize fails → check Route TLS and ConfigMap URL.

### Business / technical value

Playground shortens the path from idea to application contract (tools + system instructions).

---

## Module 6 — Build the application

**Objective:** Wire exported ideas into FastAPI MCP client + React UI; run from Workbench.  
**Duration:** 45 minutes  
**Prerequisites:** Repo cloned; Python and Node available in Workbench image.

### Steps

1. Create environments:

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

cd ../frontend
# use image Node or project nodeenv
npm ci
```

2. Local tool mode for unit tests (default):

```bash
export PACKMATE_TOOL_MODE=local
cd backend && pytest -q
```

3. MCP mode against local MCP servers (optional):

```bash
# terminal A
cd mcp-servers/weather && PYTHONPATH=src uvicorn weather_mcp.app:app --port 8080
# terminal B
cd mcp-servers/baggage-policy && PYTHONPATH=src uvicorn baggage_policy_mcp.app:app --port 8081
# terminal C
export PACKMATE_TOOL_MODE=mcp
export PACKMATE_WEATHER_MCP_URL=http://127.0.0.1:8080/mcp
export PACKMATE_BAGGAGE_MCP_URL=http://127.0.0.1:8081/mcp
export BASE_URL=... MODEL=llama-32-3b-instruct LITELLM_API_KEY=...
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

4. Frontend:

```bash
cd frontend && npm run dev -- --host 0.0.0.0 --port 5173
```

5. Use Workbench port forwarding / routes as provided by the platform.

6. **Streaming exercise (public UI path):**

```bash
curl -sS -N --max-time 180 \
  -H 'Content-Type: application/json' -H 'Accept: text/event-stream' \
  -X POST http://127.0.0.1:8000/api/v1/chat/stream \
  -d '{"message":"Je pars a Rome pendant quatre jours avec un bagage cabine."}'
```

Observe in order:

- [ ] `event: started` appears within a few seconds
- [ ] `event: progress` with `weather` and/or `baggage_rules` when tools run
- [ ] `event: heartbeat` if the model takes longer than ~10s
- [ ] `event: completed` with a PackingResponse (destination + packing_items)
- [ ] No `<think>` / chain-of-thought / medical notes in the stream

The React UI calls `/api/v1/chat/stream` (not the sync endpoint). Cancel uses `AbortController`.

### Expected result

UI returns packing plans; MCP mode calls remote tools without duplicating rule logic.

### Validation

```bash
curl -sS http://127.0.0.1:8000/health
curl -sS http://127.0.0.1:8000/ready
```

### Troubleshooting

- Frontend API proxy errors → check Vite proxy / backend URL.
- MCP timeouts → increase `PACKMATE_MCP_TIMEOUT_SECONDS`.

### Business / technical value

Same MCP servers serve both Playground prototypes and production FastAPI.

---

## Module 7 — Evaluate Packmate

**Objective:** Run Level 1 deterministic evals and understand Level 2 TrustyAI/EvalHub.  
**Duration:** 40 minutes  
**Prerequisites:** Backend venv.

### Steps

1. Level 1 (mandatory):

```bash
cd backend
.venv/bin/python -m evals.runner --mode deterministic --threshold 0.90
# or
../evaluations/scripts/run_deterministic_gate.sh
```

2. Level 2 (optional / instructor): see `evaluations/README.md`.  
   TrustyAI operator is Managed on OAI 3.4.2, but **no EvalHub instance was present at audit**. Do not claim EvalHub ran unless the instructor created one.  
   `[Screenshot: EvalHub result]` (only if available)

3. Compare two prompt/system-instruction variants conceptually (Playground export A vs B) using deterministic fixtures plus optional EvalHub.

### Expected result

Deterministic gate PASS; clear mental model of pytest vs TrustyAI.

### Validation

- [ ] Deterministic score ≥ 0.90.
- [ ] You can explain why EvalHub absence must not break local PRs.

### Troubleshooting

- Gate fails after code change → inspect `backend/evals/reports/` and failed scenario IDs.
- EvalHub script skips → expected when CRD/instance missing.

### Business / technical value

Ship safely with deterministic rules; use platform AI evals for qualitative/safety dimensions when available.

---

## Module 8 — Industrialize

**Objective:** Understand Tekton builds (four images) and GitOps promotion.  
**Duration:** 30 minutes  
**Prerequisites:** OpenShift Pipelines present (verified 1.22.4).

### Steps

1. Read `.tekton/pull-request.yaml` and `.tekton/push.yaml`.
2. Note images: backend, frontend, weather-mcp, baggage-policy-mcp.
3. Inspect `gitops/` Applications (generated; OpenShift GitOps Operator may be **absent** — manifests still valid for when it is installed).  
   `[Screenshot: Argo CD application]`
4. Confirm no tokens in YAML; digests replace `:PLACEHOLDER` / tags in prod.

### Expected result

You can describe PR checks vs push (build + GitOps digest update).

### Validation

- [ ] Name the four container images.
- [ ] Quality gate is mandatory; EvalHub optional.

### Troubleshooting

- Pipeline cannot pull `registry.redhat.io` → instructor configures pull secrets.
- Argo CD UI missing → Operator not installed; review YAML only.

### Business / technical value

AI assets and app images share one promotion path.

---

## Module 9 — Progressive delivery

**Objective:** Explain canary analysis and rollback for the backend.  
**Duration:** 25 minutes  
**Prerequisites:** Argo Rollouts manifests in `deploy/overlays/prod/` (Operator may be absent on cluster).

### Steps

1. Read `deploy/overlays/prod/rollout-backend.yaml` and `docs/CANARY_DEMO.md`.
2. Understand steps: 10% → smoke → 50% → smoke → 100%.
3. MCP servers stay Deployment (not automatically Rollouts); version via image digest.  
   `[Screenshot: Argo Rollout]`
4. Practice the *ideas* of promote / abort with `scripts/canary-demo.sh` (does not apply unless instructor enables).

### Expected result

You can explain candidate → analyse → promote → rollback.

### Validation

- [ ] Backend is the Rollout target; MCP versioning is digest-based Deployments.

### Troubleshooting

- Rollout CRD missing → review manifests only; ask platform team to install Rollouts for live demo.

### Business / technical value

LLM app changes can regress behaviour; canaries reduce blast radius.

---

## Module 10 — Observability and security

**Objective:** Use health/metrics/traces mindset and privacy rules.  
**Duration:** 25 minutes  
**Prerequisites:** Backend running.

### Steps

1. Hit `/health`, `/ready`, `/metrics`.
2. Confirm OTel defaults to exporter `none`; spans must not include medical notes.
3. Run `./scripts/security-check.sh`.
4. Review baggage disclaimer and demo-only rules.
5. Confirm sensitive notes never go to MCP (`backend/app/tools/mcp_client.py`).

### Expected result

Security check PASS; privacy story clear.

### Validation

```bash
./scripts/security-check.sh
```

### Troubleshooting

- Security check fails on `:latest` in deploy → fix overlay images to digest/PLACEHOLDER.
- Metrics scrape empty → ensure `/metrics` reachable in-cluster.

### Business / technical value

Trustworthy AI assistants need privacy, policy disclaimers, and operable telemetry.

---

## Screenshot placeholders (do not invent images)

- `[Screenshot: Create Data Science Project]`
- `[Screenshot: Workbench configuration]`
- `[Screenshot: AI asset endpoints]`
- `[Screenshot: Playground with MCP tools]`
- `[Screenshot: EvalHub result]`
- `[Screenshot: Argo CD application]`
- `[Screenshot: Argo Rollout]`
