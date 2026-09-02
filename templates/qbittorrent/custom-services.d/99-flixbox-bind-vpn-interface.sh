#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# Flixbox VPN: keep qBittorrent BitTorrent traffic on Gluetun's tunnel interface.
#
# Installed to ${CONFIG_DIR}/qbittorrent-custom-services/ (VPN mode only via init) and
# mounted at /custom-services.d. Runs after qbittorrent-nox is up.
#
# Direct mode: init removes this script so only 98-flixbox-webui-contract.sh remains.
#
# Why: shared Gluetun netns has lo + bridge + tun0. Without binding, libtorrent
# announces from bridge addresses; Gluetun's firewall drops them (EPERM) →
# torrents stall at metaDL while the WebUI stays healthy (ADR 0002).
#
# Why a long-running service (not cont-init): qBit rewrites qBittorrent.conf from
# memory at startup and can discard a pre-start InterfaceName. The WebUI API is
# the reliable path; this loop re-asserts periodically.
#
# Auth: uses QBITTORRENT_USERNAME/PASSWORD from container env (same as Decluttarr).
# After configure, localhost API calls without login return 403 — cookie required.

set -uo pipefail

IFACE="${VPN_INTERFACE:-tun0}"
API="http://127.0.0.1:${WEBUI_PORT:-8080}/api/v2"
INTERVAL="${FLIXBOX_VPN_IFACE_CHECK_INTERVAL:-300}"
COOKIE="/tmp/.flixbox-qbprefs-cookie"
PREFS="/tmp/.flixbox-qbprefs"
QBIT_USER="${QBITTORRENT_USERNAME:-admin}"
QBIT_PASS="${QBITTORRENT_PASSWORD:-}"
LOGIN_FAILED=false

log() { echo "[flixbox-bind-vpn] $*"; }

QBIT_LOGIN_SCRIPT="/config/.flixbox/qbit-api-login.sh"
API_BASE="http://127.0.0.1:${WEBUI_PORT:-8080}"

qbit_login() {
  local rc=0
  [[ -x "$QBIT_LOGIN_SCRIPT" ]] || return 1
  [[ -n "$QBIT_PASS" ]] || return 1
  [[ "$LOGIN_FAILED" == true ]] && return 1
  rm -f "$COOKIE"
  printf '%s\n%s\n' "$QBIT_USER" "$QBIT_PASS" | "$QBIT_LOGIN_SCRIPT" "$COOKIE" "$API_BASE" || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi
  LOGIN_FAILED=true
  return 1
}

prefs_code() {
  curl -s -b "$COOKIE" -o "$PREFS" -w '%{http_code}' --max-time 10 \
    "${API}/app/preferences" 2>/dev/null || echo 000
}

ensure_session() {
  local code
  code="$(prefs_code)"
  if [[ "$code" == "200" ]]; then
    return 0
  fi
  if [[ "$code" == "403" || "$code" == "401" ]]; then
    if qbit_login; then
      code="$(prefs_code)"
      [[ "$code" == "200" ]] && return 0
    fi
  fi
  if qbit_login; then
    code="$(prefs_code)"
    [[ "$code" == "200" ]]
    return
  fi
  return 1
}

correct_bind_if_needed() {
  local current
  current="$(grep -o '"current_network_interface":"[^"]*"' "$PREFS" 2>/dev/null | cut -d'"' -f4 || true)"
  if [[ "$current" == "$IFACE" ]]; then
    return 0
  fi
  if curl -sf -b "$COOKIE" -o /dev/null --max-time 10 -X POST "${API}/app/setPreferences" \
    --data-urlencode "json={\"current_network_interface\":\"${IFACE}\",\"current_interface_address\":\"\"}"; then
    log "binding corrected: ${current:-<unset>} → ${IFACE}"
    curl -sf -b "$COOKIE" -o /dev/null --max-time 10 -X POST "${API}/torrents/reannounce" \
      --data "hashes=all" || true
    return 0
  fi
  log "FAILED to set interface binding to ${IFACE}"
  return 1
}

# Wait for WebUI + credentials (configure / host bootstrap may run after first boot).
# Do not hammer login — wrong .env password while temp session is active bans 127.0.0.1.
LOGIN_ATTEMPTED=false
for _ in $(seq 1 45); do
  if [[ -z "$QBIT_PASS" ]]; then
    sleep 4
    continue
  fi
  if ensure_session; then
    correct_bind_if_needed || true
    break
  fi
  # After first failed login window, back off hard until password is aligned.
  if [[ "$LOGIN_ATTEMPTED" == true ]]; then
    sleep 15
  else
    LOGIN_ATTEMPTED=true
    sleep 4
  fi
done

if ! ensure_session; then
  if [[ -z "$QBIT_PASS" ]]; then
    log "QBITTORRENT_PASSWORD not set — waiting for .env + container recreate."
  else
    log "WebUI login failed — host bootstrap or ./bin/flixbox configure --sync-qbit-auth"
  fi
fi

log "watching interface bind → ${IFACE} (every ${INTERVAL}s)"

while true; do
  # Allow retry after host bootstrap aligned the password.
  LOGIN_FAILED=false
  if ensure_session; then
    correct_bind_if_needed || true
  else
    if [[ -z "$QBIT_PASS" ]]; then
      log "still waiting for QBITTORRENT_USERNAME/PASSWORD in container env"
    else
      log "session lost — will retry login (check QBITTORRENT_* / run configure)"
    fi
  fi
  sleep "$INTERVAL"
done
