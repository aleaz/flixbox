#!/usr/bin/env bash
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
