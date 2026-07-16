# Instructor guide

## Detected platform (read-only audit 2026-07-16)

| Item | Value |
|------|-------|
| OpenShift AI | **Self-Managed 3.4.2** (`rhods-operator.3.4.2`) |
| DataScienceCluster | `default-dsc` Ready |
| Workbenches | Managed / Ready |
| KServe / model | `llama-32-3b-instruct` Ready in `my-first-model` |
| TrustyAI | Operator Managed (pods Running); **no** TrustyAIService/EvalHub instances |
| Llama Stack Operator | Managed / Ready; no LlamaStackDistribution instances |
| Pipelines | OpenShift Pipelines **1.22.4** |
| OpenShift GitOps / Argo CD | **Absent** |
| Argo Rollouts | **Absent** |
| Playground MCP ConfigMap `gen-ai-aa-mcp-servers` | **Absent** at audit |

Details: `docs/implementation/OPENSHIFT_AI_CAPABILITIES.md`.

## Operators / features required for the full story

| Capability | Required? | Notes |
|------------|-----------|-------|
| OpenShift AI (dashboard, workbenches, KServe) | Yes | Present |
| Model `llama-32-3b-instruct` | Yes | Present |
| MCP registration ConfigMap | Yes for Playground tools | Instructor/admin creates example from `deploy/examples/mcp-registration/` |
| TrustyAI / EvalHub instance | Optional Level 2 | CRDs present; create only if demoing EvalHub |
| OpenShift Pipelines | Yes for live Tekton | Present |
| OpenShift GitOps | Optional live sync | Manifests ready; Operator absent |
| Argo Rollouts | Optional live canary | Manifests ready; Operator absent |

## Resources to prepare before the session

1. Confirm model InferenceService Ready.
2. Create Data Science Project `packmate-lab` (or let Module 2 create it).
3. Prefetch Workbench image (code-server / VS Code + Python).
4. (Admin) Deploy MCP Routes or apply Packmate overlay when ready for live demo — **not** required for local validation.
5. (Admin) Create `gen-ai-aa-mcp-servers` with real Route URLs ending in `/mcp`.
6. Optional: create EvalHub + TrustyAIService from `evaluations/*/`.
7. Do **not** commit tokens; create `packmate-llm` Secret only in-cluster when applying (instructor).

## Model and MCP

- Model: `llama-32-3b-instruct` — AI asset endpoints + in-cluster `/v1`
- MCP: `weather-mcp`, `baggage-policy-mcp` — Streamable HTTP `/mcp`
- Traveler profile: **not** an MCP

## Playground configuration

- System instructions: `playground/system-instructions.md`
- Prompts: `playground/test-prompts.json`
- Expected tools: `playground/expected-tool-calls.json`

## EvalHub / TrustyAI

- Preparatory YAML under `evaluations/`
- `evaluations/scripts/run_evalhub_optional.sh` exits 0 when absent
- Deterministic gate remains mandatory (`backend/evals` / `evaluations/scripts/run_deterministic_gate.sh`)

## Workbench preparation

- Prefer UI creation; example CR: `deploy/workbench/notebook-code-server.example.yaml` (not applied by CI)
- Clone: `https://github.com/Lindagh1/packmate-agent.git` → `git switch packmate-v2`

## Pre-session validation

```bash
oc get datasciencecluster
oc get inferenceservice -n my-first-model
oc get csv -A | grep rhods-operator
backend/.venv/bin/pytest -q
cd mcp-servers/weather && pytest -q
cd mcp-servers/baggage-policy && pytest -q
evaluations/scripts/run_deterministic_gate.sh
./scripts/validate-manifests.sh
./scripts/security-check.sh
```

## Reset procedure

1. Delete participant Workbench PVCs if disk full (UI).
2. Reset Playground chat / reload exported instructions.
3. Do not delete shared model namespace.
4. Optional: delete lab namespace Deployments only if instructor owns that namespace.

## Solutions / optional by version

- If Playground MCP UI differs slightly on 3.4.x patches, follow Red Hat “Configuring MCP servers” docs for ConfigMap shape.
- If GitOps/Rollouts Operators appear later, existing `gitops/` and prod Rollout manifests apply without redesign.
- MLflow DSC component was **Removed** — do not depend on MLflow unless activated.

## Duration

- Full lab: 4–6 hours (`docs/PARTICIPANT_GUIDE.md` Modules 1–10)
- Demo only: 20–30 minutes (`docs/DEMO_SCRIPT.md`)
