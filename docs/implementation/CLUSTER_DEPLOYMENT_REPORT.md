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
| packmate-backend | v2-dev | `sha256:ec1218cbe4457400b6fb4c0734430d6cc36a77e9065b49ada483c44cb59b05dc` |
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
| Réponse | `destination=Rome`, 9 packing items, weather présent, **2 baggage_warnings**, `rules_disclaimer` présent |
| Route externe POST chat long | Instable : timeout / EOF côté edge (~60s) malgré annotation Route `180s` — latence modèle + tours d’outils |

Logs backend contrôlés : pas de Bearer token, pas de phrase utilisateur complète dans les logs échantillonnés.

## Erreurs rencontrées et corrections

1. **DNS / egress OVN** sous NetworkPolicy stricte → egress allow-all pour weather, frontend, backend (ingress toujours restreint).
2. **Kustomize `includeSelectors: true`** polluait les selecteurs NetworkPolicy → `includeSelectors: false`.
3. **BASE_URL modèle sans `:8080`** → Connection refused ; Secret corrigé vers `:8080/v1`.
4. **Boucle d’outils** du petit modèle → `MAX_TOOL_ROUNDS=8` + forçage JSON final ; prompt anti re-appel.
5. **Probes tuées pendant chat** (client OpenAI sync bloquait l’event loop) → `asyncio.to_thread` pour les appels LLM.
6. **Timeout Route / edge** sur chat long → annotation `haproxy.router.openshift.io/timeout=180s` + nginx proxy 180s ; validation E2E principale via proxy in-pod.

## Fonctionnalités encore manuelles

- Création Workbench `packmate-code-server` (UI)
- Session Gen AI Playground (sélection modèle, auth MCP, prompts, export)
- Vérification visuelle AI asset endpoints / Playground après ConfigMap
- Chat long via Route publique si le edge impose un plafond < latence LLM

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
