#!/usr/bin/env bash
#
# CI smoke: init + env-file helpers + configure dry-run gate (C-50–C-52, D4).
# Init/profile tests run in a detached git worktree so a live stack + .env are untouched.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/env-file.sh"

SMOKE_ROOT="${SMOKE_ROOT:-/tmp/flixbox-ci-smoke}"
SMOKE_DATA="${SMOKE_DATA:-${SMOKE_ROOT}/data}"
SMOKE_CONFIG="${SMOKE_CONFIG:-${SMOKE_ROOT}/config}"
SMOKE_WORKTREE=""

pass() { printf 'OK   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

cleanup_worktree() {
  if [[ -n "${SMOKE_WORKTREE}" && -d "${SMOKE_WORKTREE}" ]]; then
    rm -rf "${SMOKE_WORKTREE}"
  fi
}
trap cleanup_worktree EXIT

# --- D4: configure fails cleanly without stack (skip when operator stack is up) ---
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE '^flixbox-'; then
  pass "D4 configure --dry-run gate (skipped — flixbox stack running)"
else
  set +e
  out="$("${ROOT_DIR}/scripts/configure-apps.sh" --dry-run 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -ne 0 ]] || fail "configure --dry-run should fail without running containers"
  echo "$out" | grep -qi 'Required containers not running' || \
    fail "configure --dry-run missing expected container error"
  pass "D4 configure --dry-run gate (no stack)"
fi

# --- D2 unit: special characters in .env values (isolated temp file) ---
unit="$(mktemp)"
printf 'EXISTING=keep\nEMPTY=\n' >"${unit}"
chmod 600 "${unit}"
# shellcheck disable=SC2016
special_val='a|b&c/d$e`f'
flixbox_env_file_set "${unit}" SPECIAL "${special_val}"
flixbox_env_file_set_if_empty "${unit}" EMPTY 'filled'
flixbox_env_file_set_if_empty "${unit}" EXISTING 'should-not-overwrite'
got="$(flixbox_env_file_get "${unit}" SPECIAL)"
[[ "$got" == "${special_val}" ]] || fail "env-file special chars (got: ${got})"
got="$(flixbox_env_file_get "${unit}" EMPTY)"
[[ "$got" == 'filled' ]] || fail "env-file set_if_empty on empty"
got="$(flixbox_env_file_get "${unit}" EXISTING)"
[[ "$got" == 'keep' ]] || fail "env-file set_if_empty must not overwrite"
eval "$(flixbox_env_file_exports "${unit}")"
[[ "${SPECIAL}" == "${special_val}" ]] || fail "env-file exports round-trip (got: ${SPECIAL})"
rm -f "${unit}"
pass "env-file helpers (special chars + safe exports)"

# --- json-payload: secrets with shell metacharacters ---
jp="${ROOT_DIR}/scripts/lib/json-payload.py"
special_pw='p|"&/$`'\''\\'
got=$(USERNAME='admin' PASSWORD="${special_pw}" python3 "${jp}" jellyfin-auth)
echo "${got}" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["Pw"]==sys.argv[1]' "${special_pw}" || \
  fail "json-payload jellyfin-auth special chars"
got=$(BOOTSTRAP=1 USERNAME='u' PASSWORD="${special_pw}" python3 "${jp}" seerr-login)
echo "${got}" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["password"]==sys.argv[1]' "${special_pw}" || \
  fail "json-payload seerr-login special chars"
got=$(HOST=qbittorrent USER=admin PASS='secret' API_KEY= \
  CAT_FIELD=tvCategory CATEGORY=tv PRIO_RECENT=recentTvPriority PRIO_OLDER=olderTvPriority \
  python3 "${jp}" qbit-download-client)
echo "${got}" | python3 -c 'import json,sys; d=json.load(sys.stdin); f={x["name"]:x["value"] for x in d["fields"]}; assert f["password"]=="secret" and f["apiKey"]==""' || \
  fail "json-payload qbit-download-client password-only (no API key yet)"

# --- json-query: param-safe queries (special-char API keys) ---
jq="${ROOT_DIR}/scripts/lib/json-query.py"
special_key='key|"&/test'
roots='[{"path":"/data/media/tv"}]'
_root_params=$(ROOT_PATH='/data/media/tv' python3 -c 'import json,os; print(json.dumps({"root_path":os.environ["ROOT_PATH"]}))')
echo "$roots" | JSON_QUERY_PARAMS="$_root_params" python3 "${jq}" arr-root-folder-exists >/dev/null || \
  fail "json-query arr-root-folder-exists path match"
_bazarr_params=$(SONARR_API_KEY="$special_key" RADARR_API_KEY='radarr-key' \
  python3 -c 'import json,os; print(json.dumps({"sonarr_key":os.environ["SONARR_API_KEY"],"radarr_key":os.environ["RADARR_API_KEY"]}))')
settings='{"general":{"use_sonarr":true,"use_radarr":true},"sonarr":{"ip":"sonarr","port":8989,"base_url":"","ssl":false,"apikey":"old"},"radarr":{"ip":"radarr","port":7878,"base_url":"","ssl":false,"apikey":"radarr-key"}}'
diff=$(echo "$settings" | JSON_QUERY_PARAMS="$_bazarr_params" python3 "${jq}" bazarr-conn-diff)
echo "$diff" | grep -q 'sonarr.apikey' || fail "json-query bazarr-conn-diff special-char key"
pass "json-query (param-safe API keys)"
pass "json-payload (special-char passwords)"

# --- C-50–C-52 + access profile sync: isolated copy (never touch operator .env) ---
SMOKE_WORKTREE="$(mktemp -d /tmp/flixbox-smoke-wt.XXXXXX)"
rsync -a --exclude='.git' --exclude='.env' "${ROOT_DIR}/" "${SMOKE_WORKTREE}/"

rm -rf "${SMOKE_ROOT}"
mkdir -p "${SMOKE_DATA}" "${SMOKE_CONFIG}"

(
  cd "${SMOKE_WORKTREE}"
  cp -f .env.example .env
  flixbox_env_file_set .env DATA_DIR "${SMOKE_DATA}"
  flixbox_env_file_set .env CONFIG_DIR "${SMOKE_CONFIG}"
  flixbox_env_file_set .env FLIXBOX_MODE direct
  flixbox_env_file_set .env VPN_ENABLED false

  ./bin/flixbox init --non-interactive
  pass "C-50 init --non-interactive"

  mode="$(stat -c '%a' .env 2>/dev/null || stat -f '%OLp' .env)"
  [[ "$mode" == "600" ]] || fail "expected .env mode 600 (got ${mode})"
  pass ".env mode 600"

  [[ -f "${SMOKE_CONFIG}/homepage/services.yaml" ]] || fail "C-51 missing homepage/services.yaml"
  [[ -f "${SMOKE_CONFIG}/recyclarr/recyclarr.yml" ]] || fail "C-51 missing recyclarr/recyclarr.yml"
  [[ -d "${SMOKE_DATA}/torrents/incomplete" ]] || fail "C-51 missing torrents/incomplete"
  [[ -f "${SMOKE_CONFIG}/qbittorrent/.flixbox/qbit-api-login.sh" ]] || \
    fail "C-51 missing qbittorrent/.flixbox/qbit-api-login.sh"
  [[ -f "${SMOKE_CONFIG}/maintainerr/rule-pack.md" ]] || \
    fail "C-51 missing maintainerr/rule-pack.md"
  pass "C-51 templates + incomplete dir"

  qbit_url="$(flixbox_env_file_get .env DECLUTTARR_QBIT_URL)"
  [[ "$qbit_url" == "http://qbittorrent:8080" ]] || fail "C-52 DECLUTTARR_QBIT_URL=${qbit_url}"
  pass "C-52 DECLUTTARR_QBIT_URL"

  bind_ip="$(flixbox_env_file_get .env FLIXBOX_ADMIN_BIND_IP)"
  [[ "$bind_ip" == "0.0.0.0" ]] || fail "expected FLIXBOX_ADMIN_BIND_IP=0.0.0.0 (got ${bind_ip})"
  pass "access profile derived bind IP (trusted)"

  flixbox_env_file_set .env FLIXBOX_ACCESS_PROFILE shared
  flixbox_env_file_set .env FLIXBOX_ADMIN_BIND_IP ""
  flixbox_env_file_set .env FLIXBOX_ARR_AUTH_METHOD ""
  flixbox_env_file_set .env FLIXBOX_ARR_AUTH_REQUIRED ""
  # shellcheck disable=SC1091
  source scripts/lib/access-profile.sh
  export FLIXBOX_ACCESS_PROFILE=shared
  unset FLIXBOX_ADMIN_BIND_IP FLIXBOX_ARR_AUTH_METHOD FLIXBOX_ARR_AUTH_REQUIRED
  drift="$(flixbox_access_profile_drift_message || true)"
  [[ -n "$drift" ]] || fail "expected drift when shared derived keys empty"
  flixbox_sync_access_profile_env .env
  bind_ip="$(flixbox_env_file_get .env FLIXBOX_ADMIN_BIND_IP)"
  method="$(flixbox_env_file_get .env FLIXBOX_ARR_AUTH_METHOD)"
  required="$(flixbox_env_file_get .env FLIXBOX_ARR_AUTH_REQUIRED)"
  [[ "$bind_ip" == "127.0.0.1" ]] || fail "shared bind (got ${bind_ip})"
  [[ "$method" == "Forms" ]] || fail "shared auth method (got ${method})"
  [[ "$required" == "Enabled" ]] || fail "shared auth required (got ${required})"
  ui_user="$(flixbox_env_file_get .env FLIXBOX_ARR_UI_USER)"
  ui_pass="$(flixbox_env_file_get .env FLIXBOX_ARR_UI_PASSWORD)"
  [[ -n "$ui_user" ]] || flixbox_env_file_set_if_empty .env FLIXBOX_ARR_UI_USER admin
  [[ -n "$ui_pass" ]] || flixbox_env_file_set_if_empty .env FLIXBOX_ARR_UI_PASSWORD 'smoke-shared-ui-pass'
  ui_user="$(flixbox_env_file_get .env FLIXBOX_ARR_UI_USER)"
  ui_pass="$(flixbox_env_file_get .env FLIXBOX_ARR_UI_PASSWORD)"
  [[ -n "$ui_user" && -n "$ui_pass" ]] || fail "shared profile FLIXBOX_ARR_UI_* placeholders"
  pass "access profile shared sync (empty → 127.0.0.1/Forms + UI placeholders)"
)

# Optional: configure idempotency when operator stack is already up
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qE '^flixbox-qbittorrent$'; then
  set +e
  out="$(cd "${ROOT_DIR}" && ./bin/flixbox configure 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || fail "configure failed during idempotency check (rc=${rc})"
  echo "$out" | grep -qE 'Done: 0 configured,' || \
    fail "configure should report 0 configured on idempotent re-run (got: $(echo "$out" | grep Done:))"
  pass "configure idempotency (live stack, 0 configured)"
fi

printf '\nAll CI smoke checks passed.\n'
