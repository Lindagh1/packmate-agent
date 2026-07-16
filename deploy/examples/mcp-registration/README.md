# MCP registration for Gen AI Playground

On OpenShift AI **3.4.x**, MCP servers appear in AI asset endpoints / Playground after a cluster administrator creates:

`ConfigMap/gen-ai-aa-mcp-servers` in `redhat-ods-applications`

This directory contains an **example** ConfigMap. It is not applied by Packmate scripts.

## Steps (manual / admin)

1. Deploy `weather-mcp` and `baggage-policy-mcp` (GitOps or instructor apply).
2. Read Route hosts:

   ```bash
   oc get route weather-mcp baggage-policy-mcp -n packmate-lab
   ```

3. Edit `gen-ai-aa-mcp-servers.yaml` with real `https://<host>/mcp` URLs.
4. Admin applies the ConfigMap (outside participant scope for most labs).
5. Open Gen AI Playground and authorize the MCP tools.

## Status on audited cluster (2026-07-16)

`gen-ai-aa-mcp-servers` was **not present**. Playground MCP discovery was therefore not verified end-to-end.
