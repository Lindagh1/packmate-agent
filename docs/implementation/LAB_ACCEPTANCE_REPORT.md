# Lab acceptance report — Packmate v2

**Date:** 2026-07-22 (DEV path acceptance run); **DEV→PROD addendum added 2026-07-23** (see § 12)
**Branch:** `packmate-v2`
**Commit tested (pre-acceptance docs WIP):** `b4a170e` (+ local doc/RBAC fixes committed with this report)
**Verdict (2026-07-22, DEV path only):** **LAB_READY_WITH_MANUAL_VISUAL_CHECKS**
**Verdict (2026-07-23, DEV→PROD scope):** **PROD PROMOTION PATH IMPLEMENTED, PENDING LIVE-CLUSTER RE-VALIDATION** — see § 12 for exactly what was and was not re-checked in this pass.

---

## 13. Addendum — portable Pipeline Python + RHOAI deps (2026-07-30)

| Item | Result |
|------|--------|
| Template | `.tekton/lab/packmate-ci.yaml.tpl` with `__PACKMATE_PIPELINE_PYTHON_IMAGE__` / CLI placeholders as Pipeline param defaults |
| Rendered | `.generated/tekton/packmate-ci.yaml` (gitignored) |
| Resolve | `scripts/resolve-pipeline-python-image.sh` → internal digest of `openshift/python:3.12-ubi9` |
| Deps | `mcp==1.27.2`, `json-repair==0.25.3`, `pydantic==2.13.1` (RHOAI 3.4 cpu-ubi9 x86_64) |
| MCP API | `streamable_http_client` |
| Check | `make verify-python-deps` (in-cluster source of truth) |
| Workbench | `scripts/setup-workbench-repository.sh` clones into `/opt/app-root/src/packmate-agent` |
| Bootstrap | resolve → in-cluster deps → render → validate → apply rendered Pipeline |

Do not commit rendered digests. Participants never hand-edit Tekton YAML or requirements.

| Item | Value |
|------|-------|
| Acceptance namespace | `packmate-acceptance-20260722-1419` |
| Config file | `/tmp/packmate-acceptance-20260722-1419.env` (not committed; via `PACKMATE_CONFIG`) |
| Images | Public GHCR digests (`lab-v1.0.0`) |
| Preserved | `packmate-lab`, `packmate-repro`, `my-first-model` |

### GHCR digests used

| Component | Reference |
|-----------|-----------|
| Backend | `ghcr.io/lindagh1/packmate-backend@sha256:c10fbeb6fbd63ca478e1b8231ddf874ec7ee1c80663b641d802ffca6e826849f` |
| Frontend | `ghcr.io/lindagh1/packmate-frontend@sha256:d6ade3f968a8e1057cb7e846a6dbded4c0f45f8b1780d16d5dd9d76b55d08305` |
| Weather MCP | `ghcr.io/lindagh1/packmate-weather-mcp@sha256:f4a8dcb5407e3bf9dfbb2e494ccb7fc478a377ce074ef2b3f219b55d57443006` |
| Baggage MCP | `ghcr.io/lindagh1/packmate-baggage-policy-mcp@sha256:17432265c056241b6ce89368f9cd1fe0ff5165d3316ef80116285b78b9d58d1a` |

Anonymous `skopeo inspect` on all four: **OK**.

---

## 2. Participant command path

| Check | Result |
|-------|--------|
| Makefile targets `preflight` `bootstrap` `verify` `cleanup` `test` `render` `promote` | Present |
| Guide paths (`playground/system-instructions.md`, `test-prompts.json`, `promote-backend-image.sh`, `sandbox.env.example`) | Exist |
| Secrets in Git | None required; `config/sandbox.env` gitignored |
| `make … CONFIG=` | **Not wired** — scripts use `PACKMATE_CONFIG` or `config/sandbox.env` (documented in guide Pro Tip) |

---

## 3. Acceptance namespace results

| Step | Result |
|------|--------|
| `make preflight` | **OK** (exit 0) |
| `make bootstrap` | **OK** (exit 0) |
| `make verify` | **OK** (exit 0) |
| DSP labels | PASS |
| Weather + Baggage MCP Running | PASS |
| `/health` MCP Routes | HTTP 200 |
| `/mcp` | Endpoint reachable (HTTP 406 on empty POST — expected without MCP session headers) |
| Backend / frontend Running | PASS |
| Frontend Route | HTTP 200 |
| SSE | `started` → heartbeats → `completed` |
| Metrics `packmate_*` | PASS |
| Images | All GHCR digests (no internal `packmate-lab` registry dependency) |

---

## 4. Playground prerequisites (technical)

| Check | Result |
|-------|--------|
| InferenceService `llama-32-3b-instruct` Ready | True |
| `/v1/models` | OK (id `llama-32-3b-instruct`) |
| ConfigMap MCP `Packmate-Weather-MCP` | Present |
| ConfigMap MCP `Packmate-Baggage-Policy-MCP` | Present |
| `playground/system-instructions.md` | Present (50 lines) |
| `playground/test-prompts.json` | 10 prompts |
| Guide steps: project, model, MCP, copy/paste prompt, New chat, View code | Documented |

**UI ClickOps:** `MANUAL_VISUAL_CHECK` (not automated).

---

## 5. Pipeline

| Item | Value |
|------|-------|
| Failed run (RBAC) | `packmate-ci-acceptance-20260722-142535` — build forbidden without `instantiatebinary` |
| Successful run | **`packmate-ci-acceptance-20260722-142839`** |
| Succeeded | **True** |
| clone / test / ai-quality-gate / validate-manifests / build-backend / publish-result | All Succeeded |
| Quality gate | score **0.9559**, scenarios **16**, status **PASS**, threshold 0.90 |
| Backend digest produced | `sha256:a0a658c7ff981e56de4ed796030f6774d77e5e6a2d8a9ffc1cfdba1f9983c767` |
| Live Deployment auto-replaced? | **No** — still GHCR `c10fbeb6…` |
| `packmate-lab` backend | Unchanged (internal digest `c057f9f1…`) |

**Minimal fix applied:** Role `packmate-pipeline` now includes `buildconfigs/instantiate` and `buildconfigs/instantiatebinary` (+ imagestream update verbs). Demonstrated blocker for the Pipeline module (Module 9 in the pre-restructure guide; Module C — CI in the current `docs/PARTICIPANT_GUIDE.md`) on a fresh namespace.

---

## 6. Argo CD

| Check | Result |
|-------|--------|
| Application | `packmate-lab` in `openshift-gitops` |
| Destination | `packmate-acceptance-20260722-1419` |
| Repository | `https://github.com/Lindagh1/packmate-agent.git` @ `packmate-v2` |
| Automated prune / selfHeal | Absent (manual sync) |
| Sync | Manual → **Synced** |
| Health | **Healthy** |
| `packmate-lab` workloads | Still Running (not pruned) |

---

## 7. Repository tests

| Suite | Result |
|-------|--------|
| Backend pytest | **125 passed** |
| Weather MCP | **6 passed** |
| Baggage MCP | **9 passed** |
| Frontend (Podman node:22) | **26 tests** + build OK |
| Quality gate | **0.9559 PASS** |
| security-check | **PASS** |
| `git diff --check` | Trailing whitespace in guide **fixed** |

---

## 8. Guide module audit (`docs/PARTICIPANT_GUIDE.md`)

| Module | Status |
|--------|--------|
| 0 Before you start | PASS |
| 1 Discover Packmate | PASS |
| 2 Data Science Project | PASS + MANUAL_VISUAL_CHECK |
| 3 Workbench | PASS + MANUAL_VISUAL_CHECK |
| 4 Clone and bootstrap | PASS (PACKMATE_CONFIG tip added) |
| 5 AI asset endpoints | PASS + MANUAL_VISUAL_CHECK |
| 6 Playground | PASS (prereqs) + MANUAL_VISUAL_CHECK |
| 7 Export and compare | PASS + MANUAL_VISUAL_CHECK |
| 8 Industrialized Route | PASS (+ MANUAL_VISUAL_CHECK for browser UX) |
| 9 Pipeline packmate-ci | PASS (after RBAC Role fix) + MANUAL_VISUAL_CHECK for UI Start |
| 10 Argo CD | PASS + MANUAL_VISUAL_CHECK |
| Conclusion / annexes | PASS |
| EvalHub / Rollouts | OPTIONAL_UNAVAILABLE / optional annex |

### Documentation corrections made

1. Trailing whitespace cleanup (`git diff --check`).  
2. Pro Tip: use `PACKMATE_CONFIG` for alternate env files (Makefile has no `CONFIG=`).  
3. Clarify Argo Application name `packmate-lab` vs destination namespace.  
4. Acceptance report (this file) + DOCX assembly plan already present from prior doc work.

### Functional fix required for acceptance (not app logic)

- Tekton Role: allow `buildconfigs/instantiatebinary` so `oc start-build --from-dir` works for participants.

---

## 9. Manual UI checks remaining

- Create DSP / Workbench screenshots  
- Playground: paste prompt, authorize MCP, observe tool calls, View code  
- Pipelines UI **Start** button (CLI PipelineRun validated)  
- Argo CD UI Sync button (CLI sync validated)

---

## 10. Optional limitations

- EvalHub not configured (`EVALHUB_OPTIONAL_NOT_CONFIGURED`)  
- Rollouts optional annex  
- Custom model endpoint is **automated** by bootstrap (`CREATE_MODEL_CUSTOM_ENDPOINT=true`); participants never Create endpoint
- Shared Application name `packmate-lab` retargets destination when bootstrapping another namespace (instructor should use one GitOps destination per class cluster)

---

## 11. Final verdict (2026-07-22, DEV path)

**LAB_READY_WITH_MANUAL_VISUAL_CHECKS**

Technical path (images, bootstrap, verify, SSE, PipelineRun, Argo Sync, tests, quality gate) validated on a fresh GHCR-only namespace. Remaining gaps are intentional ClickOps visual checks in the participant guide. This verdict covers **Modules A–C** of the current `docs/PARTICIPANT_GUIDE.md` (OpenShift AI, Development, CI); it predates the `packmate-prod` split.

---

## 12. DEV→PROD addendum (2026-07-23)

The participant guide was restructured into Modules A–F (OpenShift AI, Development, CI, **Promotion**, **Production**, **Rollback**) and the following automation was added since § 1–11 above were written: `scripts/prepare-prod.sh`, `scripts/promote-backend-image.sh --create-pr`, `scripts/rollback-prod-image.sh --create-pr`, `scripts/configure-argocd-lab-rbac.sh`, `scripts/verify-prod.sh`, `scripts/verify-gitops.sh`, `scripts/validate-prod-overlay.sh`, `argocd/appproject-packmate.yaml`, `argocd/application-packmate-prod.yaml`.

**Re-checked in this documentation pass (2026-07-23, offline/local — no live cluster in this environment):**

| Check | Result |
|---|---|
| `make validate-prod` (offline render of `deploy/overlays/prod`) | **Passed** — no Notebook/Pipeline/PipelineRun/Workbench kinds, no `:latest`, no `packmate-lab` references, `packmate-prod-llm` secretKeyRef present, exactly 4 Deployments, all digest-pinned |
| Backend pytest | **125 passed** (unchanged from § 7) |
| Deterministic AI quality gate | **score 0.9559, PASS** (threshold 0.90; unchanged from § 7) |
| `scripts/security-check.sh` | **All checks passed** |
| Frontend (`npm ci && npm run test -- --run`) / MCP suites | **Not re-run in this pass** — carried forward from § 7 (26 frontend tests, 6 Weather, 9 Baggage); re-run before the next class if the frontend or MCP servers changed |

**Not re-checked in this pass — genuinely pending a live cluster:**

- End-to-end `make bootstrap` on a fresh sandbox confirming `packmate-prod` namespace/Secret/RBAC/Argo objects are created as described in `prepare-prod.sh`.
- A live PipelineRun → `promote-backend-image.sh --pipelinerun … --create-pr` → PR review/merge → Argo CD `packmate-prod` OutOfSync → Sync → Synced/Healthy → PROD Route smoke cycle (Modules C–E).
- A live `rollback-prod-image.sh --create-pr` → merge → Sync cycle (Module F).
- SSO group/`promoter`-role propagation (log out/in) on a real Argo CD instance with `spec.rbac.scopes` patched by `configure-argocd-lab-rbac.sh`.

**Recommendation:** run the § 1–10 acceptance procedure again end-to-end on a fresh sandbox, extended through Modules D–F, before the first graded DEV→PROD class, and log the result either as a new dated section here or as a fresh acceptance report. Until then, treat the PROD promotion/rollback/Argo-RBAC path as **implemented and offline-validated**, not yet **live-cluster acceptance-tested**.
