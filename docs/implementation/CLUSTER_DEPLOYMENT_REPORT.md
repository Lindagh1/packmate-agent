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
| packmate-backend | v2-dev | `sha256:2bde1585eae84686ce4b47b05ce32457f761230fbd9e3c64872851fc1215d2d7` |
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
| Backend pytest | **114** passed |
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

Date : 2026-07-16
Images : backend `sha256:2bde1585…` · frontend `sha256:cdf68e4b…`
Endpoint public : `POST /api/v1/chat/stream` (UI) ; sync `/api/v1/chat` conservé pour tests.

### Fiabilité métier — correction des 4 `agent_error` (sans changer le SSE)

Scénarios précédemment en échec : `hiking_dolomites`, `powerbank_checked`, `liquid_cabin`, `oslo_cabin`.

| Scénario | Cause réelle | Correction |
|----------|--------------|------------|
| `hiking_dolomites` / `oslo_cabin` | Le modèle émettait **plusieurs tool-calls** ; l’historique multi-tool provoquait un **400** gateway (`single tool-calls at once`) au tour JSON suivant | Exécuter **un seul** tool-call par tour (priorité weather → baggage → profile) ; réécrire l’historique en turn mono-outil |
| `powerbank_checked` | JSON final **tronqué** (`finish_reason=length`, `max_tokens=1280`) puis `weather_summary` manquant après retries | Budget final **2560** tokens + retry ciblé si troncature ; injection déterministe de `weather_summary` / disclaimer depuis le contexte outils |
| `liquid_cabin` | JSON quasi valide mais **mal formé** (`Expecting ',' delimiter`) ; retries LLM insuffisants | Réparation JSON (virgules manquantes / trailing) avant validation Pydantic |

Validations locales associées : `backend/tests/test_business_scenarios.py` (+ tests agent/baggage mis à jour). Enrichissement bagages déterministe inchangé.

### Campagne 15 scénarios (Route publique) — baseline streaming (avant fix métier)

| Métrique | Valeur |
|----------|--------|
| Connexions avec `started` | **100 %** (15/15) |
| Flux terminés (`completed` ou `error` structuré) | **100 %** |
| `completed` métier OK | 11/15 (73 %) — **corrigé ensuite** (voir campagne post-fix) |
| Erreurs métier structurées (`agent_error`) | 4/15 (parse/LLM — transport OK) |
| Coupures idle ELB / EOF ~60s | **0** |
| Contenu sensible dans le flux | **0** |
| Heartbeat max gap estimé | **10 s** |
| TTFE (8 samples) | min 0.33 s · moy 0.38 s · p95 0.43 s · max 0.43 s |
| Durée min / médiane / max | 24.0 s / 31.1 s / 115.1 s |
| Requêtes **>60 s** avec `completed` | **≥1** (`rome_short` ≈60.7 s) |
| Requêtes longues avec heartbeats puis `error` | plusieurs (ex. hiking ≈115 s) — prouve la survie idle |

### Campagne 15 scénarios — post fix métier (backend `sha256:2bde1585…`)

- BuildConfig `packmate-backend` + digest overlay + rollout backend-only : **OK** (2026-07-16).
- Validation interne AgentService (avant panne cluster) :
  - `hiking` → **completed** (~42 s, 12 items, weather + baggage warnings)
  - `powerbank` → **completed** (~61 s, weather + baggage warnings)
  - `liquid` / `oslo_cabin` : non rejoués (coupure API mid-run)
- **Campagne publique 15/15 SSE** : **bloquée** — sandbox RHDP inaccessible
  (TLS EOF / connection refused sur API `:6443` et apps `*.apps…` depuis 2026-07-16 ~17:45
  jusqu’au contrôle 2026-07-17). Protocole SSE / Nginx / Route **non modifiés**.

Dès le retour du cluster, relancer `/tmp/packmate-sse-campaign15.py` (scénarios `/tmp/stream-scenarios.tsv`).

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
11. **JSON mal formé** (liquid, virgules manquantes) → réparation déterministe dans le parser avant Pydantic.

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
