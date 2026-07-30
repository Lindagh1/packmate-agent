# Packmate v2 lab Makefile — OpenShift AI DEV → CI → PR → Argo CD PROD

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash

.PHONY: help preflight bootstrap verify verify-dev verify-prod verify-gitops \
	prepare-prod configure-argocd-rbac cleanup test render promote validate-prod \
	verify-python-deps resolve-pipeline-python-image render-pipeline

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
	@echo "  make verify-python-deps     RHOAI mirror dependency compatibility"
	@echo "  make resolve-pipeline-python-image  Resolve openshift/python:3.12-ubi9 digest"
	@echo "  make render-pipeline        Render packmate-ci from template"
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

verify-python-deps:
	@bash "$(ROOT)/scripts/check-rhoai-python-dependencies.sh"

resolve-pipeline-python-image:
	@bash "$(ROOT)/scripts/resolve-pipeline-python-image.sh"

render-pipeline:
	@bash "$(ROOT)/scripts/render-packmate-pipeline.sh"

cleanup:
	@bash "$(ROOT)/scripts/cleanup-packmate-lab.sh"

test:
	@set -euo pipefail; \
	  INDEX_URL="$${RHOAI_PYPI_INDEX_URL:-https://console.redhat.com/api/pypi/public-rhai/rhoai/3.4/cpu-ubi9/simple}"; \
	  INDEX_HOST="$$(python3 -c 'from urllib.parse import urlparse; print(urlparse('"'"'$${INDEX_URL}'"'"').hostname)')"; \
	  cd "$(ROOT)/backend" && (test -x .venv/bin/pytest || python3.12 -m venv .venv); \
	  .venv/bin/pip -q install -U pip --index-url "$${INDEX_URL}" --trusted-host "$${INDEX_HOST}"; \
	  .venv/bin/pip -q install -r requirements-dev.txt --index-url "$${INDEX_URL}" --trusted-host "$${INDEX_HOST}"; \
	  .venv/bin/pytest -q; \
	  cd "$(ROOT)/frontend" && npm ci --silent && npm run lint && npm run test -- --run && npm run build; \
	  cd "$(ROOT)/mcp-servers/weather" && (test -x .venv/bin/pytest || python3.12 -m venv .venv); \
	  .venv/bin/pip -q install -r requirements-dev.txt --index-url "$${INDEX_URL}" --trusted-host "$${INDEX_HOST}"; \
	  .venv/bin/pytest -q; \
	  cd "$(ROOT)/mcp-servers/baggage-policy" && (test -x .venv/bin/pytest || python3.12 -m venv .venv); \
	  .venv/bin/pip -q install -r requirements-dev.txt --index-url "$${INDEX_URL}" --trusted-host "$${INDEX_HOST}"; \
	  .venv/bin/pytest -q; \
	  bash "$(ROOT)/evaluations/scripts/run_deterministic_gate.sh"; \
	  bash "$(ROOT)/scripts/security-check.sh"; \
	  bash "$(ROOT)/scripts/tests/test-pipeline-portability.sh"

render:
	@bash "$(ROOT)/scripts/render-manifests.sh"

promote:
	@bash "$(ROOT)/scripts/promote-backend-image.sh"
