# Packmate evaluations

Hybrid evaluation layout for Packmate v2: **deterministic CI gate** plus **optional OpenShift AI native evals**.

## Level 1 — Deterministic (CI source of truth)

| Location | Role |
|----------|------|
| [`backend/evals/`](../backend/evals/) | Pytest-friendly deterministic runner, fixtures, weighted evaluators |
| [`evaluations/scripts/run_deterministic_gate.sh`](./scripts/run_deterministic_gate.sh) | Shell wrapper for Tekton / local gate with threshold |

**What it does:** Scores fixture-backed packing responses (structure, dates, weather alignment, baggage safety, profile alignment, privacy, hygiene). No live LLM calls in default mode.

**Default threshold:** 0.90 (override via script env or runner flags).

```bash
./evaluations/scripts/run_deterministic_gate.sh
THRESHOLD=0.95 ./evaluations/scripts/run_deterministic_gate.sh
```

This is the only evaluation tier required to pass automated validation.

## Level 2 — TrustyAI / EvalHub (preparatory only)

| Location | Role |
|----------|------|
| [`evaluations/datasets/packmate_eval_dataset.jsonl`](./datasets/packmate_eval_dataset.jsonl) | Fictional JSONL scenarios for future LMEval / EvalHub runs |
| [`evaluations/evalhub/`](./evalhub/) | Example EvalHub custom resource (not applied in CI) |
| [`evaluations/trusty-ai/`](./trusty-ai/) | Example TrustyAIService custom resource (not applied in CI) |
| [`evaluations/scripts/run_evalhub_optional.sh`](./scripts/run_evalhub_optional.sh) | Detects EvalHub CRD/instances; skips cleanly if absent |

### Cluster audit status (2026-07-16)

On OpenShift AI **3.4.2**:

- **TrustyAI operator:** Managed (Running)
- **TrustyAIService CRD:** present — **no instances** (`oc get trustyaiservices -A` → none)
- **EvalHub CRD:** present — **no instances** (`oc get evalhubs -A` → none)

**Honest scope:** EvalHub was **not executed** during the audit. Files under `evaluations/evalhub/` and `evaluations/trusty-ai/` are **examples and documentation only**. PR pipelines must not fail when EvalHub is absent.

```bash
./evaluations/scripts/run_evalhub_optional.sh   # exits 0 with SKIP if no EvalHub
```

## When to use which level

| Goal | Use |
|------|-----|
| Merge gate / regression on response quality | Level 1 deterministic |
| Instructor-led LLM-as-judge or LMEval on cluster | Level 2 after admin creates EvalHub / TrustyAIService |
| Gen AI Playground manual demos | [`playground/`](../playground/) prompts (not scored in CI) |

## Related documentation

- [backend/evals/README.md](../backend/evals/README.md) — evaluator weights and runner CLI
- [docs/implementation/OPENSHIFT_AI_CAPABILITIES.md](../docs/implementation/OPENSHIFT_AI_CAPABILITIES.md) — platform audit notes
