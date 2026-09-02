#!/usr/bin/env bash
# Preflight: stack assert → readiness retry loop → mark PREFLIGHT_PASSED for wiring.

configure_init_qbit_context() {
  # Exported: consumed by configure modules / helpers (ShellCheck SC2034).
  export QBIT_ARR_HOST="qbittorrent"
  export QBIT_URL="http://127.0.0.1:${QBITTORRENT_PORT}"
  export QBIT_INTERNAL_API_URL="http://127.0.0.1:8080"
  export QBIT_DOCKER_CONTAINER="flixbox-qbittorrent"
  export QBIT_DOCKER_COOKIE="/tmp/flixbox-configure-cookie.txt"
  configure_ensure_qbit_webui_helpers
}

# Post-upgrade: ensure login + prefs helpers exist under CONFIG_DIR (mounted into qBit).
# After qBit first start, linuxserver may own .flixbox as PUID — host cp can fail in CI.
configure_ensure_qbit_webui_helpers() {
  local dest_dir src_login dest_login tpl
  [[ -n "${CONFIG_DIR:-}" && -n "${ROOT_DIR:-}" ]] || return 0
  dest_dir="${CONFIG_DIR}/qbittorrent/.flixbox"
  tpl="${ROOT_DIR}/templates/qbittorrent"
  src_login="${tpl}/flixbox-qbit-api-login.sh"
  dest_login="${dest_dir}/qbit-api-login.sh"
  [[ -f "$src_login" ]] || return 0
  mkdir -p "$dest_dir"

  _qbit_helper_install() {
    local src="$1" dest="$2" mode="${3:-}"
    local src_base dest_base
    if [[ -f "$dest" ]] && cmp -s "$src" "$dest" 2>/dev/null; then
      return 0
    fi
    if cp -f "$src" "$dest" 2>/dev/null; then
      [[ -n "$mode" ]] && chmod "$mode" "$dest" 2>/dev/null || true
      return 0
    fi
    command -v docker >/dev/null 2>&1 || return 1
    src_base=$(basename "$src")
    dest_base=$(basename "$dest")
    docker run --rm \
      -v "$(dirname "$src"):/src:ro" \
      -v "$(dirname "$dest"):/dest" \
      alpine:3.20 \
      sh -c "cp -f \"/src/${src_base}\" \"/dest/${dest_base}\" && if [ -n \"${mode}\" ]; then chmod \"${mode}\" \"/dest/${dest_base}\"; fi" \
      >/dev/null 2>&1
  }

  if ! _qbit_helper_install "$src_login" "$dest_login" 700; then
    fail "qBittorrent: could not install .flixbox/qbit-api-login.sh under CONFIG_DIR"
    return 1
  fi
  local f
  for f in webui-security-prefs.json webui-security-prefs-portforward.json; do
    if [[ -f "${tpl}/${f}" ]]; then
      _qbit_helper_install "${tpl}/${f}" "${dest_dir}/${f}" || true
    fi
  done
}

configure_wait_for_first_start() {
  echo ""
  log "Waiting for first-start initialization (often 1–3 min after up)..."
  info "Containers are up; warming databases and WebUIs before wiring."
  configure_assert_vpn_ready || return 1
  configure_ensure_qbittorrent_ready || return 1
  configure_ensure_http_parallel \
    "Radarr" "http://127.0.0.1:${RADARR_PORT}/ping" \
    "Sonarr" "http://127.0.0.1:${SONARR_PORT}/ping" \
    "Prowlarr" "http://127.0.0.1:${PROWLARR_PORT}/ping" \
    "Bazarr" "http://127.0.0.1:${BAZARR_PORT}/" \
    "Jellyfin" "http://127.0.0.1:${JELLYFIN_PORT}/System/Info/Public" \
    || return 1
  if flixbox_container_running flixbox-seerr; then
    configure_ensure_http "Seerr" "http://127.0.0.1:${SEERR_PORT}/api/v1/status" || true
  fi
  echo ""
}

bazarr_api_key_from_config() {
  local key=""
  for _ in $(seq 1 15); do
    if docker exec flixbox-bazarr test -f /config/config/config.yaml 2>/dev/null; then
      key=$(docker exec flixbox-bazarr grep '^\s*apikey:' /config/config/config.yaml 2>/dev/null \
        | head -1 | sed 's/.*apikey:[[:space:]]*//' | tr -d ' ' || true)
      if [[ -n "$key" ]]; then
        printf '%s' "$key"
        return 0
      fi
    fi
    sleep 2
  done
  return 1
}

# $1=soft|hard — soft: retry-friendly; hard: fail() on missing keys.
configure_discover_api_keys() {
  local mode="${1:-soft}"
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

  BAZARR_API_KEY=""
  if ! BAZARR_API_KEY=$(bazarr_api_key_from_config); then
    BAZARR_API_KEY=""
  fi

  if [[ -z "$SONARR_API_KEY" || -z "$RADARR_API_KEY" || -z "$PROWLARR_API_KEY" || -z "$BAZARR_API_KEY" ]]; then
    if [[ "$mode" == soft ]]; then
      info "API keys not all readable yet (SQLite/config still initializing) — will retry"
      return 1
    fi
    [[ -z "$SONARR_API_KEY" ]] && fail "Could not read Sonarr API key (run flixbox init?)"
    [[ -z "$RADARR_API_KEY" ]] && fail "Could not read Radarr API key (run flixbox init?)"
    [[ -z "$PROWLARR_API_KEY" ]] && fail "Could not read Prowlarr API key (run flixbox init?)"
    [[ -z "$BAZARR_API_KEY" ]] && fail "Could not read Bazarr API key after first-start timeout"
    return 1
  fi

  info "Sonarr API key: ${SONARR_API_KEY:0:8}..."
  info "Radarr API key: ${RADARR_API_KEY:0:8}..."
  info "Prowlarr API key: ${PROWLARR_API_KEY:0:8}..."
  info "Bazarr API key: ${BAZARR_API_KEY:0:8}..."

  env_set_if_empty RADARR_API_KEY "$RADARR_API_KEY"
  env_set_if_empty SONARR_API_KEY "$SONARR_API_KEY"
  env_set_if_empty PROWLARR_API_KEY "$PROWLARR_API_KEY"
  env_set_if_empty BAZARR_API_KEY "$BAZARR_API_KEY"

  export QBIT_USERNAME="${QBITTORRENT_USERNAME:-admin}"
  export QBIT_PASSWORD="${QBITTORRENT_PASSWORD:-}"
  export QBIT_TEMP_PASSWORD=""
  QBIT_TEMP_PASSWORD=$(docker logs flixbox-qbittorrent 2>&1 \
    | grep -iE 'temporary password|password is' | tail -1 \
    | grep -oE '[^ ]+$' || true)
  export QBIT_TEMP_PASSWORD

  export QBIT_API_KEY
  QBIT_API_KEY=$(qbit_api_key_from_config flixbox-qbittorrent)
  if [[ -n "$QBIT_API_KEY" ]]; then
    info "qBittorrent API key: ${QBIT_API_KEY:0:8}..."
  fi
  export SONARR_API_KEY RADARR_API_KEY PROWLARR_API_KEY BAZARR_API_KEY
  return 0
}

configure_wait_for_stack_apis() {
  log "Verifying authenticated APIs..."
  configure_ensure_stack_apis_parallel || return 1
  echo ""
}

configure_preflight_pass() {
  local discover_mode="${1:-soft}"
  configure_wait_for_first_start || return 1
  configure_discover_api_keys "$discover_mode" || return 1
  configure_wait_for_stack_apis || return 1
  configure_mark_preflight_passed
  return 0
}

configure_dry_run_preflight() {
  log "DRY RUN — preflight checks (no HTTP waits, no .env writes)"
  dry "Wait for qBittorrent, *arr, Bazarr, Jellyfin HTTP (parallel warm-up)"
  dry "Discover API keys from container config"
  dry "Verify authenticated *arr/Bazarr APIs (parallel)"
}

configure_preflight() {
  configure_state_init
  configure_assert_tools
  configure_assert_core_stack
  configure_assert_env_writable
  configure_init_qbit_context

  if $DRY_RUN; then
    configure_dry_run_preflight
    return 0
  fi

  local timeout="${CONFIGURE_PREFLIGHT_TIMEOUT:-900}"
  local start=$SECONDS
  local deadline=$((SECONDS + timeout))
  local window="${WAIT_TIMEOUT:-180}"

  while (( SECONDS < deadline )); do
    export FAILED=0
    local remaining=$((deadline - SECONDS))
    if (( remaining <= window )); then
      export CONFIGURE_SOFT_WAIT=0
      configure_preflight_pass hard && return 0
    else
      export CONFIGURE_SOFT_WAIT=1
      configure_preflight_pass soft && return 0
    fi
    info "First-start still in progress ($((SECONDS - start))s / ${timeout}s budget) — retrying in 10s..."
    sleep 10
  done

  echo "" >&2
  echo "ERROR: configure timed out after ${timeout}s waiting for first-start." >&2
  echo "  Check: ./bin/flixbox status && ./bin/flixbox logs radarr sonarr prowlarr bazarr jellyfin" >&2
  echo "  Override budget: CONFIGURE_PREFLIGHT_TIMEOUT=1200 ./bin/flixbox configure" >&2
  exit 1
}
