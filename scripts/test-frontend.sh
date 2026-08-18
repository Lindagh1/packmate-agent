#!/usr/bin/env bash
# Run the frontend validation locally or in a Node container when npm is absent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="${ROOT}/frontend"

run_npm_suite() {
  npm ci --silent
  npm run lint
  npm run test -- --run
  npm run build
}

if command -v npm >/dev/null 2>&1; then
  cd "${FRONTEND}"
  run_npm_suite
  exit 0
fi

if command -v podman >/dev/null 2>&1; then
  image="${PACKMATE_FRONTEND_TEST_IMAGE:-docker.io/library/node:22-bookworm}"
  printf 'INFO  npm not found; running frontend validation with Podman (%s)\n' "${image}"
  exec podman run --rm --userns=keep-id \
    -v "${FRONTEND}:/workspace:Z" \
    -w /workspace \
    "${image}" \
    bash -lc 'npm ci --silent && npm run lint && npm run test -- --run && npm run build'
fi

printf 'ERROR: frontend validation requires npm or Podman\n' >&2
printf 'ACTION: install Node.js 22/npm, or run make test from the provided Workbench\n' >&2
exit 1
