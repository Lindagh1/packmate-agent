# OAuth Proxy (optional)

This Kustomize **component** adds an [OpenShift oauth-proxy](https://github.com/openshift/oauth-proxy) in front of Packmate. It is **disabled by default** — neither `overlays/dev` nor `overlays/prod` include it unless you opt in.

## Enable

Uncomment the `components` block in your overlay `kustomization.yaml`:

```yaml
components:
  - ../../components/oauth-proxy
```

Then create the proxy cookie secret and OAuth client credentials in the target namespace (not stored in git):

```bash
oc create secret generic packmate-oauth-proxy \
  --from-literal=OAUTH2_PROXY_COOKIE_SECRET="$(openssl rand -base64 32)" \
  --from-literal=OAUTH2_PROXY_CLIENT_ID="<oauth-client-id>" \
  --from-literal=OAUTH2_PROXY_CLIENT_SECRET="<oauth-client-secret>" \
  -n packmate-dev
```

## Behavior

- Public `Route` targets `packmate-oauth-proxy` (port 8443).
- OAuth proxy forwards authenticated traffic to `packmate-frontend:8080`.
- The direct `packmate-frontend` Route is removed when this component is active.

Adjust `oauth-proxy-configmap.yaml` for your identity provider (`OAUTH2_PROXY_*` settings).
