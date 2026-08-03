# Instructor guide — Packmate v2 (OpenShift AI DEV → PROD)

Lab duration for participants: **≈150 minutes** (Modules A–F, see `docs/PARTICIPANT_GUIDE.md`).
Your prep: **60–120 minutes** on a ready cluster (longer the first time you publish images or configure PROD RBAC).

## Fork-first workshop model

`Lindagh1/packmate-agent` is the **canonical immutable source** (branch `packmate-v2`, release `lab-v2.0.0`). Every workshop execution uses a **participant or demo fork**.

| Rule | Detail |
|------|--------|
| Clone | Participants clone **their fork**, add canonical as `upstream` |
| Config | `GIT_REPO_URL` = fork; `CANONICAL_GIT_REPO_URL` = Lindagh1/packmate-agent; `ALLOW_CANONICAL_REPO_PROMOTION=false` |
| Argo CD | Both Applications use `repoURL=GIT_REPO_URL` and `targetRevision=GIT_REVISION` from the fork |
| Promote / rollback | PR stays inside the fork (`make verify-demo-fork` must PASS) |
| Releases | Do **not** create a `lab-v2.x` tag or GitHub Release per demo |

### Repeated demonstrations

- **Option A:** one disposable fork per participant or team.
- **Option B:** one fork with a dedicated branch, for example `demo/sandbox2571`, with `GIT_REVISION=demo/sandbox2571` and `PROMOTION_BASE_BRANCH=demo/sandbox2571`.

To reset a fork branch to the canonical release (rewrites **only the fork**):

```bash
# Confirm origin is NOT Lindagh1/packmate-agent
git remote -v
make verify-demo-fork

git fetch upstream tag lab-v2.0.0
git switch packmate-v2   # or your demo branch
git reset --hard lab-v2.0.0
git push --force-with-lease origin HEAD
```

Never run a force reset against the canonical upstream repository.

### Release policy

Create a new `lab-v2.x` tag only when the **canonical workshop itself** changes (bug fix → patch, new capability → minor, incompatible architecture → major). These do **not** create releases: new sandbox, PipelineRun, candidate digest, promotion PR, Argo Sync, participant, fork, or rollback exercise.

`ALLOW_CANONICAL_REPO_PROMOTION=true` is an instructor-only override. Never enable it in `config/sandbox.env.example` or participant docs.

### Clean-room residue and reset

Participants may delete Data Science Projects without removing Argo Applications. Before the next class:

```bash
make discover-packmate-resources   # read-only
make reset-lab                     # dry-run allowlisted plan
# Destructive only when intentional:
CONFIRM_PACKMATE_RESET=packmate-lab-and-prod make reset-lab
```

Never deletes `my-first-model`, Operators, or the shared GitOps instance. Stuck `Terminating` namespaces are reported; finalizers are never removed automatically.

### Pre-bootstrap vs post-bootstrap fork checks

| Target | When | Argo Applications |
|--------|------|-------------------|
| `make verify-demo-fork` | Before bootstrap | INFO/ACTION if still pointing upstream |
| `make verify-demo-fork-live` | After bootstrap | Must follow fork; DEV Synced/Healthy; PROD manual |

## Two environments, one cluster

| Environment | Namespace | Created by | Contains |
|-------------|-----------|-------------|----------|
| DEV | `packmate-lab` | Participant `make bootstrap` | DSP, Workbench, Playground, AI asset endpoints, Pipeline `packmate-ci`, app workloads |
| PROD | `packmate-prod` | `make bootstrap` (prepare only) + Argo CD Sync (deploy) | App workloads only — no Workbench, Pipeline, Playground, or custom model endpoint |

## Platform matrix (audit this cluster before class)

| Component | Status on reference sandbox | Lab impact |
|-----------|-------------------------------|------------|
| OpenShift AI (`rhods-operator` 3.4.x) | **Required** | Blocks lab if absent |
| Model `llama-32-3b-instruct` in `my-first-model` | **Required** | Shared; never redeploy for Packmate |
| OpenShift Pipelines 1.22.x | **Required for Module C** | Warn + screenshots if absent |
| OpenShift GitOps / Argo CD | **Required for Modules D–F** (validated install on 2026-07-22 sandbox) | `GITOPS_OPERATOR_REQUIRED` if absent |
| Argo Rollouts | Optional annex (`deploy/overlays/prod-canary-annex/`) | Not in main path |
| EvalHub instance | Optional annex | `EVALHUB_OPTIONAL_NOT_CONFIGURED` |

Classification helpers: `make preflight` prints PASS / WARNING / BLOCKED / OPTIONAL_UNAVAILABLE.

## Operators you install once (cluster admin, outside the 150-minute path)

- **Red Hat OpenShift AI** (`rhods-operator`) — required for DSP, Workbench, Gen AI studio.
- **OpenShift Pipelines** (`openshift-pipelines-operator-rh`) — required for Module C.
- **OpenShift GitOps** (`openshift-gitops-operator`) — required for Modules D–F. See `docs/INSTALL_GITOPS_PREREQUISITE.md`. Installs the cluster-scoped Argo CD instance in `openshift-gitops` that both `packmate-lab` (dev demo Application) and `packmate-prod` (real promotion target) use.
- **Argo Rollouts** — optional, only for the canary annex (`deploy/overlays/prod-canary-annex/`), not part of the graded path.

None of these are installed by Packmate scripts. `make bootstrap` / `make prepare-prod` only fail fast and print the missing-operator message when a CRD is absent.

## Shared model, one GPU allocation

- The physical Llama InferenceService stays only in **`my-first-model`** (one GPU allocation for the whole class).
- Bootstrap creates a **custom model endpoint** in `packmate-lab` (DEV only) that points at the shared cluster-local Service URL. `packmate-prod` never gets a custom model endpoint or a second InferenceService — `scripts/verify-prod.sh` fails the run if one is found.
- Defaults: `ENABLE_CUSTOM_ENDPOINTS=true`, `CREATE_MODEL_CUSTOM_ENDPOINT=true`. Custom endpoints are a **Technology Preview** feature in OpenShift AI 3.4.
- Persistence matches Gen AI Studio: ConfigMap `gen-ai-aa-custom-model-endpoints` + Secret `endpoint-api-key-<n>` (never print Secret values).
- Do **not** enable `externalProviders` for `.svc.cluster.local` URLs. Never create a second vLLM / InferenceService for Packmate, in DEV or PROD.

## Images (GHCR/Quay, persistent)

Internal OpenShift registry dies with the sandbox. Publish once:

1. Tag `lab-v1.0.0` or run **workflow_dispatch** on `.github/workflows/publish-lab-images.yml`.
2. Wait for four digests in the job summary.
3. GitHub → Packages → each image → **Change visibility → Public**.
4. Put refs into the class `config/sandbox.env` template (not in Git).

Bootstrap accepts **Quay or GHCR**; it does not hard-code a registry. Both DEV (`deploy/overlays/dev`) and the initial PROD overlay (`deploy/overlays/prod`) start from the same `lab-v1.0.0` digests; PROD only moves forward via a promotion PR (Module D).

## Preparing `packmate-prod` (what participants trigger, what you can also run standalone)

`make bootstrap` runs `scripts/prepare-prod.sh` automatically whenever `CREATE_PROD_NAMESPACE=true` or `CREATE_ARGOCD_APPLICATION=true` (both default `true`). It is **idempotent** and safe to re-run. It never deploys PROD workloads (no `oc apply -k deploy/overlays/prod`); Argo CD Sync is the only thing that ever creates PROD Deployments. It also never `oc apply`s `deploy/overlays/dev` — Application `packmate-lab` owns DEV runtime. Secrets are create-if-missing / no-op-if-identical; rotation requires `ROTATE_PACKMATE_PROD_LLM_SECRET=true make rotate-prod-llm-secret`.

`prepare-prod.sh` does, in order:

1. Creates namespace `packmate-prod`, labeled `packmate.io/environment=prod` (deliberately **not** the DSP labels `opendatahub.io/dashboard` / `modelmesh-enabled` — PROD must never look like a Data Science Project; `scripts/verify-prod.sh` checks this).
2. Ensures **Secret `packmate-prod-llm`** from `LLM_BASE_URL` / `LLM_MODEL` / `LITELLM_API_KEY` (or `LLM_API_KEY`) — values never printed, never in Git. Creates only when missing; no-ops when data is identical (preserves `resourceVersion`). Ordinary bootstrap never rotates it.
3. Grants `system:image-puller` in `packmate-lab` to the `packmate-prod` ServiceAccounts (`packmate-backend`, `packmate-frontend`, `weather-mcp`, `baggage-policy-mcp`) so PROD can pull the same internal-registry images if you ever point an overlay there (the shipped overlay uses GHCR, so this is a safety net, not a hard requirement).
4. Applies the Argo CD **AppProject `packmate`** and **Application `packmate-prod`** (manual Sync, `prune=false`, `selfHeal=false`, destination `packmate-prod` only — no wildcards).
5. Labels `packmate-prod` with `argocd.argoproj.io/managed-by=openshift-gitops` (the official OpenShift GitOps 1.x managed-namespace mechanism) so the Argo CD application-controller ServiceAccount gets namespace RBAC automatically, without a hand-written RoleBinding.
6. Optionally runs `scripts/configure-argocd-lab-rbac.sh` when `CREATE_ARGOCD_RBAC=true` (default `true`).

Run it standalone (idempotent) with:

```bash
LLM_BASE_URL=... LLM_MODEL=... LITELLM_API_KEY=... \
  make prepare-prod
```

### Local admin break-glass (fallback RBAC only — never share the password)

Step 5 above is normally sufficient. If the application-controller still cannot manage `packmate-prod` (RBAC propagation delay, non-standard GitOps install), set `ARGOCD_RBAC_FALLBACK=true` before re-running `prepare-prod.sh` to bind the `edit` role to the controller ServiceAccount directly — this is a **documented fallback**, applied only on request, never by default.

Separately, the Argo CD **local admin account** exists for break-glass cluster-admin recovery only:

- **Never share the Argo CD admin password with participants.** The whole lab is designed around OpenShift SSO (`spec.rbac.scopes` includes `groups`) so nobody needs it.
- If you must retrieve it for troubleshooting: `oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d` — read it yourself, use it, then rotate/disable it. Never paste it into chat, tickets, or screenshots.
- To disable the local admin account entirely once SSO RBAC is confirmed working, set `DISABLE_ARGOCD_LOCAL_ADMIN=true` before running `scripts/configure-argocd-lab-rbac.sh` (patches `spec.disableAdmin=true` on the ArgoCD CR).

## OpenShift group, SSO, and the AppProject "promoter" role

`scripts/configure-argocd-lab-rbac.sh` (auto-run from `prepare-prod.sh` when `CREATE_ARGOCD_RBAC=true`):

1. Patches the ArgoCD CR `spec.rbac.scopes` to include `groups` (never touches `policy` / `defaultPolicy` — no accidental `role:admin` grant).
2. Creates OpenShift **Group** `packmate-lab-users` (override with `PACKMATE_ARGO_GROUP`) and adds the participant (`oc whoami`, override with `PACKMATE_PARTICIPANT_USER`).
3. Re-applies `argocd/appproject-packmate.yaml`, which defines role **`promoter`**: `get` + `sync` on `Application/packmate-prod` only, for group `packmate-lab-users` — no `role:admin`, no delete permission, no other destination.

**Participants must log out and log back in to the Argo CD UI** after being added to the group — Argo CD reads OpenShift group membership from the OAuth token at login time, and RBAC changes may also need `oc rollout restart deployment/<argocd-name>-server -n openshift-gitops` to pick up scope changes. This is called out in Participant Guide Module E.1 and in `docs/TROUBLESHOOTING.md`.

Verify the whole PROD/GitOps setup with:

```bash
make verify-gitops
make verify-prod    # after a Sync
```

## GitHub write access for the promotion pull request

`scripts/promote-backend-image.sh --create-pr` and `scripts/rollback-prod-image.sh --create-pr` push a branch to `origin` (the **fork**) and call `gh pr create --repo <fork> --base PROMOTION_BASE_BRANCH`. This requires:

- `origin` and `GIT_REPO_URL` pointing at the fork (`make verify-demo-fork` PASS);
- `gh auth login` completed with a token that has **write access to the fork**;
- if `gh` is not authenticated, the scripts fall back to printing the manual `git push` + compare-URL instructions — nothing is lost, the commit stays local until pushed.
- `--merge-pr` is an **automated-validation-only** flag (documented in the script header); do not enable it for participant-facing sessions — merges should go through human review (Participant Guide Module D.2).

Promotion into `Lindagh1/packmate-agent` exits with `BLOCKED_CANONICAL_REPOSITORY_PROMOTION` unless `ALLOW_CANONICAL_REPO_PROMOTION=true` (instructor-only).

## Multi-user pattern: fork / namespace / group per participant

The reference model for this lab is **one ephemeral sandbox cluster per participant** (for example an OpenTLC-style sandbox) **plus one GitHub fork per participant**. On that model there is no naming collision: each participant's cluster has exactly one `packmate-lab`, one `packmate-prod`, one AppProject `packmate`, and one Application `packmate-prod`, all watching **their fork**.

If you instead run **many participants against a single shared cluster**, be aware of the current constraints before promising a fully isolated experience:

- `argocd/appproject-packmate.yaml` and `argocd/application-packmate-prod.yaml` use **fixed names** (`packmate`, `packmate-prod`) and a **fixed destination namespace** (`packmate-prod`). Only one participant's PROD promotion path can be live at a time on a shared cluster unless you fork these manifests with per-participant suffixes (namespace, AppProject name, Application name, Argo group) before applying — not templated by the scripts today.
- `PACKMATE_DEV_NAMESPACE` / `PACKMATE_NAMESPACE` **can** be given a per-participant DEV namespace (e.g. `packmate-lab-alice`), and `PACKMATE_ARGO_GROUP` / `PACKMATE_PARTICIPANT_USER` can be set per participant for the promoter role — but `PACKMATE_PROD_NAMESPACE` and the Argo CD object names still collide across participants on one cluster.
- Recommended patterns, in order of preference:
  1. **One sandbox + one fork per participant** (no changes needed) — the supported/validated path.
  2. **One shared cluster, single shared PROD** — only the instructor (or one nominated participant) Syncs to `packmate-prod`; everyone else reviews PRs in their own forks. Simple, matches the "one production" story, no manifest changes.
  3. **One shared cluster, per-participant PROD** — duplicate `argocd/appproject-packmate.yaml` / `argocd/application-packmate-prod.yaml` per participant with unique names/namespaces/groups before applying. More setup work; only do this for small advanced cohorts.
- For the **GitHub** side: **always** use participant forks. Do **not** instruct participants to open PRs into `Lindagh1/packmate-agent`. Branch protection on each fork's `packmate-v2` (require PR review, no direct pushes) is recommended so Module D's review step is enforced.

## Same-repo vs separate GitOps repo

Packmate currently ships **manifests and application code in the same repository** (`deploy/`, `argocd/` next to `backend/`, `frontend/`, `mcp-servers/`). This is what `scripts/promote-backend-image.sh` and `scripts/rollback-prod-image.sh` assume (`PROMOTION_BASE_BRANCH` / `packmate-v2`, edits under `deploy/overlays/prod/`).

- **Keep it same-repo (current, recommended for this lab):** simpler for a 150-minute session — one clone, one branch, one PR review teaches the whole DEV→PROD story without introducing a second repository, second set of credentials, or a cross-repo Tekton/Argo wiring step. Promotion PRs are easy to correlate with the PipelineRun that produced them.
- **Split into a separate GitOps repo** (`deploy/` + `argocd/` in their own repo, application code in another): more realistic for teams that want to gate deploy-time changes with different reviewers/CI than app-code changes, and it lets Argo CD's `sourceRepos` allowlist be narrower. If you adopt this for a follow-on course, plan to: change `argocd/*.yaml` `repoURL` to the GitOps repo, update `promote-backend-image.sh` / `rollback-prod-image.sh` to commit/push into that second repo (today they always edit the current checkout), and give participants write access to the GitOps repo instead of (or in addition to) the app repo. Not required for this lab — call it out as a deliberate simplification if asked.

## `CREATE_PROD_*` and related flags

Set in `config/sandbox.env` (or exported before `make bootstrap` / `make prepare-prod`):

| Flag | Default | Effect |
|------|---------|--------|
| `CREATE_PROD_NAMESPACE` | `true` | Bootstrap runs `prepare-prod.sh` (creates/labels `packmate-prod`) |
| `CREATE_PROD_SECRETS` | `true` | Documents that `packmate-prod-llm` is created; the actual creation always happens inside `prepare-prod.sh` when it runs — set both `CREATE_PROD_NAMESPACE` and this to `false` only if you are deliberately deferring all PROD prep to a manual `make prepare-prod` later |
| `CREATE_ARGOCD_APPLICATION` | `true` | Also triggers `prepare-prod.sh` (applies AppProject/Application) even if `CREATE_PROD_NAMESPACE=false` |
| `CREATE_ARGOCD_RBAC` | `true` | `prepare-prod.sh` also runs `configure-argocd-lab-rbac.sh` (SSO group + promoter role) |
| `ALLOW_CREATE_NAMESPACE` | `false` | Instructor-only: lets bootstrap create the **DEV** `packmate-lab` project itself instead of requiring ClickOps |
| `ARGOCD_RBAC_FALLBACK` | `false` | Instructor-only: allow the `edit`-role RoleBinding fallback in step 5/6 of `prepare-prod.sh` |
| `DISABLE_ARGOCD_LOCAL_ADMIN` | `false` | Instructor-only: disable the Argo CD local admin account once SSO RBAC works |

Set all four `CREATE_PROD_*`/`CREATE_ARGOCD_*` flags to `false` if you want a class session that **only** exercises DEV (Modules A–C) and skips PROD prep entirely — Modules D–F then require you to run `make prepare-prod` manually before that part of the day.

## What participants must ClickOps

- Create Data Science Project (`packmate-lab`, **DEV**)
- Create code-server Workbench
- Clone repo → `make preflight` / `make bootstrap` / `make verify`
- Playground in **Packmate Lab** (select model + enable MCP + paste system prompt + test)
- Start Pipeline `packmate-ci`, capture the candidate digest
- Run `promote-backend-image.sh --create-pr`, review, merge
- Argo CD Sync of `packmate-prod` (SSO login/re-login, click Sync)
- (Module F) Run `rollback-prod-image.sh --create-pr`, review, merge, Sync

Participants must **not** create the custom model endpoint, enter model URLs/tokens, switch to `my-first-model` for the Playground path, or believe `packmate-lab` is production.

## What bootstrap automates

- Secrets from env (values never printed), for both DEV (`packmate-llm`) and PROD (`packmate-prod-llm`)
- Enable Gen AI **custom endpoints** feature (`aiAssetCustomEndpoints=true`) when needed, DEV only
- Discover/test the shared model Service in `my-first-model`
- Weather + Baggage MCP, backend, frontend, Routes, NetworkPolicies — DEV only
- MCP ConfigMap registration (preserves other keys)
- **Automatic** Packmate custom model endpoint in `packmate-lab` (ConfigMap + Secret)
- Tekton `packmate-ci` resources + BuildConfig/ImageStream `packmate-backend`, DEV only
- `packmate-prod` namespace, Secret, image-pull RBAC, Argo CD AppProject/Application, SSO group + promoter role — **prep only, no workload apply**

## What participants must NOT do

- Install Operators
- Build four images at lab start
- Deploy or modify the Llama InferenceService
- Commit Secrets / `config/sandbox.env`
- Use an Argo CD admin password
- Port-forward for the main path
- `oc apply -k deploy/overlays/prod` directly (PROD only changes via Argo CD Sync)
- Push a promotion/rollback branch straight to `packmate-v2` without a PR

## Persistent vs ephemeral

### PERSISTENT

- Git repository + branch `packmate-v2`
- GitHub Actions workflow `.github/workflows/publish-lab-images.yml`
- Images on **GHCR or Quay** (digest-pinned)
- Manifests, system prompt, test prompts, datasets, documentation
- `deploy/overlays/prod/kustomization.yaml` history — the audit trail of every promotion/rollback

### EPHEMERAL

- Data Science Project / Workbench / PVC (DEV)
- Secrets, Deployments, Routes (DEV and PROD)
- MCP registration ConfigMap entries
- PipelineRuns
- Argo CD Applications (`packmate-lab` demo, `packmate-prod`)
- Custom model endpoint ConfigMap/Secret in `packmate-lab`
- EvalHub instance (if any)

## Pipelines

Apply via bootstrap (`CREATE_PIPELINE=true`). Bootstrap resolves `openshift/python:3.12-ubi9` (and `openshift/cli`) to the current sandbox digests, checks RHOAI 3.4 package pins in-cluster (`mcp==1.27.2`, `json-repair==0.25.3`, `pydantic==2.13.1`), renders `.tekton/lab/packmate-ci.yaml.tpl` → `.generated/tekton/packmate-ci.yaml`, and applies the generated Pipeline — never commit a sandbox-specific Python digest. Participants clone into `/opt/app-root/src/packmate-agent` and only **Start** `packmate-ci` with a **2Gi VolumeClaimTemplate**. After ImageStream rotation, re-run `make bootstrap` to re-render.

## GitOps

If the Operator is missing: share `docs/INSTALL_GITOPS_PREREQUISITE.md` and skip Modules D–F (screenshot walkthrough only).
If present: `packmate-prod` uses **manual sync**, prune off, self-heal off, destination `packmate-prod` only, via AppProject `packmate` role `promoter`.

## Evaluation

Mandatory: deterministic quality gate (threshold **0.90**, reference score **0.9559**), enforced both locally (`make test`) and in the Pipeline before any digest is eligible for promotion.
EvalHub: optional annex only.

## Reset / cleanup

```bash
make cleanup   # interactive; types DELETE-PACKMATE-LAB; DEV (packmate-lab) only
```

`scripts/cleanup-packmate-lab.sh` refuses to run against any namespace other than `packmate-lab` and never touches `my-first-model` or Operators. It does **not** delete `packmate-prod`, the Argo CD AppProject/Application, or the OpenShift group — clean those up manually between classes if you reuse the same cluster:

```bash
oc delete application packmate-prod -n openshift-gitops
oc delete appproject packmate -n openshift-gitops
oc delete project packmate-prod
oc delete group packmate-lab-users
```

## Cluster unavailable

Fall back to screenshots + local `make test` / Compose. Do not invent "validated" cluster features.

## Duration guide

| Phase | Time |
|-------|------|
| Instructor image publish (once) | 30–60 min |
| Instructor cluster smoke (DEV + PROD prep + one promotion/Sync/rollback cycle) | 45–60 min |
| Participant lab (Modules A–F) | 150 min |

## Participant handout (Word)

Participant Markdown source (Packmate v2 DEV→PROD content):

`docs/PARTICIPANT_GUIDE.md`

Assembly instructions for editors (cover, TOC, captions, page breaks — **no** auto-generated DOCX):

`docs/DOCX_ASSEMBLY_PLAN.md`

## Instructor GitOps setup

1. Install Red Hat OpenShift GitOps (or set `INSTALL_OPENSHIFT_GITOPS_OPERATOR=true`).
2. Run `make instructor-setup`.
3. Confirm Argo CD shows **packmate-lab** and **packmate-prod**.
4. Run `make configure-promotion-registry` then `make verify-gitops`.
5. Never share the local Argo CD admin password.
