# DOCX assembly plan — Packmate Agent (OpenShift AI first-touch)

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

OpenShift AI first-touch laboratory
Branch: packmate-v2
Duration: ≈ 120 minutes

Repository: https://github.com/Lindagh1/packmate-agent.git

Focus: Data Science Project · Workbench · AI asset endpoints ·
       MCP · Gen AI Playground · FastAPI application ·
       AI-aware Pipeline · Argo CD intro

Secondary: OpenShift Pipelines · OpenShift GitOps (when available)
```

Optional footer on cover: `AI Factory Lab · Packmate v2 · Confidentiality: no secrets in screenshots`

---

## 2. Table of contents structure

Insert an automatic Word TOC after the cover, based on Heading 1–3.

Suggested TOC entries (match PARTICIPANT_GUIDE headings):

1. Introduction: General Architecture Overview  
2. 0. Before you start  
3. 1. Discover Packmate  
4. 2. Create the Data Science Project  
5. 3. Create the Workbench  
6. 4. Clone and bootstrap  
7. 5. Explore AI asset endpoints  
8. 6. Prototype in the Gen AI Playground  
9. 7. Export and compare  
10. 8. Run the industrialized application  
11. 9. Run the AI-aware Pipeline  
12. 10. Sync with Argo CD  
13. Conclusion  
14. Annex A — Screenshot checklist  
15. Annex B — Optional extensions  

---

## 3. Exact chapter order

| Order | Chapter | Emoji | Source heading in PARTICIPANT_GUIDE.md |
|------:|---------|-------|----------------------------------------|
| 0 | Cover | 📖 | — |
| 1 | TOC | — | Table of contents |
| 2 | Introduction: General Architecture Overview | 🏗️ | Introduction: General Architecture Overview |
| 3 | Before you start | 🧭 | 0. Before you start |
| 4 | Discover Packmate | 🧳 | 1. Discover Packmate |
| 5 | Create the Data Science Project | 📁 | 2. Create the Data Science Project |
| 6 | Create the Workbench | 💻 | 3. Create the Workbench |
| 7 | Clone and bootstrap | 🚀 | 4. Clone and bootstrap |
| 8 | Explore AI asset endpoints | 🔌 | 5. Explore AI asset endpoints |
| 9 | Prototype in the Gen AI Playground | 🧪 | 6. Prototype in the Gen AI Playground |
| 10 | Export and compare | 📤 | 7. Export and compare |
| 11 | Run the industrialized application | 🌐 | 8. Run the industrialized application |
| 12 | Run the AI-aware Pipeline | ⚙️ | 9. Run the AI-aware Pipeline |
| 13 | Sync with Argo CD | 🐙 | 10. Sync with Argo CD |
| 14 | Conclusion | ✅ | Conclusion |
| 15 | Annex A | 📎 | Annex A — Screenshot checklist |
| 16 | Annex B | 📎 | Annex B — Optional extensions |

---

## 4. Word styles to use

| Style name | Use for |
|------------|---------|
| **Title** | Cover main title `Packmate Agent` |
| **Subtitle** | Cover tagline / duration |
| **Heading 1** | Part titles (`1. Discover Packmate`, `Conclusion`, annexes) |
| **Heading 2** | Subsections (`2.1. ClickOps`, `6.3. Run the lab scenarios`) |
| **Heading 3** | Rare fine-grained steps if needed |
| **Normal** | Explanatory paragraphs before actions |
| **List Number** | ClickOps steps |
| **List Bullet** | Prerequisites / expected bullet lists |
| **Intense Quote** or custom **Note** | Architect Note, Security Note, Pro Tip callouts |
| **Strong** | Exact UI labels (menus, buttons) — map Markdown `**bold**` |
| **HTML Code** / **Consolas 9pt** | Inline paths and resource names |
| **No Spacing + shading** | Fenced Bash code blocks |
| **Caption** | Screenshot legends (`Figure N — …`) |
| **Table Grid** | Comparison / scenario tables |
| **TOC 1–3** | Automatic table of contents |

Callout convention (match historical lab tone):

- **Architect Note:** blue-left-border or light-blue shading  
- **Security Note:** amber/left-border shading  
- **Pro Tip:** green/left-border shading  

---

## 5. Screenshot placement (immediately after the matching step)

| ID | Insert after this step | Markdown placeholder |
|----|------------------------|----------------------|
| F01 | Part 2 — after **Create** project | `[Screenshot required: Data Science Project]` |
| F02 | Part 3 — after Workbench form / **Create** | `[Screenshot required: Workbench configuration]` |
| F03 | Part 4.1 — after clone in code-server | `[Screenshot required: Repository open in code-server]` |
| F04 | Part 5.1 — AI asset endpoints list | `[Screenshot required: AI asset endpoints]` |
| F05 | Part 6.2 — System instructions pasted | `[Screenshot required: System instructions]` |
| F06 | Part 6.2 — model + MCP enabled | `[Screenshot required: Playground with model and MCP servers]` |
| F07 | Part 6.4 — Weather tool call detail | `[Screenshot required: Weather MCP tool call]` |
| F08 | Part 6.4 — Baggage tool call detail | `[Screenshot required: Baggage MCP tool call]` |
| F09 | Part 7.1 — View code / Copy code | `[Screenshot required: View code export]` |
| F10 | Part 8.1 — browser on Frontend Route | `[Screenshot required: Packmate Route]` |
| F11 | Part 9.1 — PipelineRun graph running/succeeded | `[Screenshot required: Tekton Pipeline graph]` |
| F12 | Part 9.2 — ai-quality-gate logs (score/PASS) | `[Screenshot required: AI quality gate result]` |
| F13 | Part 10.2 — Application OutOfSync | `[Screenshot required: Argo CD OutOfSync]` |
| F14 | Part 10.2 — Application Synced and Healthy | `[Screenshot required: Argo CD Synced and Healthy]` |

---

## 6. Screenshot captions (legends)

| ID | Caption |
|----|---------|
| F01 | Figure 1 — Data Science Project `packmate-lab` created in OpenShift AI |
| F02 | Figure 2 — Workbench configuration (code-server) before Create |
| F03 | Figure 3 — Packmate repository open in the code-server Workbench |
| F04 | Figure 4 — AI asset endpoints showing the shared Llama model |
| F05 | Figure 5 — Packmate system instructions pasted in Playground Configure → Prompt |
| F06 | Figure 6 — Playground session with model and both Packmate MCP servers enabled |
| F07 | Figure 7 — Weather MCP tool call observed in the Playground |
| F08 | Figure 8 — Baggage Policy MCP tool call observed in the Playground |
| F09 | Figure 9 — Playground View code / export dialog |
| F10 | Figure 10 — Packmate React application on the OpenShift Route |
| F11 | Figure 11 — Tekton Pipeline `packmate-ci` graph |
| F12 | Figure 12 — AI quality gate result (scenarios, score, threshold 0.90, PASS/FAIL) |
| F13 | Figure 13 — Argo CD Application `packmate-lab` in OutOfSync state |
| F14 | Figure 14 — Argo CD Application `packmate-lab` Synced and Healthy |

Do **not** invent screenshots. Leave a grey placeholder box with the caption if the PNG is missing.

---

## 7. Code block placement

| Location | Language | Content |
|----------|----------|---------|
| Cover / Before you start | Bash | Full early command sequence (`git clone` … `make verify`) |
| Part 4.1 | Bash | `git clone` / `git switch packmate-v2` |
| Part 4.2 | Bash | `cp config/sandbox.env.example config/sandbox.env` |
| Part 4.3 | Bash | `make preflight` / `make bootstrap` / `make verify` |
| Part 8.1 | Bash | `oc get route packmate-frontend -n packmate-lab` |
| Part 9.2 | Bash | `scripts/promote-backend-image.sh <digest>` |

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
| Introduction (architecture) | Page break | Part 0 / 1 starts fresh |
| Part 3 (Workbench) | Optional page break | Before clone/bootstrap (command-heavy) |
| Part 5 (AI asset endpoints) | Page break | Playground chapter is long |
| Part 6 (Playground) | Page break | Before export/compare |
| Part 8 (Route app) | Page break | Before Pipelines |
| Part 9 (Pipeline) | Page break | Before Argo CD |
| Conclusion | Page break | Annexes separated |
| Annex A | Optional section break | Annex B |

Avoid orphan headings: keep each `n.1 ClickOps` with at least two lines of body on the same page.

---

## 9. Conclusion text (for Word)

Use the Conclusion section from `docs/PARTICIPANT_GUIDE.md` verbatim, including **Skills acquired**.

Short cover-back / last-page option:

```
You completed the Packmate OpenShift AI first-touch path:
Data Science Project → Workbench → bootstrap → AI assets →
Playground (model + prompt + MCP) → Route application →
AI-aware Pipeline → Argo CD Sync (when GitOps is available).

Optional later: Argo Rollouts, EvalHub.
```

---

## 10. Annex list

| Annex | Title | Content |
|-------|-------|---------|
| A | Screenshot checklist | Ordered list F01–F14 / placeholders |
| B | Optional extensions | Rollouts, EvalHub, custom endpoint CLI, retired Streamlit/S2I note |
| C *(optional instructor-only)* | Instructor setup pointers | Link text only to `docs/INSTRUCTOR_GUIDE.md` and `docs/REPRODUCE_SANDBOX.md` — do not paste secrets |
| D *(optional)* | Architecture diagram | Export mermaid from `README.md` / `docs/ARCHITECTURE.md` as a single figure |

Not in the participant DOCX:

- Secret values, tokens, kubeconfigs;
- obsolete Streamlit / S2I lab chapters from the historical Word file;
- false screenshots.

---

## Assembly checklist for the editor

1. Paste cover text → Title/Subtitle styles.  
2. Insert TOC field.  
3. Import `docs/PARTICIPANT_GUIDE.md` (or copy section by section) preserving Heading 1–2 and bold UI labels.  
4. Convert `> **Architect Note:**` / `Security Note` / `Pro Tip` into styled callouts.  
5. Convert fenced `bash` blocks into shaded code paragraphs.  
6. Insert figures F01–F14 immediately after their steps; apply Caption style.  
7. Apply page breaks from section 8.  
8. Spell-check UI strings against the live OpenShift AI / Pipelines / Argo CD consoles.  
9. Final pass: no Streamlit, no S2I, no admin Argo password instructions, no Secret values.
