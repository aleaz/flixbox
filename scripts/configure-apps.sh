#!/usr/bin/env bash
#
# Idempotent API wiring for Flixbox after first container start (ADR 0005).
#
# Usage:
#   ./scripts/configure-apps.sh [--dry-run] [--verbose] [--sync-qbit-auth]
#   ./bin/flixbox configure [--dry-run] [--verbose] [--sync-qbit-auth]
#
# Prerequisites:
#   - ./bin/flixbox init (generates *arr API keys + qBit/admin passwords)
#   - ./bin/flixbox up (stack healthy; Gluetun healthy in VPN mode)
#
# --sync-qbit-auth:
#   Force .env QBITTORRENT_* (and qBit API key from config) onto qBit WebUI,
#   Radarr/Sonarr download clients, and recreate Decluttarr. Use after changing
#   the password in the qBit UI (update .env first) or after rotating credentials.
#
# Still manual after this script:
#   - Prowlarr indexers (your credentials)
#   - Optional Maintainerr rules (destructive — deliberate)
#   - Recyclarr sync: docker compose --profile recyclarr run --rm recyclarr sync

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/configure-helpers.sh"

DRY_RUN=false
VERBOSE=false
SYNC_QBIT_AUTH=false
QBIT_COOKIE="/tmp/flixbox_qbit_configure_cookie.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --verbose|-v) VERBOSE=true; shift ;;
    --sync-qbit-auth) SYNC_QBIT_AUTH=true; shift ;;
    --help|-h)
      sed -n '2,22p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--dry-run] [--verbose] [--sync-qbit-auth]" >&2
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
  CONFIG_DIR="${CONFIG_DIR:-/srv/flixbox/config}"
  QBITTORRENT_PORT="${QBITTORRENT_PORT:-8080}"
  RADARR_PORT="${RADARR_PORT:-7878}"
  SONARR_PORT="${SONARR_PORT:-8989}"
  PROWLARR_PORT="${PROWLARR_PORT:-9696}"
  BAZARR_PORT="${BAZARR_PORT:-6767}"
  JELLYFIN_PORT="${JELLYFIN_PORT:-8096}"
  SEERR_PORT="${SEERR_PORT:-5055}"
}

container_running() {
  docker ps --format '{{.Names}}' | grep -qx "$1"
}

load_env

if [[ "${FLIXBOX_ACCESS_PROFILE:-trusted}" == "shared" ]]; then
  info "Access profile: shared — admin ports on 127.0.0.1; after configure, create Forms users with FLIXBOX_ARR_UI_* (docs/user/13-access-profiles.md#create-arr-login-shared)"
fi

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
fi

# ADR 0014: same logical host in VPN and Direct
QBIT_ARR_HOST="qbittorrent"
QBIT_URL="http://127.0.0.1:${QBITTORRENT_PORT}"
QBIT_INTERNAL_API_URL="http://127.0.0.1:8080"
QBIT_DOCKER_CONTAINER="flixbox-qbittorrent"
QBIT_DOCKER_COOKIE="/tmp/flixbox-configure-cookie.txt"

log "Discovering API keys..."

# Prefer .env (init-generated) then container config.xml
SONARR_API_KEY="${SONARR_API_KEY:-}"
RADARR_API_KEY="${RADARR_API_KEY:-}"
PROWLARR_API_KEY="${PROWLARR_API_KEY:-}"
[[ -z "$SONARR_API_KEY" ]] && SONARR_API_KEY=$(api_key_from_config_xml flixbox-sonarr)
[[ -z "$RADARR_API_KEY" ]] && RADARR_API_KEY=$(api_key_from_config_xml flixbox-radarr)
[[ -z "$PROWLARR_API_KEY" ]] && PROWLARR_API_KEY=$(api_key_from_config_xml flixbox-prowlarr)

SONARR_API_KEY=$(resolve_arr_api_key SONARR_API_KEY flixbox-sonarr "$SONARR_API_KEY")
RADARR_API_KEY=$(resolve_arr_api_key RADARR_API_KEY flixbox-radarr "$RADARR_API_KEY")
PROWLARR_API_KEY=$(resolve_arr_api_key PROWLARR_API_KEY flixbox-prowlarr "$PROWLARR_API_KEY")

BAZARR_API_KEY=$(docker exec flixbox-bazarr grep '^\s*apikey:' /config/config/config.yaml 2>/dev/null \
  | head -1 | sed 's/.*apikey:[[:space:]]*//' | tr -d ' ' || true)

[[ -n "$SONARR_API_KEY" ]] && info "Sonarr API key: ${SONARR_API_KEY:0:8}..."
[[ -z "$SONARR_API_KEY" ]] && fail "Could not read Sonarr API key (run flixbox init?)"
[[ -n "$RADARR_API_KEY" ]] && info "Radarr API key: ${RADARR_API_KEY:0:8}..."
[[ -z "$RADARR_API_KEY" ]] && fail "Could not read Radarr API key (run flixbox init?)"
[[ -n "$PROWLARR_API_KEY" ]] && info "Prowlarr API key: ${PROWLARR_API_KEY:0:8}..."
[[ -z "$PROWLARR_API_KEY" ]] && fail "Could not read Prowlarr API key (run flixbox init?)"
[[ -n "$BAZARR_API_KEY" ]] && info "Bazarr API key: ${BAZARR_API_KEY:0:8}..."
[[ -z "$BAZARR_API_KEY" ]] && fail "Could not read Bazarr API key (wait for Bazarr first start)"

env_set_if_empty RADARR_API_KEY "$RADARR_API_KEY"
env_set_if_empty SONARR_API_KEY "$SONARR_API_KEY"
env_set_if_empty PROWLARR_API_KEY "$PROWLARR_API_KEY"
env_set_if_empty BAZARR_API_KEY "$BAZARR_API_KEY"

QBIT_USERNAME="${QBITTORRENT_USERNAME:-admin}"
QBIT_PASSWORD="${QBITTORRENT_PASSWORD:-}"
QBIT_TEMP_PASSWORD=""
QBIT_TEMP_PASSWORD=$(docker logs flixbox-qbittorrent 2>&1 \
  | grep -iE 'temporary password|password is' | tail -1 \
  | grep -oE '[^ ]+$' || true)

QBIT_API_KEY=$(qbit_api_key_from_config flixbox-qbittorrent)
[[ -n "$QBIT_API_KEY" ]] && info "qBittorrent API key: ${QBIT_API_KEY:0:8}..."

echo ""
log "Waiting for first-start initialization (databases + APIs)..."
wait_for_qbittorrent || exit 1
wait_for_arr_api "Sonarr" "$SONARR_PORT" "$SONARR_API_KEY" "v3" || exit 1
wait_for_arr_api "Radarr" "$RADARR_PORT" "$RADARR_API_KEY" "v3" || exit 1
wait_for_arr_api "Prowlarr" "$PROWLARR_PORT" "$PROWLARR_API_KEY" "v1" || exit 1
wait_for_bazarr_api "$BAZARR_PORT" "$BAZARR_API_KEY" || exit 1
wait_for_service "Jellyfin" "http://127.0.0.1:${JELLYFIN_PORT}/System/Info/Public" || exit 1
container_running flixbox-seerr && wait_for_service "Seerr" "http://127.0.0.1:${SEERR_PORT}/api/v1/status" || true
echo ""

configure_qbittorrent() {
  log "Configuring qBittorrent..."

  if ! wait_for_qbittorrent; then
    return
  fi

  if $DRY_RUN; then
    dry "Auth via in-container :8080 (env password or temp); set stable WebUI password if needed"
    dry "Apply WebUI host-header fix for remapped QBITTORRENT_PORT"
    dry "Create categories tv/movies under /data/torrents/{tv,movies}"
    dry "Prefs: auto TMM, UPnP off, encryption, limits; tun0 bind if VPN"
    $SYNC_QBIT_AUTH && dry "Force-push .env password to qBit + *arr download clients + Decluttarr"
    return
  fi

  local authed=false
  if [[ -n "$QBIT_PASSWORD" ]] && qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_PASSWORD" "$QBIT_COOKIE"; then
    authed=true
  elif [[ -n "$QBIT_TEMP_PASSWORD" ]] && qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_TEMP_PASSWORD" "$QBIT_COOKIE"; then
    authed=true
    if [[ -n "$QBIT_PASSWORD" && "$QBIT_PASSWORD" != "$QBIT_TEMP_PASSWORD" ]]; then
      local http_code
      http_code=$(qbit_curl_authed_code -X POST \
        --data-urlencode "json={\"web_ui_password\":\"${QBIT_PASSWORD}\"}" \
        "${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}/api/v2/app/setPreferences")
      if [[ "$http_code" == "200" ]]; then
        ok "qBittorrent: WebUI password set from .env"
        docker exec "${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}" rm -f "${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}" 2>/dev/null || true
        if ! qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_PASSWORD" "$QBIT_COOKIE"; then
          fail "qBittorrent: re-auth after password change failed"
          return
        fi
      else
        fail "qBittorrent: set WebUI password (HTTP ${http_code})"
      fi
    else
      env_set_if_empty QBITTORRENT_PASSWORD "$QBIT_TEMP_PASSWORD"
      QBIT_PASSWORD="${QBITTORRENT_PASSWORD:-$QBIT_TEMP_PASSWORD}"
    fi
  fi

  if ! $authed; then
    fail "qBittorrent: authentication failed — set QBITTORRENT_PASSWORD in .env to the current WebUI password (or check temp password in: docker compose logs qbittorrent)"
    return
  fi

  env_set_if_empty QBITTORRENT_USERNAME "$QBIT_USERNAME"
  env_set_if_empty QBITTORRENT_PASSWORD "$QBIT_PASSWORD"

  # --sync-qbit-auth: always re-apply .env password (source of truth for Decluttarr/*arr).
  if $SYNC_QBIT_AUTH && [[ -n "$QBIT_PASSWORD" ]]; then
    local sync_pw_code
    sync_pw_code=$(qbit_curl_authed_code -X POST \
      --data-urlencode "json={\"web_ui_password\":\"${QBIT_PASSWORD}\"}" \
      "${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}/api/v2/app/setPreferences")
    if [[ "$sync_pw_code" == "200" ]]; then
      ok "qBittorrent: WebUI password synced from .env (--sync-qbit-auth)"
      docker exec "${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}" rm -f "${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}" 2>/dev/null || true
      if ! qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_PASSWORD" "$QBIT_COOKIE"; then
        fail "qBittorrent: re-auth after --sync-qbit-auth failed"
        return
      fi
      ENV_DIRTY=true
    else
      fail "qBittorrent: sync password from .env (HTTP ${sync_pw_code})"
    fi
  fi

  # cont-init WebUI keys can be overwritten when qBit first starts — apply via API.
  local webui_code
  # qBit 5.x API keys (4.x used web_ui_host_header_validation / web_ui_auth_subnet_*).
  webui_code=$(qbit_curl_authed_code -X POST \
    --data-urlencode 'json={"web_ui_host_header_validation_enabled":false,"bypass_local_auth":false,"bypass_auth_subnet_whitelist_enabled":true,"bypass_auth_subnet_whitelist":"172.30.42.0/24","web_ui_max_auth_fail_count":20,"web_ui_ban_duration":300}' \
    "${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}/api/v2/app/setPreferences")
  if [[ "$webui_code" == "200" ]]; then
    ok "qBittorrent: WebUI host-header + Docker subnet whitelist"
  else
    fail "qBittorrent: WebUI settings (HTTP ${webui_code})"
  fi

  local http_code cat_name save_path
  for cat_name in tv movies; do
    save_path="/data/torrents/${cat_name}"
    http_code=$(qbit_curl_authed_code \
      --data-urlencode "category=${cat_name}" \
      --data-urlencode "savePath=${save_path}" \
      "${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}/api/v2/torrents/createCategory")
    case "$http_code" in
      200) ok "qBittorrent: category '${cat_name}' → ${save_path}" ;;
      409) skip "qBittorrent: category '${cat_name}'" ;;
      *) fail "qBittorrent: category '${cat_name}' (HTTP ${http_code})" ;;
    esac
  done

  local current_prefs
  current_prefs=$(qbit_curl_authed "${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}/api/v2/app/preferences" 2>/dev/null || true)

  local prefs_ok=false
  if [[ -n "$current_prefs" ]]; then
    if [[ "${FLIXBOX_MODE}" == "vpn" ]]; then
      if json_extract "$current_prefs" "
p = data
if not p.get('auto_tmm_enabled', False): sys.exit(1)
if p.get('upnp', True): sys.exit(1)
if p.get('encryption', 0) != 1: sys.exit(1)
if not p.get('limit_utp_rate', False): sys.exit(1)
if not p.get('limit_lan_peers', False): sys.exit(1)
if p.get('current_network_interface', '') != 'tun0': sys.exit(1)
"; then
        prefs_ok=true
      fi
    else
      if json_extract "$current_prefs" "
p = data
if not p.get('auto_tmm_enabled', False): sys.exit(1)
if p.get('upnp', True): sys.exit(1)
if p.get('encryption', 0) != 1: sys.exit(1)
if not p.get('limit_utp_rate', False): sys.exit(1)
if not p.get('limit_lan_peers', False): sys.exit(1)
"; then
        prefs_ok=true
      fi
    fi
  fi

  if $prefs_ok; then
    skip "qBittorrent: preferences"
  else
    local prefs
    prefs='{"auto_tmm_enabled":true,"upnp":false,"encryption":1,"limit_utp_rate":true,"limit_lan_peers":true,"max_active_downloads":5,"max_active_torrents":10,"max_active_uploads":5}'
    if [[ "${FLIXBOX_MODE}" == "vpn" ]]; then
      prefs='{"auto_tmm_enabled":true,"upnp":false,"encryption":1,"limit_utp_rate":true,"limit_lan_peers":true,"max_active_downloads":5,"max_active_torrents":10,"max_active_uploads":5,"current_network_interface":"tun0","current_interface_address":""}'
    fi
    http_code=$(qbit_curl_authed_code \
      -X POST \
      --data-urlencode "json=${prefs}" \
      "${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}/api/v2/app/setPreferences")
    if [[ "$http_code" == "200" ]]; then
      ok "qBittorrent: preferences updated"
    else
      fail "qBittorrent: set preferences (HTTP ${http_code})"
    fi
  fi

  rm -f "$QBIT_COOKIE"
  docker exec "${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}" rm -f "${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}" 2>/dev/null || true
}

configure_prowlarr() {
  log "Configuring Prowlarr..."

  if [[ -z "$PROWLARR_API_KEY" ]]; then
    fail "Prowlarr: no API key, skipping"
    return
  fi

  local base="http://127.0.0.1:${PROWLARR_PORT}"
  local auth="X-Api-Key: ${PROWLARR_API_KEY}"

  if ! wait_for_arr_api "Prowlarr" "$PROWLARR_PORT" "$PROWLARR_API_KEY" "v1"; then
    return
  fi

  local cf_tag_id
  cf_tag_id=$(prowlarr_ensure_tag_id "$base" "$auth" "cf") || true
  if [[ -z "$cf_tag_id" ]]; then
    fail "Prowlarr: create or resolve tag 'cf'"
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
    local proxy_payload
    proxy_payload="{\"name\":\"Byparr\",\"implementation\":\"FlareSolverr\",\"configContract\":\"FlareSolverrSettings\",\"fields\":[{\"name\":\"host\",\"value\":\"http://byparr:8191\"},{\"name\":\"requestTimeout\",\"value\":60}],\"tags\":[${cf_tag_id}]}"
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
      app_payload="{\"name\":\"${arr_name}\",\"syncLevel\":\"fullSync\",\"implementation\":\"${arr_name}\",\"configContract\":\"${arr_name}Settings\",\"fields\":[{\"name\":\"prowlarrUrl\",\"value\":\"http://prowlarr:9696\"},{\"name\":\"baseUrl\",\"value\":\"http://${name_lower}:${arr_port}\"},{\"name\":\"apiKey\",\"value\":\"${arr_key}\"},{\"name\":\"syncCategories\",\"value\":${arr_categories}}],\"tags\":[${cf_tag_id}]}"
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

  if ! wait_for_bazarr_api "$BAZARR_PORT" "$BAZARR_API_KEY"; then
    return
  fi

  if $DRY_RUN; then
    dry "Connect Bazarr to Sonarr/Radarr; enable ffsubsync; ES/EN language defaults"
    return
  fi

  local settings
  settings=$(api_get "${base}/api/system/settings" "$auth") || true
  if [[ -z "$settings" ]]; then
    fail "Bazarr: could not fetch settings"
    return
  fi

  local needs_restart=false
  local conn_state
  conn_state=$(json_extract "$settings" "
want = {
    'sonarr': {'ip': 'sonarr', 'port': 8989, 'base_url': '', 'ssl': False, 'apikey': '''${SONARR_API_KEY}'''},
    'radarr': {'ip': 'radarr', 'port': 7878, 'base_url': '', 'ssl': False, 'apikey': '''${RADARR_API_KEY}'''},
}
general = data.get('general', {})
diff = []
for section, fields in sorted(want.items()):
    current = data.get(section, {})
    if not general.get('use_' + section):
        diff.append('general.use_' + section)
    for field, expected in sorted(fields.items()):
        if field == 'apikey' and not expected:
            continue
        actual = current.get(field)
        if field == 'port':
            actual = int(actual) if str(actual).isdigit() else actual
        if actual != expected:
            diff.append(section + '.' + field)
print(' '.join(diff) if diff else 'MATCH')")

  if [[ -z "$conn_state" ]]; then
    fail "Bazarr: could not compare Sonarr/Radarr connections"
  elif [[ "$conn_state" == "MATCH" ]]; then
    skip "Bazarr: Sonarr/Radarr connections"
  else
    local conn_keys=(
      "settings-general-use_sonarr=true"
      "settings-sonarr-ip=sonarr"
      "settings-sonarr-port=8989"
      "settings-sonarr-base_url="
      "settings-sonarr-ssl=false"
      "settings-sonarr-apikey=${SONARR_API_KEY}"
      "settings-general-use_radarr=true"
      "settings-radarr-ip=radarr"
      "settings-radarr-port=7878"
      "settings-radarr-base_url="
      "settings-radarr-ssl=false"
      "settings-radarr-apikey=${RADARR_API_KEY}"
    )
    if bazarr_settings_post "$base" "$auth" "${conn_keys[@]}"; then
      ok "Bazarr: connected to Sonarr and Radarr"
      needs_restart=true
    else
      fail "Bazarr: connect Sonarr/Radarr"
    fi
  fi

  local subsync_state
  subsync_state=$(json_extract "$settings" "
want = {'use_subsync': True, 'use_subsync_threshold': True, 'subsync_threshold': 90,
        'use_subsync_movie_threshold': True, 'subsync_movie_threshold': 70}
current = data.get('subsync', {})
diff = [k for k, v in sorted(want.items()) if current.get(k) != v]
print(' '.join(diff) if diff else 'MATCH')")
  if [[ "$subsync_state" == "MATCH" ]]; then
    skip "Bazarr: subtitle sync"
  elif [[ -n "$subsync_state" ]]; then
    if bazarr_settings_post "$base" "$auth" \
      "settings-subsync-use_subsync=true" \
      "settings-subsync-use_subsync_threshold=true" \
      "settings-subsync-subsync_threshold=90" \
      "settings-subsync-use_subsync_movie_threshold=true" \
      "settings-subsync-subsync_movie_threshold=70"; then
      ok "Bazarr: enabled subtitle sync (ffsubsync)"
      needs_restart=true
    else
      fail "Bazarr: enable subtitle sync"
    fi
  fi

  if $needs_restart; then
    info "Restarting Bazarr to apply settings..."
    docker restart flixbox-bazarr >/dev/null 2>&1 || true
  fi
}

configure_jellyfin() {
  log "Configuring Jellyfin..."

  if ! container_running flixbox-jellyfin; then
    fail "Jellyfin: container not running"
    return
  fi

  local base="http://127.0.0.1:${JELLYFIN_PORT}"
  if ! wait_for_service "Jellyfin" "${base}/System/Info/Public"; then
    return
  fi

  local admin_user="${FLIXBOX_ADMIN_USER:-admin}"
  local admin_pass="${FLIXBOX_ADMIN_PASSWORD:-}"

  if $DRY_RUN; then
    dry "Complete Jellyfin startup if needed; add movie/TV libraries; create API key"
    return
  fi

  local needs_startup=false
  if jellyfin_startup_wizard_pending "$base"; then
    needs_startup=true
  fi

  if $needs_startup; then
    if [[ -z "$admin_pass" ]]; then
      fail "Jellyfin: startup wizard incomplete — set FLIXBOX_ADMIN_PASSWORD in .env and re-run"
      return
    fi
    # Jellyfin 10.x: initialize first user, then set password, then complete wizard.
    curl -s -o /dev/null -X POST "${base}/Startup/Configuration" \
      -H 'Content-Type: application/json' \
      -d '{"UICulture":"en-US","MetadataCountryCode":"US","PreferredDisplayLanguage":"en"}' || true
    curl -s -o /dev/null "${base}/Startup/User" || true
    local user_code
    user_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${base}/Startup/User" \
      -H 'Content-Type: application/json' \
      -d "{\"Name\":\"${admin_user}\",\"Password\":\"${admin_pass}\"}")
    if [[ "$user_code" =~ ^2 ]]; then
      ok "Jellyfin: startup user ${admin_user} configured"
    else
      fail "Jellyfin: startup user setup failed (HTTP ${user_code})"
      return
    fi
    # Seerr bootstrap requires Jellyfin admin; ensure flag on first user (Jellyfin 10.11 quirk).
    local jf_auth_json jf_token jf_user_id jf_is_admin
    jf_auth_json=$(curl -s -X POST "${base}/Users/AuthenticateByName" \
      -H 'Content-Type: application/json' \
      -H 'X-Emby-Authorization: MediaBrowser Client="Flixbox", Device="configure", DeviceId="flixbox-configure", Version="1.0.0"' \
      -d "{\"Username\":\"${admin_user}\",\"Pw\":\"${admin_pass}\"}" 2>/dev/null || true)
    jf_token=$(json_extract "$jf_auth_json" "print(data.get('AccessToken',''))" || true)
    jf_user_id=$(json_extract "$jf_auth_json" "print(data.get('User', {}).get('Id', ''))" || true)
    jf_is_admin=$(json_extract "$jf_auth_json" "print(str(data.get('User', {}).get('Policy', {}).get('IsAdministrator', False)).lower())" || echo false)
    if [[ -n "$jf_token" && -n "$jf_user_id" && "$jf_is_admin" != "true" ]]; then
      local policy_json policy_code
      policy_json=$(curl -s "${base}/Users/${jf_user_id}" -H "X-Emby-Token: ${jf_token}" 2>/dev/null || true)
      policy_json=$(json_extract "$policy_json" "
p = data.get('Policy', {})
p['IsAdministrator'] = True
data['Policy'] = p
print(__import__('json').dumps(data.get('Policy', {})))" || true)
      if [[ -n "$policy_json" ]]; then
        policy_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${base}/Users/${jf_user_id}/Policy" \
          -H "X-Emby-Token: ${jf_token}" -H 'Content-Type: application/json' -d "$policy_json")
        if [[ "$policy_code" =~ ^2 ]]; then
          ok "Jellyfin: granted administrator to ${admin_user}"
        else
          info "Jellyfin: could not set administrator policy (HTTP ${policy_code})"
        fi
      fi
    fi
    unset jf_token jf_auth_json
    curl -s -o /dev/null -X POST "${base}/Startup/RemoteAccess" \
      -H 'Content-Type: application/json' \
      -d '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}' || true
    local complete_code
    complete_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${base}/Startup/Complete")
    if [[ "$complete_code" =~ ^2 ]]; then
      ok "Jellyfin: completed startup wizard"
    else
      fail "Jellyfin: startup Complete failed (HTTP ${complete_code}) — finish wizard in UI once, then re-run configure"
      return
    fi
  else
    skip "Jellyfin: startup wizard"
  fi

  # Authenticate for library + API key ops
  if [[ -z "$admin_pass" ]]; then
    info "Jellyfin: no FLIXBOX_ADMIN_PASSWORD — skip libraries/API key (add manually)"
    return
  fi

  local auth_json token
  auth_json=$(curl -s -X POST "${base}/Users/AuthenticateByName" \
    -H 'Content-Type: application/json' \
    -H 'X-Emby-Authorization: MediaBrowser Client="Flixbox", Device="configure", DeviceId="flixbox-configure", Version="1.0.0"' \
    -d "{\"Username\":\"${admin_user}\",\"Pw\":\"${admin_pass}\"}" 2>/dev/null || true)
  token=$(json_extract "$auth_json" "print(data.get('AccessToken',''))" || true)
  if [[ -z "$token" ]]; then
    fail "Jellyfin: login failed (check FLIXBOX_ADMIN_USER/PASSWORD)"
    return
  fi

  local libs
  libs=$(curl -s "${base}/Library/VirtualFolders" -H "X-Emby-Token: ${token}" 2>/dev/null || true)

  ensure_jf_library() {
    local lib_name="$1" collection_type="$2" path="$3"
    if json_extract "$libs" "sys.exit(0 if any(p.get('Name','').lower()=='''${lib_name}'''.lower() or '''${path}''' in (p.get('Locations') or []) for p in data) else 1)" 2>/dev/null; then
      skip "Jellyfin: library ${lib_name}"
      return
    fi
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
      "${base}/Library/VirtualFolders?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''${lib_name}'''))")&collectionType=${collection_type}&refreshLibrary=true" \
      -H "X-Emby-Token: ${token}" \
      -H 'Content-Type: application/json' \
      -d "{\"LibraryOptions\":{\"PathInfos\":[{\"Path\":\"${path}\"}]}}")
    if [[ "$code" =~ ^2 ]]; then
      ok "Jellyfin: added library ${lib_name} → ${path}"
    else
      # Alternate body shape
      code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
        "${base}/Library/VirtualFolders?name=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''${lib_name}'''))")&collectionType=${collection_type}&paths=${path}&refreshLibrary=true" \
        -H "X-Emby-Token: ${token}")
      if [[ "$code" =~ ^2 ]]; then
        ok "Jellyfin: added library ${lib_name} → ${path}"
      else
        fail "Jellyfin: add library ${lib_name} (HTTP ${code})"
      fi
    fi
  }

  ensure_jf_library "Movies" "movies" "/data/media/movies"
  ensure_jf_library "TV Shows" "tvshows" "/data/media/tv"

  # API key for Seerr / Maintainerr
  if [[ -n "${JELLYFIN_API_KEY:-}" ]]; then
    skip "Jellyfin: API key (.env already set)"
  else
    local key_json new_key
    key_json=$(curl -s -X POST "${base}/Auth/Keys?app=Flixbox" \
      -H "X-Emby-Token: ${token}" 2>/dev/null || true)
    new_key=$(json_extract "$key_json" "print(data.get('AccessToken') or data.get('Key') or '')" || true)
    if [[ -z "$new_key" ]]; then
      # List existing keys
      local keys
      keys=$(curl -s "${base}/Auth/Keys" -H "X-Emby-Token: ${token}" 2>/dev/null || true)
      new_key=$(json_extract "$keys" "
items = data if isinstance(data, list) else data.get('Items', data.get('items', []))
flix = [i for i in items if 'flixbox' in str(i.get('AppName','') or i.get('Name','')).lower()]
print((flix[0].get('AccessToken') or flix[0].get('Key') or '') if flix else '')" || true)
    fi
    if [[ -n "$new_key" ]]; then
      env_set_if_empty JELLYFIN_API_KEY "$new_key"
      JELLYFIN_API_KEY="$new_key"
      ok "Jellyfin: API key ready"
    else
      info "Jellyfin: could not create API key automatically — create one in Dashboard → API Keys"
    fi
  fi
  unset token
}

configure_seerr() {
  log "Configuring Seerr..."

  if ! container_running flixbox-seerr; then
    fail "Seerr: container not running"
    return
  fi

  local base="http://127.0.0.1:${SEERR_PORT}"
  if ! wait_for_service "Seerr" "${base}/api/v1/status"; then
    return
  fi

  local admin_user="${FLIXBOX_ADMIN_USER:-admin}"
  local admin_pass="${FLIXBOX_ADMIN_PASSWORD:-}"

  if $DRY_RUN; then
    dry "Seerr Jellyfin auth + Radarr/Sonarr services + initialize"
    return
  fi

  if [[ -z "$admin_pass" ]]; then
    info "Seerr: skip (need FLIXBOX_ADMIN_PASSWORD for Jellyfin login)"
    return
  fi

  local public init_flag
  public=$(curl -s "${base}/api/v1/settings/public" 2>/dev/null || true)
  init_flag=$(json_extract "$public" "print(str(data.get('initialized', False)).lower())" || echo false)

  # Login / create admin via Jellyfin
  local cookie="/tmp/flixbox_seerr_configure_cookie.txt"
  local login_code login_body
  if [[ "$init_flag" == "true" ]]; then
    login_body=$(seerr_login_json false "$admin_user" "$admin_pass")
  else
    login_body=$(seerr_login_json true "$admin_user" "$admin_pass")
  fi
  login_code=$(curl -s -o /tmp/flixbox_seerr_login.json -w '%{http_code}' -c "$cookie" \
    -X POST "${base}/api/v1/auth/jellyfin" \
    -H 'Content-Type: application/json' \
    -d "$login_body")

  if [[ ! "$login_code" =~ ^2 ]]; then
    local login_msg
    login_msg=$(json_extract "$(cat /tmp/flixbox_seerr_login.json 2>/dev/null || echo '{}')" \
      "print(data.get('message') or data.get('error') or '')" 2>/dev/null || true)
    if [[ -n "$login_msg" ]]; then
      fail "Seerr: Jellyfin auth failed (HTTP ${login_code}: ${login_msg})"
    else
      fail "Seerr: Jellyfin auth failed (HTTP ${login_code}) — check FLIXBOX_ADMIN_USER/PASSWORD"
    fi
    rm -f "$cookie" /tmp/flixbox_seerr_login.json
    return
  fi
  ok "Seerr: authenticated via Jellyfin"

  # Radarr / Sonarr services
  add_seerr_arr() {
    local kind="$1" host="$2" port="$3" api_key="$4" root="$5" is_default="${6:-false}"
    local list profiles profile_id profile_name lang_profile_id payload http_code
    list=$(curl -s -b "$cookie" "${base}/api/v1/settings/${kind}" 2>/dev/null || true)
    if json_extract "$list" "sys.exit(0 if any(True for _ in (data if isinstance(data,list) else [])) else 1)" 2>/dev/null \
      && [[ -n "$list" && "$list" != "[]" ]]; then
      skip "Seerr: ${kind} service"
      return
    fi
    local arr_base arr_auth
    arr_base="http://127.0.0.1:${port}"
    arr_auth="X-Api-Key: ${api_key}"
    profiles=$(api_get "${arr_base}/api/v3/qualityprofile" "$arr_auth") || true
    profile_id=$(json_extract "$profiles" "print(data[0]['id'] if data else '')" || true)
    profile_name=$(json_extract "$profiles" "print(data[0]['name'] if data else '')" || true)
    if [[ -z "$profile_id" ]]; then
      fail "Seerr: add ${kind} (no quality profile from ${kind})"
      return
    fi
    if [[ "$kind" == "radarr" ]]; then
      payload=$(cat <<EOF
{"name":"Radarr","hostname":"${host}","port":${port},"apiKey":"${api_key}","useSsl":false,"baseUrl":"","activeProfileId":${profile_id},"activeProfileName":"${profile_name}","activeDirectory":"${root}","is4k":false,"minimumAvailability":"released","isDefault":${is_default},"syncEnabled":true,"preventSearch":false}
EOF
)
    else
      local lang_profiles
      lang_profiles=$(api_get "${arr_base}/api/v3/languageprofile" "$arr_auth") || true
      lang_profile_id=$(json_extract "$lang_profiles" "print(data[0]['id'] if data else 1)" || echo 1)
      payload=$(cat <<EOF
{"name":"Sonarr","hostname":"${host}","port":${port},"apiKey":"${api_key}","useSsl":false,"baseUrl":"","activeProfileId":${profile_id},"activeProfileName":"${profile_name}","activeDirectory":"${root}","activeLanguageProfileId":${lang_profile_id},"activeAnimeProfileId":null,"activeAnimeLanguageProfileId":null,"activeAnimeDirectory":"","is4k":false,"enableSeasonFolders":true,"isDefault":${is_default},"syncEnabled":true,"preventSearch":false}
EOF
)
    fi
    http_code=$(curl -s -o /tmp/flixbox_seerr_arr.json -w '%{http_code}' -b "$cookie" -X POST \
      "${base}/api/v1/settings/${kind}" \
      -H 'Content-Type: application/json' \
      -d "$payload")
    if [[ "$http_code" =~ ^2 ]]; then
      ok "Seerr: added ${kind}"
    else
      if [[ "${VERBOSE:-false}" == "true" ]]; then
        info "Seerr ${kind} response (HTTP ${http_code}): $(cat /tmp/flixbox_seerr_arr.json 2>/dev/null || true)"
      fi
      fail "Seerr: add ${kind} (HTTP ${http_code})"
    fi
  }

  add_seerr_arr radarr radarr 7878 "$RADARR_API_KEY" "/data/media/movies" true
  add_seerr_arr sonarr sonarr 8989 "$SONARR_API_KEY" "/data/media/tv" false

  if [[ "$init_flag" == "true" ]]; then
    skip "Seerr: initialize"
  else
    if curl -s -o /dev/null -w '%{http_code}' -b "$cookie" -X POST \
      "${base}/api/v1/settings/initialize" | grep -qE '^2'; then
      ok "Seerr: initialized"
    else
      info "Seerr: initialize skipped or failed (may already be done)"
    fi
  fi

  rm -f "$cookie" /tmp/flixbox_seerr_login.json
}

reload_hygiene_if_needed() {
  if ! $ENV_DIRTY && ! $SYNC_QBIT_AUTH; then
    return
  fi
  if $DRY_RUN; then
    dry "Recreate Decluttarr/Unpackerr after .env key writes"
    return
  fi
  log "Recreating Decluttarr + Unpackerr to pick up .env keys..."
  if docker compose --project-directory "${ROOT_DIR}" up -d --force-recreate decluttarr unpackerr >/dev/null 2>&1; then
    ok "Hygiene containers recreated"
  else
    fail "Could not recreate Decluttarr/Unpackerr — run: ./bin/flixbox reload"
  fi
}

# --- Run ---
configure_qbittorrent
echo ""
configure_arr_service "Sonarr" "$SONARR_PORT" "$SONARR_API_KEY" "/data/media/tv" "tv" \
  "$QBIT_ARR_HOST" "$QBIT_API_KEY" "$QBIT_USERNAME" "$QBIT_PASSWORD"
echo ""
configure_arr_service "Radarr" "$RADARR_PORT" "$RADARR_API_KEY" "/data/media/movies" "movies" \
  "$QBIT_ARR_HOST" "$QBIT_API_KEY" "$QBIT_USERNAME" "$QBIT_PASSWORD"
echo ""
configure_prowlarr
echo ""
configure_bazarr
echo ""
patch_recyclarr_keys
echo ""
configure_jellyfin
# Reload env for JELLYFIN_API_KEY if written
load_env
echo ""
configure_seerr
echo ""
reload_hygiene_if_needed

echo ""
log "Done: ${CONFIGURED} configured, ${SKIPPED} skipped, ${FAILED} failed"
echo ""
log "Still manual:"
info "  • Prowlarr: add your indexers (tag cf on Cloudflare indexers)"
info "  • Maintainerr: connect services + enable rules deliberately"
info "  • Optional: docker compose --profile recyclarr run --rm recyclarr sync"
info "  • Guide: docs/user/05-first-run.md"

rm -f "$QBIT_COOKIE"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
