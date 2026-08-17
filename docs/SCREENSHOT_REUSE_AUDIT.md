# Participant guide screenshot reuse audit

## Source and method

Primary source: `Packmate_RHDP_Workshop_Participant_Final_Release (1).docx`

Source SHA-256: `0b290e847a7e439d9dd6b0b9b7860dcaf2cb9107e002ef08b47fe7b46d37e445`

The PNGs below were extracted from `word/media` in the prior DOCX and cropped locally to the relevant controls. Cropping preserved the original pixel values and lossless PNG format; no UI was generated, repainted, or composited. The old document XML and adjacent figure captions were used to identify each source image before it was compared with the current participant steps.

## Approved reuse

| Current guide location | Prior DOCX media | Repository asset | Verification |
|---|---|---|---|
| Module 1.1 | `image15.png` | `module-01-rhdp-openshift-ai-order.png` | Shows the RHDP OpenShift AI 3 activity and Order control used by the current participant flow. |
| Module 1.3 | `image1.png` | `module-01-participant-fork-branch.png` | Shows a participant-owned fork with `packmate-v2` selected and the canonical repository identified as its source. |
| Module 2.1 | `image2.png` | `module-02-openshift-ai-launcher.png` | Shows Red Hat OpenShift AI in the OpenShift application launcher. |
| Module 2.1 | `image20.png` | `module-02-create-project-dialog.png` | Shows the current Create project dialog and its name field; the caption does not claim that the blank example field is already populated. |
| Module 2.2 | `image5.png` | `module-02-workbench-image-and-size.png` | Cropped to the Code Server Python 3.12 image, version, and deployment-size controls. The old Update button and warning were excluded because the current step creates a Workbench. |
| Module 5.1 | `image29.png` | `module-05-mcp-asset-endpoints.png` | Shows both Packmate MCP assets active under project `packmate-lab`. |
| Module 5.2 | `image25.png` | `module-05-playground-model-mcp.png` | Shows the Packmate model and both enabled MCP servers in the Playground. It is not used as tool-call evidence. |
| Module 7.1 | `image11.png` | `module-07-pipeline-entry-success.png` | Shows where to find `packmate-ci` in `packmate-lab` and locate the Pipeline start point. It is a navigation example, not current-run evidence. |
| Module 9.1 | `image33.png` | `module-09-argocd-openshift-login.png` | Cropped to the required Log in via OpenShift control; local username/password fields were excluded. |

## Current live captures

These screenshots were captured from the final RHDP validation on 2026-08-13,
not extracted from the previous guide:

| Current guide location | Repository asset | Verified live state |
|---|---|---|
| Module 6.1 | `module-06-dev-response-current.png` | Completed DEV response with current weather and a structured packing report. |
| Module 8.3 | `module-08-promotion-pull-request-current.png` | Merged participant-fork PR #2, one commit and one changed PROD overlay file. |
| Module 9.4 | `module-09-prod-response-current.png` | Completed PROD response after Argo CD reached Synced/Healthy and the live digest matched Git. |

Five additional current captures remain in the repository as validation
evidence but are not embedded because they prove an obvious repository state,
repeat a pre-submit or blank application state, or do not improve navigation:
`module-03-repository-open-current.png`,
`module-06-dev-application-current.png`,
`module-06-dev-request-current.png`,
`module-09-prod-application-current.png`, and
`module-09-prod-request-current.png`. Thus eight current screenshots were
captured, of which three materially improve the final participant guide.

## Removed from the participant sequence

- `module-03-repository-open-current.png` only proved the repository was open after the clone command; it added no useful navigation cue.
- `module-05-view-code-export.png` repeated the simple View Code instruction and forced a sparse spill page in the DOCX render.
- `module-06-dev-request-current.png` repeated the written Rome scenario immediately before the more useful structured DEV result.
- `module-06-dev-routes.png` and `module-09-prod-routes.png` repeated route-list state already established by the adjacent commands and required results.

## Explicitly rejected old evidence

- `image8.png` and `image18.png` show obsolete Pipeline defaults, an internal registry reference, the old `packmate-v2` revision, or a 1 GiB workspace. They contradict the rendered current defaults and 2 GiB instruction.
- `image12.png` and `image28.png` show an old manual/empty-description promotion pull-request flow and old branch evidence. The refactored `make promote` path generates a fork-local PR body and validates the one-file digest change.
- `image14.png` shows an old Argo CD revision and a visible **History and Rollback** control. It is excluded from the guide.
- `image19.png` shows PROD tracking `packmate-v2` while DEV is OutOfSync. It cannot prove the current prepared-branch PROD transition.
- `image7.png` has a newest PipelineRun still Running and does not show the current seven-task graph, so it is not used as success evidence.
- `image10.png` shows the old Workbench name `packmate-lab`, not `packmate-workbench`.
- `image13.png`, `image17.png`, `image21.png`, and `image24.png` contain prior preflight, baseline, branch, or registry output that no longer matches the automated refactored setup.
- `image6.png`, `image27.png`, and `image32.png` belong to the previous participant-driven GitOps installation path, which is not part of the current participant module sequence.
- `image16.png` and `image23.png` show the old token/login-copy flow and are unnecessary for the current authenticated Workbench path.
- `image22.png` identifies the correct Packmate model asset but displays a stale `Unknown` status. It is not used as current readiness evidence.
- `image30.png` does not show the pasted Packmate system instructions, so it is not used for that evidence slot.

## Final UI-slot disposition

The final participant guide contains no empty screenshot boxes. The final live
validation proved the underlying resources and behavior, but no appropriate
current captures were locally available for the authenticated Workbench list,
model-readiness view, expanded tool calls, seven-task graph, quality/digest task
details, or Argo CD transition views. Older images for those states were stale
or contradicted the current workflow, so the slots were removed.

The guide retains the adjacent instructions and required results. Module 7 also
records the complete evidence contract in text: PipelineRun name, seven
succeeded tasks, 16 scenarios, PASS, score, threshold `0.90`, and the full
external `PROMOTION_IMAGE_REFERENCE`. No static diagram was substituted for a
real UI state.
