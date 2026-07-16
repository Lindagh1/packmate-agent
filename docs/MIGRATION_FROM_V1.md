# Migration from Packmate v1

| Area | v1 | v2 |
|------|----|----|
| UI | Streamlit | React + PatternFly lab UI |
| API | Scripted agent in Streamlit process | FastAPI service |
| Packaging | Ad-hoc | Podman Containerfiles + Compose |
| CI | Generated/ad-hoc | Tekton Pipelines as Code |
| Images | Often `:latest` | Placeholder tags + digest promotion |
| Delivery | Manual / single Deployment | Argo CD GitOps; prod backend Rollout |
| Observability | print logs | Prometheus + optional OpenTelemetry |
| Privacy | Limited | Explicit consent + deterministic filters |
| Quality | Manual checks | Deterministic evaluation gate |

## What stays

- Original Streamlit files remain for reference (`app.py`, `app.sh`, `agent.py`, `k8s/app.yaml`) and are not modified by v2 work.

## Cutover advice

1. Keep v1 available during lab
2. Deploy v2 to a dedicated namespace
3. Point demo traffic to frontend Route
4. Retire v1 only after instructor validation
