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
| packmate-backend | v2-dev | `sha256:ed74feec22ad25da07d66260090520e8cbf4cb4f33ad3b884eb42547e2f1d3a9` |
| packmate-frontend | v2-dev | `sha256:a6517ab1a06aaf5273755da816c0d4f72482bbc53fc10a20185eda88b567a1be` |
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
| Backend pytest | 96 passed |
| Frontend lint / test / build | OK |
| weather MCP tests | 6 passed |
| baggage-policy MCP tests | 9 passed |
| Quality gate déterministe | **0.9559** PASSED (seuil 0.90) |
| `scripts/security-check.sh` | passed |
| `scripts/validate-manifests.sh` | passed |

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
| Route publique `POST /api/v1/chat` (campagne 10 scénarios) | Voir **Performance Route publique** ci-dessous |
| Réponse (succès) | destination + météo + packing items + baggage warnings/disclaimer quand requis |

Logs backend contrôlés : pas de Bearer token, pas de phrase utilisateur complète dans les logs échantillonnés.

## Performance Route publique (campagne 10 requêtes)

Date de mesure : 2026-07-16 (backend `sha256:ed74feec…`, `parallel_tool_calls=False`, `max_tokens=1280`).

Scénarios fictifs : Rome cabine, Oslo hiver, business Frankfurt, randonnée, powerbank checked, liquide cabine, Rome court, Lisbonne, Oslo cabine, Barcelone + batterie.

### Statistiques (toutes requêtes, y compris coupures ELB)

| Métrique | Valeur |
|----------|--------|
| Succès | **7 / 10 (70 %)** |
| Échecs | 3 (`rome_cabin`, `powerbank_checked`, `barcelona_battery`) — TLS EOF / idle ~60s |
| min | 23.2 s |
| moyenne | 38.4 s |
| médiane (p50) | 31.1 s |
| p90 | 60.2 s |
| p95 | 60.2 s |
| max | 60.3 s |

### Parmi les 7 succès HTTP 200

| Métrique | Valeur |
|----------|--------|
| min–max | 23.2–40.0 s |
| médiane | ≈26.4 s |
| météo | présente sur tous les succès concernés |
| baggage warnings / disclaimer | présents sur les scénarios cabine/liquides/business |

### Critères lab (p95 &lt; 50s, max &lt; 58s, succès 100 %)

**Non atteints** sur la Route publique à cause de l’idle AWS Classic ELB (~60s), pas de Nginx ni de l’annotation Route 180s.

Mesures in-cluster (sans ELB) : `rome_cabin` ≈48s OK ; certains scénarios powerbank peuvent dépasser 60–100s ou échouer au parse JSON si la génération est trop longue — le plafond ELB coupe avant la fin.

### Optimisations synchrones déjà appliquées

- Cache des tool calls identiques ; omit `traveler_profile` sans profil
- Force JSON dès weather + baggage obtenus
- `parallel_tool_calls=False` (le modèle refuse les multi tool-calls)
- Capture `ExceptionGroup` MCP → plus de 500 non gérés
- `max_tokens=1280` ; outils MCP bagages en parallèle quand `include_general_rules`

### Risque ELB restant

Toute requête dont le TTFB dépasse ~60s sans bytes est coupée par l’ELB, même si HAProxy/Nginx sont à 180s.

### Recommandation opérationnelle

1. Démos / validation participante : privilégier des prompts typiques (Rome court, Oslo, business, liquides) — **stables &lt; 40s**.
2. Garantie stricte p95 &lt; 50s / succès 100 % via Route publique : **nécessite streaming (keep-alive) ou API asynchrone** — non implémenté automatiquement ici.
3. Alternative cluster-admin (hors lab) : monter l’idle timeout AWS Classic ELB.

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

## Fonctionnalités encore manuelles

- Création Workbench `packmate-code-server` (UI)
- Session Gen AI Playground (sélection modèle, auth MCP, prompts, export)
- Vérification visuelle AI asset endpoints / Playground après ConfigMap
- Streaming / job asynchrone si une SLA publique stricte &lt; 50s est exigée
- Option admin : idle timeout AWS ELB (hors `packmate-lab`)

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
