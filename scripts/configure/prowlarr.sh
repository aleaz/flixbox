#!/usr/bin/env bash
configure_prowlarr() {
  log "Configuring Prowlarr..."

  if [[ -z "$PROWLARR_API_KEY" ]]; then
    fail "Prowlarr: no API key, skipping"
    return
  fi

  if $DRY_RUN; then
    dry "Add Byparr indexer proxy (http://byparr:8191) when Byparr is running"
    dry "Add Sonarr and Radarr application sync"
    return
  fi

  local base="http://127.0.0.1:${PROWLARR_PORT}"
  local auth="X-Api-Key: ${PROWLARR_API_KEY}"

  if ! configure_ensure_arr_api "Prowlarr" "$PROWLARR_PORT" "$PROWLARR_API_KEY" "v1"; then
    return
  fi

  local cf_tag_id
  cf_tag_id=$(prowlarr_ensure_tag_id "$base" "$auth" "cf") || true
  if [[ -z "$cf_tag_id" ]]; then
    fail "Prowlarr: create or resolve tag 'cf'"
    return
  fi

  local proxies
  proxies=$(api_get "${base}/api/v1/indexerProxy" "$auth") || true
  if json_query prowlarr-has-cf-proxy "$proxies" '{}' >/dev/null 2>&1; then
    skip "Prowlarr: Byparr/FlareSolverr proxy"
  elif ! flixbox_container_running flixbox-byparr; then
    info "Prowlarr: Byparr not running — skipping CF proxy (ensure Byparr is up with the full stack, then re-run configure, or add the proxy manually)"
    skip "Prowlarr: Byparr/FlareSolverr proxy"
  else
    local proxy_payload
    proxy_payload=$(TAG_ID="$cf_tag_id" flixbox_json prowlarr-byparr-proxy)
    if api_post "${base}/api/v1/indexerProxy" "application/json" "$proxy_payload" "$auth" >/dev/null 2>&1; then
      ok "Prowlarr: added Byparr proxy (tag: cf)"
    else
      fail "Prowlarr: add Byparr proxy"
    fi
  fi

  local apps arr_name arr_probe_port arr_container_port arr_key arr_categories name_lower app_payload existing_app_id existing_app stored_key
  apps=$(api_get "${base}/api/v1/applications" "$auth") || true

  for arr_name in Sonarr Radarr; do
    if [[ "$arr_name" == "Sonarr" ]]; then
      arr_probe_port="$SONARR_PORT"
      arr_container_port=8989
      arr_key="$SONARR_API_KEY"
      arr_categories="[5000, 5010, 5020, 5030, 5040, 5045, 5050, 5060, 5070, 5080]"
    else
      arr_probe_port="$RADARR_PORT"
      arr_container_port=7878
      arr_key="$RADARR_API_KEY"
      arr_categories="[2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060, 2070, 2080]"
    fi
    name_lower=$(echo "$arr_name" | tr '[:upper:]' '[:lower:]')
    existing_app_id=$(json_query prowlarr-app-id-by-name "$apps" "$(NAME_LOWER="$name_lower" json_params name_lower=NAME_LOWER)")
    if [[ -n "$existing_app_id" ]]; then
      if [[ -z "$arr_key" ]]; then
        skip "Prowlarr: ${arr_name} application"
        continue
      fi
      existing_app=$(api_get "${base}/api/v1/applications/${existing_app_id}" "$auth") || true
      stored_key=$(json_query prowlarr-app-api-key "$existing_app" '{}')
      if prowlarr_app_api_key_in_sync "$stored_key" "$arr_key" "$arr_probe_port" "v3"; then
        skip "Prowlarr: ${arr_name} application"
      else
        app_payload=$(echo "$existing_app" | API_KEY="$arr_key" flixbox_json prowlarr-patch-api-key)
        if api_put "${base}/api/v1/applications/${existing_app_id}" "application/json" "$app_payload" "$auth" >/dev/null 2>&1; then
          ok "Prowlarr: refreshed ${arr_name} API key"
        else
          fail "Prowlarr: update ${arr_name} application API key"
        fi
      fi
    elif [[ -z "$arr_key" ]]; then
      fail "Prowlarr: add ${arr_name} (no API key)"
    else
      app_payload=$(ARR_NAME="$arr_name" PORT="$arr_container_port" API_KEY="$arr_key" \
        CATEGORIES="$arr_categories" TAG_ID="$cf_tag_id" flixbox_json prowlarr-arr-app)
      if api_post "${base}/api/v1/applications" "application/json" "$app_payload" "$auth" >/dev/null 2>&1; then
        ok "Prowlarr: added ${arr_name} application sync"
      else
        fail "Prowlarr: add ${arr_name} application"
      fi
    fi
  done
}
