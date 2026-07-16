# Architecture

## Runtime components

```mermaid
flowchart TB
  subgraph edge [Edge]
    User
  end
  subgraph openshift [OpenShift project]
    Route --> Frontend
    Frontend -->|ClusterIP /api| Backend
    Backend --> ConfigMap
    Backend --> SecretLLM[Secret packmate-llm]
  end
  subgraph modelns [my-first-model]
    Predictor[llama-32-3b-instruct-predictor]
  end
  Backend -->|BASE_URL /v1| Predictor
  Backend --> OpenMeteo[Open-Meteo API]
```

## Agent loop

1. Receive chat request + optional traveler profile
2. Call tools as needed: weather, baggage_rules, traveler_profile
3. Ask model for structured PackingResponse JSON
4. Parse + validate with Pydantic
5. Deterministically enrich baggage warnings, privacy filters, daily forecast, category order
6. Return response

## Delivery

```mermaid
flowchart LR
  PR[Pull Request] --> TektonPR[Tekton PR pipeline]
  Push[Push main] --> TektonPush[Tekton push pipeline]
  TektonPush --> Images[Image digests]
  Images --> GitOps[GitOps commit]
  GitOps --> ArgoDev[Argo CD dev auto]
  GitOps --> ArgoProd[Argo CD prod manual]
  ArgoProd --> Rollout[Backend Rollout canary]
```

## Privacy boundaries

- Medical notes stay local unless explicit consent flag is true
- Logs and OTel spans never include message bodies or notes
- Frontend does not persist sensitive fields

## Observability

- `/metrics` Prometheus exposition
- Optional OTLP traces
- `/health` liveness, `/ready` readiness (no LLM dependency)
