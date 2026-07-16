# TrustyAIService example (preparatory)

Example **TrustyAIService** custom resource for Packmate-related TrustyAI workloads on OpenShift AI.

## Audit status

- TrustyAI operator was **Managed** (Running) on OAI 3.4.2
- TrustyAIService CRD was **present**
- **No TrustyAIService instances** existed at audit (`oc get trustyaiservices -A` → none)
- This example was **not applied**; no TrustyAI inference service was exercised for Packmate

## Usage

1. Confirm TrustyAI operator is Managed in the DataScienceCluster.
2. Replace `PLACEHOLDER_*` values in [trustyaiservice-example.yaml](./trustyaiservice-example.yaml).
3. Apply only when an instructor enables native TrustyAI evals — **not** in automated validation.

```bash
# Instructor-only (example):
# oc apply -f evaluations/trusty-ai/trustyaiservice-example.yaml
```

## Relationship to Packmate evals

| Tier | Mechanism |
|------|-----------|
| Level 1 | [`backend/evals/`](../../backend/evals/) deterministic gate |
| Level 2 | EvalHub + TrustyAIService (optional, cluster-dependent) |

See [../README.md](../README.md) for the full hybrid evaluation model.
