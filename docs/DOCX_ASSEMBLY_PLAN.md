# Generated participant guide specification

The canonical participant prose is `docs/PARTICIPANT_GUIDE.md`.

Run:

```bash
make guide
```

This repository-native workflow produces:

- `docs/generated/Packmate_Participant_Guide.html`
- `docs/generated/Packmate_Participant_Guide.docx`
- `docs/generated/Packmate_Participant_Guide.pdf`

The generator uses only repository source, repository screenshot assets, locally installed LibreOffice and, when available, headless Chrome for the final PDF print. It does not download fonts, screenshots, templates, or participant data.

## Document order

1. Cover
2. Start here
3. Module 1 — RHDP sandbox and GitHub fork
4. Module 2 — OpenShift AI project and Workbench
5. Module 3 — Participant workspace and Git fork
6. Module 4 — GitOps, registry access and bootstrap
7. Module 5 — OpenShift AI Playground
8. Module 6 — DEV application
9. Module 7 — Tekton Pipeline
10. Module 8 — Git promotion
11. Module 9 — PROD synchronization and validation
12. Workshop complete
13. Appendix A — Participant troubleshooting
14. Appendix B — Participant command reference

## Visual language

- white page background;
- black headings with Red Hat red rules and accents;
- light grey supporting panels;
- blue information and learning callouts;
- green success checkpoints;
- red warnings and stop checkpoints;
- dark terminal blocks with wrapped monospace text.

Module headings are kept with the content that follows and use a strong red section rule. Content flows continuously so a final checkpoint is not stranded on an otherwise empty page. Heading groups, figures, and table rows avoid bad page breaks where the output format supports them. Approved screenshots are losslessly cropped repository PNGs. When no current, workflow-accurate screenshot is available, the guide relies on the adjacent instruction and required result instead of inventing an image or displaying an empty placeholder.

## Screenshot evidence

The final source embeds 12 screenshots: nine verified and cropped from the prior participant DOCX, plus three captures from the final live RHDP validation. The extraction, crop, caption, reuse, and rejection decisions are recorded in `docs/SCREENSHOT_REUSE_AUDIT.md`.

The embedded screenshots are:

1. RHDP OpenShift AI order page
2. Participant fork and branch
3. OpenShift AI launcher
4. Create project dialog
5. Workbench image and size controls
6. MCP asset endpoints
7. Playground model and MCP selection
8. Current DEV application response
9. Pipeline entry and start navigation
10. Current promotion pull request
11. Argo CD OpenShift login control
12. Current PROD application response

The generated HTML, DOCX, and PDF contain no screenshot placeholders.

## Validation

`make guide` finishes by running `make validate-guide`. Validation checks module order, required appendices, forbidden legacy wording, the exact 12 screenshot references, zero screenshot placeholders, generated file presence, embedded DOCX images, document text, page count, and obvious stranded module headings.
