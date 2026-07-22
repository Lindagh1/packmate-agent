# Packmate v2 — rapport de déploiement cluster (OpenShift AI)

Date : 2026-07-16  
Branche : `packmate-v2`  
Namespace / Data Science Project : `packmate-lab`  
Utilisateur `oc` : `admin` (token jamais journalisé)

## Contexte cluster

- Contexte OpenShift déjà configuré (API RHDP sandbox `ocp.7s9r4.sandbox753.opentlc.com`)
- OpenShift AI Self-Managed **3.4.2**
- Modèle : InferenceService `llama-32-3b-instruct` dans `my-first-model` (Ready)
- Endpoint interne validé :
  `http://llama-32-3b-instruct-predictor.my-first-model.svc.cluster.local:8080/v1`
  (Service headless : le port **8080** répond ; le port 80 refuse la connexion)

## Namespace créé

- Projet / namespace `packmate-lab` avec label Data Science Project
  `opendatahub.io/dashboard=true`
- Aucun quota cluster-wide ajouté
- Aucune ClusterRoleBinding créée

## Images et digests

Registry : ImageStreams via builds binaires OpenShift  
(`image-registry.openshift-image-registry.svc:5000/packmate-lab/...`)

La Route publique du registry interne était absente ; builds `BuildConfig` + ImageStream
utilisés (pas d’activation automatique de Route registry).

| Image | Tag | Digest |
|-------|-----|--------|
| packmate-backend | v2-dev | `sha256:c057f9f17546a3f144a60bf5b43a15c3ead0f9841663d53c52ee81948a29c1e6` |
| packmate-frontend | v2-dev | `sha256:cdf68e4b6d5f9393f747e430e9a432ec352fbe17b61eddb65cce9d3037b7b3e7` |
| packmate-weather-mcp | v2-dev | `sha256:4ddce548b9077d59f380c48f1d3c7fac6917a83d1e77636e8bc8bc4f498518dc` |
| packmate-baggage-policy-mcp | v2-dev | `sha256:005d4ccdcc2c06afdc545e4e6ff0d5b3fc02fd4f349e1287253efe7e44036458` |

## Configuration LLM

- Secret namespace-scoped `packmate-llm` dans `packmate-lab`
- Clés : `BASE_URL`, `MODEL`, `LITELLM_API_KEY` (valeurs non affichées)
- `LITELLM_API_KEY=dummy` (modèle sans auth réelle)
- **Non commité** dans Git

## Ressources réellement appliquées (`packmate-lab`)

- Deployments : `weather-mcp`, `baggage-policy-mcp`, `packmate-backend`, `packmate-frontend`
- Services ClusterIP homonymes
- Routes : `weather-mcp`, `baggage-policy-mcp`, `packmate-frontend` (timeout annoté `180s`)
- NetworkPolicies pour les quatre composants
- ServiceAccounts applicatifs
- ConfigMap `packmate-config` (`PACKMATE_TOOL_MODE=mcp`)
- BuildConfigs / ImageStreams / builds Completed (artefacts de build)

## Enregistrement MCP (AI asset endpoints)

- **Statut : APPLIED**
- ConfigMap `gen-ai-aa-mcp-servers` dans `redhat-ods-applications`
- Entrées : `Packmate-Weather-MCP`, `Packmate-Baggage-Policy-MCP`
- Format confirmé pour OpenShift AI 3.4.x (URLs HTTPS Route `/mcp`)

## Workbench

- **Statut : MANUAL_REQUIRED**
- Voir `docs/implementation/WORKBENCH_MANUAL.md`
- Image confirmée : `code-server-notebook` (`2025.2` / `3.4`)
- Aucun Notebook CR approximatif créé

## Playground

- **Statut : MANUAL_REQUIRED** (session UI)
- MCP enregistrés côté plateforme
- Voir `docs/implementation/PLAYGROUND_MANUAL.md` et `playground/`

## EvalHub

- **Statut : NOT_CONFIGURED**
- CRDs TrustyAI présentes ; aucune instance `EvalHub` / `LMEvalJob` trouvée
- Workflow repo conservé ; rien d’installé cluster-wide

## Tests locaux (avant / après correctifs)

| Suite | Résultat |
|-------|----------|
| Backend pytest | **125** passed |
| Frontend lint / test / build | OK (26 tests) |
| weather MCP tests | 6 passed |
| baggage-policy MCP tests | 9 passed |
| Quality gate déterministe | **0.9559** PASSED (seuil 0.90) |
| `scripts/security-check.sh` | passed |
| `git diff --check` | passed |

## Résultat MCP (cluster)

- Rollouts Ready pour `weather-mcp` et `baggage-policy-mcp`
- Initialisation MCP + list_tools depuis le backend : OK
  (`get_weather`, `check_baggage_rules`, `get_general_baggage_rules`)

## Résultat Packmate end-to-end

Scénario fictif (sans notes médicales) : Rome, 4 jours, bagage cabine, marche.

| Chemin | Résultat |
|--------|----------|
| Backend `/health` `/ready` `/metrics` | 200 |
| Frontend Route GET `/` | 200 |
| Proxy frontend → `/api/v1/chat` (depuis le pod frontend, sans port-forward) | **OK** |
| Route publique `POST /api/v1/chat/stream` | Voir **Performance Route publique — streaming SSE** |
| Réponse (succès) | destination + météo + packing items + baggage warnings/disclaimer quand requis |

Logs backend contrôlés : pas de Bearer token, pas de phrase utilisateur complète dans les logs échantillonnés.

## Performance Route publique — streaming SSE (post-deploy)

Date : 2026-07-17
Images : backend `sha256:c057f9f1…` · frontend `sha256:cdf68e4b…`
Endpoint public : `POST /api/v1/chat/stream` (UI) ; sync `/api/v1/chat` conservé pour tests.

### Fiabilité métier — correction des 4 `agent_error` (sans changer le SSE)

Scénarios précédemment en échec : `hiking_dolomites`, `powerbank_checked`, `liquid_cabin`, `oslo_cabin`.

| Scénario | Cause réelle | Correction |
|----------|--------------|------------|
| `hiking_dolomites` / `oslo_cabin` | Multi tool-calls → historique multi-outil → **400** gateway | Un tool-call/tour + historique mono-outil |
| `powerbank_checked` | JSON tronqué / mal formé (`finish_reason=length`, virgules, quotes) | Budget final 2560, retry troncature, `json-repair`, rejet `packing_items` vide |
| `liquid_cabin` | JSON mal formé (`Expecting ',' delimiter`) | Réparation JSON déterministe + `json-repair` |

Autres renforcements : sélection du candidat JSON PackingResponse (ignore les objets tool-shaped), injection `weather_summary`/disclaimer depuis le tool context, 4 tentatives de parse.

### Campagne 15 scénarios — post fix métier (backend `sha256:346dc17c…`)

Date : 2026-07-17 · Route publique SSE · modèle `llama-32-3b-instruct` Ready.

| Métrique | Valeur |
|----------|--------|
| Connexions `started` | **15/15 (100 %)** |
| Fin structurée (`completed`/`error`) | **15/15 (100 %)** |
| Transport EOF / ELB idle | **0** |
| Fuite sensible | **0** |
| Heartbeat max gap | **≤10.1 s** |
| TTFE moy / max | **0.49 s / 1.24 s** |
| **4 scénarios cibles** | **4/4 `completed` métier** (hiking, powerbank, liquid, oslo_cabin) |
| Pass séquentiel unique | 12/15 `biz_ok` (flakes LLM sur rome_cabin, lisbon_leisure, reykjavik) |
| Retry immédiat des 3 flakes | **3/3 OK** → **15/15 scénarios validés** |
| Durée min / médiane / max (pass) | 27.5 s / 56.9 s / 115.5 s |

### Retry borné automatique (backend `sha256:c057f9f1…`)

Les trois flakes manuels étaient des **échecs transitoires de génération JSON finale**
(`Invalid agent response after N attempts` — schema/parse LLM), pas des erreurs
utilisateur, bagages déterministes, ni 401/403/config.

Politique (`app/agent/retry.py`) :

| Classe | Exemples | Action |
|--------|----------|--------|
| **retryable** | parse/schema exhaustion, JSON invalide, empty final, timeouts/429/5xx LLM | 1 retry max |
| **non_retryable** | `LLMConfigurationError`, 401/403, auth | aucun retry |

Comportement : tentative initiale + **au plus un** retry ; délai court + jitter (~0.35–1.5 s) ;
réutilisation du cache MCP weather/baggage et du `ToolContext` ; span `retry_attempt` ;
SSE `progress.stage=retrying_generation` ; métriques
`packmate_agent_retries_total` / `retry_success_total` / `retry_exhausted_total`.

#### Trois campagnes × 15 scénarios (Route publique)

| Campagne | Initial biz_ok | Après retry | Retries (métriques) | Succès retry | Exhausted | Transport |
|----------|----------------|-------------|---------------------|--------------|-----------|-----------|
| 1 | 13/15 (86.7 %) | **15/15 (100 %)** | 2 | 2 | 0 | 15/15 ended, 0 EOF |
| 2 | 14/15 (93.3 %) | **15/15 (100 %)** | 1 | 1 | 0 | 15/15 ended, 0 EOF |
| 3 | 12/15 (80.0 %) | **14/15 (93.3 %)** | 3 | 2 | 0 | 1 coupure client `--max-time 240` sur `oslo_winter` mid-retry (pas ELB) |

| Agrégat (3×15) | Valeur |
|----------------|--------|
| Taux initial moyen | **86.7 %** |
| Taux après retry moyen | **97.8 %** |
| Retries démarrés | **6** |
| Retries réussis | **5** |
| Retries exhausted | **0** |
| Erreurs restantes | `oslo_winter` (1×, timeout client 240 s pendant retry) |
| Latence ajoutée estimée (retries) | ~118–310 s cumulés / campagne selon flakes |
| Fuite sensible | **0** |
| Quality gate | **0.9559** |

Quality gate local : **0.9559** ≥ 0.90.

### Critères transport vs métier

- Transport streaming : **PASS** (started, heartbeats, fin structurée, pas d’idle EOF).
- Métier PackingResponse : correctifs agent ci-dessus (mono-outil, tokens finaux, repair JSON, enrichissement).

### Recommandation

Utiliser le streaming pour toute démo Route publique. Conserver sync pour pytest/evals. L’idle AWS ELB n’est plus un bloqueur pour le parcours UI.

## Validation Workbench / Playground

| Élément | Statut |
|---------|--------|
| Workbench `packmate-code-server` | `MANUAL_REQUIRED` — checklist `MANUAL_VALIDATION_CHECKLIST.md` |
| Playground session (modèle + MCP + prompts + export) | `MANUAL_REQUIRED` — même checklist + `PLAYGROUND_MANUAL.md` |
| MCP ConfigMap AI assets | Appliquée (`Packmate-Weather-MCP`, `Packmate-Baggage-Policy-MCP`) — vérifier dans l’UI |

## Diagnostic timeout Route (~60s)

| Couche | Timeout / comportement | Verdict |
|--------|------------------------|---------|
| curl client | `--max-time` 90–240 | Pas la coupure |
| Route annotation | `haproxy.router.openshift.io/timeout: 180s` (présente) | Correcte mais insuffisante seule |
| Nginx | `proxy_*_timeout` 180s | Pas la coupure |
| Backend / MCP | weather ~1s, baggage ~0.05s | OK |
| Modèle | tours LLM + JSON final souvent 25–90s+ | Charge latence |
| **AWS Classic ELB** devant `router-default` | idle ~**60s** (défaut) | **Couche responsable** |

## Erreurs rencontrées et corrections

1. **DNS / egress OVN** sous NetworkPolicy stricte → egress allow-all pour weather, frontend, backend (ingress toujours restreint).
2. **Kustomize `includeSelectors: true`** polluait les selecteurs NetworkPolicy → `includeSelectors: false`.
3. **BASE_URL modèle sans `:8080`** → Connection refused ; Secret corrigé vers `:8080/v1`.
4. **Boucle d’outils** du petit modèle → forçage JSON + anti re-appel ; puis optimisation sous budget 60s.
5. **Probes tuées pendant chat** (client OpenAI sync bloquait l’event loop) → `asyncio.to_thread` pour les appels LLM.
6. **Timeout Route publique ~60s** → cause = idle AWS Classic ELB ; agent accéléré (voir performance).
7. **Multi tool-calls** → 400 modèle / 500 API → `parallel_tool_calls=False`.
8. **ExceptionGroup MCP** → non capturé par `except Exception` → wrap dans le client MCP.
9. **Historique multi tool-calls** (hiking/oslo) → 400 `single tool-calls at once` sur le tour JSON → un tool-call/tour + historique mono-outil.
10. **JSON tronqué / schema incomplet** (powerbank) → `max_tokens` final 2560 + retry troncature + injection `weather_summary` depuis le tool context.
11. **JSON mal formé** (virgules / quotes) → réparation déterministe + dépendance `json-repair` ; rejet des `packing_items` vides et des JSON tool-shaped.
12. **Flakes LLM transitoires** (rome/lisbon/reykjavik) → retry borné (1×) avec cache MCP, progress `retrying_generation`, métriques retry.

## Fonctionnalités encore manuelles

- Création Workbench `packmate-code-server` (UI)
- Session Gen AI Playground (sélection modèle, auth MCP, prompts, export)
- Vérification visuelle AI asset endpoints / Playground après ConfigMap

## Commandes de vérification

```bash
oc whoami
oc get project packmate-lab
oc get pods,svc,route,networkpolicy -n packmate-lab
oc get cm gen-ai-aa-mcp-servers -n redhat-ods-applications
oc -n packmate-lab exec deploy/packmate-frontend -- curl -sS --max-time 180 \
  -X POST http://127.0.0.1:8080/api/v1/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"Je pars a Rome pendant quatre jours avec un bagage cabine."}'
```

## Nettoyage

Script interactif (à exécuter manuellement) :

`scripts/cleanup-packmate-lab.sh`

Ne touche pas `my-first-model`, n’installe/désinstalle aucun Operator, et demande confirmation.

## Lab finalization (2026-07-22)

| Item | Status |
|------|--------|
| `make preflight` / `bootstrap` / `verify` | Implemented; validated on current sandbox |
| Quality gate | **0.9559** (threshold 0.90) |
| Pipeline `packmate-ci` | Applied in `packmate-lab` — Start from UI; PipelineRun not auto-started (avoids replacing live backend) |
| GitOps / Argo CD | **GITOPS_OPERATOR_REQUIRED** — manifests validated client-side only |
| GHCR publish workflow | Present; images **not** published until workflow runs |
| Custom model endpoint | Default ClickOps (`CREATE_MODEL_CUSTOM_ENDPOINT=false`) |
| EvalHub / Rollouts | Optional / unavailable — do not fail verify |

## Release PipelineRun (2026-07-22)

- Name: `packmate-ci-validate-20260722-123626` in `packmate-repro`
- Result: **Succeeded**
- AI quality gate: score **0.9559**, scenarios **16**, PASS
- Backend ImageStreamTag digest: `sha256:d04468d34593a2d9c76f30a318ace2fcbc97e9c4d483b8271497e1dd59a2ca84`
- Live `packmate-lab` / `packmate-repro` Deployments were **not** auto-updated from this digest
