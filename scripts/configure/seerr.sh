#!/usr/bin/env bash
configure_seerr() {
  log "Configuring Seerr..."

  if ! flixbox_container_running flixbox-seerr; then
    info "Seerr: container not running — skipping (optional service)"
    return
  fi

  if $DRY_RUN; then
    dry "Seerr Jellyfin auth + Radarr/Sonarr services + initialize"
    return
  fi

  local base="http://127.0.0.1:${SEERR_PORT}"
  if ! configure_ensure_http "Seerr" "${base}/api/v1/status"; then
    return
  fi

  local admin_user="${FLIXBOX_ADMIN_USER:-admin}"
  local admin_pass="${FLIXBOX_ADMIN_PASSWORD:-}"

  if [[ -z "$admin_pass" ]]; then
    info "Seerr: skip (need FLIXBOX_ADMIN_PASSWORD for Jellyfin login)"
    return
  fi

  local public init_flag
  public=$(curl -s "${base}/api/v1/settings/public" 2>/dev/null || true)
  init_flag=$(json_query seerr-initialized "$public" || echo false)

  # Login / create admin via Jellyfin
  local cookie seerr_login_resp seerr_arr_resp
  cookie=$(configure_tmpfile)
  seerr_login_resp=$(configure_tmpfile)
  seerr_arr_resp=$(configure_tmpfile)
  local login_code login_body
  if [[ "$init_flag" == "true" ]]; then
    login_body=$(seerr_login_json false "$admin_user" "$admin_pass")
  else
    login_body=$(seerr_login_json true "$admin_user" "$admin_pass")
  fi
  login_code=$(curl -s -o "$seerr_login_resp" -w '%{http_code}' -c "$cookie" \
    -X POST "${base}/api/v1/auth/jellyfin" \
    -H 'Content-Type: application/json' \
    -d "$login_body")

  if [[ ! "$login_code" =~ ^2 ]]; then
    local login_msg
    login_msg=$(json_query seerr-error-message "$(cat "$seerr_login_resp" 2>/dev/null || echo '{}')" 2>/dev/null || true)
    if [[ -n "$login_msg" ]]; then
      fail "Seerr: Jellyfin auth failed (HTTP ${login_code}: ${login_msg})"
    else
      fail "Seerr: Jellyfin auth failed (HTTP ${login_code}) — check FLIXBOX_ADMIN_USER/PASSWORD"
    fi
    return
  fi
  info "Seerr: Jellyfin session ready"

  # Radarr / Sonarr services
  add_seerr_arr() {
    local kind="$1" host="$2" probe_port="$3" container_port="$4" api_key="$5" root="$6" is_default="${7:-false}"
    local list profiles profile_id profile_name lang_profile_id payload http_code existing_id stored_key
    list=$(curl -s -b "$cookie" "${base}/api/v1/settings/${kind}" 2>/dev/null || true)
    existing_id=$(json_query arr-first-list-field "$list" "$(FIELD=id json_params field=FIELD)" 2>/dev/null || true)
    if [[ -n "$existing_id" ]]; then
      stored_key=$(json_query arr-first-list-field "$list" "$(FIELD=apiKey json_params field=FIELD)" 2>/dev/null || true)
      if [[ "$stored_key" == "$api_key" ]]; then
        skip "Seerr: ${kind} service"
        return
      fi
      payload=$(echo "$list" | API_KEY="$api_key" flixbox_json seerr-patch-arr-api-key)
      http_code=$(curl -s -o "$seerr_arr_resp" -w '%{http_code}' -b "$cookie" -X PUT \
        "${base}/api/v1/settings/${kind}/${existing_id}" \
        -H 'Content-Type: application/json' \
        -d "$payload")
      if [[ "$http_code" =~ ^2 ]]; then
        ok "Seerr: refreshed ${kind} API key"
      else
        fail "Seerr: update ${kind} API key (HTTP ${http_code}) — set it in Seerr Settings if needed"
      fi
      return
    fi
    local arr_base arr_auth
    arr_base="http://127.0.0.1:${probe_port}"
    arr_auth="X-Api-Key: ${api_key}"
    profiles=$(api_get "${arr_base}/api/v3/qualityprofile" "$arr_auth") || true
    profile_id=$(json_query arr-first-list-field "$profiles" "$(FIELD=id json_params field=FIELD)" || true)
    profile_name=$(json_query arr-first-list-field "$profiles" "$(FIELD=name json_params field=FIELD)" || true)
    if [[ -z "$profile_id" ]]; then
      fail "Seerr: add ${kind} (no quality profile from ${kind})"
      return
    fi
    if [[ "$kind" == "radarr" ]]; then
      payload=$(HOST="$host" PORT="$container_port" API_KEY="$api_key" PROFILE_ID="$profile_id" \
        PROFILE_NAME="$profile_name" ROOT="$root" IS_DEFAULT="$is_default" \
        flixbox_json seerr-radarr-service)
    else
      local lang_profiles
      # Sonarr v4 removed /api/v3/languageprofile (merged into quality profiles).
      # The endpoint returns 404 on v4 (handled by || true); defaulting to 1 is correct for v4.
      lang_profiles=$(api_get "${arr_base}/api/v3/languageprofile" "$arr_auth") || true
      lang_profile_id=$(json_query arr-first-lang-profile-id "$lang_profiles" || echo 1)
      payload=$(HOST="$host" PORT="$container_port" API_KEY="$api_key" PROFILE_ID="$profile_id" \
        PROFILE_NAME="$profile_name" ROOT="$root" LANG_PROFILE_ID="$lang_profile_id" \
        IS_DEFAULT="$is_default" flixbox_json seerr-sonarr-service)
    fi
    http_code=$(curl -s -o "$seerr_arr_resp" -w '%{http_code}' -b "$cookie" -X POST \
      "${base}/api/v1/settings/${kind}" \
      -H 'Content-Type: application/json' \
      -d "$payload")
    if [[ "$http_code" =~ ^2 ]]; then
      ok "Seerr: added ${kind}"
    else
      if [[ "${VERBOSE:-false}" == "true" ]]; then
        info "Seerr ${kind} response (HTTP ${http_code}): $(cat "$seerr_arr_resp" 2>/dev/null | configure_redact || true)"
      fi
      fail "Seerr: add ${kind} (HTTP ${http_code})"
    fi
  }

  add_seerr_arr radarr radarr "$RADARR_PORT" 7878 "$RADARR_API_KEY" "/data/media/movies" true
  add_seerr_arr sonarr sonarr "$SONARR_PORT" 8989 "$SONARR_API_KEY" "/data/media/tv" false

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
}
