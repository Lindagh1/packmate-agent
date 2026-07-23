# DOCX assembly plan — Packmate Agent (OpenShift AI DEV → PROD)

This plan tells an editor how to assemble the Word document from Markdown.
**Do not** auto-generate the `.docx` here. Source of truth for participant prose:

`docs/PARTICIPANT_GUIDE.md`

Editorial style reference (structure only, not Streamlit/S2I content):

`AI-Factory Lab_ Packmate Agent.docx`

---

## 1. Cover page text

```
📖 Project Documentation
Packmate Agent

OpenShift AI DEV → PROD laboratory
Branch: packmate-v2
Duration: ≈ 150 minutes

Repository: https://github.com/Lindagh1/packmate-agent.git

Focus: Data Science Project · Workbench · AI asset endpoints ·
       MCP · Gen AI Playground · FastAPI application ·
       AI-aware Pipeline · Promotion pull request ·
       Argo CD production Sync · Rollback

Secondary: OpenShift Pipelines · OpenShift GitOps (required for Modules D–F)
```

Optional footer on cover: `AI Factory Lab · Packmate v2 · Confidentiality: no secrets in screenshots`

---

## 2. Table of contents structure

Insert an automatic Word TOC after the cover, based on Heading 1–3.

Suggested TOC entries (match PARTICIPANT_GUIDE headings):

1. Introduction: General Architecture Overview
2. 0. Before you start
3. MODULE A — OpenShift AI
4. MODULE B — Development
5. MODULE C — CI
6. MODULE D — Promotion
7. MODULE E — Production
8. MODULE F — Rollback
9. Conclusion
10. Annex A — Screenshot checklist
11. Annex B — Optional extensions

---

## 3. Exact chapter order

| Order | Chapter | Emoji | Source heading in PARTICIPANT_GUIDE.md |
|------:|---------|-------|----------------------------------------|
| 0 | Cover | 📖 | — |
| 1 | TOC | — | Table of contents |
| 2 | Introduction: General Architecture Overview | 🏗️ | Introduction: General Architecture Overview |
| 3 | Before you start | 🧭 | 0. Before you start |
| 4 | MODULE A — OpenShift AI | 🅰️ | MODULE A — OpenShift AI |
| 5 | MODULE B — Development | 🅱️ | MODULE B — Development |
| 6 | MODULE C — CI | 🅲 | MODULE C — CI |
| 7 | MODULE D — Promotion | 🅳 | MODULE D — Promotion |
| 8 | MODULE E — Production | 🅴 | MODULE E — Production |
| 9 | MODULE F — Rollback | 🅵 | MODULE F — Rollback |
| 10 | Conclusion | ✅ | Conclusion |
| 11 | Annex A | 📎 | Annex A — Screenshot checklist |
| 12 | Annex B | 📎 | Annex B — Optional extensions |

Module A has internal sub-headings A.1–A.7 (Discover, Create DSP, Create Workbench,
Clone and bootstrap, AI asset endpoints, Playground, View code export) — keep them
as Heading 2 under the Module A Heading 1.

---

## 4. Word styles to use

| Style name | Use for |
|------------|---------|
| **Title** | Cover main title `Packmate Agent` |
| **Subtitle** | Cover tagline / duration |
| **Heading 1** | Module titles (`MODULE A — OpenShift AI`, `Conclusion`, annexes) |
| **Heading 2** | Subsections (`A.2. Create the Data Science Project (DEV)`, `D.1. Run the promotion script`) |
| **Heading 3** | Rare fine-grained steps if needed |
| **Normal** | Explanatory paragraphs before actions |
| **List Number** | ClickOps steps |
| **List Bullet** | Prerequisites / expected bullet lists |
| **Intense Quote** or custom **Note** | Architect Note, Security Note, Pro Tip callouts |
| **Strong** | Exact UI labels (menus, buttons) — map Markdown `**bold**` |
| **HTML Code** / **Consolas 9pt** | Inline paths and resource names |
| **No Spacing + shading** | Fenced Bash code blocks |
| **Caption** | Screenshot legends (`Figure N — …`) |
| **Table Grid** | Comparison / scenario / DEV vs PROD tables |
| **TOC 1–3** | Automatic table of contents |

Callout convention (match historical lab tone):

- **Architect Note:** blue-left-border or light-blue shading
- **Security Note:** amber/left-border shading
- **Pro Tip:** green/left-border shading

---

## 5. Screenshot placement (immediately after the matching step)

| ID | Insert after this step | Markdown placeholder |
|----|------------------------|----------------------|
| F01 | Module A.2 — after **Create** project | `[Screenshot required: DEV project]` |
| F02 | Module A.3 — after Workbench form / **Create** | `[Screenshot required: Workbench configuration]` |
| F03 | Module A.4 — after clone in code-server | `[Screenshot required: Repository open in code-server]` |
| F04 | Module A.5 — AI asset endpoints list | `[Screenshot required: AI asset endpoints in packmate-lab]` |
| F05 | Module A.6 — System instructions pasted | `[Screenshot required: System instructions]` |
| F06 | Module A.6 — model + MCP enabled | `[Screenshot required: Playground with model and MCP servers]` |
| F07 | Module A.6 — Weather tool call detail | `[Screenshot required: Weather MCP tool call]` |
| F08 | Module A.6 — Baggage tool call detail | `[Screenshot required: Baggage MCP tool call]` |
| F09 | Module A.7 — View code / Copy code | `[Screenshot required: View code export]` |
| F10 | Module C.2 — PipelineRun graph succeeded | `[Screenshot required: Pipeline successful]` |
| F11 | Module C.2 — ai-quality-gate logs (score/PASS) | `[Screenshot required: AI quality gate PASS]` |
| F12 | Module C.3 — build-backend / publish-result digest | `[Screenshot required: Candidate image digest]` |
| F13 | Module D.1 — GitHub pull request opened | `[Screenshot required: Promotion pull request]` |
| F14 | Module E.2 — Application OutOfSync | `[Screenshot required: Argo CD OutOfSync]` |
| F15 | Module E.3 — Application Synced and Healthy | `[Screenshot required: Argo CD Synced and Healthy]` |
| F16 | Module E.4 — browser on PROD Frontend Route | `[Screenshot required: PROD Route]` |

---

## 6. Screenshot captions (legends)

| ID | Caption |
|----|---------|
| F01 | Figure 1 — DEV Data Science Project `packmate-lab` created in OpenShift AI |
| F02 | Figure 2 — Workbench configuration (code-server) before Create |
| F03 | Figure 3 — Packmate repository open in the code-server Workbench |
| F04 | Figure 4 — AI asset endpoints in `packmate-lab` showing the shared Llama model + both MCP servers |
| F05 | Figure 5 — Packmate system instructions pasted in Playground Configure → Prompt |
| F06 | Figure 6 — Playground session with model and both Packmate MCP servers enabled |
| F07 | Figure 7 — Weather MCP tool call observed in the Playground |
| F08 | Figure 8 — Baggage Policy MCP tool call observed in the Playground |
| F09 | Figure 9 — Playground View code / export dialog |
| F10 | Figure 10 — Tekton Pipeline `packmate-ci` graph, Succeeded |
| F11 | Figure 11 — AI quality gate result (scenarios, score, threshold 0.90, PASS) |
| F12 | Figure 12 — Candidate backend image digest from `build-backend` / `publish-result` |
| F13 | Figure 13 — Promotion pull request diff limited to `deploy/overlays/prod/kustomization.yaml` |
| F14 | Figure 14 — Argo CD Application `packmate-prod` in OutOfSync state |
| F15 | Figure 15 — Argo CD Application `packmate-prod` Synced and Healthy |
| F16 | Figure 16 — Packmate React application on the PROD OpenShift Route (`packmate-prod`) |

Do **not** invent screenshots. Leave a grey placeholder box with the caption if the PNG is missing.

---

## 7. Code block placement

| Location | Language | Content |
|----------|----------|---------|
| Cover / Before you start | Bash | Full early command sequence (`git clone` … `make verify`) |
| Module A.4 | Bash | `git clone` / `git switch packmate-v2`, `cp config/sandbox.env.example config/sandbox.env`, `make preflight` / `make bootstrap` / `make verify` |
| Module B.1 | Bash | `oc get route packmate-frontend -n packmate-lab` |
| Module C.1 | Bash | `oc create -n packmate-lab -f .tekton/lab/packmate-ci-run.yaml` |
| Module D.1 | Bash | `scripts/promote-backend-image.sh --pipelinerun <name> --namespace packmate-lab --create-pr` |
| Module E.4 | Bash | `oc get route packmate-frontend -n packmate-prod` |
| Module F.1 | Bash | `scripts/rollback-prod-image.sh --create-pr` |

Formatting:

- Title line above block optional: `Bash` (as in the historical doc).
- Use a single-column shaded paragraph; avoid smart quotes in commands.
- Keep comments that warn about secrets (`# never commit`).

---

## 8. Recommended page breaks

| After… | Break type | Reason |
|--------|------------|--------|
| Cover page | Page break | TOC on its own opening page |
| Automatic TOC | Page break | Start Introduction cleanly |
| Introduction (architecture) | Page break | Before you start / Module A starts fresh |
| Module A.3 (Workbench) | Optional page break | Before clone/bootstrap (command-heavy) |
| Module A.5 (AI asset endpoints) | Page break | Playground chapter is long |
| Module A.6 (Playground) | Page break | Before View code / Module B |
| Module B (Development) | Page break | Before Module C (CI) |
| Module C (CI) | Page break | Before Module D (Promotion) |
| Module D (Promotion) | Page break | Before Module E (Production) |
| Module E (Production) | Page break | Before Module F (Rollback) |
| Conclusion | Page break | Annexes separated |
| Annex A | Optional section break | Annex B |

Avoid orphan headings: keep each `A.2 ClickOps` (etc.) with at least two lines of body on the same page.

---

## 9. Conclusion text (for Word)

Use the Conclusion section from `docs/PARTICIPANT_GUIDE.md` verbatim, including **Skills acquired**.

Short cover-back / last-page option:

```
You completed the Packmate OpenShift AI DEV → PROD path:
Data Science Project → Workbench → bootstrap → AI assets →
Playground (model + prompt + MCP) → DEV Route application →
AI-aware Pipeline → candidate digest → promotion pull request →
Argo CD Sync into packmate-prod → PROD Route → rollback pull request.

Optional later: Argo Rollouts canary annex, EvalHub.
```

---

## 10. Annex list

| Annex | Title | Content |
|-------|-------|---------|
| A | Screenshot checklist | Ordered list F01–F16 / placeholders |
| B | Optional extensions | Rollouts canary annex, EvalHub, custom endpoint automation note, retired Streamlit/S2I note |
| C *(optional instructor-only)* | Instructor setup pointers | Link text only to `docs/INSTRUCTOR_GUIDE.md` and `docs/REPRODUCE_SANDBOX.md` — do not paste secrets |
| D *(optional)* | Architecture diagram | Export the DEV/PROD mermaid diagram from `README.md` / `docs/ARCHITECTURE.md` as a single figure |

Not in the participant DOCX:

- Secret values, tokens, kubeconfigs, the Argo CD admin password;
- obsolete Streamlit / S2I lab chapters from the historical Word file;
- false screenshots.

---

## Assembly checklist for the editor

1. Paste cover text → Title/Subtitle styles.
2. Insert TOC field.
3. Import `docs/PARTICIPANT_GUIDE.md` (or copy section by section) preserving Heading 1–2 and bold UI labels.
4. Convert `> **Architect Note:**` / `Security Note` / `Pro Tip` into styled callouts.
5. Convert fenced `bash` blocks into shaded code paragraphs.
6. Insert figures F01–F16 immediately after their steps; apply Caption style.
7. Apply page breaks from section 8.
8. Spell-check UI strings against the live OpenShift AI / Pipelines / Argo CD consoles.
9. Final pass: no Streamlit, no S2I, no admin Argo password instructions, no Secret values, no claim that `packmate-lab` is production.
