#!/usr/bin/env bash
#
# Shared helpers for scripts/configure-apps.sh (sourced, not executed).
# Requires python3 for JSON parsing.

FLIXBOX_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${FLIXBOX_LIB}/env-file.sh"
# shellcheck disable=SC1091
source "${FLIXBOX_LIB}/configure-runtime.sh"
# shellcheck disable=SC1091
source "${FLIXBOX_LIB}/configure-state.sh"
# shellcheck disable=SC1091
source "${FLIXBOX_LIB}/configure-context.sh"
FLIXBOX_JSON_PAYLOAD="${FLIXBOX_LIB}/json-payload.py"
FLIXBOX_JSON_QUERY="${FLIXBOX_LIB}/json-query.py"

flixbox_json() {
  python3 "${FLIXBOX_JSON_PAYLOAD}" "$@"
}

# shellcheck disable=SC2034 # read by configure-apps.sh when sourced
CONFIGURED=0
# shellcheck disable=SC2034
SKIPPED=0
# shellcheck disable=SC2034
FAILED=0
# Exported so ShellCheck treats later assignments as used by the caller script.
export ENV_DIRTY=false

# Build JSON_QUERY_PARAMS from param_key=ENV_VAR pairs (comma-separated spec).
# Values are read from the process environment — prefix assignments inside $(...):
#   "$(ROOT_PATH="$root_path" json_params root_path=ROOT_PATH)"
json_params() {
  python3 -c '
import json, os, sys
out = {}
for spec in sys.argv[1].split(","):
    spec = spec.strip()
    if not spec:
        continue
    key, env_name = spec.split("=", 1)
    out[key.strip()] = os.environ.get(env_name.strip(), "")
print(json.dumps(out))
' "$1"
}

# Named query (scripts/lib/json-query.py) — parameters via JSON, never shell-interpolated Python.
json_query() {
  local query="$1" json="$2" params="${3-}"
  [[ -n "$params" ]] || params='{}'
  echo "$json" | JSON_QUERY_PARAMS="$params" python3 "${FLIXBOX_JSON_QUERY}" "$query"
}

# shellcheck disable=SC1091
source "${FLIXBOX_LIB}/cli-msg.sh"

# Configure report lines on stdout (primary result); tips/warnings on stderr via cli_*.
# Vocab: updated | unchanged | failed | dry-run (ADR 0021). No Unicode status glyphs.
# When FLIXBOX_CONFIGURE_JSON=1, suppress human lines — emit one JSON object at end.
_configure_line() {
  if [[ "${FLIXBOX_CONFIGURE_JSON:-0}" == "1" ]]; then
    return 0
  fi
  cli_configure_line "$1" "$2"
}

log()  { cli_info "$*"; }
ok()   { _configure_line updated "$*"; CONFIGURED=$((CONFIGURED + 1)); }
skip() { _configure_line unchanged "$*"; SKIPPED=$((SKIPPED + 1)); }
fail() {
  _configure_line failed "$*"
  FAILED=$((FAILED + 1))
  # Return 0 so set -e does not abort wiring; FAILED drives exit 1 at end (ADR 0016 PARTIAL).
  return 0
}
warn() { cli_warn "$*"; }
info() {
  if [[ "${FLIXBOX_CONFIGURE_JSON:-0}" == "1" ]]; then
    return 0
  fi
  cli_info "$*"
}
dry()  { _configure_line dry-run "$*"; }

flixbox_configure_emit_json() {
  UPDATED="$CONFIGURED" UNCHANGED="$SKIPPED" FAILED_N="$FAILED" \
    DRY_RUN="${DRY_RUN:-false}" python3 - <<'PY'
import json, os
updated = int(os.environ.get("UPDATED") or 0)
unchanged = int(os.environ.get("UNCHANGED") or 0)
failed = int(os.environ.get("FAILED_N") or 0)
dry = (os.environ.get("DRY_RUN") or "false").lower() == "true"
obj = {
    "schemaVersion": 1,
    "ok": failed == 0,
    "dryRun": dry,
    "summary": {
        "updated": updated,
        "unchanged": unchanged,
        "failed": failed,
    },
}
print(json.dumps(obj, indent=2))
PY
}

# Taxonomy helpers when configure runs standalone (also provided by bin/flixbox).
if ! declare -F die >/dev/null 2>&1; then
  die() { cli_die 1 "$*"; }
fi
if ! declare -F die_usage >/dev/null 2>&1; then
  die_usage() { cli_die 2 "$*"; }
fi
if ! declare -F die_config >/dev/null 2>&1; then
  die_config() { cli_die 4 "$*"; }
fi
if ! declare -F die_partial >/dev/null 2>&1; then
  die_partial() { cli_die 6 "$*"; }
fi

_api_request() {
  local method="$1" url="$2"
  shift 2
  local args=(-s -w '\n%{http_code}' -o -)
  if [[ "$method" != "GET" ]]; then
    local content_type="$1" data="$2"
    shift 2
    args+=(-X "$method" -H "Content-Type: ${content_type}")
    if [[ -n "$data" ]]; then
      args+=(--data "$data")
    fi
  fi
  local h
  for h in "$@"; do args+=(-H "$h"); done
  local response code body
  response=$(curl "${args[@]}" "$url")
  code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  if [[ "$code" =~ ^2 ]]; then
    echo "$body"
    return 0
  fi
  [[ "$method" != "GET" ]] && echo "$body"
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    echo "  [verbose] ${method} ${url} → HTTP ${code}" >&2
    echo "  [verbose] Response: $(printf '%s' "$body" | configure_redact)" >&2
  fi
  return 1
}

api_get()  { _api_request GET  "$@"; }
api_post() { _api_request POST "$@"; }
api_put()  { _api_request PUT  "$@"; }

# Cap WAIT_TIMEOUT to remaining CONFIGURE_PREFLIGHT_DEADLINE (ADR 0016).
configure_wait_window() {
  local timeout="${WAIT_TIMEOUT:-180}"
  local global_deadline="${CONFIGURE_PREFLIGHT_DEADLINE:-}"
  if [[ -n "$global_deadline" ]]; then
    local rem=$((global_deadline - SECONDS))
    if (( rem < 1 )); then
      printf '%s' 1
      return 0
    fi
    if (( timeout > rem )); then
      timeout=$rem
    fi
  fi
  printf '%s' "$timeout"
}

wait_for_service() {
  local name="$1" url="$2"
  local timeout
  timeout="$(configure_wait_window)"
  local start=$SECONDS
  local deadline=$((SECONDS + timeout))
  local last_heartbeat=$SECONDS
  local code=""
  while (( SECONDS < deadline )); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --connect-timeout 2 "$url" 2>/dev/null || true)
    if [[ "$code" =~ ^[23] ]] || [[ "$code" == "401" ]]; then
      return 0
    fi
    if (( SECONDS - last_heartbeat >= 10 )); then
      info "Still waiting for ${name} ($((SECONDS - start))s/${timeout}s, last HTTP: ${code:-none})..."
      last_heartbeat=$SECONDS
    fi
    sleep 1
  done
  if [[ "${CONFIGURE_SOFT_WAIT:-0}" == 1 ]]; then
    info "${name} not responding yet (${timeout}s window, last HTTP: ${code:-none}) — will retry"
    return 1
  fi
  fail "${name} not responding after ${timeout}s at ${url} (last HTTP: ${code:-none})"
  return 1
}

# Wait until an authenticated *arr/Prowlarr API responds (DB + config ready).
wait_for_arr_api() {
  local name="$1" port="$2" api_key="$3" api_version="${4:-v3}"
  local timeout
  timeout="$(configure_wait_window)"
  local start=$SECONDS deadline=$((SECONDS + timeout)) last_heartbeat=$SECONDS code=""
  local base="http://127.0.0.1:${port}"
  local status_path="/api/${api_version}/system/status"
  [[ "$api_version" == "v1" ]] && status_path="/api/v1/system/status"
  while (( SECONDS < deadline )); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --connect-timeout 2 \
      -H "X-Api-Key: ${api_key}" "${base}${status_path}" 2>/dev/null || true)
    if [[ "$code" == "200" ]]; then
      return 0
    fi
    if (( SECONDS - last_heartbeat >= 10 )); then
      info "Still waiting for ${name} API ($((SECONDS - start))s/${timeout}s, last HTTP: ${code:-none})..."
      last_heartbeat=$SECONDS
    fi
    sleep 2
  done
  if [[ "${CONFIGURE_SOFT_WAIT:-0}" == 1 ]]; then
    info "${name} API not ready yet (${timeout}s window, last HTTP: ${code:-none}) — will retry"
    return 1
  fi
  fail "${name} API not ready after ${timeout}s (last HTTP: ${code:-none})"
  return 1
}

wait_for_bazarr_api() {
  local port="$1" api_key="$2"
  local timeout
  timeout="$(configure_wait_window)"
  local start=$SECONDS deadline=$((SECONDS + timeout)) last_heartbeat=$SECONDS code=""
  local base="http://127.0.0.1:${port}"
  while (( SECONDS < deadline )); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --connect-timeout 2 \
      -H "X-API-KEY: ${api_key}" "${base}/api/system/status" 2>/dev/null || true)
    if [[ "$code" == "200" ]]; then
      return 0
    fi
    if (( SECONDS - last_heartbeat >= 10 )); then
      info "Still waiting for Bazarr API ($((SECONDS - start))s/${timeout}s, last HTTP: ${code:-none})..."
      last_heartbeat=$SECONDS
    fi
    sleep 2
  done
  if [[ "${CONFIGURE_SOFT_WAIT:-0}" == 1 ]]; then
    info "Bazarr API not ready yet (${timeout}s window, last HTTP: ${code:-none}) — will retry"
    return 1
  fi
  fail "Bazarr API not ready after ${timeout}s (last HTTP: ${code:-none})"
  return 1
}

# Write KEY=value into ROOT .env (always overwrite). Sets ENV_DIRTY=true on write.
env_set_key() {
  local key="$1" value="$2" env_file="${ROOT_DIR}/.env"
  [[ -f "$env_file" ]] || return 0
  [[ -n "$value" ]] || return 0
  if $DRY_RUN; then
    dry "Set ${key} in .env"
    return 0
  fi
  if ! flixbox_env_file_set "$env_file" "$key" "$value"; then
    configure_env_write_fatal "$key"
  fi
  ENV_DIRTY=true
}

# Prefer live config.xml key; sync .env when wiped config was recreated on first up.
resolve_arr_api_key() {
  local env_name="$1" container="$2" env_value="$3"
  local config_key app_label="${container#flixbox-}"
  config_key=$(api_key_from_config_xml "$container")
  if [[ -z "$config_key" ]]; then
    echo "$env_value"
    return 0
  fi
  if [[ -n "$env_value" && "$env_value" != "$config_key" ]]; then
    info "${app_label}: ${env_name} in .env out of sync with container — updating .env"
    env_set_key "$env_name" "$config_key" || return 1
  elif [[ -z "$env_value" ]]; then
    env_set_key "$env_name" "$config_key" || return 1
  fi
  echo "$config_key"
}

prowlarr_ensure_tag_id() {
  local base="$1" auth_header="$2" label="$3"
  local tags tag_id result
  tags=$(api_get "${base}/api/v1/tag" "$auth_header") || return 1
  tag_id=$(json_query prowlarr-tag-id-by-label "$tags" "$(LABEL="$label" json_params label=LABEL)")
  if [[ -n "$tag_id" ]]; then
    echo "$tag_id"
    return 0
  fi
  result=$(api_post "${base}/api/v1/tag" "application/json" \
    "$(LABEL="$label" flixbox_json prowlarr-tag)" "$auth_header") || return 1
  tag_id=$(json_query print-field "$result" '{"field":"id"}')
  if [[ -n "$tag_id" ]]; then
    echo "$tag_id"
    return 0
  fi
  return 1
}

jellyfin_startup_wizard_pending() {
  local base="$1" pub
  pub=$(curl -s --max-time 5 "${base}/System/Info/Public" 2>/dev/null || true)
  echo "$pub" | grep -qiE '"StartupWizardCompleted"[[:space:]]*:[[:space:]]*false'
}

seerr_login_json() {
  local bootstrap="$1" admin_user="$2" admin_pass="$3"
  BOOTSTRAP="$([[ "$bootstrap" == "true" ]] && echo 1 || echo 0)" \
  USERNAME="$admin_user" PASSWORD="$admin_pass" \
  flixbox_json seerr-login
}

qbit_auth() {
  local url="$1" username="$2" password="$3" cookie_file="$4"
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local api_url="${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}"
  local cookie_path="${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}"
  local login_script="/config/.flixbox/qbit-api-login.sh"
  local response http_code body verify_code form_file

  # Prefer in-container API (port 8080). Host-published QBITTORRENT_PORT sends a
  # Host header qBit 5.x rejects remapped ports unless web_ui_host_header_validation_enabled=false.
  # Credentials via stdin to qbit-api-login.sh — never on docker exec argv.
  if flixbox_container_running "$container"; then
    docker exec "$container" rm -f "$cookie_path" 2>/dev/null || true
    if ! printf '%s\n%s\n' "$username" "$password" | docker exec -i "$container" \
      "$login_script" "$cookie_path" "$api_url" 2>/dev/null; then
      return 1
    fi
    return 0
  fi

  form_file=$(configure_tmpfile)
  QBIT_USER="$username" QBIT_PASS="$password" flixbox_json qbit-login-form >"$form_file"
  response=$(curl -s -m 20 -w '\n%{http_code}' \
    -c "$cookie_file" \
    -H 'Host: localhost:8080' \
    -d @"$form_file" \
    "${url}/api/v2/auth/login")
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -1)
  case "$http_code" in
    200) [[ "$body" == "Ok." ]] || return 1 ;;
    204) ;;
    *) return 1 ;;
  esac
  chmod 600 "$cookie_file" 2>/dev/null || true
  verify_code=$(curl -s -m 20 -o /dev/null -w '%{http_code}' \
    -b "$cookie_file" -H 'Host: localhost:8080' "${url}/api/v2/app/version")
  [[ "$verify_code" == "200" ]]
}

qbit_curl_authed() {
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local cookie_path="${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}"
  if flixbox_container_running "$container"; then
    docker exec "$container" curl -s -b "$cookie_path" "$@"
    return
  fi
  curl -s -H 'Host: localhost:8080' "$@"
}

qbit_curl_authed_code() {
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local cookie_path="${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}"
  if flixbox_container_running "$container"; then
    docker exec "$container" curl -s -o /dev/null -w '%{http_code}' -b "$cookie_path" "$@"
    return
  fi
  curl -s -o /dev/null -w '%{http_code}' -H 'Host: localhost:8080' "$@"
}

# Set WebUI password via API (JSON-safe for special characters in the password).
qbit_set_webui_password() {
  local password="$1"
  local json api_url="${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}"
  json=$(PASSWORD="$password" flixbox_json qbit-webui-password)
  qbit_curl_authed_code -X POST --data-urlencode "json=${json}" "${api_url}/api/v2/app/setPreferences"
}

wait_for_qbittorrent() {
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local api_url="${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}"
  local timeout
  timeout="$(configure_wait_window)"
  local start=$SECONDS deadline=$((SECONDS + timeout)) last_heartbeat=$SECONDS code=""
  while (( SECONDS < deadline )); do
    code=$(docker exec "$container" curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
      "${api_url}/" 2>/dev/null || true)
    if [[ "$code" == "200" ]]; then
      return 0
    fi
    if (( SECONDS - last_heartbeat >= 10 )); then
      info "Still waiting for qBittorrent ($((SECONDS - start))s/${timeout}s, last HTTP: ${code:-none})..."
      last_heartbeat=$SECONDS
    fi
    sleep 1
  done
  if [[ "${CONFIGURE_SOFT_WAIT:-0}" == 1 ]]; then
    info "qBittorrent not responding yet (${timeout}s window, last HTTP: ${code:-none}) — will retry"
    return 1
  fi
  fail "qBittorrent not responding after ${timeout}s (last HTTP: ${code:-none})"
  return 1
}

api_key_from_config_xml() {
  local container="$1"
  docker exec "$container" cat /config/config.xml 2>/dev/null \
    | sed -n 's:.*<ApiKey>\([^<]*\)</ApiKey>.*:\1:p' | head -1
}

qbit_api_key_from_config() {
  local container="$1"
  local cookie_path="${2:-${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}}"
  local key prefs api_url="${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}"
  key=$(docker exec "$container" grep -m1 '^WebUI\\API\\APIKey=' /config/qBittorrent/qBittorrent.conf 2>/dev/null \
    | cut -d= -f2- | tr -d '\r' || true)
  if [[ -n "$key" ]]; then
    printf '%s' "$key"
    return 0
  fi
  # qBit 5.x may keep the key in WebUI preferences only (not qBittorrent.conf).
  if docker exec "$container" test -f "$cookie_path" 2>/dev/null; then
    prefs=$(docker exec "$container" curl -s -b "$cookie_path" "${api_url}/api/v2/app/preferences" 2>/dev/null || true)
    if [[ -n "$prefs" ]]; then
      key=$(json_query qbit-web-ui-api-key "$prefs" 2>/dev/null || true)
      if [[ -n "$key" ]]; then
        printf '%s' "$key"
      fi
    fi
  fi
}

bazarr_settings_post() {
  local base="$1" auth="$2"
  shift 2
  local args=(-s -w '\n%{http_code}' -o - -X POST -H "$auth")
  local kv
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  local response code body
  response=$(curl "${args[@]}" "${base}/api/system/settings")
  code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  if [[ "$code" =~ ^2 ]]; then
    return 0
  fi
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    echo "  [verbose] POST ${base}/api/system/settings → HTTP ${code}" >&2
    echo "  [verbose] Response: ${body}" >&2
  fi
  return 1
}

# Write KEY=value into ROOT .env when missing or empty. Sets ENV_DIRTY=true on write.
env_set_if_empty() {
  local key="$1" value="$2" env_file="${ROOT_DIR}/.env"
  local before after
  [[ -f "$env_file" ]] || return 0
  [[ -n "$value" ]] || return 0
  before="$(flixbox_env_file_get "$env_file" "$key")"
  [[ -n "$before" ]] && return 0
  if $DRY_RUN; then
    dry "Write ${key} to .env (was empty)"
    return 0
  fi
  if ! flixbox_env_file_set_if_empty "$env_file" "$key" "$value"; then
    configure_env_write_fatal "$key"
  fi
  after="$(flixbox_env_file_get "$env_file" "$key")"
  if [[ -n "$after" ]]; then
    ENV_DIRTY=true
    info "Wrote ${key} to .env (was empty)"
  fi
}

# Replace REPLACE_* placeholders in recyclarr.yml only (never overwrite real keys).
# Uses Python so API keys with / & \ never break sed.
recyclarr_replace_placeholder() {
  local file="$1" placeholder="$2" value="$3"
  RECYCLARR_FILE="$file" RECYCLARR_PLACEHOLDER="$placeholder" RECYCLARR_VALUE="$value" python3 <<'PY'
import os
from pathlib import Path

path = Path(os.environ["RECYCLARR_FILE"])
placeholder = os.environ["RECYCLARR_PLACEHOLDER"]
value = os.environ["RECYCLARR_VALUE"]
text = path.read_text()
if placeholder not in text:
    raise SystemExit(0)
path.write_text(text.replace(placeholder, value))
PY
}

patch_recyclarr_keys() {
  local file="${CONFIG_DIR}/recyclarr/recyclarr.yml"
  [[ -f "$file" ]] || return 0

  local needs_write=false
  if [[ -n "${RADARR_API_KEY:-}" ]] && grep -q 'REPLACE_RADARR_API_KEY' "$file" 2>/dev/null; then
    needs_write=true
  fi
  if [[ -n "${SONARR_API_KEY:-}" ]] && grep -q 'REPLACE_SONARR_API_KEY' "$file" 2>/dev/null; then
    needs_write=true
  fi
  if $needs_write && ! $DRY_RUN; then
    # Reclaim only recyclarr/ — not DATA_DIR or the rest of CONFIG_DIR while the stack is up.
    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/seerr-perms.sh"
    flixbox_reclaim_path_for_host_write "${CONFIG_DIR}/recyclarr" || true
  fi

  local changed=false
  if [[ -n "${RADARR_API_KEY:-}" ]] && grep -q 'REPLACE_RADARR_API_KEY' "$file" 2>/dev/null; then
    if $DRY_RUN; then
      dry "Patch Recyclarr Radarr API key placeholder"
    else
      recyclarr_replace_placeholder "$file" 'REPLACE_RADARR_API_KEY' "$RADARR_API_KEY"
      changed=true
    fi
  fi
  if [[ -n "${SONARR_API_KEY:-}" ]] && grep -q 'REPLACE_SONARR_API_KEY' "$file" 2>/dev/null; then
    if $DRY_RUN; then
      dry "Patch Recyclarr Sonarr API key placeholder"
    else
      recyclarr_replace_placeholder "$file" 'REPLACE_SONARR_API_KEY' "$SONARR_API_KEY"
      changed=true
    fi
  fi
  if $changed; then
    ok "Recyclarr: patched API key placeholders"
  elif grep -qE 'REPLACE_(RADARR|SONARR)_API_KEY' "$file" 2>/dev/null; then
    info "Recyclarr: placeholders remain (keys not available yet)"
  else
    skip "Recyclarr: API keys"
  fi
  if $needs_write && ! $DRY_RUN && [[ -n "${PUID:-}" && -n "${PGID:-}" ]]; then
    # shellcheck disable=SC1091
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/seerr-perms.sh"
    flixbox_chown_tree "${CONFIG_DIR}/recyclarr" "$PUID" "$PGID" || true
  fi
}

# Servarr/Prowlarr often redact apiKey fields in GET responses (********).
is_redacted_api_key() {
  local key="$1"
  [[ -z "$key" ]] && return 0
  [[ "$key" =~ ^[[:space:]*]+$ ]]
}

# True when *arr responds to system/status with the given API key.
arr_system_status_ok() {
  local port="$1" api_key="$2" api_version="${3:-v3}"
  [[ -n "$api_key" ]] || return 1
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
    -H "X-Api-Key: ${api_key}" "http://127.0.0.1:${port}/api/${api_version}/system/status" 2>/dev/null || echo 000)
  [[ "$code" == "200" ]]
}

# Skip Prowlarr app PUT when keys match or stored value is redacted but *arr is reachable.
prowlarr_app_api_key_in_sync() {
  local stored_key="$1" arr_key="$2" arr_port="$3" arr_api_version="${4:-v3}"
  [[ -n "$arr_key" ]] || return 1
  if [[ "$stored_key" == "$arr_key" ]]; then
    return 0
  fi
  if is_redacted_api_key "$stored_key" && arr_system_status_ok "$arr_port" "$arr_key" "$arr_api_version"; then
    return 0
  fi
  return 1
}

# True when Gluetun port-forward hooks need unauthenticated localhost WebUI API.
qbit_webui_bypass_local_auth_expected() {
  [[ "${VPN_PORT_FORWARDING:-off}" == "on" ]]
}

# JSON blob for qBit WebUI security prefs (single source: templates/qbittorrent/webui-security-prefs*.json).
qbit_webui_security_prefs_json() {
  local root="${ROOT_DIR:-}"
  local prefs_file
  if [[ -z "$root" || ! -f "${root}/templates/qbittorrent/webui-security-prefs.json" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
      root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
  fi
  if [[ -z "$root" || ! -f "${root}/templates/qbittorrent/webui-security-prefs.json" ]]; then
    if [[ -f "${PWD}/templates/qbittorrent/webui-security-prefs.json" ]]; then
      root="$PWD"
    fi
  fi
  if qbit_webui_bypass_local_auth_expected; then
    prefs_file="${root}/templates/qbittorrent/webui-security-prefs-portforward.json"
  else
    prefs_file="${root}/templates/qbittorrent/webui-security-prefs.json"
  fi
  [[ -f "$prefs_file" ]] || return 1
  python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1], encoding="utf-8"))))' "$prefs_file"
}

# qBit 5.x WebUI security prefs applied by configure (ADR 0008 whitelist).
qbit_webui_security_prefs_ok() {
  local prefs_json="$1"
  [[ -n "$prefs_json" ]] || return 1
  local expect_bypass="false"
  qbit_webui_bypass_local_auth_expected && expect_bypass="true"
  json_query qbit-webui-security-ok "$prefs_json" \
    "$(EXPECT_BYPASS_LOCAL="$expect_bypass" json_params expect_bypass_local=EXPECT_BYPASS_LOCAL)" >/dev/null 2>&1
}
