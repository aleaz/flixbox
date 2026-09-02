#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# Flixbox: keep qBittorrent WebUI security + identity aligned with .env.
#
# Installed to ${CONFIG_DIR}/qbittorrent-custom-services/ (Direct + VPN) and
# mounted at /custom-services.d. Runs after qbittorrent-nox is up.
#
# Why a long-running service (not cont-init alone): qBit rewrites
# qBittorrent.conf from memory at startup and can discard Preferences keys
# (HostHeaderValidation, AuthSubnetWhitelist). The WebUI API is the reliable
# path — same pattern as 99-flixbox-bind-vpn-interface.sh (ADR 0002 / 0019).
#
# Password bootstrap: prefer QBITTORRENT_PASSWORD. Optional host helper may write
# /config/.flixbox/session-temp-password when the session temp password only
# appears in docker logs. Do NOT hammer login — that bans 127.0.0.1.
#
# Auth: QBITTORRENT_USERNAME/PASSWORD via container env; login via qbit-api-login.sh (stdin).

set -uo pipefail

API="http://127.0.0.1:${WEBUI_PORT:-8080}/api/v2"
API_BASE="http://127.0.0.1:${WEBUI_PORT:-8080}"
INTERVAL="${FLIXBOX_WEBUI_CONTRACT_INTERVAL:-120}"
COOKIE="/tmp/.flixbox-webui-contract-cookie"
PREFS="/tmp/.flixbox-webui-contract-prefs"
QBIT_USER="${QBITTORRENT_USERNAME:-admin}"
QBIT_PASS="${QBITTORRENT_PASSWORD:-}"
QBIT_LOGIN_SCRIPT="/config/.flixbox/qbit-api-login.sh"
TEMP_FILE="/config/.flixbox/session-temp-password"
# flixbox_net — MUST match compose/network-base.yml
SUBNET_WHITELIST="172.30.42.0/24"

ENV_LOGIN_OK=false
ENV_ATTEMPTED=false
BOOTSTRAP_TRIED=false
BANNED_BACKOFF=0

log() { echo "[flixbox-webui-contract] $*"; }

qbit_login_with() {
  local user="$1" pass="$2" rc=0
  [[ -x "$QBIT_LOGIN_SCRIPT" ]] || return 1
  [[ -n "$pass" ]] || return 1
  rm -f "$COOKIE"
  printf '%s\n%s\n' "$user" "$pass" | "$QBIT_LOGIN_SCRIPT" "$COOKIE" "$API_BASE" || rc=$?
  case "$rc" in
    0) return 0 ;;
    2) return 2 ;;
    *) return 1 ;;
  esac
}

prefs_code() {
  curl -s -b "$COOKIE" -o "$PREFS" -w '%{http_code}' --max-time 10 \
    "${API}/app/preferences" 2>/dev/null || echo 000
}

find_temp_password() {
  local line temp
  if [[ -f "$TEMP_FILE" ]]; then
    temp="$(tr -d '\r\n' <"$TEMP_FILE" 2>/dev/null || true)"
    if [[ -n "$temp" ]]; then
      printf '%s\n' "$temp"
      return 0
    fi
  fi
  line="$(
    {
      grep -h -i 'temporary password' /config/qBittorrent/logs/*.log 2>/dev/null || true
      grep -h -i 'temporary password' /config/qBittorrent/*.log 2>/dev/null || true
    } | tail -1
  )"
  [[ -n "$line" ]] || return 1
  printf '%s\n' "${line##* }"
}

security_prefs_ok() {
  local json="$1"
  [[ -n "$json" ]] || return 1
  # Match scripts/lib/json-query.py qbit_webui_security_ok: missing key defaults to
  # validation ON → must see explicit false (do not treat omit as OK).
  printf '%s' "$json" | grep -q '"web_ui_host_header_validation_enabled":false' || return 1
  printf '%s' "$json" | grep -q '"bypass_auth_subnet_whitelist_enabled":true' || return 1
  printf '%s' "$json" | grep -q "\"bypass_auth_subnet_whitelist\":\"${SUBNET_WHITELIST}\"" || return 1
  return 0
}

apply_security_prefs() {
  # MUST match qbit_webui_security_prefs_json() in scripts/lib/configure-helpers.sh (CI C-85).
  local json='{"web_ui_host_header_validation_enabled":false,"bypass_auth_subnet_whitelist_enabled":true,"bypass_auth_subnet_whitelist":"'"${SUBNET_WHITELIST}"'","web_ui_max_auth_fail_count":20,"web_ui_ban_duration":300}'
  if [[ "${VPN_PORT_FORWARDING:-off}" == "on" ]]; then
    json='{"web_ui_host_header_validation_enabled":false,"bypass_local_auth":true,"bypass_auth_subnet_whitelist_enabled":true,"bypass_auth_subnet_whitelist":"'"${SUBNET_WHITELIST}"'","web_ui_max_auth_fail_count":20,"web_ui_ban_duration":300}'
  fi
  curl -sf -b "$COOKIE" -o /dev/null --max-time 10 -X POST "${API}/app/setPreferences" \
    --data-urlencode "json=${json}"
}

json_escape_string() {
  local s="$1"
  local out="" c
  local -i idx ord
  for ((idx = 0; idx < ${#s}; idx++)); do
    c="${s:idx:1}"
    case "$c" in
      \\) out+='\\' ;;
      '"') out+='\"' ;;
      $'\n') out+='\n' ;;
      $'\r') out+='\r' ;;
      $'\t') out+='\t' ;;
      *)
        printf -v ord '%d' "'$c"
        if ((ord < 32)); then
          printf -v c '\\u%04x' "$ord"
          out+="$c"
        else
          out+="${s:idx:1}"
        fi
        ;;
    esac
  done
  printf '%s' "$out"
}

apply_env_password() {
  [[ -n "$QBIT_PASS" ]] || return 1
  local escaped json
  escaped="$(json_escape_string "$QBIT_PASS")"
  json="{\"web_ui_password\":\"${escaped}\"}"
  curl -sf -b "$COOKIE" -o /dev/null --max-time 10 -X POST "${API}/app/setPreferences" \
    --data-urlencode "json=${json}"
}

try_bootstrap_from_temp() {
  [[ "$BOOTSTRAP_TRIED" == true ]] && return 1
  BOOTSTRAP_TRIED=true
  [[ -n "$QBIT_PASS" ]] || return 1
  local temp rc
  temp="$(find_temp_password || true)"
  [[ -n "$temp" && "$temp" != "$QBIT_PASS" ]] || return 1
  qbit_login_with "$QBIT_USER" "$temp"
  rc=$?
  if [[ "$rc" -eq 2 ]]; then
    BANNED_BACKOFF=1
    log "WebUI ban active — waiting (restart qbittorrent clears ban)"
    return 1
  fi
  [[ "$rc" -eq 0 ]] || return 1
  if apply_env_password; then
    log "WebUI password aligned from temporary session → .env"
    rm -f "$COOKIE" "$TEMP_FILE"
    if qbit_login_with "$QBIT_USER" "$QBIT_PASS"; then
      ENV_LOGIN_OK=true
      return 0
    fi
  else
    log "FAILED to set WebUI password from .env after temp login"
  fi
  return 1
}

ensure_session() {
  local code rc
  code="$(prefs_code)"
  if [[ "$code" == "200" ]]; then
    ENV_LOGIN_OK=true
    return 0
  fi

  if [[ "$BANNED_BACKOFF" -eq 1 ]]; then
    return 1
  fi

  if [[ "$ENV_LOGIN_OK" == true && -n "$QBIT_PASS" ]]; then
    qbit_login_with "$QBIT_USER" "$QBIT_PASS"
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      code="$(prefs_code)"
      [[ "$code" == "200" ]] && return 0
    elif [[ "$rc" -eq 2 ]]; then
      BANNED_BACKOFF=1
      return 1
    fi
    return 1
  fi

  # Cold start: at most one env attempt + one temp bootstrap per backoff window.
  if [[ "$ENV_ATTEMPTED" != true && -n "$QBIT_PASS" ]]; then
    ENV_ATTEMPTED=true
    qbit_login_with "$QBIT_USER" "$QBIT_PASS"
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      ENV_LOGIN_OK=true
      code="$(prefs_code)"
      [[ "$code" == "200" ]] && return 0
    elif [[ "$rc" -eq 2 ]]; then
      BANNED_BACKOFF=1
      log "WebUI ban active — waiting (restart qbittorrent clears ban)"
      return 1
    fi
  fi

  try_bootstrap_from_temp && return 0
  return 1
}

ensure_contract() {
  local code
  code="$(prefs_code)"
  [[ "$code" == "200" ]] || return 1
  if security_prefs_ok "$(cat "$PREFS" 2>/dev/null || true)"; then
    return 0
  fi
  if apply_security_prefs; then
    log "WebUI security contract applied (HostHeader + Docker subnet whitelist)"
    return 0
  fi
  log "FAILED to apply WebUI security contract"
  return 1
}

# Wait for WebUI without burning auth attempts (ban risk).
for _ in $(seq 1 45); do
  if ensure_session && ensure_contract; then
    break
  fi
  if [[ "$BANNED_BACKOFF" -eq 1 ]]; then
    sleep 30
  else
    sleep 4
  fi
done

if ! ensure_session; then
  if [[ -z "$QBIT_PASS" ]]; then
    log "QBITTORRENT_PASSWORD not set — waiting for .env + container recreate."
  elif [[ "$BANNED_BACKOFF" -eq 1 ]]; then
    log "WebUI ban — restart qbittorrent, then host bootstrap or configure --sync-qbit-auth"
  else
    log "WebUI login pending — host bootstrap writes session-temp-password, or run configure --sync-qbit-auth"
  fi
else
  ensure_contract || true
fi

log "watching WebUI contract (every ${INTERVAL}s)"

while true; do
  # Clear ban backoff periodically so a restart of qBit (same container PID namespace) can recover.
  if [[ "$BANNED_BACKOFF" -eq 1 ]]; then
    sleep "$INTERVAL"
    BANNED_BACKOFF=0
    BOOTSTRAP_TRIED=false
    ENV_LOGIN_OK=false
    ENV_ATTEMPTED=false
    continue
  fi
  if ensure_session; then
    ensure_contract || true
  else
    if [[ -z "$QBIT_PASS" ]]; then
      log "still waiting for QBITTORRENT_USERNAME/PASSWORD in container env"
    else
      log "session not ready — host bootstrap or configure --sync-qbit-auth"
    fi
  fi
  sleep "$INTERVAL"
done
