#!/usr/bin/env bash
# Validate the rendered PRODUCTION overlay (oc kustomize deploy/overlays/prod).
# Offline-first: renders locally, does not apply to a cluster.
#
# Fails if the rendered output contains: Notebook, Pipeline, PipelineRun,
# Workbench kinds; ":latest" image tags; the packmate-lab namespace; a
# secretKeyRef/Secret named "packmate-llm" (must be "packmate-prod-llm");
# or cleartext password-like patterns.
#
# Passes only if: namespace is packmate-prod, backend/frontend/MCP images
# are all digest-pinned, and exactly 4 Deployments are present.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="${ROOT}/deploy/overlays/prod"

command -v oc >/dev/null 2>&1 || { echo "ERROR: oc CLI not found (required to run 'oc kustomize')" >&2; exit 1; }
[[ -d "${OVERLAY}" ]] || { echo "ERROR: ${OVERLAY} not found" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
RENDERED="${TMP}/prod-rendered.yaml"

echo "Rendering ${OVERLAY} ..."
oc kustomize "${OVERLAY}" > "${RENDERED}"

echo "Validating rendered output ..."
python3 - "${RENDERED}" <<'PY'
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required for offline validation (pip install pyyaml)", file=sys.stderr)
    sys.exit(1)

path = Path(sys.argv[1])
text = path.read_text()
docs = [d for d in yaml.safe_load_all(text) if d]

failed = False


def fail(msg):
    global failed
    print(f"FAIL: {msg}", file=sys.stderr)
    failed = True


def ok(msg):
    print(f"OK:   {msg}")


# --- 1) Forbidden kinds -----------------------------------------------------
forbidden_kinds = {"Notebook", "Pipeline", "PipelineRun", "Workbench"}
present_kinds = {d.get("kind") for d in docs if isinstance(d, dict)}
found_forbidden = forbidden_kinds & present_kinds
if found_forbidden:
    fail(f"forbidden kind(s) present in rendered prod overlay: {sorted(found_forbidden)}")
else:
    ok("no Notebook/Pipeline/PipelineRun/Workbench kinds in rendered prod overlay")

# --- 2) No :latest tags ------------------------------------------------------
latest_hits = re.findall(r'image:\s*\S*:latest(?:\s|$|["\'])', text)
if latest_hits:
    fail(f":latest image tag(s) found: {latest_hits}")
else:
    ok("no :latest image tags")

# --- 2b) No OpenShift internal-registry PROD images (not portable) ----------
if "image-registry.openshift-image-registry.svc" in text or "default-route-openshift-image-registry" in text:
    fail("PROD overlay must not reference the OpenShift internal registry (use durable GHCR digests)")
else:
    ok("no OpenShift internal-registry image references in PROD")

# --- 3) No packmate-lab as Kubernetes namespace ----------------------------
# Portable PROD must not use packmate-lab as metadata.namespace.
if re.search(r'(?m)^\s*namespace:\s*packmate-lab\s*$', text):
    fail("rendered prod overlay sets metadata namespace packmate-lab")
elif re.search(r'(?m)^\s*namespace:\s*packmate-lab\b', text):
    fail("packmate-lab used as a Kubernetes namespace field in prod overlay")
else:
    ok("no packmate-lab Kubernetes namespace fields")

# --- 4) Secret naming: packmate-llm must be packmate-prod-llm ---------------
if re.search(r'\bname:\s*packmate-llm\b', text):
    fail("secretKeyRef/Secret references 'packmate-llm' (must be 'packmate-prod-llm')")
else:
    ok("no 'packmate-llm' secret references")

if "packmate-prod-llm" not in text:
    fail("expected secretKeyRef reference to 'packmate-prod-llm' is missing")
else:
    ok("backend secretKeyRef targets 'packmate-prod-llm'")

# --- 5) Cleartext password-like patterns ------------------------------------
cleartext_re = re.compile(
    r'(?i)(password|passwd|pwd|api[_-]?key|secret)\s*[:=]\s*["\']?[^"\'\s{}$][^\n"\']{3,}'
)
suspicious = []
for m in cleartext_re.finditer(text):
    snippet = m.group(0)
    if "secretKeyRef" in snippet or "valueFrom" in snippet:
        continue
    suspicious.append(snippet.strip())
if suspicious:
    fail(f"possible cleartext password/secret pattern(s): {suspicious[:5]}")
else:
    ok("no cleartext password/secret patterns")

for doc in docs:
    if isinstance(doc, dict) and doc.get("kind") == "Secret" and (doc.get("data") or doc.get("stringData")):
        fail(f"Secret/{(doc.get('metadata') or {}).get('name')} carries data/stringData in rendered output")

# --- 6) Pass conditions: namespace, digests, exactly 4 Deployments ---------
namespaced_docs = [d for d in docs if isinstance(d, dict) and (d.get("metadata") or {}).get("namespace")]
bad_ns = {
    d["metadata"]["namespace"]
    for d in namespaced_docs
    if d["metadata"]["namespace"] != "packmate-prod"
}
if bad_ns:
    fail(f"unexpected namespace(s) in rendered output: {sorted(bad_ns)}")
elif not namespaced_docs:
    fail("no namespaced resources found in rendered output")
else:
    ok("all namespaced resources target packmate-prod")

deployments = [d for d in docs if isinstance(d, dict) and d.get("kind") == "Deployment"]
if len(deployments) == 4:
    ok(f"exactly 4 Deployments present: {sorted(d['metadata']['name'] for d in deployments)}")
else:
    fail(f"expected exactly 4 Deployments, found {len(deployments)}: "
         f"{sorted((d.get('metadata') or {}).get('name') for d in deployments)}")

digest_images = []
for d in deployments:
    containers = (((d.get("spec") or {}).get("template") or {}).get("spec") or {}).get("containers") or []
    for c in containers:
        img = c.get("image", "")
        if "@sha256:" in img:
            digest_images.append(img)
        else:
            fail(f"Deployment/{d['metadata']['name']} container {c.get('name')} image is not digest-pinned: {img}")

if len(digest_images) >= 4:
    ok(f"{len(digest_images)} container image(s) digest-pinned (@sha256:...)")

if failed:
    sys.exit(1)
print("Prod overlay validation passed.")
PY
