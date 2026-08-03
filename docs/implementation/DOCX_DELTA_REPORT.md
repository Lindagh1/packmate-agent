# DOCX documentation delta report

**Source:** Packmate clean-room deep audit (2026-08-03)  
**Canonical release today:** `lab-v2.0.0` @ `7494359` (pre-hardening)  
**Purpose:** Drive a later editable workshop DOCX update. Do not edit the external DOCX from this file alone.

Path: `/tmp/packmate-deep-audit/DOCX_DELTA_REPORT.md`  
Also mirrored under: `docs/implementation/DOCX_DELTA_REPORT.md`

---

## 1. DOCX sections that must change

| Section | Change type |
|---------|-------------|
| Cover / repository URL | Distinguish canonical vs fork |
| Before you start | Fork-first clone + upstream DISABLED |
| Module A.4 Clone and bootstrap | Fork URL, `verify-demo-fork`, then bootstrap |
| Module C Pipeline | git-url = fork; seven tasks including publish-candidate |
| Module D Promotion | PR inside fork; `verify-github-write-readiness`; askpass recovery |
| Module E Production | Argo follows fork; manual Sync |
| Module F Rollback | Rollback PR inside fork |
| Instructor appendix | Residue discovery + reset-lab; no release per demo |
| Architecture diagram caption | Fork as writable GitOps source |

---

## 2–3. Old wording → replacement wording

| Old | Replacement |
|-----|-------------|
| `git clone … Lindagh1/packmate-agent.git` as the participant path | Clone **your fork**; add Lindagh1 as `upstream`; `git remote set-url --push upstream DISABLED` |
| “GitHub write access on Lindagh1/packmate-agent” | Write access to **your fork** only; upstream is read-only for demos |
| Single `make verify-demo-fork` after bootstrap | Pre: `make verify-demo-fork`; Post: `make verify-demo-fork-live` |
| Cleanup = delete packmate-lab only | Also discover/reset Argo Applications, AppProject, group residue |
| Implied new tag per sandbox | Reuse `lab-v2.0.0`; no release per demonstration |
| Open PR into Lindagh1/packmate-agent from a fork head | PR stays **fork branch → fork packmate-v2** |
| “Copy the main branch only” (default GitHub fork UI) | Explicitly include all branches / ensure `packmate-v2` exists |

---

## 4. Screenshots that can remain

- OpenShift AI dashboard / DSP create
- Workbench Ready
- Playground Rome scenario (model + MCP)
- DEV Route Rome streaming
- PipelineRun Succeeded task list (update caption if task count shown as 6 vs 7)
- Argo CD Synced/Healthy cards (generic UI)
- PROD Route smoke

---

## 5. Screenshots that must be replaced

- Any clone terminal showing `Lindagh1/packmate-agent` as **origin**
- Any `gh pr create` targeting Lindagh1 as base repo
- Any Argo Application details showing canonical repoURL as the participant destination after bootstrap
- Any release/tag creation during a demo
- Old `make cleanup` as the complete clean-room story

---

## 6. New screenshots required

1. GitHub **Fork** dialog with “Copy the main branch only” **unchecked** / all branches
2. `git remote -v` showing origin=fork, upstream=canonical, push DISABLED
3. `make verify-demo-fork` PASS (pre-bootstrap), including INFO about Argo migration if residue exists
4. `make verify-github-write-readiness` PASS
5. `make verify-demo-fork-live` PASS after bootstrap
6. `make discover-packmate-resources` showing STALE_PACKMATE when namespaces deleted
7. `make reset-lab` dry-run PLAN output
8. Promotion PR URL on **lindagh-labs** (or participant) fork, not Lindagh1
9. PipelineRun param `git-url` = fork URL
10. Optional: askpass ECONNREFUSED recovery terminal sequence

---

## 7. Command outputs that should be captured

```text
git remote -v
make verify-demo-fork
make verify-github-write-readiness
make preflight
make bootstrap
make verify-dev
make verify-demo-fork-live
make verify-gitops
# PipelineRun results: quality score + GHCR digest
scripts/promote-backend-image.sh --pipelinerun … --create-pr
# PR diff: only deploy/overlays/prod/kustomization.yaml
make verify-prod
scripts/rollback-prod-image.sh --create-pr
make discover-packmate-resources
make reset-lab
```

---

## Clean-room participant order (for DOCX procedure chapter)

1. Canonical `lab-v2.0.0` exists  
2. Fork exists with `packmate-v2`  
3. Instructor: Operators + shared model Ready; `make discover-packmate-resources` clean or reset  
4. Create DSP `packmate-lab` + code-server Workbench  
5. Clone fork; add upstream; disable upstream push; configure-git  
6. `config/sandbox.env` from example (`GIT_REPO_URL`=fork)  
7. `verify-demo-fork` → `verify-github-write-readiness` → `preflight` → `bootstrap`  
8. `verify-dev` → `verify-demo-fork-live` → `verify-gitops`  
9. Playground + DEV Route  
10. Pipeline (fork URL, PVC 2Gi, 7 tasks)  
11. Promote PR in fork → merge → manual PROD Sync  
12. PROD verify + rollback PR in fork  
13. Repeat bootstrap: Secret RVs / model UID unchanged; no new release  

**Full clean-room validation is NOT claimed until that path is executed live.**
