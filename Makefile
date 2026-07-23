# Packmate v2 lab Makefile — OpenShift AI DEV → CI → PR → Argo CD PROD

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash

.PHONY: help preflight bootstrap verify verify-dev verify-prod verify-gitops \
	prepare-prod configure-argocd-rbac cleanup test render promote validate-prod

help:
	@echo "Packmate lab targets:"
	@echo "  make preflight              Cluster and image checks"
	@echo "  make bootstrap              DEV workloads + AI assets + prepare PROD (idempotent)"
	@echo "  make prepare-prod           Create packmate-prod + Secret + Argo (no workload apply)"
	@echo "  make configure-argocd-rbac  SSO group + AppProject promoter role"
	@echo "  make verify / verify-dev    DEV readiness (compat)"
	@echo "  make verify-prod            PROD readiness after Argo Sync"
	@echo "  make verify-gitops          AppProject/Application/RBAC checks"
	@echo "  make validate-prod          Static PROD overlay checks"
	@echo "  make cleanup                Interactive packmate-lab cleanup"
	@echo "  make test                   Unit tests + quality gate + security-check"
	@echo "  make render                 Render Kustomize DEV + PROD overlays"
	@echo "  make promote                Promote backend digest (see script --help)"

preflight:
	@bash "$(ROOT)/scripts/preflight-sandbox.sh"

bootstrap:
	@bash "$(ROOT)/scripts/bootstrap-sandbox.sh"

prepare-prod:
	@bash "$(ROOT)/scripts/prepare-prod.sh"

configure-argocd-rbac:
	@bash "$(ROOT)/scripts/configure-argocd-lab-rbac.sh"

verify verify-dev:
	@bash "$(ROOT)/scripts/verify-sandbox.sh"

verify-prod:
	@bash "$(ROOT)/scripts/verify-prod.sh"

verify-gitops:
	@bash "$(ROOT)/scripts/verify-gitops.sh"

validate-prod:
	@bash "$(ROOT)/scripts/validate-prod-overlay.sh"

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
