#!/usr/bin/env bash
# Preflight checks, API key discovery, and wait-for-ready (configure phase).

configure_assert_tools() {
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
}

configure_assert_stack() {
  local required=(flixbox-radarr flixbox-sonarr flixbox-prowlarr flixbox-bazarr flixbox-qbittorrent)
  local missing=() c
  for c in "${required[@]}"; do
    flixbox_container_running "$c" || missing+=("$c")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Required containers not running: ${missing[*]}" >&2
    echo "Start the stack first: ./bin/flixbox up" >&2
    exit 1
  fi

  if [[ "${FLIXBOX_MODE}" == "vpn" ]]; then
    if ! flixbox_container_running flixbox-gluetun; then
      echo "ERROR: FLIXBOX_MODE=vpn but flixbox-gluetun is not running." >&2
      exit 1
    fi
    local gluetun_health
    gluetun_health=$(docker inspect -f '{{.State.Health.Status}}' flixbox-gluetun 2>/dev/null || echo unknown)
    if [[ "$gluetun_health" != "healthy" ]]; then
      echo "ERROR: Gluetun is '${gluetun_health}' (need 'healthy')." >&2
      echo "       Wait for VPN connect, then re-run. Check: ./bin/flixbox logs gluetun" >&2
      exit 1
    fi
  fi
}

configure_init_qbit_context() {
  # ADR 0014: same logical host in VPN and Direct
  QBIT_ARR_HOST="qbittorrent"
  QBIT_URL="http://127.0.0.1:${QBITTORRENT_PORT}"
  QBIT_INTERNAL_API_URL="http://127.0.0.1:8080"
  QBIT_DOCKER_CONTAINER="flixbox-qbittorrent"
  QBIT_DOCKER_COOKIE="/tmp/flixbox-configure-cookie.txt"
}

configure_discover_api_keys() {
  log "Discovering API keys..."

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
}

configure_wait_for_stack() {
  echo ""
  log "Waiting for first-start initialization (databases + APIs)..."
  wait_for_qbittorrent || exit 1
  wait_for_arr_api "Sonarr" "$SONARR_PORT" "$SONARR_API_KEY" "v3" || exit 1
  wait_for_arr_api "Radarr" "$RADARR_PORT" "$RADARR_API_KEY" "v3" || exit 1
  wait_for_arr_api "Prowlarr" "$PROWLARR_PORT" "$PROWLARR_API_KEY" "v1" || exit 1
  wait_for_bazarr_api "$BAZARR_PORT" "$BAZARR_API_KEY" || exit 1
  wait_for_service "Jellyfin" "http://127.0.0.1:${JELLYFIN_PORT}/System/Info/Public" || exit 1
  if flixbox_container_running flixbox-seerr; then
    wait_for_service "Seerr" "http://127.0.0.1:${SEERR_PORT}/api/v1/status" || true
  fi
  echo ""
}

configure_preflight() {
  configure_assert_tools
  configure_assert_stack
  configure_init_qbit_context
  configure_discover_api_keys
  configure_wait_for_stack
}
