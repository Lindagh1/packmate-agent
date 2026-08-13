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
| Module 5.4 | `image31.png` | `module-05-view-code-export.png` | Shows the Playground View Code export and generated Python configuration without credentials. |
| Module 6.1 | `image26.png` | `module-06-dev-routes.png` | Shows accepted frontend and MCP Routes in `packmate-lab`. |
| Module 7.1 | `image11.png` | `module-07-pipeline-entry-success.png` | Shows `packmate-ci` in `packmate-lab` and a successful last run. It is only a navigation example; the current seven-task success graph remains a named placeholder. |
| Module 9.1 | `image33.png` | `module-09-argocd-openshift-login.png` | Cropped to the required Log in via OpenShift control; local username/password fields were excluded. |
| Module 9.4 | `image9.png` | `module-09-prod-routes.png` | Shows accepted frontend and MCP Routes in `packmate-prod`. It is not presented as proof of the final application response. |

## Current live captures

These screenshots were captured from the final RHDP validation on 2026-08-13,
not extracted from the previous guide:

| Current guide location | Repository asset | Verified live state |
|---|---|---|
| Module 3.1 | `module-03-repository-open-current.png` | Live `packmate-workbench` code-server shows the participant repository and prepared branch. |
| Module 6.1 | `module-06-dev-request-current.png` | Current DEV Route with the Rome weekend prompt and Cabin baggage selected. |
| Module 6.1 | `module-06-dev-response-current.png` | Completed DEV response with current weather and a structured packing report. |
| Module 8.3 | `module-08-promotion-pull-request-current.png` | Merged participant-fork PR #2, one commit and one changed PROD overlay file. |
| Module 9.4 | `module-09-prod-response-current.png` | Completed PROD response after Argo CD reached Synced/Healthy and the live digest matched Git. |

Three additional current captures are retained as validation evidence but are
not embedded because they repeat the same blank application landing/request
states: `module-06-dev-application-current.png`,
`module-09-prod-application-current.png`, and
`module-09-prod-request-current.png`. Thus eight current screenshots were
captured, of which five materially improve the participant guide.

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

## Placeholder classification after live validation

The final validation proved the underlying resources and application behavior,
but the authenticated OpenShift AI, Tekton, and Argo CD consoles could not be
captured by local browser automation without handling a user's SSO credential.
The guide therefore retains only screenshots that materially help a beginner:

| Placeholder | Classification | Exact reason it remains |
|---|---|---|
| `packmate-workbench` Running and ready to open | **LIVE SCREENSHOT NEEDED** | The Notebook and PVC were proven Ready/Bound and code-server was opened, but a current Workbenches-list capture requires authenticated OpenShift AI UI access. The old image shows the wrong Workbench name. |
| Packmate Llama model asset in `packmate-lab` with current readiness state | **LIVE SCREENSHOT NEEDED** | The shared InferenceService and custom endpoint were proven ready through the cluster API and `/v1/models`; the old asset image says `Unknown` and cannot represent current readiness. |
| Weather MCP tool call | **LIVE SCREENSHOT NEEDED** | A real Streamable HTTP MCP call returned four Rome forecast days, but the expanded Playground tool-call control is authenticated UI evidence. |
| Baggage MCP tool call | **LIVE SCREENSHOT NEEDED** | A real MCP call returned the cabin-liquid rules and disclaimer, but the expanded Playground tool-call control is authenticated UI evidence. |
| Successful PipelineRun seven-task graph | **LIVE SCREENSHOT NEEDED** | `packmate-ci-whbrq` succeeded with all seven tasks; none of the old captures shows that current graph and its participant branch. |
| AI quality gate PASS | **LIVE SCREENSHOT NEEDED** | The live result was 16 scenarios, score `0.9559`, threshold `0.90`, status PASS; the current Tekton task-detail UI still needs a safe authenticated capture. |
| Candidate image digest | **LIVE SCREENSHOT NEEDED** | The live Pipeline published an immutable GHCR digest, but a current `publish-result` task-result capture is needed to teach where to find it. |
| Argo CD OutOfSync | **LIVE SCREENSHOT NEEDED** | The reviewed Git change preceded manual Sync, but the transition view is authenticated Argo CD UI and no previous screenshot matches the prepared branch. |
| Argo CD Synced and Healthy | **LIVE SCREENSHOT NEEDED** | The live Application reached Synced/Healthy at the merged revision, but the final resource-tree view is authenticated Argo CD UI and the old image shows an obsolete revision. |

The former **System instructions** slot is classified **REMOVE PLACEHOLDER**:
the authoritative text is already opened from `playground/system-instructions.md`,
and a screenshot of pasted text adds no useful control or state evidence. No
remaining slot is better represented by a static diagram; each is a concrete UI
state the participant must recognize.
