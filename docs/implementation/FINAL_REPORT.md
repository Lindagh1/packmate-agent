# Packmate v2 final report — OpenShift AI recenter

Date: 2026-07-16  
Branch: `packmate-v2`  
Status: **local implementation + cluster read-only audit complete — no real cluster apply, no git push, no Operator install**

## Architecture finale

- **OpenShift AI path:** DSP `packmate-lab` → Workbench → AI asset endpoints → MCP registration → Gen AI Playground → FastAPI/React → Tekton/GitOps/Rollouts
- Frontend: React + PatternFly
- Backend: FastAPI with `PACKMATE_TOOL_MODE=local|mcp`
- MCP servers: `weather-mcp`, `baggage-policy-mcp` (Streamable HTTP `/mcp`)
- Traveler profile: in-app only (never shared MCP)
- Quality: Level 1 deterministic evals mandatory; Level 2 TrustyAI/EvalHub preparatory/optional
- Delivery artifacts retained: Kustomize, Tekton PaC, Argo CD apps, Argo Rollouts canary (backend), security-check

## Commits locaux (recenter phases)

| Subject |
|---------|
| Document OpenShift AI capabilities audit |
| Add Packmate MCP servers |
| Integrate MCP tools with Packmate backend |
| Add OpenShift AI Playground workflow |
| Add TrustyAI and EvalHub evaluation workflow |
| Align CI CD with OpenShift AI and MCP architecture |
| Recenter Packmate lab on OpenShift AI |

(Plus earlier Packmate v2 lab commits on the same branch.)

## Ce qui a été testé localement

| Suite | Result (this recenter) |
|-------|------------------------|
| Backend pytest | **96 passed** (includes MCP adapter tests) |
| MCP weather pytest | **6 passed** |
| MCP baggage-policy pytest | **9 passed** |
| Deterministic quality gate | Expected PASS ~0.9559 @ 0.90 (re-run in final validation) |
| Podman build weather-mcp / baggage-policy-mcp | PASS (earlier in Phase B) |
| Frontend / full four-image rebuild | Re-run in final validation |

## Ce qui a été testé par dry-run

- `oc kustomize` + `oc apply --dry-run=client` including MCP Deployments/Services/Routes/NetworkPolicies
- No `oc apply` without dry-run
- No real PipelineRun / Argo sync / Rollout promotion

## Observé en lecture seule sur le cluster

| Capability | Status |
|------------|--------|
| OpenShift AI 3.4.2 | Verified (CSV + DSC Ready) |
| Workbenches / Notebooks API | Available |
| InferenceService llama-32-3b-instruct | Ready |
| TrustyAI operator | Running; CRDs for EvalHub/LMEval/TrustyAIService present |
| EvalHub / TrustyAIService instances | **None** |
| `gen-ai-aa-mcp-servers` ConfigMap | **Absent** |
| Llama Stack Operator | Ready; no distribution instances |
| Tekton / Pipelines | Present 1.22.4 |
| Argo CD / Rollouts Operators | **Absent** |

## Non déployé réellement

- Data Science Project / Workbench
- MCP pods / Routes
- Playground ConfigMap registration
- EvalHub / TrustyAIService
- Packmate app namespaces
- Tekton pipelines on-cluster
- Argo CD Applications / Rollouts

## TrustyAI / EvalHub

- **APIs available, instances absent**
- Preparatory assets under `evaluations/`
- Optional Tekton step skips cleanly when absent
- **EvalHub was not executed**

## MCP / Playground support

- Transport decision: **Streamable HTTP** at `/mcp` (documented in `DECISIONS.md`)
- Registration mechanism: platform ConfigMap (not MCP CRD)
- Playground end-to-end tool calls: **not verified in UI** (ConfigMap absent; no apply)

## Décisions restant à valider humainement

1. Exact Workbench catalog image name for the classroom.
2. Admin creation of `gen-ai-aa-mcp-servers` with real Route hosts.
3. Whether to stand up EvalHub for the live session.
4. Install OpenShift GitOps + Argo Rollouts if live progressive delivery is required.
5. Production digest promotion registry credentials (Secrets out of Git).

## Manifests adaptés

- `deploy/base/mcp-weather`, `deploy/base/mcp-baggage`
- Backend ConfigMap `PACKMATE_TOOL_MODE=mcp` + NetworkPolicy egress to MCP
- Overlay image entries for four images
- `.tekton` PR/push extended for MCP tests and four builds
- Example registration + workbench YAML (not applied)
