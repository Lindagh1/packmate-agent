#!/usr/bin/env python3
"""Resolve a GHCR tag to Docker-Content-Digest. Auth from REGISTRY_AUTH_FILE."""
from __future__ import annotations

import json
import os
import sys
import urllib.request


def main() -> int:
    auth_file = os.environ.get("REGISTRY_AUTH_FILE", "")
    owner = os.environ.get("PACKMATE_PROMOTION_REGISTRY_OWNER", "").lower()
    name = os.environ.get("PACKMATE_PROMOTION_IMAGE_NAME", "")
    tag = os.environ.get("EXT_TAG", "")
    if not all([auth_file, owner, name, tag]):
        print("missing REGISTRY_AUTH_FILE / owner / name / EXT_TAG", file=sys.stderr)
        return 2
    cfg = json.load(open(auth_file, encoding="utf-8"))
    auth = cfg["auths"]["ghcr.io"]["auth"]
    url = f"https://ghcr.io/v2/{owner}/{name}/manifests/{tag}"
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": "Basic " + auth,
            "Accept": (
                "application/vnd.oci.image.index.v1+json, "
                "application/vnd.docker.distribution.manifest.list.v2+json, "
                "application/vnd.docker.distribution.manifest.v2+json"
            ),
        },
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        digest = resp.headers.get("Docker-Content-Digest")
    if not digest:
        print("missing Docker-Content-Digest", file=sys.stderr)
        return 1
    print(digest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
