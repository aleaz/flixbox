#!/usr/bin/env bash
#
# CI smoke: init + env-file helpers + configure dry-run gate (C-50–C-52, D4).
# Safe for local runs: restores .env on exit when one already existed.
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/env-file.sh"

SMOKE_ROOT="${SMOKE_ROOT:-/tmp/flixbox-ci-smoke}"
SMOKE_DATA="${SMOKE_DATA:-${SMOKE_ROOT}/data}"
SMOKE_CONFIG="${SMOKE_CONFIG:-${SMOKE_ROOT}/config}"
ENV_BACKUP=""

pass() { printf 'OK   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

cleanup() {
  if [[ -n "${ENV_BACKUP}" && -f "${ENV_BACKUP}" ]]; then
    cp -f "${ENV_BACKUP}" "${ROOT_DIR}/.env"
    rm -f "${ENV_BACKUP}"
  fi
}
trap cleanup EXIT

if [[ -f "${ROOT_DIR}/.env" ]]; then
  ENV_BACKUP="$(mktemp)"
  cp -f "${ROOT_DIR}/.env" "${ENV_BACKUP}"
fi

rm -rf "${SMOKE_ROOT}"
mkdir -p "${SMOKE_DATA}" "${SMOKE_CONFIG}"

# --- D2 unit: special characters in .env values ---
unit="$(mktemp)"
printf 'EXISTING=keep\nEMPTY=\n' >"${unit}"
chmod 600 "${unit}"
# Literal $ and backticks must not expand when stored/loaded.
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
# exports must not shell-expand $ or backticks
eval "$(flixbox_env_file_exports "${unit}")"
[[ "${SPECIAL}" == "${special_val}" ]] || fail "env-file exports round-trip (got: ${SPECIAL})"
rm -f "${unit}"
pass "env-file helpers (special chars + safe exports)"

# --- C-50: init --non-interactive ---
cp -f "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
flixbox_env_file_set "${ROOT_DIR}/.env" DATA_DIR "${SMOKE_DATA}"
flixbox_env_file_set "${ROOT_DIR}/.env" CONFIG_DIR "${SMOKE_CONFIG}"
flixbox_env_file_set "${ROOT_DIR}/.env" FLIXBOX_MODE direct
flixbox_env_file_set "${ROOT_DIR}/.env" VPN_ENABLED false

"${ROOT_DIR}/bin/flixbox" init --non-interactive
pass "C-50 init --non-interactive"

# .env must be owner-only
mode="$(stat -c '%a' "${ROOT_DIR}/.env" 2>/dev/null || stat -f '%OLp' "${ROOT_DIR}/.env")"
[[ "$mode" == "600" ]] || fail "expected .env mode 600 (got ${mode})"
pass ".env mode 600"

# --- C-51: templates ---
[[ -f "${SMOKE_CONFIG}/homepage/services.yaml" ]] || fail "C-51 missing homepage/services.yaml"
[[ -f "${SMOKE_CONFIG}/recyclarr/recyclarr.yml" ]] || fail "C-51 missing recyclarr/recyclarr.yml"
[[ -d "${SMOKE_DATA}/torrents/incomplete" ]] || fail "C-51 missing torrents/incomplete"
pass "C-51 templates + incomplete dir"

# --- C-52: Decluttarr URL ---
qbit_url="$(flixbox_env_file_get "${ROOT_DIR}/.env" DECLUTTARR_QBIT_URL)"
[[ "$qbit_url" == "http://qbittorrent:8080" ]] || fail "C-52 DECLUTTARR_QBIT_URL=${qbit_url}"
pass "C-52 DECLUTTARR_QBIT_URL"

# Profile-derived keys present after init (trusted default)
bind_ip="$(flixbox_env_file_get "${ROOT_DIR}/.env" FLIXBOX_ADMIN_BIND_IP)"
[[ "$bind_ip" == "0.0.0.0" ]] || fail "expected FLIXBOX_ADMIN_BIND_IP=0.0.0.0 (got ${bind_ip})"
pass "access profile derived bind IP (trusted)"

# shared profile sync
flixbox_env_file_set "${ROOT_DIR}/.env" FLIXBOX_ACCESS_PROFILE shared
# clear derived keys to simulate empty drift
flixbox_env_file_set "${ROOT_DIR}/.env" FLIXBOX_ADMIN_BIND_IP ""
flixbox_env_file_set "${ROOT_DIR}/.env" FLIXBOX_ARR_AUTH_METHOD ""
flixbox_env_file_set "${ROOT_DIR}/.env" FLIXBOX_ARR_AUTH_REQUIRED ""
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/access-profile.sh"
export FLIXBOX_ACCESS_PROFILE=shared
unset FLIXBOX_ADMIN_BIND_IP FLIXBOX_ARR_AUTH_METHOD FLIXBOX_ARR_AUTH_REQUIRED
drift="$(flixbox_access_profile_drift_message || true)"
[[ -n "$drift" ]] || fail "expected drift when shared derived keys empty"
flixbox_sync_access_profile_env "${ROOT_DIR}/.env"
bind_ip="$(flixbox_env_file_get "${ROOT_DIR}/.env" FLIXBOX_ADMIN_BIND_IP)"
method="$(flixbox_env_file_get "${ROOT_DIR}/.env" FLIXBOX_ARR_AUTH_METHOD)"
required="$(flixbox_env_file_get "${ROOT_DIR}/.env" FLIXBOX_ARR_AUTH_REQUIRED)"
[[ "$bind_ip" == "127.0.0.1" ]] || fail "shared bind (got ${bind_ip})"
[[ "$method" == "Forms" ]] || fail "shared auth method (got ${method})"
[[ "$required" == "Enabled" ]] || fail "shared auth required (got ${required})"
pass "access profile shared sync (empty → 127.0.0.1/Forms)"

# restore trusted for leftover .env if backup absent
flixbox_env_file_set "${ROOT_DIR}/.env" FLIXBOX_ACCESS_PROFILE trusted
flixbox_sync_access_profile_env "${ROOT_DIR}/.env"
# --- D4: configure fails cleanly without stack ---
set +e
out="$("${ROOT_DIR}/scripts/configure-apps.sh" --dry-run 2>&1)"
rc=$?
set -e
[[ "$rc" -ne 0 ]] || fail "configure --dry-run should fail without running containers"
echo "$out" | grep -qi 'Required containers not running' || \
  fail "configure --dry-run missing expected container error"
pass "D4 configure --dry-run gate (no stack)"

printf '\nAll CI smoke checks passed.\n'
