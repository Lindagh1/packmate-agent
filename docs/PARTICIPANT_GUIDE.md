# 📖 Project Documentation: Packmate Agent

**OpenShift AI DEV → PROD lab** · Branch `packmate-v2` · ≈ **150 minutes**

Repository: `https://github.com/Lindagh1/packmate-agent.git`

---

## Introduction: General Architecture Overview

The Packmate ecosystem is structured as an end-to-end, cloud-native path from **Gen AI prototype** to **industrialized application running in production**, with hands-on CI and GitOps promotion.

Two environments matter for this lab:

| Environment | Namespace | What it is | Who deploys it |
|-------------|-----------|-------------|-----------------|
| **DEV** | `packmate-lab` | Your Data Science Project: Workbench, Playground, AI asset endpoints, backend/frontend/MCP for experimentation, Pipeline `packmate-ci` | `make bootstrap` (you) |
| **PROD** | `packmate-prod` | Runtime-only namespace: no Workbench, no Playground, no Pipeline. Serves the validated app on its own Route | **Argo CD Sync only**, after a merged promotion pull request |

`packmate-lab` is **DEV**. It is never production, and it is never synced by Argo CD directly to end users. Every change that reaches `packmate-prod` goes through: **Pipeline (validate) → pull request (promote) → merge → Argo CD Sync (deploy)**.

It separates discovery, prototyping, delivery, and runtime into clear layers:

1. **The AI application layer (FastAPI + React)**
   The packing assistant uses a Llama model, a Packmate **system prompt**, and two MCP tools (Weather, Baggage Policy). The industrialized path adds schema validation, MCP cache, bounded LLM retry, SSE streaming, metrics, and NetworkPolicies.

2. **The cloud-native workspace (Red Hat OpenShift AI, DEV only)**
   You create a **Data Science Project** and a **code-server Workbench** in `packmate-lab`. You explore **AI asset endpoints**, prototype in the **Gen AI Playground**, then compare the export with the FastAPI service.

3. **The lab bootstrap (prebuilt images)**
   Automation (`make bootstrap`) deploys Weather MCP, Baggage MCP, backend, and frontend in `packmate-lab` from **digest-pinned** images (GHCR/Quay). It also registers the MCP servers, creates the **Packmate custom model endpoint** in your project, installs Pipeline `packmate-ci`, and **prepares `packmate-prod`** (namespace, Secret, image-pull RBAC, Argo CD AppProject/Application) — without deploying any PROD workload. You do **not** build four images at the start of the lab and you do **not** redeploy the shared Llama model in `my-first-model`.

4. **CI and promotion (Pipelines + pull request)**
   You start Pipeline `packmate-ci` from the UI (tests + AI quality gate + backend build). A passing run produces a **candidate backend digest**. Promoting that digest to PROD is a **Git pull request**, never a direct cluster change.

5. **Production delivery (Argo CD)**
   Merging the promotion PR makes Application `packmate-prod` **OutOfSync**. You **Sync** it manually (prune disabled) via OpenShift SSO and confirm **Synced / Healthy** on the **PROD Route**.

> **Architect Note:**
> Playground = model + system prompt + MCP, in DEV only.
> FastAPI Packmate = the same idea industrialized (validation, retry, security, streaming), running in both DEV and PROD.

> **Security Note:**
> Never commit `config/sandbox.env`, API keys, or Secret values. Secrets are created by bootstrap/`prepare-prod` from environment variables and are never printed. You never see or use the Argo CD admin password.

---

## Table of contents

| Part | Title | Duration |
|------|-------|----------|
| 🏗️ | [Introduction: General Architecture Overview](#introduction-general-architecture-overview) | — |
| 🧭 | [0. Before you start](#0-before-you-start) | 5 min |
| 🅰️ | [MODULE A — OpenShift AI](#module-a--openshift-ai) | 65 min |
| 🅱️ | [MODULE B — Development](#module-b--development) | 15 min |
| 🅲 | [MODULE C — CI](#module-c--ci) | 20 min |
| 🅳 | [MODULE D — Promotion](#module-d--promotion) | 15 min |
| 🅴 | [MODULE E — Production](#module-e--production) | 20 min |
| 🅵 | [MODULE F — Rollback](#module-f--rollback) | 10 min |
| ✅ | [Conclusion](#conclusion) | 5 min |
| 📎 | [Annex A — Screenshot checklist](#annex-a--screenshot-checklist) | — |
| 📎 | [Annex B — Optional extensions](#annex-b--optional-extensions) | — |

---

## 🧭 0. Before you start

Ask your instructor for:

- the **OpenShift AI** dashboard URL and the **OpenShift console** / **Argo CD** links;
- confirmation that model `llama-32-3b-instruct` is **Ready** in project `my-first-model`;
- the four **digest-pinned** image references for `config/sandbox.env` (GHCR/Quay);
- confirmation that you have **GitHub write access** (or a fork) on `Lindagh1/packmate-agent` — Module D opens a real pull request.

You will **not** install Operators, deploy the Llama model, use an Argo CD admin password, or port-forward for the main path.

Maximum early command sequence (Workbench terminal, after Module A steps A.2–A.3):

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

**Expected result:** After Module A, `make verify` prints `verify-sandbox: OK (lab core ready)`, and bootstrap has also prepared (but not deployed to) `packmate-prod`.

---

## MODULE A — OpenShift AI

**Duration:** 65 minutes
**Objective:** Provision the DEV project, bootstrap Packmate, and prototype in the Gen AI Playground.

### A.1. Discover Packmate

Packmate helps a traveler build a packing list using:

- live **weather** context (Weather MCP);
- **baggage policy** rules for cabin/checked constraints (Baggage Policy MCP);
- a Llama model guided by a Packmate **system prompt**.

1. Open the **OpenShift AI** dashboard provided by the instructor.
2. Locate **Data Science Projects** and **Gen AI studio** in the navigation.

**Expected result:** You can name the three AI building blocks: model, system prompt, MCP tools.

> **Pro Tip:**
> Keep this mental model for the whole lab — every later module either *prototypes* those three pieces (DEV) or *industrializes and ships* them (DEV → PROD).

### A.2. Create the Data Science Project (DEV)

Participants create the project themselves so the OpenShift AI dashboard ownership story stays clear. Bootstrap refuses to invent the project unless the instructor sets `ALLOW_CREATE_NAMESPACE=true`.

1. In OpenShift AI, open **Data Science Projects**.
2. Click **Create project**.
3. Set the name to **`packmate-lab`** (or the name given by the instructor). This is your **DEV** project — it is never production.
4. Click **Create**.

[Screenshot required: DEV project]

**Expected result:** The project appears in the Data Science Projects list.

**Common error:** Creating a plain OpenShift project from the OpenShift console only — always use **Data Science Projects** in the AI dashboard.

### A.3. Create the Workbench

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

### A.4. Clone and bootstrap

Bootstrap verifies the cluster, deploys the two MCP servers, backend, and frontend in `packmate-lab`, registers MCP endpoints, installs Pipeline `packmate-ci`, **prepares `packmate-prod`** (namespace, Secret, image-pull RBAC, Argo CD AppProject/Application, your Argo CD group), and prints remaining UI steps. It never rebuilds four images at lab start and never deploys workloads into `packmate-prod`.

```bash
git clone https://github.com/Lindagh1/packmate-agent.git
cd packmate-agent
git switch packmate-v2
```

[Screenshot required: Repository open in code-server]

```bash
cp config/sandbox.env.example config/sandbox.env
```

Edit `config/sandbox.env` and set the four image lines from the instructor (digest-pinned GHCR/Quay references). Keep placeholders such as `LITELLM_API_KEY=dummy` unless told otherwise.

> **Security Note:**
> Never commit `config/sandbox.env`. It is gitignored.

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
- bootstrap prints a Frontend **Route** URL and SSE smoke success, then a `=== prepare-prod complete ===` block for `packmate-prod` (namespace, Secret, RBAC — no workload);
- `verify-sandbox: OK (lab core ready)`.

**Common error:** `MANUAL STEP REQUIRED: Create the Data Science Project` — complete step A.2 first.

> **Architect Note:**
> Images come from an external registry that survives ephemeral sandboxes. The Pipeline later builds **only the backend**, and only into `packmate-lab` — never into `packmate-prod`.

### A.5. Explore AI asset endpoints

The physical model stays in **`my-first-model`**. You do not deploy a second Llama instance and you do **not** create an endpoint manually. `make bootstrap` registers, in **DEV only**:

- **Packmate Llama 3.2 3B** (custom endpoint in `packmate-lab` pointing at the shared predictor)
- **Packmate-Weather-MCP**
- **Packmate-Baggage-Policy-MCP**

`packmate-prod` never has AI asset endpoints, a Workbench, or a Playground — it is a runtime-only namespace (Module E).

1. Open **Gen AI studio** → **AI asset endpoints**.
2. Select project **Packmate Lab** / **`packmate-lab`**.
3. Confirm the three assets above are listed (refresh the dashboard if an asset is missing just after bootstrap).

[Screenshot required: AI asset endpoints in packmate-lab]

**Expected result:** All three assets are visible in `packmate-lab` without any Create endpoint ClickOps.

**Common error:** Assets missing after bootstrap — hard-refresh Gen AI studio, then re-run `make verify`. Do not create a second model in `packmate-lab`, and do not switch to the `my-first-model` project to run the Playground — the shared model lives there, but your Packmate Playground session runs in `packmate-lab` against the custom endpoint bootstrap created for you.

### A.6. Prototype in the Gen AI Playground

The source of truth for the prompt is:

`playground/system-instructions.md`

1. In code-server, open **`playground/system-instructions.md`**.
2. Select all content and **copy**.
3. Open **Gen AI studio** → **Playground**.
4. Select project **Packmate Lab** / **`packmate-lab`**.
5. Select model **Packmate Llama 3.2 3B**.
6. Open **Configure** → **Prompt**.
7. Paste into **System instructions**.

[Screenshot required: System instructions]

8. Start a **New chat**.
9. Enable / authorize **Packmate-Weather-MCP** and **Packmate-Baggage-Policy-MCP**.

[Screenshot required: Playground with model and MCP servers]

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

Expand the tool / function call details in the Playground transcript and capture at least one Weather call and one Baggage call.

[Screenshot required: Weather MCP tool call]

[Screenshot required: Baggage MCP tool call]

**Expected result:** Structured packing advice, policy disclaimer when relevant, no invented tool results, no chain-of-thought leak.

> **Pro Tip:**
> If MCP buttons are greyed out, authorize them for the chat session, then start a **New chat** after pasting system instructions.

### A.7. Export with View code

1. In the Playground, open **View code** (or **Copy code**).
2. Skim the exported prompt / tool wiring (do not paste secrets into shared notes).

[Screenshot required: View code export]

**Expected result:** You can name the fields the export contains (model, system prompt, tools) and confirm none of them is a secret value.

> **Architect Note:**
> Export is a bridge, not the production artifact. Modules B–E turn this prototype into a Route your users actually call.

---

## MODULE B — Development

**Duration:** 15 minutes
**Objective:** Use the deployed DEV application and contrast it with the Playground prototype.

### B.1. Open the DEV Route

1. Copy the Frontend Route URL printed by bootstrap, or run:

```bash
oc get route packmate-frontend -n packmate-lab
```

2. Open the HTTPS URL in your browser. This is the **DEV Route** — `packmate-lab`, not production.
3. Submit a packing request (for example a weekend in Rome with a cabin bag).
4. Confirm a structured response returns (SSE runs under the hood).

**Expected result:** The application answers without port-forward.

**Common error:** Calling `localhost` from the Workbench — always use the OpenShift **Route**.

### B.2. Compare the industrialized app with the Playground

In the repository, open (read-only) `backend/app/agent/service.py`.

| Playground (Module A) | FastAPI Packmate (DEV Route, this module) |
|------------------------|--------------------------------------------|
| Model + system prompt + MCP in the UI | Same tools, plus response schema validation |
| Manual chat session | MCP cache, bounded LLM retry, metrics |
| Prototype export | SSE streaming through the OpenShift Route |
| Instant experimentation | NetworkPolicies, GitOps-friendly manifests, promotable to PROD |

**Expected result:** You can state at least one reason industrialization matters (validation, retry, streaming, or security), and explain that this DEV Route is still not the environment your end users hit — that is `packmate-prod` (Module E).

---

## MODULE C — CI

**Duration:** 20 minutes
**Objective:** Start `packmate-ci` from the UI, read the AI quality gate, and capture a candidate backend digest.

You do **not** write Pipeline YAML. Bootstrap already installed the namespace-scoped Pipeline (and its BuildConfig/ImageStream) in `packmate-lab` when Pipelines is available. The Pipeline only ever touches `packmate-lab` — it never deploys to `packmate-prod`.

### C.1. Start the Pipeline

1. Open the **OpenShift Web Console**.
2. Go to **Pipelines** (or **Pipelines** → **Pipelines**).
3. Select project **`packmate-lab`**.
4. Open Pipeline **`packmate-ci`**.
5. Click **Start**.
6. Keep defaults (repository URL and revision **`packmate-v2`**) unless the instructor says otherwise.
7. For workspace **`source`**, choose **VolumeClaimTemplate** with **2 GiB**. **Never select Empty Directory** — clone output would not be visible to later tasks (`test`, `ai-quality-gate`, `validate-manifests`, `build-backend`).
8. Click **Start** again to create the PipelineRun.

> **Pro Tip:**
> Instructor / CLI alternative: `oc create -n packmate-lab -f .tekton/lab/packmate-ci-run.yaml` (already uses a 2Gi VolumeClaimTemplate).

### C.2. Read the pipeline graph and the AI quality gate

Visual path:

**clone → test → ai-quality-gate → validate-manifests → build-backend → publish-result**

[Screenshot required: Pipeline successful]

1. Open task **ai-quality-gate**.
2. Record: number of scenarios, **score**, threshold **0.90**, **PASS** or **FAIL**.

[Screenshot required: AI quality gate PASS]

**Expected result:** Pipeline **Succeeded** (or instructor explains a sandbox limit). Quality gate target is **≥ 0.90** (reference lab score **0.9559**).

**Common error:** Pipelines Operator missing — follow instructor screenshots; the OpenShift AI path remains valid.

**Common error:** `Could not open requirements file: requirements-dev.txt` on task **test** while **clone** succeeded — the PipelineRun used **Empty Directory** for workspace `source`. Re-start with a **2Gi VolumeClaimTemplate** (see `docs/TROUBLESHOOTING.md`).

### C.3. Capture the candidate backend digest

1. Open task **build-backend** (or **publish-result**) and copy result `digest` (or `IMAGE_DIGEST` / `IMAGE_REFERENCE`).

[Screenshot required: Candidate image digest]

**Expected result:** You have a `sha256:...` digest and the PipelineRun name — both required by Module D. This digest is a **candidate**: it exists as an ImageStream tag in `packmate-lab` only, and the live DEV Deployment is **not** auto-replaced.

> **Pro Tip:**
> The Pipeline builds **only the backend**. It does not rebuild the four lab images and must not silently replace any live Deployment — in DEV or PROD — unless you promote on purpose (Module D).

---

## MODULE D — Promotion

**Duration:** 15 minutes
**Objective:** Turn a validated candidate digest into a reviewable pull request against `packmate-v2`.

Promotion is **Git, not `oc`**. `scripts/promote-backend-image.sh` never touches the cluster except to read the PipelineRun and to verify the digest exists in the DEV ImageStream; it edits only `deploy/overlays/prod/kustomization.yaml` (backend `newName`/`digest`) and opens a pull request.

### D.1. Run the promotion script

From the Workbench terminal, using the PipelineRun name from Module C:

```bash
scripts/promote-backend-image.sh \
  --pipelinerun <pipelinerun-name> \
  --namespace packmate-lab \
  --create-pr
```

The script:

1. reads the PipelineRun and refuses to continue unless it **Succeeded**;
2. refuses to continue unless the AI quality gate **status is PASS** and **score ≥ 0.90**;
3. edits **only** the backend image entry in `deploy/overlays/prod/kustomization.yaml` (never the dev overlay, frontend, or MCP images);
4. commits on a new branch `promote/backend-<short-digest>`, pushes it, and opens a pull request to `packmate-v2` (requires `gh auth login` with write access, or a fork — ask your instructor).

**Expected result:** A new pull request appears on GitHub, its diff touching only `deploy/overlays/prod/kustomization.yaml`.

[Screenshot required: Promotion pull request]

### D.2. Review the pull request

Before merging, confirm in the PR description and diff:

- the **PipelineRun** name and **AI quality score** match what you recorded in Module C;
- the **image reference** matches the candidate digest from Module C;
- the diff touches **only** `deploy/overlays/prod/kustomization.yaml` (backend `newName`/`digest`) — nothing else.

**Expected result:** You can explain why this review step exists (it is the only human gate before an image reaches production).

### D.3. Merge

Merge the pull request once reviewed (instructor may reserve merge rights in a shared class repo — see `docs/INSTRUCTOR_GUIDE.md`).

**Expected result:** `packmate-v2` now contains the new backend digest in the PROD overlay. Nothing changed yet in the cluster — that is Module E.

> **Security Note:**
> `promote-backend-image.sh` never pushes directly to `packmate-v2` and never applies `deploy/overlays/prod` to the cluster. Merging Git does not deploy; only Argo CD Sync deploys.

---

## MODULE E — Production

**Duration:** 20 minutes
**Objective:** Sync the merged promotion into `packmate-prod` via Argo CD and confirm the PROD Route serves the new backend.

### E.1. Open Argo CD with OpenShift SSO

1. From the OpenShift console, open the **Argo CD** link / GitOps plugin.
2. Sign in with **OpenShift SSO** (do **not** use an Argo CD admin password).
3. If your instructor just granted you the `packmate-lab-users` group / **promoter** role, **log out and log back in** — Argo CD reads your OpenShift group membership from the OAuth token issued at login, so the new role only takes effect after a fresh SSO session.
4. Open Application **`packmate-prod`** (destination namespace `packmate-prod`).

### E.2. Observe OutOfSync

After the Module D merge, Application `packmate-prod` reconciles against Git and shows the new backend digest is not yet running.

1. Note the current status (**Synced** / **OutOfSync**, **Healthy** / **Progressing**).
2. Wait until status becomes **OutOfSync** (a manual refresh in the UI may be needed).

[Screenshot required: Argo CD OutOfSync]

### E.3. Sync with Prune disabled

1. Click **Sync**.
2. Confirm the sync options shown: **manual** Sync, **Prune disabled**, **self-heal disabled** — this AppProject/Application intentionally never auto-prunes or auto-heals, so an instructor-managed Secret (`packmate-prod-llm`) is never deleted by a Sync.
3. Wait for the Application to report **Synced** and **Healthy**.

[Screenshot required: Argo CD Synced and Healthy]

**Expected result:** You can explain Synced vs OutOfSync, and why Prune stays off in this lab.

> **Security Note:**
> The AppProject `packmate` limits destinations to `packmate-prod` only — no wildcard destinations. Your **promoter** role can `get` and `sync` Application `packmate-prod` only; it cannot delete Applications or reach any other namespace.

### E.4. Verify the PROD Route

1. Get the PROD Route:

```bash
oc get route packmate-frontend -n packmate-prod
```

2. Open the HTTPS URL. This is the **PROD Route** — a different namespace, Secret, and Deployment set from Module B's DEV Route.

[Screenshot required: PROD Route]

3. Run the same Rome scenario you used in the Playground (Module A) and DEV (Module B): a weekend in Rome with a cabin bag.
4. Confirm a structured, streamed response returns with the promoted backend.

**Expected result:** `packmate-prod` answers the Rome scenario, without a Workbench, Pipeline, or Playground in that namespace.

**Common error:** Searching for Argo CD local admin credentials — use OpenShift SSO only.

**Common error:** Application stays **OutOfSync** after group membership was granted — see `docs/TROUBLESHOOTING.md` (SSO group refresh).

---

## MODULE F — Rollback

**Duration:** 10 minutes
**Objective:** Restore the previous backend digest in production through Git, without rebuilding anything.

Rollback is the mirror image of promotion: another pull request, never a direct cluster edit and never a new Pipeline build.

### F.1. Run the rollback script

```bash
scripts/rollback-prod-image.sh --create-pr
```

The script:

1. reads the **current** backend digest from `deploy/overlays/prod/kustomization.yaml`;
2. walks the Git history of that file to find the most recent **different** digest;
3. edits the overlay back to that previous digest, commits on branch `rollback/backend-<short-digest>`, pushes, and opens a pull request to `packmate-v2`.

The script never calls `oc` and never touches the cluster — it only rewrites Git history forward with a new commit.

### F.2. Review and merge

Review the rollback PR exactly like a promotion PR (Module D.2): the diff must touch only the backend `newName`/`digest` in the PROD overlay.

### F.3. Sync

Merge, then repeat Module E.2–E.3: Argo CD Application `packmate-prod` becomes **OutOfSync**, click **Sync**, confirm **Synced / Healthy**.

**Expected result:** `packmate-prod` is back on the previous backend digest. You did **not** rebuild an image, start a Pipeline, or touch DEV to roll back PROD.

> **Pro Tip:**
> The same pattern works for any bad promotion: Git pull request in, Argo CD Sync out. There is no "redeploy previous version" button in the cluster — the source of truth is always the Git history of `deploy/overlays/prod/kustomization.yaml`.

---

## Conclusion

In about two and a half hours you practiced a full OpenShift AI **DEV → PROD** journey:

1. created a **Data Science Project** and **Workbench** in DEV (`packmate-lab`);
2. bootstrapped Packmate from **prebuilt images**, which also prepared PROD (`packmate-prod`) without deploying to it;
3. connected **model + system prompt + MCP** in the Playground;
4. compared the prototype with the **FastAPI** application on the DEV Route;
5. ran an **AI-aware Pipeline** with a deterministic quality gate and captured a candidate digest;
6. **promoted** that digest to production through a reviewed pull request;
7. **synced** the change into `packmate-prod` with Argo CD (Prune disabled) and verified the PROD Route;
8. **rolled back** production through another pull request, without rebuilding anything.

### Skills acquired

- Navigate OpenShift AI (projects, Workbenches, AI asset endpoints, Playground) in a DEV project.
- Register and observe MCP tool calls safely.
- Distinguish prototype vs industrialized Gen AI services, and DEV vs PROD namespaces.
- Launch a Tekton Pipeline from the UI, read an AI quality gate, and capture a candidate digest.
- Promote a validated artifact to production through a Git pull request — never a direct cluster edit.
- Interpret Argo CD Sync / OutOfSync / Healthy and use SSO-based RBAC (no admin password) to Sync PROD.
- Roll back production safely through Git.

Optional topics **not required today:** Argo Rollouts canary demos (`deploy/overlays/prod-canary-annex/`), EvalHub-native evaluation (`EVALHUB_OPTIONAL_NOT_CONFIGURED`).

---

## Annex A — Screenshot checklist

Place each capture immediately after the matching step in your notes or Word export:

1. `[Screenshot required: DEV project]`
2. `[Screenshot required: Workbench configuration]`
3. `[Screenshot required: Repository open in code-server]`
4. `[Screenshot required: AI asset endpoints in packmate-lab]`
5. `[Screenshot required: System instructions]`
6. `[Screenshot required: Playground with model and MCP servers]`
7. `[Screenshot required: Weather MCP tool call]`
8. `[Screenshot required: Baggage MCP tool call]`
9. `[Screenshot required: View code export]`
10. `[Screenshot required: Pipeline successful]`
11. `[Screenshot required: AI quality gate PASS]`
12. `[Screenshot required: Candidate image digest]`
13. `[Screenshot required: Promotion pull request]`
14. `[Screenshot required: Argo CD OutOfSync]`
15. `[Screenshot required: Argo CD Synced and Healthy]`
16. `[Screenshot required: PROD Route]`

---

## Annex B — Optional extensions

| Extension | Status in main lab |
|-----------|--------------------|
| Argo Rollouts canary (`deploy/overlays/prod-canary-annex/`) | Optional annex — not required |
| EvalHub evaluation | Optional — `EVALHUB_OPTIONAL_NOT_CONFIGURED` if no instance |
| Custom model endpoint | Created automatically by `make bootstrap` (`CREATE_MODEL_CUSTOM_ENDPOINT=true`), DEV only |
| Historical Streamlit / S2I path | Retired — not part of Packmate v2 |

See also: `docs/ARCHITECTURE.md`, `docs/REPRODUCE_SANDBOX.md`, `docs/INSTRUCTOR_GUIDE.md`, `docs/OPERATIONS.md`, `docs/DOCX_ASSEMBLY_PLAN.md`.
