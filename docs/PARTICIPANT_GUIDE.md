# 📖 Project Documentation: Packmate Agent

**OpenShift AI first-touch lab** · Branch `packmate-v2` · ≈ **120 minutes**

Repository: `https://github.com/Lindagh1/packmate-agent.git`

---

## Introduction: General Architecture Overview

The Packmate ecosystem is structured as an end-to-end, cloud-native path from **Gen AI prototype** to **industrialized application**, with a short visual introduction to CI and GitOps.

It separates discovery, prototyping, runtime, and delivery into clear layers:

1. **The AI application layer (FastAPI + React)**
   The packing assistant uses a Llama model, a Packmate **system prompt**, and two MCP tools (Weather, Baggage Policy). The industrialized path adds schema validation, MCP cache, bounded LLM retry, SSE streaming, metrics, and NetworkPolicies.

2. **The cloud-native workspace (Red Hat OpenShift AI)**
   You create a **Data Science Project** and a **code-server Workbench**. You explore **AI asset endpoints**, prototype in the **Gen AI Playground**, then compare the export with the FastAPI service.

3. **The lab bootstrap (prebuilt images)**
   Automation (`make bootstrap`) deploys Weather MCP, Baggage MCP, backend, and frontend from **digest-pinned** images (GHCR/Quay). You do **not** build four images at the start of the lab and you do **not** redeploy the shared Llama model in `my-first-model`.

4. **Secondary ClickOps (Pipelines + Argo CD)**
   You start Pipeline `packmate-ci` from the UI (tests + AI quality gate + backend build only). If OpenShift GitOps is available, you observe **OutOfSync → Sync → Healthy** in Argo CD.

> **Architect Note:**
> Playground = model + system prompt + MCP.
> FastAPI Packmate = the same idea industrialized (validation, retry, security, streaming).

> **Security Note:**
> Never commit `config/sandbox.env`, API keys, or Secret values. Secrets are created by bootstrap from environment variables and are never printed.

---

## Table of contents

| Part | Title | Duration |
|------|-------|----------|
| 🏗️ | [Introduction: General Architecture Overview](#introduction-general-architecture-overview) | — |
| 🧭 | [0. Before you start](#0-before-you-start) | 5 min |
| 🧳 | [1. Discover Packmate](#1-discover-packmate) | 5 min |
| 📁 | [2. Create the Data Science Project](#2-create-the-data-science-project) | 5 min |
| 💻 | [3. Create the Workbench](#3-create-the-workbench) | 10 min |
| 🚀 | [4. Clone and bootstrap](#4-clone-and-bootstrap) | 15 min |
| 🔌 | [5. Explore AI asset endpoints](#5-explore-ai-asset-endpoints) | 10 min |
| 🧪 | [6. Prototype in the Gen AI Playground](#6-prototype-in-the-gen-ai-playground) | 25 min |
| 📤 | [7. Export and compare](#7-export-and-compare) | 10 min |
| 🌐 | [8. Run the industrialized application](#8-run-the-industrialized-application) | 10 min |
| ⚙️ | [9. Run the AI-aware Pipeline](#9-run-the-ai-aware-pipeline) | 15 min |
| 🐙 | [10. Sync with Argo CD](#10-sync-with-argo-cd) | 10 min |
| ✅ | [Conclusion](#conclusion) | 5 min |
| 📎 | [Annex A — Screenshot checklist](#annex-a--screenshot-checklist) | — |
| 📎 | [Annex B — Optional extensions](#annex-b--optional-extensions) | — |

---

## 🧭 0. Before you start

Ask your instructor for:

- the **OpenShift AI** dashboard URL;
- confirmation that model `llama-32-3b-instruct` is **Ready** in project `my-first-model`;
- the four **digest-pinned** image references for `config/sandbox.env` (GHCR/Quay).

You will **not** install Operators, deploy the Llama model, use Argo CD admin passwords, or port-forward for the main path.

Maximum early command sequence (Workbench terminal, after Modules 2–3):

```bash
git clone https://github.com/Lindagh1/packmate-agent.git
cd packmate-agent
git switch packmate-v2
cp config/sandbox.env.example config/sandbox.env
# paste instructor image refs — never commit this file
make preflight
make bootstrap
make verify
```

**Expected result:** After Module 4, `make verify` prints `verify-sandbox: OK (lab core ready)`.

---

## 🧳 1. Discover Packmate

**Duration:** 5 minutes
**Objective:** Understand the packing use case and the OpenShift AI story.

Packmate helps a traveler build a packing list using:

- live **weather** context (Weather MCP);
- **baggage policy** rules for cabin/checked constraints (Baggage Policy MCP);
- a Llama model guided by a Packmate **system prompt**.

### 1.1. Open the platform

1. Open the **OpenShift AI** dashboard provided by the instructor.
2. Locate **Data Science Projects** and **Gen AI studio** in the navigation.

**Expected result:** You can name the three AI building blocks: model, system prompt, MCP tools.

> **Pro Tip:**
> Keep this mental model for the whole lab — every later module is either *prototyping* those three pieces or *industrializing* them.

---

## 📁 2. Create the Data Science Project

**Duration:** 5 minutes
**Objective:** Create your lab project manually (ClickOps).

Participants create the project themselves so the OpenShift AI dashboard ownership story stays clear. Bootstrap refuses to invent the project unless the instructor sets `ALLOW_CREATE_NAMESPACE=true`.

### 2.1. ClickOps

1. In OpenShift AI, open **Data Science Projects**.
2. Click **Create project**.
3. Set the name to **`packmate-lab`** (or the name given by the instructor).
4. Click **Create**.

[Screenshot required: Data Science Project]

**Expected result:** The project appears in the Data Science Projects list.

**Common error:** Creating a plain OpenShift project from the OpenShift console only — always use **Data Science Projects** in the AI dashboard.

---

## 💻 3. Create the Workbench

**Duration:** 10 minutes
**Objective:** Provision a code-server IDE inside your Data Science Project.

### 3.1. ClickOps

1. Open project **`packmate-lab`**.
2. Go to **Workbenches** → **Create workbench**.
3. Choose a **code-server** image approved by the instructor (for example **Code Server | Data Science | CPU | Python 3.12**).
4. Set sizing as instructed (typical: small/medium CPU and memory).
5. Click **Create** and wait until status is **Running**.
6. Click **Open** to enter the cloud IDE.

[Screenshot required: Workbench configuration]

**Expected result:** The code-server UI loads and a terminal is available.

> **Security Note:**
> Do not paste production tokens into Workbench notebooks or screenshots. Lab LLM connectivity for the deployed app uses the Secret created by bootstrap, not values stored in Git.

**Common error:** Image pull stays **Pending** — wait for pre-pulled images or ask the instructor.

---

## 🚀 4. Clone and bootstrap

**Duration:** 15 minutes
**Objective:** Clone the repository and deploy Packmate from prebuilt images.

Bootstrap verifies the cluster, deploys the two MCP servers, backend, and frontend, registers MCP endpoints, installs Pipeline resources when available, and prints remaining UI steps. It never rebuilds four images at lab start.

### 4.1. Clone in the Workbench terminal

```bash
git clone https://github.com/Lindagh1/packmate-agent.git
cd packmate-agent
git switch packmate-v2
```

[Screenshot required: Repository open in code-server]

### 4.2. Configure the sandbox file

```bash
cp config/sandbox.env.example config/sandbox.env
```

Edit `config/sandbox.env` and set the four image lines from the instructor (digest-pinned GHCR/Quay references). Keep placeholders such as `LITELLM_API_KEY=dummy` unless told otherwise.

> **Security Note:**
> Never commit `config/sandbox.env`. It is gitignored.

### 4.3. Preflight, bootstrap, verify

```bash
make preflight
make bootstrap
make verify
```

> **Pro Tip:**
> For an alternate env file (instructor smoke / acceptance), export `PACKMATE_CONFIG=/path/to/file.env` before `make preflight|bootstrap|verify`. The participant path still uses `config/sandbox.env`.

Confirm the bootstrap prompt with **`y`** when asked (unless the instructor already set `SKIP_CONFIRM=true`).

**Expected result:**

- `Preflight OK` (warnings for optional GitOps/Rollouts/EvalHub are acceptable);
- bootstrap prints a Frontend **Route** URL and SSE smoke success;
- `verify-sandbox: OK (lab core ready)`.

**Common error:** `MANUAL STEP REQUIRED: Create the Data Science Project` — complete Part 2 first.

> **Architect Note:**
> Images come from an external registry that survives ephemeral sandboxes. The Pipeline later builds **only the backend** for the CI demonstration.

---

## 🔌 5. Explore AI asset endpoints

**Duration:** 10 minutes
**Objective:** Locate the shared model and the Packmate MCP servers.

The physical model stays in **`my-first-model`**. You do not deploy a second Llama instance.

### 5.1. Mode A — simplest (recommended)

1. Open **Gen AI studio** → **AI asset endpoints**.
2. Select project **`my-first-model`**.
3. Confirm model **`llama-32-3b-instruct`**.

[Screenshot required: AI asset endpoints]

### 5.2. Mode B — single project experience (optional)

1. Open **Gen AI studio** → **AI asset endpoints**.
2. Select project **Packmate Lab** / **`packmate-lab`**.
3. If needed, click **Models** → **Create endpoint**.
4. Fill the values printed by bootstrap under **MANUAL STEP REQUIRED — Create model endpoint** (URL, Model ID, display name). Leave token blank if predictor auth is disabled.

**Expected result:** You can open a Playground session that sees the model and, after bootstrap, the Packmate MCP entries.

**Common error:** Searching only in `packmate-lab` while Mode A keeps the model in `my-first-model`.

---

## 🧪 6. Prototype in the Gen AI Playground

**Duration:** 25 minutes
**Objective:** Paste the Packmate system prompt, enable MCP tools, and observe tool calls.

The source of truth for the prompt is:

`playground/system-instructions.md`

### 6.1. Copy the system instructions

1. In code-server, open **`playground/system-instructions.md`**.
2. Select all content and **copy**.

### 6.2. Configure the Playground

1. Open **Gen AI studio** → **Playground**.
2. Select the project (`my-first-model` or `packmate-lab`).
3. Open **Configure** → **Prompt**.
4. Paste into **System instructions**.

[Screenshot required: System instructions]

5. Start a **New chat**.
6. Enable / authorize **Packmate-Weather-MCP** and **Packmate-Baggage-Policy-MCP**.

[Screenshot required: Playground with model and MCP servers]

### 6.3. Run the lab scenarios

Use prompts from `playground/test-prompts.json` or equivalent wording:

| # | Scenario | What to observe |
|---|----------|-----------------|
| 1 | Rome with cabin bag | Weather + baggage tools; packing list |
| 2 | Oslo in winter | Cold-weather items |
| 3 | External battery / power bank | Battery warning |
| 4 | Liquid above 100 ml in cabin | Liquids warning |
| 5 | Hiking trip | Activity-aligned packing |
| 6 | Unknown bag type | Safe handling / clarification |
| 7 | Ask for chain-of-thought | Refusal; no hidden reasoning leak |
| 8 | Weather unavailable | No invented weather facts |

### 6.4. Observe tool calls

1. Expand the tool / function call details in the Playground transcript.
2. Capture at least one Weather call and one Baggage call.

[Screenshot required: Weather MCP tool call]

[Screenshot required: Baggage MCP tool call]

**Expected result:** Structured packing advice, policy disclaimer when relevant, no invented tool results, no chain-of-thought leak.

> **Pro Tip:**
> If MCP buttons are greyed out, authorize them for the chat session, then start a **New chat** after pasting system instructions.

---

## 📤 7. Export and compare

**Duration:** 10 minutes
**Objective:** Export the Playground prototype and contrast it with the FastAPI application.

### 7.1. Export from the Playground

1. In the Playground, open **View code** (or **Copy code**).
2. Skim the exported prompt / tool wiring (do not paste secrets into shared notes).

[Screenshot required: View code export]

### 7.2. Compare with the industrialized service

In the repository, open (read-only) `backend/app/agent/service.py`.

| Playground | FastAPI Packmate |
|------------|------------------|
| Model + system prompt + MCP in the UI | Same tools, plus response schema validation |
| Manual chat session | MCP cache, bounded LLM retry, metrics |
| Prototype export | SSE streaming through the OpenShift Route |
| Instant experimentation | NetworkPolicies, GitOps-friendly manifests |

**Expected result:** You can state at least one reason industrialization matters (validation, retry, streaming, or security).

> **Architect Note:**
> Export is a bridge, not the production artifact. The Route application is what participants and demos should call “the Packmate app”.

---

## 🌐 8. Run the industrialized application

**Duration:** 10 minutes
**Objective:** Use the deployed React + FastAPI app on the public Route.

### 8.1. Open the Route

1. Copy the Frontend Route URL printed by bootstrap, or run:

```bash
oc get route packmate-frontend -n packmate-lab
```

2. Open the HTTPS URL in your browser.

[Screenshot required: Packmate Route]

3. Submit a packing request (for example a weekend in Rome with a cabin bag).
4. Confirm a structured response returns (SSE runs under the hood).

**Expected result:** The application answers without port-forward.

**Common error:** Calling `localhost` from the Workbench — always use the OpenShift **Route**.

---

## ⚙️ 9. Run the AI-aware Pipeline

**Duration:** 15 minutes
**Objective:** Start `packmate-ci` from the UI and read the AI quality gate.

You do **not** write Pipeline YAML. Bootstrap already installed the namespace-scoped Pipeline when Pipelines is available.

### 9.1. Start the Pipeline

1. Open the **OpenShift Web Console**.
2. Go to **Pipelines** (or **Pipelines** → **Pipelines**).
3. Select project **`packmate-lab`**.
4. Open Pipeline **`packmate-ci`**.
5. Click **Start**.
6. Keep defaults (repository URL and revision **`packmate-v2`**) unless the instructor says otherwise.
7. Click **Start** again to create the PipelineRun.

[Screenshot required: Tekton Pipeline graph]

### 9.2. Read the AI quality gate

Visual path:

**clone → test → ai-quality-gate → validate-manifests → build-backend → publish-result**

1. Open task **ai-quality-gate**.
2. Record: number of scenarios, **score**, threshold **0.90**, **PASS** or **FAIL**.

[Screenshot required: AI quality gate result]

3. From **publish-result** / build logs, copy the backend **digest**.
4. Optional later promotion (Workbench):

```bash
scripts/promote-backend-image.sh <digest>
```

The script shows a diff, asks confirmation, and **never** pushes automatically.

**Expected result:** Pipeline Succeeded (or instructor explains a sandbox limit). Quality gate target is **≥ 0.90** (reference lab score **0.9559**).

> **Pro Tip:**
> The Pipeline builds **only the backend**. It does not rebuild the four lab images and must not silently replace the live Deployment unless you promote on purpose.

**Common error:** Pipelines Operator missing — follow instructor screenshots; the OpenShift AI path remains valid.

---

## 🐙 10. Sync with Argo CD

**Duration:** 10 minutes
**Objective:** Observe GitOps reconcile (OutOfSync → Sync → Healthy).

If OpenShift GitOps is absent, read `docs/INSTALL_GITOPS_PREREQUISITE.md` and treat this part as a visual walkthrough.

### 10.1. Open Argo CD with OpenShift SSO

1. From the OpenShift console, open the **Argo CD** link / GitOps plugin.
2. Sign in with **OpenShift SSO** (do **not** use an Argo admin password).
3. Open Application **`packmate-lab`** (application name; destination namespace is your Packmate project).

### 10.2. Observe and sync

1. Note the current status (**Synced** / **OutOfSync**, **Healthy** / **Progressing**).
2. If the instructor triggered a benign Git change, wait until status becomes **OutOfSync**.

[Screenshot required: Argo CD OutOfSync]

3. Click **Sync** (manual sync; prune and self-heal are disabled for first-touch safety).

[Screenshot required: Argo CD Synced and Healthy]

**Expected result:** You can explain Synced vs OutOfSync and why prune is off in a teaching lab.

> **Security Note:**
> The AppProject limits destinations to the Packmate namespace. There are no wildcard destinations and no admin RoleBindings for participants.

**Common error:** Searching for Argo CD local admin credentials — use OpenShift SSO only.

---

## Conclusion

In about two hours you practiced an OpenShift AI first-touch journey:

1. created a **Data Science Project** and **Workbench**;
2. bootstrapped Packmate from **prebuilt images**;
3. connected **model + system prompt + MCP** in the Playground;
4. compared the prototype with the **FastAPI** application on a **Route**;
5. ran an **AI-aware Pipeline** with a deterministic quality gate;
6. (when available) synchronized an **Argo CD** Application.

### Skills acquired

- Navigate OpenShift AI (projects, Workbenches, AI asset endpoints, Playground).
- Register and observe MCP tool calls safely.
- Distinguish prototype vs industrialized Gen AI services.
- Launch a Tekton Pipeline from the UI and read an AI quality gate.
- Interpret Argo CD Sync / OutOfSync / Healthy without installing Operators yourself.

Optional topics **not required today:** Argo Rollouts canary demos, EvalHub-native evaluation (`EVALHUB_OPTIONAL_NOT_CONFIGURED`).

---

## Annex A — Screenshot checklist

Place each capture immediately after the matching step in your notes or Word export:

1. `[Screenshot required: Data Science Project]`
2. `[Screenshot required: Workbench configuration]`
3. `[Screenshot required: Repository open in code-server]`
4. `[Screenshot required: AI asset endpoints]`
5. `[Screenshot required: System instructions]`
6. `[Screenshot required: Playground with model and MCP servers]`
7. `[Screenshot required: Weather MCP tool call]`
8. `[Screenshot required: Baggage MCP tool call]`
9. `[Screenshot required: View code export]`
10. `[Screenshot required: Packmate Route]`
11. `[Screenshot required: Tekton Pipeline graph]`
12. `[Screenshot required: AI quality gate result]`
13. `[Screenshot required: Argo CD OutOfSync]`
14. `[Screenshot required: Argo CD Synced and Healthy]`

---

## Annex B — Optional extensions

| Extension | Status in main lab |
|-----------|--------------------|
| Argo Rollouts canary | Optional annex — not required |
| EvalHub evaluation | Optional — `EVALHUB_OPTIONAL_NOT_CONFIGURED` if no instance |
| Custom model endpoint CLI | Optional instructor flag `CREATE_MODEL_CUSTOM_ENDPOINT=true` |
| Historical Streamlit / S2I path | Retired — not part of Packmate v2 |

See also: `docs/ARCHITECTURE.md`, `docs/REPRODUCE_SANDBOX.md`, `docs/INSTRUCTOR_GUIDE.md`, `docs/DOCX_ASSEMBLY_PLAN.md`.
