#!/usr/bin/with-contenv bash
# Flixbox VPN: keep qBittorrent BitTorrent traffic on Gluetun's tunnel interface.
#
# Installed to ${CONFIG_DIR}/qbittorrent-custom-services/ (VPN mode only) and
# mounted at /custom-services.d. Runs after qbittorrent-nox is up.
#
# Why: shared Gluetun netns has lo + bridge + tun0. Without binding, libtorrent
# announces from bridge addresses; Gluetun's firewall drops them (EPERM) →
# torrents stall at metaDL while the WebUI stays healthy (ADR 0002).
#
# Why a long-running service (not cont-init): qBit rewrites qBittorrent.conf from
# memory at startup and can discard a pre-start InterfaceName. The WebUI API is
# the reliable path; this loop re-asserts periodically.
#
# Auth: cont-init enables AuthSubnetWhitelist for flixbox_net and LocalHostAuth=false.
# Fresh volumes before that may return 403 — configure / first WebUI login fixes it.

set -uo pipefail

IFACE="${VPN_INTERFACE:-tun0}"
API="http://127.0.0.1:${WEBUI_PORT:-8080}/api/v2"
INTERVAL="${FLIXBOX_VPN_IFACE_CHECK_INTERVAL:-300}"

log() { echo "[flixbox-bind-vpn] $*"; }

prefs_code() {
  curl -s -o /tmp/.flixbox-qbprefs -w '%{http_code}' --max-time 10 \
    "${API}/app/preferences" 2>/dev/null || echo 000
}

code=000
for _ in $(seq 1 90); do
  code="$(prefs_code)"
  [[ "$code" == "200" || "$code" == "403" ]] && break
  sleep 2
done

if [[ "$code" == "403" ]]; then
  log "preferences API 403 (localhost auth not ready yet)."
  log "Run ./bin/flixbox configure after qBit is reachable, or log in once via WebUI."
  exec sleep infinity
fi

if [[ "$code" != "200" ]]; then
  log "preferences API never reachable (last HTTP ${code})"
  exec sleep infinity
fi

log "watching interface bind → ${IFACE} (every ${INTERVAL}s)"

while true; do
  code="$(prefs_code)"
  if [[ "$code" != "200" ]]; then
    log "preferences fetch failed (HTTP ${code}); retry in ${INTERVAL}s"
  else
    current="$(grep -o '"current_network_interface":"[^"]*"' /tmp/.flixbox-qbprefs 2>/dev/null | cut -d'"' -f4 || true)"
    if [[ "$current" != "$IFACE" ]]; then
      if curl -sf -o /dev/null --max-time 10 -X POST "${API}/app/setPreferences" \
        --data-urlencode "json={\"current_network_interface\":\"${IFACE}\",\"current_interface_address\":\"\"}"; then
        log "binding corrected: ${current:-<unset>} → ${IFACE}"
        curl -sf -o /dev/null --max-time 10 -X POST "${API}/torrents/reannounce" \
          --data "hashes=all" || true
      else
        log "FAILED to set interface binding to ${IFACE}"
      fi
    fi
  fi
  sleep "$INTERVAL"
done
