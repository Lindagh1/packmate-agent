# Packmate v2 — final audit report

**Audit date:** 2026-07-16 (final audit pass)
**Branch:** `packmate-v2`
**Working tree before report edit:** clean; ahead of `origin/packmate-v2` by 17 commits
**Scope:** local tests, Podman builds, Kustomize, dry-runs, read-only `oc` — **no apply, no push, no Operator install, no pipeline run, no MCP deploy**

---

## Architecture finale

```
OpenShift AI (DSP packmate-lab / Workbench / AI assets / Gen AI Playground)
        │
        ├─ model: llama-32-3b-instruct (my-first-model)
        │
        ├─ MCP (Streamable HTTP /mcp): weather-mcp, baggage-policy-mcp
        │     └─ registered via ConfigMap gen-ai-aa-mcp-servers (admin; absent on cluster)
        │
        └─ Packmate app
              ├─ React frontend (Route)
              ├─ FastAPI backend (PACKMATE_TOOL_MODE=local|mcp)
              │     traveler_profile: in-app only (never shared MCP)
              └─ delivery: Tekton (4 images) → GitOps → Argo CD → Rollouts canary (backend)
```

Repository pillars: `mcp-servers/`, `playground/`, `evaluations/`, `deploy/` (incl. MCP + workbench example), `.tekton/`, `gitops/`, `docs/`.

---

## Commits locaux (recenter + lab)

| SHA | Subject |
|-----|---------|
| `4447a45` | Recenter Packmate lab on OpenShift AI |
| `7840526` | Align CI CD with OpenShift AI and MCP architecture |
| `93b2e55` | Add TrustyAI and EvalHub evaluation workflow |
| `250451c` | Add OpenShift AI Playground workflow |
| `3c4658d` | Integrate MCP tools with Packmate backend |
| `ac3aef1` | Add Packmate MCP servers |
| `45b8359` | Document OpenShift AI capabilities audit |
| (+ earlier v2 lab commits through documentation / security / Rollouts / Tekton / manifests / OTel / evals / UI / compose) |

Sous-agents intégrés via commits Playground (`250451c`), EvalHub (`93b2e55`), Workbench+CI (`7840526`).

---

## Nombre total de tests réussis (cette passe)

| Suite | Result |
|-------|--------|
| Backend pytest | **96 passed** |
| Frontend lint | **PASS** (`eslint .`) |
| Frontend vitest | **18 passed** |
| Frontend build | **PASS** |
| MCP weather | **6 passed** (logic + protocol + structured errors) |
| MCP baggage-policy | **9 passed** (rules + protocol + disclaimer) |
| Backend MCP privacy/timeout/network subset | **5 passed** |
| **Total automated tests counted** | **96 + 18 + 6 + 9 = 129** (privacy subset already included in the 96) |

---

## Quality gate

| Item | Result |
|------|--------|
| Mode | deterministic |
| Threshold | 0.90 |
| Overall score | **0.9559** |
| Scenarios | 16 |
| Verdict | **QUALITY GATE PASSED** |

---

## Images construites (Podman, tag `:audit`)

| Image | Result | Size | Base (FROM) | Runtime USER | Port |
|-------|--------|------|-------------|--------------|------|
| `localhost/packmate-backend:audit` | PASS | ~1.1 GB | `ubi9/python-312:latest` | `1001` | `8080/tcp` |
| `localhost/packmate-frontend:audit` | PASS | ~325 MB | build `ubi9/nodejs-22`; runtime `ubi9/nginx-126` | `1001` | `8080/tcp` (+8443) |
| `localhost/packmate-weather-mcp:audit` | PASS | ~1.1 GB | `ubi9/python-312:latest` | `1001` | `8080/tcp` |
| `localhost/packmate-baggage-policy-mcp:audit` | PASS | ~1.1 GB | `ubi9/python-312:latest` | `1001` | `8080/tcp` |

---

## Manifests validés

| Check | Result |
|-------|--------|
| `oc kustomize` dev/prod | OK |
| `scripts/validate-manifests.sh` | **PASS** (dev 20 docs, prod 25 docs) |
| Dev contents | frontend, backend, weather-mcp, baggage-policy-mcp; 4 SA; 4 Services; 3 Routes; 4 NetworkPolicies; probes+resources; `PACKMATE_TOOL_MODE` + MCP URLs in ConfigMap |
| Prod contents | same MCP/app + **Rollout** backend, **stable + canary** Services, PDBs, AnalysisTemplates |
| Prod forbidden patterns | **none** (`:latest`, privileged, allowPrivilegeEscalation, cluster-admin, plaintext Secret data, API keys, ImageStream triggers) |
| `scripts/security-check.sh` | **All security checks passed** |
| `git diff --check` | **clean** (exit 0) |

### Dry-run

| Command | Result |
|---------|--------|
| `oc apply --dry-run=client` **dev** | **PASS** — all core resources mapped |
| `oc apply --dry-run=client` **prod** | Core resources OK; **Rollout + AnalysisTemplate** fail mapping — Argo Rollouts CRDs **absent** |
| `oc apply --dry-run=server` **dev** | Fails: namespace `packmate-dev` **not found** (expected; not created) |
| `oc apply --dry-run=server` **prod** | Namespace `packmate-prod` not found + Rollout/AnalysisTemplate CRDs absent |

---

## Fonctionnalités OpenShift AI réellement détectées (lecture seule)

| Capability | Status |
|------------|--------|
| OpenShift AI Self-Managed **3.4.2** (`rhods-operator`) | Detected / Succeeded |
| DataScienceCluster Ready; Workbenches Managed | Detected |
| KServe InferenceService `llama-32-3b-instruct` | Previously verified Ready (not re-applied) |
| TrustyAI component Managed; CRDs EvalHub / TrustyAIService / LMEval | **APIs present** |
| OpenShift Pipelines **1.22.4** | Detected / Succeeded |
| Notebook CRD (`kubeflow.org`) | Present |
| Llama Stack Operator API | Present (component Managed) |

Aligned with `docs/implementation/OPENSHIFT_AI_CAPABILITIES.md` — **no correction required** to that document this pass.

---

## Fonctionnalités seulement documentées (non exécutées E2E)

- Gen AI Playground tool calls with Packmate MCP
- AI asset endpoints UI walkthrough
- Workbench / DSP `packmate-lab` creation
- Playground export → FastAPI handoff
- Tekton PipelineRuns on-cluster
- Argo CD sync / Argo Rollouts promote
- TrustyAI/EvalHub evaluation jobs

---

## Fonctionnalités non disponibles / absentes sur ce cluster

| Item | Evidence |
|------|----------|
| OpenShift GitOps / Argo CD Application APIs | No CSV; no `applications.argoproj.io` |
| Argo Rollouts CRDs | No `rollouts.argoproj.io`; dry-run mapping errors |
| EvalHub / TrustyAIService **instances** | `oc get` → none |
| `gen-ai-aa-mcp-servers` ConfigMap | **NotFound** |
| MLflow as Managed DSC component | `mlflowoperator: Removed` |

---

## Éléments non déployés

Namespaces Packmate, MCP pods/Routes, Workbench/DSP, Playground ConfigMap, EvalHub instances, Secrets, real Tekton runs, Argo Applications, Rollouts.

---

## Participant guide checklist

`docs/PARTICIPANT_GUIDE.md` Modules 1–10 cover: DSP → Workbench → clone → AI assets → MCP register → Playground + system instructions + export → FastAPI → deterministic + TrustyAI/EvalHub → Tekton → Argo CD → canary/rollback → observability/security. **Confirmed present.**

---

## Actions manuelles encore nécessaires

1. Créer DSP `packmate-lab` + Workbench code-server (UI).
2. Admin: déployer MCP + ConfigMap `gen-ai-aa-mcp-servers` avec URLs `/mcp`.
3. Exercer Playground (outil MCP) et exporter la config.
4. Créer namespaces + Secret `packmate-llm` hors Git si apply réel.
5. Optionnel: EvalHub/TrustyAIService; installer GitOps + Rollouts pour démo live.
6. Valider image Workbench catalogue de la salle.

---

## Risques restants

1. Prod Rollout inutilisable tant que l’Operator Rollouts est absent.
2. Playground MCP inutilisable tant que ConfigMap d’enregistrement est absente.
3. EvalHub non exécutable sans instance.
4. Server dry-run bloqué par namespaces absents (volontaire).
5. UBI `:latest` uniquement sur **FROM** des Containerfiles (bases), pas dans les manifests deploy.

---

## Verdict d’audit

**Packmate v2 est cohérent localement** (tests, quality gate, 4 images, manifests, security-check).
**Le parcours OpenShift AI est documenté et partiellement détecté sur le cluster**, mais **non validé par un déploiement ou une session Playground réelle**.
