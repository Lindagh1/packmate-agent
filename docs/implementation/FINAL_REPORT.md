# Packmate beginner workshop — finalization report

Date: 2026-08-13

Development branch: `refactor/beginner-workshop` (local only)

Disposable live-validation branch: `demo/final-validation-20260813`

## Outcome

The beginner workshop now follows Modules 1–9 from RHDP and OpenShift AI
through a fork-owned immutable promotion and an explicit manual Argo CD PROD
Sync. The participant path ends after verified PROD; it contains no Module 10
and no participant rollback procedure.

The final real-sandbox run passed the clean reset, Workbench, simplified
participant configuration, GitOps/bootstrap, integrated DEV, seven-task Tekton
Pipeline, fork-only pull request, exact-digest PROD deployment, application
scenario, and post-bootstrap acceptance checks. Module 5 is PARTIAL only because
the authenticated Playground UI/tool-call panels were not directly observed;
the shared model, both registered MCP assets, and both live MCP protocol calls
were verified independently.

## Live immutable promotion

| Item | Result |
|---|---|
| PipelineRun | `packmate-ci-whbrq` — Succeeded |
| AI quality | 16 scenarios; score `0.9559`; PASS at `0.90` |
| Candidate | `ghcr.io/lindagh-labs/packmate-backend@sha256:e5ad84baeb8ddf6069e8f08fc7dcf2f5987ec4f48f93c16a9a25be4d38febdb8` |
| Promotion | Participant-fork PR #2; one commit; one changed file |
| PROD GitOps | `packmate-prod` Synced/Healthy; automatic Sync off; prune off |
| PROD verification | Exact Git digest, Route/SSE healthy, Rome scenario completed without `agent_error` |

## Fixes proven by the run

- Participant configuration is a safe `make configure-participant` operation;
  no copied Python heredoc or credential is required.
- `make prepare-demo-baseline` persists matching branch, Git revision, and
  promotion base automatically; no manual `sed` repair is required.
- Example PipelineRuns inherit rendered participant fork/branch defaults.
- `make verify-demo-baseline PIPELINERUN=<name>` validates the requested live
  candidate instead of dropping the argument.
- PROD Argo CD comparison ignores only OpenShift-generated ServiceAccount pull
  secret fields while retaining comparison of the Git-owned GHCR pull secret.
- Frontend validation runs locally with npm or through a Node 22 Podman fallback;
  it can no longer fail silently when npm is absent.
- The participant guide is generated from one Markdown source into HTML, DOCX,
  and a visually reviewed 25-page PDF with module page breaks.

## Validation summary

Backend 132 passed; frontend lint/26 tests/build passed; Weather MCP 6 passed;
Baggage MCP 9 passed; deterministic evaluation scored 0.9559; 164 shell
regression checks passed; security, renders, Pipeline/PROD validation, GitOps
ownership, guide generation/validation, and live post-bootstrap acceptance all
passed.

## Remaining honest evidence limitation

The authenticated Playground interaction and expanded tool-call panels were not
captured during the live run. The guide does not substitute stale screenshots or
empty boxes for that evidence: it retains the verified instructions and required
results in text. `docs/SCREENSHOT_REUSE_AUDIT.md` records every reuse and rejection
decision. There is no remaining technical DEV→PROD release blocker.
