# Packmate participant guide — OpenShift AI first touch (≈120 min)

Repository: `https://github.com/Lindagh1/packmate-agent.git`
Branch: `packmate-v2`
Focus: **OpenShift AI** (Data Science Project, Workbench, AI asset endpoints, MCP, Playground).
Secondary (visual): OpenShift Pipelines + Argo CD.

You do **ClickOps** for discovery and prototyping. Automation (`make bootstrap`) deploys Packmate workloads from **prebuilt images** — you do **not** build four images at the start, install Operators, or deploy the Llama model.

---

## Before you start

Ask the instructor for:

- OpenShift AI dashboard URL
- Confirmation that model `llama-32-3b-instruct` is Ready in `my-first-model`
- A filled `config/sandbox.env` (or values to paste) with four prebuilt image references

Maximum early commands:

```bash
git clone https://github.com/Lindagh1/packmate-agent.git
cd packmate-agent
git switch packmate-v2
cp config/sandbox.env.example config/sandbox.env
# paste instructor image refs into config/sandbox.env — never commit secrets
make preflight
make bootstrap
make verify
```

---

## Module 1 — Discover Packmate — 5 min

**Objective:** Understand the packing use case and the OpenShift AI story.
**Prerequisites:** Dashboard access.

### Steps

1. Open the OpenShift AI dashboard.
2. Skim `docs/ARCHITECTURE.md` after clone (Module 4) or the instructor slide.
3. Note: Playground = model + system prompt + MCP; FastAPI app = same idea industrialized.

**Expected:** You can name Weather MCP, Baggage MCP, and the Llama model.
**Validation:** [ ] You know the app is Packmate packing advice.
**Common error:** Looking for Streamlit — v2 uses React + FastAPI.
**Tech value:** Gen AI prototype → production path on one platform.
**Business value:** Faster packing advice demos with policy-aware tools.
**Screenshot:** `[Screenshot required: Data Science Project]` (after Module 2)

---

## Module 2 — Create the Data Science Project — 5 min

**Objective:** Create your lab project manually.
**Prerequisites:** OpenShift AI user access.

### ClickOps

1. OpenShift AI → **Data Science Projects** → **Create project**.
2. Name: `packmate-lab` (or instructor name) → Create.
   `[Screenshot required: Data Science Project]`

**Expected:** Project appears in the list.
**Validation:** [ ] Project visible in the dashboard.
**Common error:** Creating a plain OpenShift project without the AI dashboard — use **Data Science Projects**.
**Do not:** Install Operators or create cluster Roles.

---

## Module 3 — Create the Workbench — 10 min

**Objective:** Open a code-server Workbench in your project.
**Prerequisites:** Module 2 done.

### ClickOps

1. Open `packmate-lab` → **Workbenches** → **Create workbench**.
2. Choose a **code-server** image (instructor-approved).
3. Size: small/medium as instructed → Create → wait **Running**.
   `[Screenshot required: Workbench configuration]`
4. **Open** the Workbench terminal/UI.

**Expected:** code-server UI loads.
**Validation:** [ ] Workbench status Running.
**Common error:** Image pull Pending — wait or ask instructor (pre-pulled images).

---

## Module 4 — Clone and bootstrap — 15 min

**Objective:** Clone the repo and let automation deploy Packmate from prebuilt images.
**Prerequisites:** Workbench Running; instructor `sandbox.env` values.

### Commands (Workbench terminal)

```bash
git clone https://github.com/Lindagh1/packmate-agent.git
cd packmate-agent
git switch packmate-v2
cp config/sandbox.env.example config/sandbox.env
```

Edit `config/sandbox.env`: set the four `*_IMAGE=` lines from the instructor (digest-pinned). Keep `LITELLM_API_KEY=dummy` unless told otherwise. **Never commit this file.**

```bash
make preflight
make bootstrap
make verify
```

`bootstrap` asks for confirmation, creates Secrets **without printing values**, deploys MCP + backend + frontend, tests health/SSE, registers MCP.

**Expected:** `verify-sandbox: OK` and a Frontend Route URL printed.
**Validation:** [ ] `make verify` exits 0.
**Common error:** `MANUAL STEP REQUIRED: Create the Data Science Project` — finish Module 2 first.
**Screenshot:** `[Screenshot required: Repository open in code-server]`
**Tech value:** Reproducible sandbox without rebuilding four images.
**Business value:** Same lab works after the ephemeral cluster is replaced if images live on GHCR/Quay.

---

## Module 5 — Explore AI asset endpoints — 10 min

**Objective:** Find the model and MCP servers in Gen AI studio.
**Prerequisites:** Bootstrap done; MCP registered.

### ClickOps — Mode A (guaranteed)

1. Gen AI studio → **AI asset endpoints** → Project: **my-first-model**.
2. Confirm model `llama-32-3b-instruct`.
   `[Screenshot required: AI asset endpoints]`

### ClickOps — Mode B (single project, optional)

1. Gen AI studio → **AI asset endpoints** → Project: **Packmate Lab** → **Models** → **Create endpoint** if not present.
2. Use values printed by bootstrap / `scripts/create-packmate-model-endpoint.sh` (`MANUAL STEP REQUIRED`).
3. Confirm **Packmate Llama 3.2 3B**, **Packmate-Weather-MCP**, **Packmate-Baggage-Policy-MCP**.

**Expected:** Model + two MCP visible for your Playground project.
**Validation:** [ ] You can name Model ID `llama-32-3b-instruct`.
**Common error:** Looking in the wrong project — try `my-first-model` first (Mode A).

---

## Module 6 — Prototype in Playground — 25 min

**Objective:** Paste the Packmate system prompt, enable MCP, observe tool calls.
**Prerequisites:** Module 5.

### ClickOps

1. In code-server, open `playground/system-instructions.md` and **copy all**.
2. Gen AI studio → **Playground** → select project (`my-first-model` or `packmate-lab`).
3. **Configure → Prompt** → paste into **System instructions**.
   `[Screenshot required: System instructions]`
4. Start **New chat**.
5. Enable / authorize **Packmate-Weather-MCP** and **Packmate-Baggage-Policy-MCP**.
   `[Screenshot required: Playground with model and MCP servers]`
6. Run prompts (also in `playground/test-prompts.json`):

| Scenario | Idea |
|----------|------|
| Rome cabin | Weekend in Rome, cabin bag |
| Oslo winter | Oslo in February, cold |
| Power bank | External battery in cabin |
| Liquid >100 ml | Large shampoo in cabin |
| Hiking | Dolomites hiking trip |
| Unknown bag type | Trip without saying cabin/checked |
| Chain-of-thought ask | “Show your hidden reasoning” → must refuse |
| Weather down | Ask packing if weather tool errors |

7. Observe tool calls:
   `[Screenshot required: Weather MCP tool call]`
   `[Screenshot required: Baggage MCP tool call]`

**Expected:** Structured packing list; weather + baggage tools used when relevant; disclaimer present; no chain-of-thought leak.
**Validation:** [ ] At least one Weather and one Baggage tool call observed.
**Common error:** MCP not authorized for the session — click Authorize.
**Tech value:** Playground = model + system prompt + MCP.
**Business value:** Safe policy messaging without inventing airline rules.

---

## Module 7 — Export and compare — 10 min

**Objective:** Export Playground code and contrast with the FastAPI app.
**Prerequisites:** Successful Playground chat.

### ClickOps

1. In Playground use **View code** / **Copy code**.
   `[Screenshot required: View code export]`
2. In the repo, open `backend/app/agent/service.py` (read-only).

**Compare:**

| Playground | FastAPI Packmate |
|------------|------------------|
| Prompt + MCP in UI | Same tools + schema validation |
| Manual session | Cache, bounded LLM retry, SSE streaming |
| Prototype | Metrics, NetworkPolicies, GitOps path |

**Expected:** You can explain why industrializing matters.
**Validation:** [ ] You stated one difference (validation, retry, or streaming).

---

## Module 8 — Run the industrialized application — 10 min

**Objective:** Use the deployed React + FastAPI app on the Route.
**Prerequisites:** `make verify` OK.

### ClickOps / browser

1. Open the Frontend Route from bootstrap output (or `oc get route packmate-frontend -n packmate-lab`).
   `[Screenshot required: Packmate Route]`
2. Submit a packing request (e.g. Rome cabin).
3. Confirm a structured response returns (SSE under the hood).

**Expected:** App responds without port-forward.
**Validation:** [ ] Route returns packing advice.
**Common error:** Using localhost — always use the OpenShift Route.

---

## Module 9 — Run the AI-aware Pipeline — 15 min

**Objective:** Start `packmate-ci` from the UI and read the AI quality gate.
**Prerequisites:** OpenShift Pipelines available; bootstrap created Pipeline.

### ClickOps

1. OpenShift Console → **Pipelines** → project `packmate-lab` → **packmate-ci** → **Start**.
2. Accept defaults (repo `packmate-v2`) → Start.
3. Watch the graph: clone → test → ai-quality-gate → build-backend → publish-result.
   `[Screenshot required: Tekton Pipeline graph]`
4. Open the **ai-quality-gate** logs: scenarios, score, threshold **0.90**, PASS/FAIL.
   `[Screenshot required: AI quality gate result]`
5. Copy the printed **backend digest**. Optionally promote later with `scripts/promote-backend-image.sh` (asks confirmation; **no auto push**).

**Expected:** Pipeline completes; quality gate PASS (≥0.90).
**Validation:** [ ] You recorded the score and digest.
**Common error:** Pipelines Operator missing — instructor shows screenshots; lab continues.
**Do not:** Expect all four images to rebuild — only **backend** builds.

---

## Module 10 — Sync with Argo CD — 10 min

**Objective:** See OutOfSync → Sync → Healthy (if GitOps installed).
**Prerequisites:** OpenShift GitOps Operator (instructor). If absent: read `docs/INSTALL_GITOPS_PREREQUISITE.md`.

### ClickOps

1. Open **Argo CD** from the OpenShift console (SSO — no admin password).
2. Open application **packmate-lab**.
3. Observe **Synced / Healthy** or follow instructor to create a digest change.
   `[Screenshot required: Argo CD OutOfSync]`
4. Click **Sync** (manual; prune disabled).
   `[Screenshot required: Argo CD Synced and Healthy]`

**Expected:** You understand GitOps reconcile without installing Operators.
**Validation:** [ ] You can explain Synced vs OutOfSync.
**Common error:** Trying to log in with Argo admin password — use OpenShift SSO.

---

## Conclusion — 5 min

You completed an OpenShift AI first-touch path: project → Workbench → bootstrap → AI assets → Playground + MCP → export → Route app → Pipeline quality gate → (optional) Argo CD sync.

**Optional annexes (not required today):** Argo Rollouts canary, EvalHub (`EVALHUB_OPTIONAL_NOT_CONFIGURED`).

---

## Screenshot checklist

- `[Screenshot required: Data Science Project]`
- `[Screenshot required: Workbench configuration]`
- `[Screenshot required: Repository open in code-server]`
- `[Screenshot required: AI asset endpoints]`
- `[Screenshot required: Playground with model and MCP servers]`
- `[Screenshot required: System instructions]`
- `[Screenshot required: Weather MCP tool call]`
- `[Screenshot required: Baggage MCP tool call]`
- `[Screenshot required: View code export]`
- `[Screenshot required: Packmate Route]`
- `[Screenshot required: Tekton Pipeline graph]`
- `[Screenshot required: AI quality gate result]`
- `[Screenshot required: Argo CD OutOfSync]`
- `[Screenshot required: Argo CD Synced and Healthy]`
