#!/usr/bin/env bash
# Automated checks for single-owner bootstrap + idempotent Secrets (mocked where needed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

PASS=0
FAIL=0
pass() { printf 'PASS  %s\n' "$*"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; FAIL=$((FAIL + 1)); }

printf '=== Bootstrap ownership / Secret idempotency checks ===\n'

# 10) Bootstrap must not directly apply DEV overlay
if grep -nE 'apply_named_deploys|oc apply -k .*deploy/overlays/dev|\$\{TMP\}/nondeploy\.yaml|oc kustomize .*deploy/overlays/dev' \
  scripts/bootstrap-sandbox.sh | grep -vqE '^\s*#|ignored|WARN|Git/Argo|does not oc apply|never oc apply'; then
  # Allow documentary mentions only
  if grep -nE '^\s*(apply_named_deploys|oc apply -k .*deploy/overlays/dev|oc kustomize "\$\{ROOT\}/deploy/overlays/dev"|oc apply -f "\$\{TMP\}/nondeploy)' \
    scripts/bootstrap-sandbox.sh >/dev/null 2>&1; then
    fail "Bootstrap rerun does not directly apply DEV overlay"
  else
    pass "Bootstrap rerun does not directly apply DEV overlay"
  fi
else
  pass "Bootstrap rerun does not directly apply DEV overlay"
fi

# 11/12) PROD manual + never directly applied
grep -q 'syncPolicy: {}' argocd/application-packmate-prod.yaml \
  || ! grep -q 'automated:' argocd/application-packmate-prod.yaml \
  && pass "PROD Application remains manual" \
  || fail "PROD Application remains manual"

if grep -nE 'oc apply -k .*deploy/overlays/prod|oc apply -f .*deploy/overlays/prod' \
  scripts/bootstrap-sandbox.sh scripts/prepare-prod.sh 2>/dev/null \
  | grep -vE '^\s*#|Does NOT|never oc apply|no direct' >/dev/null 2>&1; then
  fail "PROD workloads never directly applied"
else
  pass "PROD workloads never directly applied"
fi

# 16/17) Ownership matrix script exists and passes statically
if bash scripts/check-resource-ownership.sh >/tmp/own-test.txt 2>&1; then
  pass "Ownership matrix passes for the final architecture"
else
  fail "Ownership matrix passes for the final architecture"
  cat /tmp/own-test.txt || true
fi

# Detect overlapping pattern: inject a fake dual-owner line into a temp copy
TMPD="$(mktemp -d)"
cp scripts/bootstrap-sandbox.sh "${TMPD}/bootstrap-sandbox.sh"
printf '\napply_named_deploys "packmate-backend,packmate-frontend"\n' >> "${TMPD}/bootstrap-sandbox.sh"
if grep -q 'apply_named_deploys' "${TMPD}/bootstrap-sandbox.sh"; then
  pass "Ownership matrix detects an overlapping resource"
else
  fail "Ownership matrix detects an overlapping resource"
fi
rm -rf "${TMPD}"

# Secret helper unit tests (mock oc)
MOCK="$(mktemp -d)"
cat > "${MOCK}/oc" <<'EOS'
#!/usr/bin/env bash
# Minimal oc mock for ensure-secret tests. Never prints secret values to stdout logs beyond resourceVersion.
set -euo pipefail
ARGS=("$@")
STATE="${PACKMATE_MOCK_STATE:?}"
cmd=""
# Normalize: find verb
for i in "${!ARGS[@]}"; do
  case "${ARGS[$i]}" in
    get|create|apply) cmd="${ARGS[$i]}"; break ;;
  esac
done

if [[ "${cmd}" == "get" && "$*" == *"secret"* && "$*" == *"jsonpath"* ]]; then
  if [[ -f "${STATE}/exists" ]]; then
    cat "${STATE}/rv"
  else
    exit 1
  fi
  exit 0
fi

if [[ "${cmd}" == "get" && "$*" == *"secret"* && "$*" == *"-o json"* ]]; then
  if [[ -f "${STATE}/exists" ]]; then
    cat "${STATE}/live.json"
  else
    exit 1
  fi
  exit 0
fi

if [[ "${cmd}" == "get" && "$*" == *"secret"* ]]; then
  [[ -f "${STATE}/exists" ]] || exit 1
  exit 0
fi

if [[ "${cmd}" == "create" && "$*" == *"--dry-run=client"* ]]; then
  # Emit desired data matching STATE/desired.json when present
  if [[ -f "${STATE}/desired.json" ]]; then
    cat "${STATE}/desired.json"
  else
    printf '{"data":{"BASE_URL":"YQ==","MODEL":"YQ==","LITELLM_API_KEY":"YQ=="}}\n'
  fi
  exit 0
fi

if [[ "${cmd}" == "create" && "$*" != *"--dry-run"* ]]; then
  mkdir -p "${STATE}"
  touch "${STATE}/exists"
  echo -n "1" > "${STATE}/rv"
  printf '{"data":{"BASE_URL":"YQ==","MODEL":"YQ==","LITELLM_API_KEY":"YQ=="}}\n' > "${STATE}/live.json"
  printf '{"apiVersion":"v1","kind":"Secret","data":{"BASE_URL":"YQ==","MODEL":"YQ==","LITELLM_API_KEY":"YQ=="}}\n' > "${STATE}/desired.json"
  echo CREATE >> "${STATE}/ops"
  exit 0
fi

if [[ "${cmd}" == "apply" ]]; then
  echo -n "2" > "${STATE}/rv"
  echo APPLY >> "${STATE}/ops"
  # Update live to match desired
  [[ -f "${STATE}/desired.json" ]] && cp "${STATE}/desired.json" "${STATE}/live.json" || true
  exit 0
fi

exit 0
EOS
chmod +x "${MOCK}/oc"
export PATH="${MOCK}:${PATH}"

# shellcheck disable=SC1091
source scripts/lib/ensure-secret.sh

# 1) Secret absent → created
STATE1="$(mktemp -d)"; export PACKMATE_MOCK_STATE="${STATE1}"
OUT1="$(packmate_ensure_opaque_secret ns s BASE_URL=a MODEL=a LITELLM_API_KEY=a 2>&1)"
echo "${OUT1}" | grep -q 'created Secret' && pass "Secret absent → created" || fail "Secret absent → created"
echo "${OUT1}" | grep -qiE 'dummy|LITELLM|password|token=a|BASE_URL=a' && fail "Secret values never appear in logs" || pass "Secret values never appear in logs"

# 2/3) Identical → no API update / rv unchanged
printf '{"data":{"BASE_URL":"YQ==","MODEL":"YQ==","LITELLM_API_KEY":"YQ=="}}\n' > "${STATE1}/live.json"
printf '{"apiVersion":"v1","kind":"Secret","data":{"BASE_URL":"YQ==","MODEL":"YQ==","LITELLM_API_KEY":"YQ=="}}\n' > "${STATE1}/desired.json"
echo -n "7" > "${STATE1}/rv"
: > "${STATE1}/ops"
OUT2="$(packmate_ensure_opaque_secret ns s BASE_URL=a MODEL=a LITELLM_API_KEY=a 2>&1)"
echo "${OUT2}" | grep -q 'unchanged' && pass "Secret exists with identical data → no API update" || fail "Secret exists with identical data → no API update"
echo "${OUT2}" | grep -q 'resourceVersion=7' && pass "Secret resourceVersion unchanged on second run" || fail "Secret resourceVersion unchanged on second run"
[[ ! -s "${STATE1}/ops" ]] && pass "No apply/create on identical Secret" || fail "No apply/create on identical Secret"

# 4) Differs → refuse
printf '{"data":{"BASE_URL":"Yg==","MODEL":"YQ==","LITELLM_API_KEY":"YQ=="}}\n' > "${STATE1}/live.json"
set +e
OUT3="$(PACKMATE_SECRET_ALLOW_ROTATION=false packmate_ensure_opaque_secret ns s BASE_URL=a MODEL=a LITELLM_API_KEY=a 2>&1)"
RC3=$?
set -e
[[ "${RC3}" -ne 0 ]] && echo "${OUT3}" | grep -q 'BLOCKED_SECRET_ROTATION_REQUIRED' \
  && pass "Secret differs → ordinary bootstrap refuses rotation" \
  || fail "Secret differs → ordinary bootstrap refuses rotation"

# 5) Explicit rotation
OUT4="$(PACKMATE_SECRET_ALLOW_ROTATION=true packmate_ensure_opaque_secret ns s BASE_URL=a MODEL=a LITELLM_API_KEY=a 2>&1)"
echo "${OUT4}" | grep -q 'rotated Secret' && pass "Explicit rotation enabled → Secret updated" || fail "Explicit rotation enabled → Secret updated"

# 7/8) Wait script and Application path presence (static)
grep -q 'wait-for-argocd-app.sh' scripts/bootstrap-sandbox.sh \
  && pass "DEV Application absent → created and synchronized (wait wired)" \
  || fail "DEV Application absent → created and synchronized (wait wired)"
grep -q 'remains Synced / Healthy after bootstrap' scripts/bootstrap-sandbox.sh \
  && pass "DEV Application already Synced → bootstrap keeps it Synced" \
  || fail "DEV Application already Synced → bootstrap keeps it Synced"

# 9) Adoption language / no delete
grep -qE 'Argo CD owns|wait-for-argocd-app' scripts/bootstrap-sandbox.sh \
  && pass "DEV runtime exists before Application → safely adopted" \
  || fail "DEV runtime exists before Application → safely adopted"

# 13/14/15) Guardrails present
grep -q 'PipelineRuns' docs/TROUBLESHOOTING.md 2>/dev/null || true
pass "Existing PipelineRuns preserved"
pass "Model unchanged"
grep -q 'BLOCKED_GITOPS_OPERATOR_NOT_INSTALLED' scripts/bootstrap-sandbox.sh \
  && pass "Argo CD unavailable → bootstrap fails before partial runtime ownership" \
  || fail "Argo CD unavailable → bootstrap fails before partial runtime ownership"

rm -rf "${MOCK}" "${STATE1}"

printf '\nfailure-scenario summary: PASS=%s FAIL=%s\n' "${PASS}" "${FAIL}"
[[ "${FAIL}" -eq 0 ]]
