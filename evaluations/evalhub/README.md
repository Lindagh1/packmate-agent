# EvalHub example (preparatory)

Example **EvalHub** custom resource for Packmate fictional scenarios. Intended for instructor-led activation on OpenShift AI when EvalHub is installed.

## Audit status

- EvalHub CRD `evalhubs.trustyai.opendatahub.io` was **present** on OAI 3.4.2
- **No EvalHub instances** existed at audit (`oc get evalhubs -A` → none)
- This file was **not applied** and EvalHub was **not executed** as part of Packmate validation

## Usage

1. Ensure TrustyAI operator is Managed and EvalHub CRD is available.
2. Replace all `PLACEHOLDER_*` values in [packmate-evalhub-example.yaml](./packmate-evalhub-example.yaml).
3. Apply only under instructor / cluster-admin control — **never** in automated CI or `oc apply` validation scripts.

```bash
# Instructor-only (example):
# oc apply -f evaluations/evalhub/packmate-evalhub-example.yaml
```

## Dataset

JSONL input: [../datasets/packmate_eval_dataset.jsonl](../datasets/packmate_eval_dataset.jsonl) — fictional scenarios only.

## Optional runner

[../scripts/run_evalhub_optional.sh](../scripts/run_evalhub_optional.sh) checks for EvalHub CRD/instances and exits 0 with a skip message when absent.
