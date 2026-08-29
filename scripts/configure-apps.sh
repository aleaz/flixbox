#!/usr/bin/env bash
#
# Idempotent API wiring for Flixbox *arr apps after first container start.
#
# Usage:
#   ./scripts/configure-apps.sh [--dry-run] [--verbose]
#   ./bin/flixbox configure [--dry-run] [--verbose]
#
# Prerequisites (manual, once):
#   - Stack running: ./bin/flixbox up
#   - qBittorrent WebUI: log in and change the temporary password
#   - Radarr, Sonarr, Prowlarr, Bazarr: complete each app's first-run wizard
#
# Stays manual after this script:
#   - Prowlarr indexers (your credentials)
#   - Jellyfin libraries + API key
#   - Seerr connections
#   - Maintainerr rules
#   - Recyclarr profile sync (optional profile)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/configure-helpers.sh"

DRY_RUN=false
VERBOSE=false
QBIT_COOKIE="/tmp/flixbox_qbit_configure_cookie.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --verbose|-v) VERBOSE=true; shift ;;
    --help|-h)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--dry-run] [--verbose]" >&2
      exit 1
      ;;
  esac
done

load_env() {
  if [[ -f "${ROOT_DIR}/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source <(grep -E '^[A-Z_][A-Z0-9_]*=' "${ROOT_DIR}/.env" | sed 's/\r$//')
    set +a
  fi
  FLIXBOX_MODE="${FLIXBOX_MODE:-direct}"
  QBITTORRENT_PORT="${QBITTORRENT_PORT:-8080}"
  RADARR_PORT="${RADARR_PORT:-7878}"
  SONARR_PORT="${SONARR_PORT:-8989}"
  PROWLARR_PORT="${PROWLARR_PORT:-9696}"
  BAZARR_PORT="${BAZARR_PORT:-6767}"
}

env_set_if_empty() {
  local key="$1" value="$2" env_file="${ROOT_DIR}/.env"
  [[ -f "$env_file" ]] || return 0
  local current
  current=$(grep -E "^${key}=" "$env_file" 2>/dev/null | head -1 | cut -d= -f2- || true)
  [[ -n "$current" ]] && return 0
  if grep -q "^${key}=" "$env_file" 2>/dev/null; then
    if [[ "$(uname -s)" == Darwin ]]; then
      sed -i '' "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
      sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    fi
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$env_file"
  fi
  info "Wrote ${key} to .env (was empty)"
}

container_running() {
  docker ps --format '{{.Names}}' | grep -qx "$1"
}

load_env

echo "=== Flixbox app configuration ==="
echo ""

if ! command -v docker &>/dev/null; then
  echo "ERROR: docker not found." >&2
  exit 1
fi
if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 required for JSON parsing." >&2
  exit 1
fi

if $DRY_RUN; then
  log "DRY RUN — no changes will be made"
fi

REQUIRED=(flixbox-radarr flixbox-sonarr flixbox-prowlarr flixbox-bazarr flixbox-qbittorrent)
MISSING=()
for c in "${REQUIRED[@]}"; do
  container_running "$c" || MISSING+=("$c")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "ERROR: Required containers not running: ${MISSING[*]}" >&2
  echo "Start the stack first: ./bin/flixbox up" >&2
  exit 1
fi

if [[ "${FLIXBOX_MODE}" == "vpn" ]]; then
  if ! container_running flixbox-gluetun; then
    echo "ERROR: FLIXBOX_MODE=vpn but flixbox-gluetun is not running." >&2
    exit 1
  fi
  GLUETUN_HEALTH=$(docker inspect -f '{{.State.Health.Status}}' flixbox-gluetun 2>/dev/null || echo unknown)
  if [[ "$GLUETUN_HEALTH" != "healthy" ]]; then
    echo "ERROR: Gluetun is '${GLUETUN_HEALTH}' (need 'healthy')." >&2
    echo "       Wait for VPN connect, then re-run. Check: ./bin/flixbox logs gluetun" >&2
    exit 1
  fi
  QBIT_ARR_HOST="gluetun"
else
  QBIT_ARR_HOST="qbittorrent"
fi

QBIT_URL="http://127.0.0.1:${QBITTORRENT_PORT}"

log "Discovering API keys..."

SONARR_API_KEY=$(api_key_from_config_xml flixbox-sonarr)
RADARR_API_KEY=$(api_key_from_config_xml flixbox-radarr)
PROWLARR_API_KEY=$(api_key_from_config_xml flixbox-prowlarr)
BAZARR_API_KEY=$(docker exec flixbox-bazarr grep '^\s*apikey:' /config/config/config.yaml 2>/dev/null \
  | head -1 | sed 's/.*apikey:[[:space:]]*//' | tr -d ' ' || true)

[[ -n "$SONARR_API_KEY" ]] && info "Sonarr API key: ${SONARR_API_KEY:0:8}..."
[[ -z "$SONARR_API_KEY" ]] && fail "Could not read Sonarr API key (complete first-run wizard?)"
[[ -n "$RADARR_API_KEY" ]] && info "Radarr API key: ${RADARR_API_KEY:0:8}..."
[[ -z "$RADARR_API_KEY" ]] && fail "Could not read Radarr API key (complete first-run wizard?)"
[[ -n "$PROWLARR_API_KEY" ]] && info "Prowlarr API key: ${PROWLARR_API_KEY:0:8}..."
[[ -z "$PROWLARR_API_KEY" ]] && fail "Could not read Prowlarr API key (complete first-run wizard?)"
[[ -n "$BAZARR_API_KEY" ]] && info "Bazarr API key: ${BAZARR_API_KEY:0:8}..."
[[ -z "$BAZARR_API_KEY" ]] && fail "Could not read Bazarr API key (complete first-run wizard?)"

if [[ -n "$RADARR_API_KEY" ]]; then
  env_set_if_empty RADARR_API_KEY "$RADARR_API_KEY"
fi
if [[ -n "$SONARR_API_KEY" ]]; then
  env_set_if_empty SONARR_API_KEY "$SONARR_API_KEY"
fi

QBIT_USERNAME="${QBITTORRENT_USERNAME:-}"
QBIT_PASSWORD="${QBITTORRENT_PASSWORD:-}"
if [[ -z "$QBIT_USERNAME" && -f .env ]]; then
  QBIT_USERNAME=$(grep -E '^QBITTORRENT_USERNAME=' .env 2>/dev/null | head -1 | cut -d= -f2- || true)
fi
if [[ -z "$QBIT_PASSWORD" && -f .env ]]; then
  QBIT_PASSWORD=$(grep -E '^QBITTORRENT_PASSWORD=' .env 2>/dev/null | head -1 | cut -d= -f2- || true)
fi
QBIT_USERNAME="${QBIT_USERNAME:-admin}"
if [[ -z "$QBIT_PASSWORD" ]]; then
  QBIT_PASSWORD=$(docker logs flixbox-qbittorrent 2>&1 \
    | grep -iE 'temporary password|password is' | tail -1 \
    | grep -oE '[^ ]+$' || true)
fi

QBIT_API_KEY=$(qbit_api_key_from_config flixbox-qbittorrent)
if [[ -n "$QBIT_API_KEY" ]]; then
  info "qBittorrent API key: ${QBIT_API_KEY:0:8}..."
fi

echo ""

configure_qbittorrent() {
  log "Configuring qBittorrent..."

  if ! wait_for_service "qBittorrent" "${QBIT_URL}/api/v2/app/version"; then
    return
  fi

  if $DRY_RUN; then
    dry "Create categories tv → /data/torrents/tv, movies → /data/torrents/movies"
    dry "Set basic preferences (auto TMM, UPnP off, encryption prefer)"
    return
  fi

  if [[ -z "$QBIT_PASSWORD" ]]; then
    fail "qBittorrent: no password — log in via WebUI first (${QBIT_URL})"
    return
  fi

  if ! qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_PASSWORD" "$QBIT_COOKIE"; then
    fail "qBittorrent: authentication failed (check WebUI login at ${QBIT_URL})"
    return
  fi

  local http_code cat_name save_path
  for cat_name in tv movies; do
    save_path="/data/torrents/${cat_name}"
    http_code=$(curl -s -o /dev/null -w '%{http_code}' \
      -b "$QBIT_COOKIE" \
      --data-urlencode "category=${cat_name}" \
      --data-urlencode "savePath=${save_path}" \
      "${QBIT_URL}/api/v2/torrents/createCategory")
    case "$http_code" in
      200) ok "qBittorrent: category '${cat_name}' → ${save_path}" ;;
      409) skip "qBittorrent: category '${cat_name}'" ;;
      *) fail "qBittorrent: category '${cat_name}' (HTTP ${http_code})" ;;
    esac
  done

  local prefs='{"auto_tmm_enabled":true,"upnp":false,"encryption":1}'
  if [[ "${FLIXBOX_MODE}" == "vpn" ]]; then
    prefs='{"auto_tmm_enabled":true,"upnp":false,"encryption":1,"current_network_interface":"tun0","current_interface_address":""}'
  fi
  http_code=$(curl -s -o /dev/null -w '%{http_code}' \
    -b "$QBIT_COOKIE" \
    --data-urlencode "json=${prefs}" \
    "${QBIT_URL}/api/v2/app/setPreferences")
  if [[ "$http_code" == "200" ]]; then
    ok "qBittorrent: preferences updated"
  else
    fail "qBittorrent: set preferences (HTTP ${http_code})"
  fi

  rm -f "$QBIT_COOKIE"
}

configure_prowlarr() {
  log "Configuring Prowlarr..."

  if [[ -z "$PROWLARR_API_KEY" ]]; then
    fail "Prowlarr: no API key, skipping"
    return
  fi

  local base="http://127.0.0.1:${PROWLARR_PORT}"
  local auth="X-Api-Key: ${PROWLARR_API_KEY}"

  if ! wait_for_service "Prowlarr" "${base}/api/v1/health"; then
    return
  fi

  if $DRY_RUN; then
    dry "Add Byparr indexer proxy (http://byparr:8191)"
    dry "Add Sonarr and Radarr application sync"
    return
  fi

  local proxies
  proxies=$(api_get "${base}/api/v1/indexerProxy" "$auth") || true
  if json_extract "$proxies" "sys.exit(0 if any('byparr' in p.get('name','').lower() or 'flaresolverr' in p.get('name','').lower() for p in data) else 1)"; then
    skip "Prowlarr: Byparr/FlareSolverr proxy"
  else
    local proxy_payload='{"name":"Byparr","implementation":"FlareSolverr","configContract":"FlareSolverrSettings","fields":[{"name":"host","value":"http://byparr:8191"},{"name":"requestTimeout","value":60}],"tags":["cf"]}'
    if api_post "${base}/api/v1/indexerProxy" "application/json" "$proxy_payload" "$auth" >/dev/null 2>&1; then
      ok "Prowlarr: added Byparr proxy (tag: cf)"
    else
      fail "Prowlarr: add Byparr proxy"
    fi
  fi

  local apps arr_name arr_port arr_key arr_categories name_lower app_payload
  apps=$(api_get "${base}/api/v1/applications" "$auth") || true

  for arr_name in Sonarr Radarr; do
    if [[ "$arr_name" == "Sonarr" ]]; then
      arr_port=8989
      arr_key="$SONARR_API_KEY"
      arr_categories="[5000, 5010, 5020, 5030, 5040, 5045, 5050, 5060, 5070, 5080]"
    else
      arr_port=7878
      arr_key="$RADARR_API_KEY"
      arr_categories="[2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060, 2070, 2080]"
    fi
    name_lower=$(echo "$arr_name" | tr '[:upper:]' '[:lower:]')
    if json_extract "$apps" "sys.exit(0 if any(a.get('name','').lower() == '${name_lower}' for a in data) else 1)"; then
      skip "Prowlarr: ${arr_name} application"
    elif [[ -z "$arr_key" ]]; then
      fail "Prowlarr: add ${arr_name} (no API key)"
    else
      app_payload="{\"name\":\"${arr_name}\",\"syncLevel\":\"fullSync\",\"implementation\":\"${arr_name}\",\"configContract\":\"${arr_name}Settings\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://${name_lower}:${arr_port}\"},{\"name\":\"apiKey\",\"value\":\"${arr_key}\"},{\"name\":\"syncCategories\",\"value\":${arr_categories}}],\"tags\":[\"cf\"]}"
      if api_post "${base}/api/v1/applications" "application/json" "$app_payload" "$auth" >/dev/null 2>&1; then
        ok "Prowlarr: added ${arr_name} application sync"
      else
        fail "Prowlarr: add ${arr_name} application"
      fi
    fi
  done
}

configure_bazarr() {
  log "Configuring Bazarr..."

  if [[ -z "$BAZARR_API_KEY" ]]; then
    fail "Bazarr: no API key, skipping"
    return
  fi

  local base="http://127.0.0.1:${BAZARR_PORT}"
  local auth="X-API-KEY: ${BAZARR_API_KEY}"

  if ! wait_for_service "Bazarr" "${base}/api/system/status"; then
    return
  fi

  if $DRY_RUN; then
    dry "Connect Bazarr to Sonarr (sonarr:8989) and Radarr (radarr:7878)"
    return
  fi

  if bazarr_settings_post "$base" "$auth" \
    "settings-general-use_sonarr=true" \
    "settings-sonarr-ip=sonarr" \
    "settings-sonarr-port=8989" \
    "settings-sonarr-base_url=" \
    "settings-sonarr-ssl=false" \
    "settings-sonarr-apikey=${SONARR_API_KEY}" \
    "settings-general-use_radarr=true" \
    "settings-radarr-ip=radarr" \
    "settings-radarr-port=7878" \
    "settings-radarr-base_url=" \
    "settings-radarr-ssl=false" \
    "settings-radarr-apikey=${RADARR_API_KEY}"; then
    ok "Bazarr: connected to Sonarr and Radarr"
  else
    fail "Bazarr: connect Sonarr/Radarr"
  fi
}

configure_qbittorrent
configure_arr_service "Sonarr" "$SONARR_PORT" "$SONARR_API_KEY" "/data/media/tv" "tv" "$QBIT_ARR_HOST" "$QBIT_API_KEY"
configure_arr_service "Radarr" "$RADARR_PORT" "$RADARR_API_KEY" "/data/media/movies" "movies" "$QBIT_ARR_HOST" "$QBIT_API_KEY"
configure_prowlarr
configure_bazarr

echo ""
log "Done: ${CONFIGURED} configured, ${SKIPPED} skipped, ${FAILED} failed"
echo ""
log "Still manual (~20–30 min):"
info "  • Prowlarr: add your indexers (tag cf on Cloudflare indexers)"
info "  • Jellyfin: libraries at /data/media/movies and /data/media/tv + API key"
info "  • Seerr: connect Jellyfin, Radarr, Sonarr"
info "  • .env: QBITTORRENT_USERNAME/PASSWORD for Decluttarr → ./bin/flixbox reload"
info "  • Guide: docs/user/05-first-run.md"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
