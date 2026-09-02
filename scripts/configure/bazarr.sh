#!/usr/bin/env bash
configure_bazarr() {
  log "Configuring Bazarr..."

  if [[ -z "$BAZARR_API_KEY" ]]; then
    fail "Bazarr: no API key, skipping"
    return
  fi

  local base="http://127.0.0.1:${BAZARR_PORT}"
  local auth="X-API-KEY: ${BAZARR_API_KEY}"

  if $DRY_RUN; then
    dry "Connect Bazarr to Sonarr/Radarr; enable ffsubsync; ES/EN language defaults"
    return
  fi

  if ! configure_ensure_bazarr_api "$BAZARR_PORT" "$BAZARR_API_KEY"; then
    return
  fi

  local settings
  settings=$(api_get "${base}/api/system/settings" "$auth") || true
  if [[ -z "$settings" ]]; then
    fail "Bazarr: could not fetch settings"
    return
  fi

  local needs_restart=false
  local conn_state _bazarr_params
  _bazarr_params="$(SONARR_API_KEY="$SONARR_API_KEY" RADARR_API_KEY="$RADARR_API_KEY" \
    SONARR_PORT="$SONARR_PORT" RADARR_PORT="$RADARR_PORT" \
    json_params sonarr_key=SONARR_API_KEY,radarr_key=RADARR_API_KEY,sonarr_port=SONARR_PORT,radarr_port=RADARR_PORT)"
  conn_state=$(json_query bazarr-conn-diff "$settings" "$_bazarr_params")

  if [[ -z "$conn_state" ]]; then
    fail "Bazarr: could not compare Sonarr/Radarr connections"
  elif [[ "$conn_state" == "MATCH" ]]; then
    skip "Bazarr: Sonarr/Radarr connections"
  else
    local conn_keys=(
      "settings-general-use_sonarr=true"
      "settings-sonarr-ip=sonarr"
      "settings-sonarr-port=${SONARR_PORT}"
      "settings-sonarr-base_url="
      "settings-sonarr-ssl=false"
      "settings-sonarr-apikey=${SONARR_API_KEY}"
      "settings-general-use_radarr=true"
      "settings-radarr-ip=radarr"
      "settings-radarr-port=${RADARR_PORT}"
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
  subsync_state=$(json_query bazarr-subsync-diff "$settings" '{}')
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
    if ! wait_for_bazarr_api "$BAZARR_PORT" "$BAZARR_API_KEY"; then
      warn "Bazarr: API not ready after restart — re-run ./bin/flixbox configure if wiring fails"
    fi
  fi
}
