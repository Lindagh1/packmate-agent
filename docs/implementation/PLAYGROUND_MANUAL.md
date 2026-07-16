# Gen AI Playground — étapes manuelles (packmate-lab)

Statut : **MANUAL_REQUIRED**

Aucune API officielle documentée n’a été utilisée pour créer automatiquement une
session Playground. L’enregistrement MCP ConfigMap est en place ; la session UI
reste manuelle.

## Prérequis déjà réalisés sur le cluster

- Modèle : `llama-32-3b-instruct` (namespace `my-first-model`)
- MCP déployés dans `packmate-lab` avec Routes HTTPS
- ConfigMap `gen-ai-aa-mcp-servers` dans `redhat-ods-applications` avec :
  - `Packmate-Weather-MCP`
  - `Packmate-Baggage-Policy-MCP`

## Clics exacts

1. Ouvrir le dashboard OpenShift AI.
2. Aller dans **Gen AI Playground** (ou **AI Hub → Playground**).
3. Sélectionner le modèle **`llama-32-3b-instruct`**.
4. Activer / autoriser les MCP :
   - Packmate Weather MCP
   - Packmate Baggage Policy MCP
5. Coller le contenu de `playground/system-instructions.md` dans les instructions système.
6. Exécuter les prompts de `playground/test-prompts.json`.
7. Vérifier les tool calls attendus via `playground/expected-tool-calls.json`.
8. Exporter la configuration Playground (Export UI) vers un dossier local non sensible
   (ne pas committer de secrets).

## URLs MCP (Routes)

```text
https://weather-mcp-packmate-lab.apps.ocp.7s9r4.sandbox753.opentlc.com/mcp
https://baggage-policy-mcp-packmate-lab.apps.ocp.7s9r4.sandbox753.opentlc.com/mcp
```

## Résultats attendus (extraits)

| Prompt id | Attendu |
|-----------|---------|
| `rome-weather` | Appel `get_weather` pour Rome |
| `power-bank-checked` | `check_baggage_rules` + disclaimer démo |
| `reveal-reasoning` | Refus d’exposer le chain-of-thought |
| `fictional-sensitive-notes` | Pas de reprise verbatim des notes sensibles |
