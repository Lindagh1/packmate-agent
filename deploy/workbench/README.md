# Packmate lab Workbench (code-server)

OpenShift AI **Workbench** for hands-on Packmate development. The lab uses a Data Science Project (DSP) named **`packmate-lab`** and a **code-server** (or VS Code–compatible) Workbench where you clone this repository and run backend, frontend, and MCP servers locally.

> **This directory is documentation plus an example only.** Packmate CI does **not** apply these manifests. Create the Workbench through the OpenShift AI dashboard unless your instructor explicitly applies the YAML.

## Prerequisites

- OpenShift AI / RHODS with **Workbenches** component Ready (`default-workbenches`).
- Notebook CRD present: `kubeflow.org/v1` (`oc get crd notebooks.kubeflow.org`).
- Cluster login and permission to create a Data Science Project and Workbench in your namespace.

## Step 1 — Create Data Science Project `packmate-lab`

**Primary path: UI**

1. Open **OpenShift AI** → **Data Science Projects**.
2. Click **Create data science project**.
3. Name: **`packmate-lab`**.
4. Create the project and note the namespace (often matches the project name).

**Optional:** Your platform may require DSP annotations on the namespace. Follow your cluster’s OpenShift AI docs if the UI prompts for additional settings.

## Step 2 — Create a code-server Workbench

**Primary path: UI**

1. Inside **`packmate-lab`**, open **Workbenches** → **Create workbench**.
2. **Name:** e.g. `packmate-dev` or `code-server`.
3. **Image:** choose a **code-server** or **VS Code** workbench image from your catalog (ODH/RHODS). Examples vary by release — pick the image your instructor documents.
4. **Resources (reasonable starting point):**
   - CPU: **1** (request) / **2** (limit)
   - Memory: **4 Gi** (request) / **8 Gi** (limit)
   - Storage: **20 Gi** (adjust for your lab)
5. Create the Workbench and wait until it is **Running**.
6. Click **Open** to launch the IDE in the browser.

### Example YAML (reference only — do not apply from CI)

[`notebook-code-server.example.yaml`](notebook-code-server.example.yaml) shows a `Notebook` CR (`kubeflow.org/v1`) with placeholder image and resource fields. Replace the **`PLACEHOLDER`** image with your cluster’s code-server image before any manual apply. Instructors may apply it; students should prefer the UI.

```bash
# Example only — review and edit first; not run by Packmate pipelines
# oc apply -f deploy/workbench/notebook-code-server.example.yaml -n packmate-lab
```

## Step 3 — Clone the Packmate repository

**Inside the Workbench terminal** (not via a Kubernetes Secret):

```bash
cd ~/projects   # or your preferred workspace path
git clone https://github.com/example/packmate-agent.git
cd packmate-agent
git checkout packmate-v2
```

Use your fork URL if applicable. For private repos, configure Git credentials in the Workbench (SSH key or personal access token) — **do not** commit tokens or store clone URLs with embedded passwords in manifests.

## Step 4 — Local development in the Workbench

Typical flow:

```bash
# Backend (local tool mode)
cp .env.example .env
# Set LITELLM_API_KEY and PACKMATE_TOOL_MODE=local for in-process tools
cd backend && python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -v

# MCP servers (optional, separate terminals)
cd mcp-servers/weather && pip install -r requirements-dev.txt && pytest -v
cd mcp-servers/baggage-policy && pip install -r requirements-dev.txt && pytest -v

# Frontend
cd frontend && npm ci && npm run dev
```

Set `PACKMATE_TOOL_MODE=mcp` when pointing the backend at in-cluster MCP Routes/Services (see [`deploy/README.md`](../README.md)).

## Related

- MCP registration for Gen AI Playground: [`deploy/examples/mcp-registration/`](../examples/mcp-registration/)
- OpenShift AI capability audit: [`docs/implementation/OPENSHIFT_AI_CAPABILITIES.md`](../../docs/implementation/OPENSHIFT_AI_CAPABILITIES.md)
- Deployment manifests (applied via GitOps, not from this folder): [`deploy/`](../)
