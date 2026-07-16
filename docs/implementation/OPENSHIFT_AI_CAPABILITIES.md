# OpenShift AI capabilities audit (Packmate v2)

**Audit date:** 2026-07-16  
**Cluster access mode:** read-only (`oc get` / `api-resources` / `crd` / `csv`)  
**No apply, no Operator install, no real deployment performed during this audit.**

## Summary

| Item | Detected value |
|------|----------------|
| OpenShift AI release | **OpenShift AI Self-Managed 3.4.2** (`rhods-operator.3.4.2`) |
| DataScienceCluster | `default-dsc` — Ready |
| DSCInitialization | `default-dsci` — Ready |
| Model in lab | `llama-32-3b-instruct` InferenceService in `my-first-model` (Ready) |
| Pipelines Operator | OpenShift Pipelines **1.22.4** (Succeeded) |
| Argo CD / GitOps Operator | **Absent** (no Application/AppProject CSV/API observed) |
| Argo Rollouts | **Absent** (no Rollout CRD/API observed) |

## Legend

| Status | Meaning |
|--------|---------|
| **Available and verified** | API/Operator/resource observed Ready or Succeeded on this cluster |
| **Available but untested** | API or component Managed/present; Packmate has not exercised it end-to-end |
| **API or Operator absent** | Not found via `oc api-resources`, CRDs, CSV, or pods |
| **Technology Preview (possible)** | Present in product docs/components; treat as TP unless Red Hat marks GA for your install |
| **Manual UI step required** | Reliable path is dashboard/UI (or cluster-admin ConfigMap); not fully declarative for participants |

---

## Platform components (DataScienceCluster)

Observed `spec.components` / `status.components` management states:

| Component | managementState | Audit status |
|-----------|-----------------|--------------|
| dashboard | Managed | Available and verified (pods Running in `redhat-ods-applications`) |
| workbenches | Managed (`default-workbenches` Ready) | Available and verified (API); no Notebook CRs created by Packmate |
| kserve | Managed | Available and verified (`InferenceService` Ready) |
| trustyai | Managed | Available but untested (operator Running; no TrustyAIService/EvalHub instances) |
| llamastackoperator | Managed (`default-llamastackoperator` Ready) | Available but untested (no LlamaStackDistribution instances) |
| aipipelines | Managed | Available but untested |
| modelregistry | Managed | Available but untested |
| feastoperator | Managed | Available but untested |
| ray | Managed | Available but untested |
| trainer / trainingoperator | Managed | Available but untested |
| kueue | Removed | API or Operator absent (component Removed) |
| mlflowoperator | Removed | API or Operator absent as Managed component (MLflowOperator API type exists; no MLflow pods observed) |
| sparkoperator | Removed | API or Operator absent (component Removed) |

---

## Model serving and AI asset endpoints

| Capability | Evidence | Status | Notes for Packmate |
|------------|----------|--------|--------------------|
| InferenceService / KServe | CRD + Ready ISVC `llama-32-3b-instruct` | Available and verified | In-cluster URL: `http://llama-32-3b-instruct-predictor.my-first-model.svc.cluster.local:8080/v1` |
| ServingRuntime | Present in `my-first-model` | Available and verified | vLLM runtime |
| LLMInferenceService APIs | CRDs present | Available but untested | Not used by current Packmate manifests |
| AI asset endpoints (dashboard) | Dashboard pods Running; product feature of OAI 3.x | Available but untested | **Manual UI step required** to discover/register endpoints |
| Gen AI Playground | Documented for OAI 3.4; dashboard present | Available but untested | **Manual UI step required**; MCP registration via admin ConfigMap |

---

## MCP (Model Context Protocol) and Gen AI Playground

| Capability | Evidence | Status | Notes |
|------------|----------|--------|-------|
| MCP-named Kubernetes CRDs | None matching `mcp` / `modelcontext` (except MachineConfigPool abbreviation) | API or Operator absent as first-class MCP CR | Registration is not a Packmate CRD |
| Platform MCP ConfigMap | `gen-ai-aa-mcp-servers` in `redhat-ods-applications` | **Not found** | Must be created by cluster admin for Playground discovery |
| Official registration mechanism (OAI 3.4 docs) | ConfigMap `gen-ai-aa-mcp-servers` with JSON `{ "url", "description" }` per server key | Available but untested | **Manual / cluster-admin step**; Packmate will ship example YAML only |
| Transport expected by Playground | Streamable HTTP endpoint URL in ConfigMap (community + OAI 3.x guidance); SSE optional for inspectors | Available but untested | Decision recorded in `DECISIONS.md` after Phase B: prefer **Streamable HTTP** at `/mcp` |
| Llama Stack Operator | Managed, Ready | Available but untested | No `LlamaStackDistribution` instances |
| Playground tool authorization | UI flow in Gen AI Playground | Manual UI step required | Participants authorize MCP tools in UI |

**Honest gap:** This audit did **not** open the dashboard UI or successfully call a registered MCP from Playground. Support is inferred from Operator version **3.4.2**, docs, and platform ConfigMap contract.

---

## Workbenches / notebooks

| Capability | Evidence | Status | Notes |
|------------|----------|--------|-------|
| Workbenches component | `default-workbenches` Ready | Available and verified | |
| Notebook CRD (`kubeflow.org`) | Present (`v1`, `v1alpha1`, `v1beta1`) | Available but untested | Declarative example may be generated under `deploy/workbench/` |
| Existing Notebooks | `oc get notebooks -A` → none | Available but untested | Creating `packmate-lab` DSP + code-server is a **manual UI** lab step unless instructor applies YAML |

---

## TrustyAI / EvalHub / evaluations

| Capability | Evidence | Status | Notes |
|------------|----------|--------|-------|
| TrustyAI operator | Pod Running; component Managed; versions reported in DSC (operator v1.37.0, service v0.28.0, LMEval, Guardrails) | Available and verified (operator) | |
| TrustyAIService CRD | Present | Available but untested | `oc get trustyaiservices -A` → none |
| EvalHub CRD | `evalhubs.trustyai.opendatahub.io` present | Available but untested | `oc get evalhubs -A` → none |
| LMEvalJob CRD | Present | Available but untested | No jobs observed |
| GuardrailsOrchestrator / NemoGuardrails | CRDs present | Available but untested | Out of Packmate MVP scope unless needed |
| MLflow as Managed DSC component | `mlflowoperator: Removed` | API or Operator absent (not Managed) | Do not claim MLflow tracking in lab unless activated |

**Honest gap:** No EvalHub or TrustyAIService instance was created or executed. Packmate will prepare datasets/configs and document activation; PR pipelines must not hard-fail when EvalHub is absent.

---

## CI/CD related Operators (outside DSC)

| Capability | Evidence | Status |
|------------|----------|--------|
| OpenShift Pipelines / Tekton | CSV Succeeded 1.22.4; controller pods Running | Available and verified |
| Argo CD / OpenShift GitOps | No matching CSV; Application CRDs previously absent | API or Operator absent |
| Argo Rollouts | No Rollout API in `api-resources` grep | API or Operator absent |

GitOps and Rollouts manifests in this repo remain **generated + client dry-run** material until Operators are installed by the platform team.

---

## Steps that require manual UI (or admin) action

1. Create Data Science Project `packmate-lab` (or equivalent namespace + DSP annotations).
2. Create code-server Workbench (image, CPU, memory, storage).
3. Open Workbench and clone the repository.
4. Browse **AI asset endpoints** for `llama-32-3b-instruct`.
5. Deploy MCP Routes/Services (GitOps/manifests) then register URLs in `gen-ai-aa-mcp-servers` (**cluster admin**).
6. Open **Gen AI Playground**, select model, authorize MCP tools, craft system instructions, export config.
7. Create/open EvalHub or TrustyAIService instances if the lab wants native AI evals.
8. Install OpenShift GitOps / Argo Rollouts if progressive delivery demos must run on-cluster (currently absent).

---

## Implications for Packmate phases B–I

- Build real MCP servers with **Streamable HTTP** primary transport; document SSE as optional debug path.
- Keep traveler profile **in-app only** (privacy); do not publish as shared MCP.
- Ship EvalHub/TrustyAI **preparatory** assets; gate Tekton deterministically; make EvalHub optional.
- Keep existing Kustomize / Tekton / Argo CD / Rollouts; adapt for MCP images/URLs without requiring absent Operators to be present for PR validation.
- Document honestly: local tests and dry-runs vs cluster read-only observations vs undeployed features.
