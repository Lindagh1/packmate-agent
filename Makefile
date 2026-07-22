# Packmate v2 lab Makefile — first-touch OpenShift AI (+ Pipelines / GitOps intro)

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash

.PHONY: help preflight bootstrap verify cleanup test render promote

help:
	@echo "Packmate lab targets:"
	@echo "  make preflight   Cluster and image checks"
	@echo "  make bootstrap   Deploy Packmate workloads (idempotent)"
	@echo "  make verify      Non-destructive readiness checks"
	@echo "  make cleanup     Interactive packmate-lab cleanup"
	@echo "  make test        Backend + frontend + MCP unit tests + quality gate"
	@echo "  make render      Render Kustomize overlays"
	@echo "  make promote     Promote a backend digest into the GitOps overlay (local)"

preflight:
	@bash "$(ROOT)/scripts/preflight-sandbox.sh"

bootstrap:
	@bash "$(ROOT)/scripts/bootstrap-sandbox.sh"

verify:
	@bash "$(ROOT)/scripts/verify-sandbox.sh"

cleanup:
	@bash "$(ROOT)/scripts/cleanup-packmate-lab.sh"

test:
	@set -euo pipefail; \
	  cd "$(ROOT)/backend" && (test -x .venv/bin/pytest || python3 -m venv .venv && .venv/bin/pip -q install -r requirements-dev.txt); \
	  .venv/bin/pytest -q; \
	  cd "$(ROOT)/frontend" && npm ci --silent && npm run lint && npm run test -- --run && npm run build; \
	  cd "$(ROOT)/mcp-servers/weather" && (test -x .venv/bin/pytest || python3 -m venv .venv && .venv/bin/pip -q install -r requirements-dev.txt); \
	  .venv/bin/pytest -q; \
	  cd "$(ROOT)/mcp-servers/baggage-policy" && (test -x .venv/bin/pytest || python3 -m venv .venv && .venv/bin/pip -q install -r requirements-dev.txt); \
	  .venv/bin/pytest -q; \
	  bash "$(ROOT)/evaluations/scripts/run_deterministic_gate.sh"; \
	  bash "$(ROOT)/scripts/security-check.sh"

render:
	@bash "$(ROOT)/scripts/render-manifests.sh"

promote:
	@bash "$(ROOT)/scripts/promote-backend-image.sh"
