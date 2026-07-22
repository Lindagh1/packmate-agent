# Lab acceptance report — Packmate v2

**Date:** 2026-07-22  
**Branch:** `packmate-v2`  
**Commit tested (pre-acceptance docs WIP):** `b4a170e` (+ local doc/RBAC fixes committed with this report)  
**Verdict:** **LAB_READY_WITH_MANUAL_VISUAL_CHECKS**

---

## 1. Environment

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

**Minimal fix applied:** Role `packmate-pipeline` now includes `buildconfigs/instantiate` and `buildconfigs/instantiatebinary` (+ imagestream update verbs). Demonstrated blocker for Module 9 on a fresh namespace.

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
- Custom model endpoint remains ClickOps (`CREATE_MODEL_CUSTOM_ENDPOINT=false`)  
- Shared Application name `packmate-lab` retargets destination when bootstrapping another namespace (instructor should use one GitOps destination per class cluster)

---

## 11. Final verdict

**LAB_READY_WITH_MANUAL_VISUAL_CHECKS**

Technical path (images, bootstrap, verify, SSE, PipelineRun, Argo Sync, tests, quality gate) validated on a fresh GHCR-only namespace. Remaining gaps are intentional ClickOps visual checks in the participant guide.
