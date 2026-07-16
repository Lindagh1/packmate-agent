# Workbench creation — manual steps (packmate-lab)

Declarative Notebook creation was **not applied automatically** during live deployment.
Reason: no existing Notebook CR was available on this cluster to copy a confirmed
OAuth-sidecar / annotation layout for OpenShift AI **3.4.2**. Creating an approximate
Notebook CR risks a stuck Workbench.

## Confirmed image on this cluster

ImageStream: `code-server-notebook` (namespace `redhat-ods-applications`)  
Recommended tag: **`2025.2`** or **`3.4`**  
Dashboard name: **Code Server | Data Science | CPU | Python 3.12**

## UI steps

1. Open OpenShift AI dashboard → **Projects** → **Packmate Lab** (`packmate-lab`).
2. Open the project → **Workbenches** → **Create workbench**.
3. Name: `packmate-code-server`.
4. Image: **Code Server | Data Science | CPU | Python 3.12** (tag `2025.2` / `3.4`).
5. Resources:
   - CPU request `500m`, limit `2`
   - Memory request `2Gi`, limit `4Gi`
   - Cluster storage `20Gi`
6. Do **not** inject Git or LLM credentials in the Workbench form for this lab
   (clone with HTTPS when needed; use the in-cluster Packmate app for LLM).
7. Create → wait until **Running** → Open.
8. In the terminal:

```bash
git clone https://github.com/Lindagh1/packmate-agent.git
cd packmate-agent
git switch packmate-v2
```

## Status

`MANUAL_REQUIRED`
