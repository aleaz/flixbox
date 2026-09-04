#!/usr/bin/env bash
configure_qbittorrent() {
  log "Configuring qBittorrent..."

  if $DRY_RUN; then
    dry "Auth via in-container :8080 (env password or temp); set stable WebUI password if needed"
    dry "Apply WebUI host-header fix for remapped QBITTORRENT_PORT"
    dry "Create categories tv/movies under /data/torrents/{tv,movies}"
    dry "Prefs: auto TMM, UPnP off, encryption, limits; tun0 bind if VPN"
    if $SYNC_QBIT_AUTH; then
      dry "Force-push .env password to qBit + *arr download clients + Decluttarr"
    fi
    return 0
  fi

  if ! configure_ensure_qbittorrent_ready; then
    return
  fi

  local authed=false
  if [[ -n "$QBIT_PASSWORD" ]] && qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_PASSWORD" "$QBIT_COOKIE"; then
    authed=true
  elif [[ -n "$QBIT_TEMP_PASSWORD" ]] && qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_TEMP_PASSWORD" "$QBIT_COOKIE"; then
    authed=true
    if [[ -n "$QBIT_PASSWORD" && "$QBIT_PASSWORD" != "$QBIT_TEMP_PASSWORD" ]]; then
      local http_code
      http_code=$(qbit_set_webui_password "$QBIT_PASSWORD")
      if [[ "$http_code" == "200" ]]; then
        ok "qBittorrent: WebUI password set from .env"
        docker exec "${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}" rm -f "${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}" 2>/dev/null || true
        local attempt reauthed=false
        for attempt in 1 2 3; do
          if qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_PASSWORD" "$QBIT_COOKIE"; then
            reauthed=true
            break
          fi
          [[ "$attempt" -lt 3 ]] && sleep 2
        done
        if ! $reauthed; then
          fail "qBittorrent: re-auth after password change failed"
          return
        fi
      else
        fail "qBittorrent: set WebUI password (HTTP ${http_code})"
        return
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
    sync_pw_code=$(qbit_set_webui_password "$QBIT_PASSWORD")
    if [[ "$sync_pw_code" == "200" ]]; then
      ok "qBittorrent: WebUI password synced from .env (--sync-qbit-auth)"
      docker exec "${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}" rm -f "${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}" 2>/dev/null || true
      if ! qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$QBIT_PASSWORD" "$QBIT_COOKIE"; then
        fail "qBittorrent: re-auth after --sync-qbit-auth failed"
        return
      fi
      export ENV_DIRTY=true
    else
      fail "qBittorrent: sync password from .env (HTTP ${sync_pw_code})"
      return
    fi
  fi

  # cont-init WebUI keys can be overwritten when qBit first starts — apply via API when needed.
  local current_prefs webui_code
  current_prefs=$(qbit_curl_authed "${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}/api/v2/app/preferences" 2>/dev/null || true)
  if qbit_webui_security_prefs_ok "$current_prefs"; then
    skip "qBittorrent: WebUI host-header + Docker subnet whitelist"
  else
    local webui_json webui_code
    webui_json=$(qbit_webui_security_prefs_json)
    webui_code=$(qbit_curl_authed_code -X POST \
      --data-urlencode "json=${webui_json}" \
      "${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}/api/v2/app/setPreferences")
    if [[ "$webui_code" == "200" ]]; then
      ok "qBittorrent: WebUI host-header + Docker subnet whitelist"
    else
      fail "qBittorrent: WebUI settings (HTTP ${webui_code})"
    fi
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

  local prefs_ok=false
  if [[ -n "$current_prefs" ]]; then
    if [[ "${FLIXBOX_MODE}" == "vpn" ]]; then
      if json_query qbit-prefs-vpn-ok "$current_prefs" >/dev/null 2>&1; then
        prefs_ok=true
      fi
    else
      if json_query qbit-prefs-direct-ok "$current_prefs" >/dev/null 2>&1; then
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

  # API key may appear in qBittorrent.conf or WebUI preferences after auth/password setup.
  QBIT_API_KEY=$(qbit_api_key_from_config "${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}")
  if [[ -n "$QBIT_API_KEY" ]]; then
    info "qBittorrent API key: ${QBIT_API_KEY:0:8}..."
  fi

  rm -f "$QBIT_COOKIE"
  docker exec "${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}" rm -f "${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}" 2>/dev/null || true
}
