#!/usr/bin/env bash
# Level 1 deterministic evaluation gate for Packmate.
# Wraps backend/evals/runner.py — does not modify or replace backend/evals tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND="${ROOT}/backend"
THRESHOLD="${THRESHOLD:-0.90}"
REPORT_JSON="${REPORT_JSON:-${ROOT}/evaluations/reports/deterministic-latest.json}"

PYTHON="${BACKEND}/.venv/bin/python"
if [[ ! -x "${PYTHON}" ]]; then
  PYTHON="$(command -v python3)"
fi

mkdir -p "$(dirname "${REPORT_JSON}")"

echo "Packmate Level 1 deterministic gate (threshold=${THRESHOLD})"
cd "${BACKEND}"
exec "${PYTHON}" -m evals.runner \
  --mode deterministic \
  --threshold "${THRESHOLD}" \
  --report-json "${REPORT_JSON}"
