#!/usr/bin/env bash
# Shared Radarr/Sonarr wiring (root folders, qBit client, NFO metadata, custom formats).

# Build Radarr/Sonarr qBittorrent download-client JSON (password-safe).
build_qbit_download_client_json() {
  local qbit_host="$1" qbit_user="$2" qbit_pass="$3" qbit_api_key="$4"
  local cat_field="$5" category="$6" priority_recent="$7" priority_older="$8"
  local existing_id="${9:-}"
  HOST="$qbit_host" USER="$qbit_user" PASS="$qbit_pass" API_KEY="$qbit_api_key" \
  CAT_FIELD="$cat_field" CATEGORY="$category" PRIO_RECENT="$priority_recent" \
  PRIO_OLDER="$priority_older" EXISTING_ID="$existing_id" \
  flixbox_json qbit-download-client
}

# Ensure a Reject ISO-style custom format exists and is scored (idempotent).
ensure_custom_format() {
  local base="$1" auth="$2" name="$3" cf_name="$4" cf_score="$5" cf_specs="$6"
  local formats cf_id
  formats=$(api_get "${base}/api/v3/customformat" "$auth") || true
  CF_NAME="$cf_name" cf_id=$(json_query arr-cf-id-by-name "$formats" "$(json_params cf_name=CF_NAME)")
  if [[ -n "$cf_id" ]]; then
    skip "${name}: ${cf_name} custom format"
  else
    local cf_payload cf_result
    cf_payload="{\"name\":\"${cf_name}\",\"includeCustomFormatWhenRenaming\":false,\"specifications\":${cf_specs}}"
    cf_result=$(api_post "${base}/api/v3/customformat" "application/json" "$cf_payload" "$auth") || true
    cf_id=$(json_query print-field "$cf_result" '{"field":"id"}')
    if [[ -n "$cf_id" ]]; then
      ok "${name}: added ${cf_name} custom format"
    else
      fail "${name}: add ${cf_name} custom format"
      return
    fi
  fi
  local profiles profile_ids
  profiles=$(api_get "${base}/api/v3/qualityprofile" "$auth") || true
  profile_ids=$(json_query arr-profile-ids "$profiles" '{}')
  local pid profile updated_profile
  for pid in $profile_ids; do
    profile=$(api_get "${base}/api/v3/qualityprofile/${pid}" "$auth") || continue
    CF_ID="$cf_id" CF_SCORE="$cf_score" _cf_params="$(CF_ID="$cf_id" CF_SCORE="$cf_score" json_params cf_id=CF_ID,cf_score=CF_SCORE)"
    if json_query arr-cf-scored-in-profile "$profile" "$_cf_params" >/dev/null 2>&1; then
      continue
    fi
    CF_ID="$cf_id" CF_NAME="$cf_name" CF_SCORE="$cf_score" _cf_params="$(CF_ID="$cf_id" CF_NAME="$cf_name" CF_SCORE="$cf_score" json_params cf_id=CF_ID,cf_name=CF_NAME,cf_score=CF_SCORE)"
    updated_profile=$(json_query arr-cf-patch-profile "$profile" "$_cf_params")
    if api_put "${base}/api/v3/qualityprofile/${pid}" "application/json" "$updated_profile" "$auth" >/dev/null 2>&1; then
      ok "${name}: scored ${cf_name} at ${cf_score} in profile ${pid}"
    else
      fail "${name}: score ${cf_name} in profile ${pid}"
    fi
  done
}

# $1=name $2=port $3=api_key $4=root_path $5=category $6=qbit_host $7=qbit_api_key $8=qbit_user $9=qbit_pass
configure_arr_service() {
  local name="$1" port="$2" api_key="$3" root_path="$4" category="$5" qbit_host="$6"
  local qbit_api_key="${7:-}" qbit_user="${8:-}" qbit_pass="${9:-}"

  log "Configuring ${name}..."

  if [[ -z "$api_key" ]]; then
    fail "${name}: no API key, skipping"
    return
  fi

  local base="http://127.0.0.1:${port}"
  local auth="X-Api-Key: ${api_key}"

  if $DRY_RUN; then
    dry "Add root folder ${root_path}"
    dry "Add qBittorrent download client (${qbit_host}:8080, category ${category})"
    dry "Enable NFO metadata + Reject ISO custom format"
    return
  fi

  if ! configure_ensure_arr_api "$name" "$port" "$api_key" "v3"; then
    return
  fi

  local cat_field priority_recent priority_older
  if [[ "$category" == "tv" ]]; then
    cat_field="tvCategory"
    priority_recent="recentTvPriority"
    priority_older="olderTvPriority"
  else
    cat_field="movieCategory"
    priority_recent="recentMoviePriority"
    priority_older="olderMoviePriority"
  fi

  local roots
  roots=$(api_get "${base}/api/v3/rootfolder" "$auth") || true
  ROOT_PATH="$root_path"
  if json_query arr-root-folder-exists "$roots" "$(json_params root_path=ROOT_PATH)" >/dev/null 2>&1; then
    skip "${name}: root folder ${root_path}"
  else
    if api_post "${base}/api/v3/rootfolder" "application/json" "{\"path\":\"${root_path}\"}" "$auth" >/dev/null 2>&1; then
      ok "${name}: added root folder ${root_path}"
    else
      fail "${name}: add root folder ${root_path}"
    fi
  fi

  local clients existing_id
  clients=$(api_get "${base}/api/v3/downloadclient" "$auth") || true
  existing_id=$(json_query arr-qbit-client-id "$clients" '{}')

  if [[ -z "$qbit_api_key" && -z "$qbit_pass" ]]; then
    fail "${name}: add/update qBittorrent (need API key or QBITTORRENT_PASSWORD)"
  else
    local qbit_payload
    qbit_payload=$(build_qbit_download_client_json "$qbit_host" "$qbit_user" "$qbit_pass" \
      "$qbit_api_key" "$cat_field" "$category" "$priority_recent" "$priority_older")
    if [[ -n "$existing_id" ]]; then
      local existing_client force_client_sync=false key_drift=false stored_api_key=""
      [[ "${SYNC_QBIT_AUTH:-false}" == "true" ]] && force_client_sync=true
      existing_client=$(api_get "${base}/api/v3/downloadclient/${existing_id}" "$auth") || true
      # Accidental qBit API key regen: password auth can still make Test pass while apiKey is stale.
      if [[ -n "$existing_client" && -n "$qbit_api_key" ]]; then
        stored_api_key=$(json_query arr-qbit-client-api-key "$existing_client" '{}')
        if [[ -n "$stored_api_key" && "$stored_api_key" != "$qbit_api_key" ]]; then
          key_drift=true
        fi
      fi
      if ! $force_client_sync && ! $key_drift && [[ -n "$existing_client" ]] \
        && api_post "${base}/api/v3/downloadclient/test" "application/json" "$existing_client" "$auth" >/dev/null 2>&1; then
        skip "${name}: qBittorrent download client"
      else
        qbit_payload=$(build_qbit_download_client_json "$qbit_host" "$qbit_user" "$qbit_pass" \
          "$qbit_api_key" "$cat_field" "$category" "$priority_recent" "$priority_older" "$existing_id")
        if api_put "${base}/api/v3/downloadclient/${existing_id}" "application/json" "$qbit_payload" "$auth" >/dev/null 2>&1 \
          && api_post "${base}/api/v3/downloadclient/test" "application/json" "$qbit_payload" "$auth" >/dev/null 2>&1; then
          if $force_client_sync; then
            ok "${name}: synced qBittorrent download client from .env (--sync-qbit-auth)"
          elif $key_drift; then
            ok "${name}: refreshed qBittorrent API key on download client"
          else
            ok "${name}: updated qBittorrent download client (${qbit_host}:8080)"
          fi
        else
          fail "${name}: update qBittorrent download client (Test failed — check QBITTORRENT_PASSWORD / ban)"
        fi
      fi
    else
      if api_post "${base}/api/v3/downloadclient" "application/json" "$qbit_payload" "$auth" >/dev/null 2>&1; then
        ok "${name}: added qBittorrent download client (${qbit_host}:8080)"
      else
        fail "${name}: add qBittorrent download client"
      fi
    fi
  fi

  # NFO metadata (Kodi/XBMC) — helps Jellyfin
  local metadata meta_id meta_enabled
  metadata=$(api_get "${base}/api/v3/metadata" "$auth") || true
  meta_id=$(json_query arr-xbmc-meta-id "$metadata" '{}')
  if [[ -n "$meta_id" ]]; then
    meta_enabled=$(json_query arr-xbmc-enabled "$metadata" '{}')
    if [[ "$meta_enabled" == "true" ]]; then
      skip "${name}: NFO metadata"
    else
      local meta_fields meta_payload
      if [[ "$category" == "tv" ]]; then
        meta_fields='[{"name":"seriesMetadata","value":true},{"name":"seriesMetadataEpisodeGuide","value":true},{"name":"seriesMetadataUrl","value":false},{"name":"episodeMetadata","value":true},{"name":"seriesImages","value":false},{"name":"seasonImages","value":false},{"name":"episodeImages","value":false}]'
      else
        meta_fields='[{"name":"movieMetadata","value":true},{"name":"movieMetadataURL","value":false},{"name":"movieMetadataLanguage","value":1},{"name":"movieImages","value":false},{"name":"useMovieNfo","value":true}]'
      fi
      meta_payload="{\"enable\":true,\"name\":\"Kodi (XBMC) / Emby\",\"id\":${meta_id},\"fields\":${meta_fields},\"implementation\":\"XbmcMetadata\",\"configContract\":\"XbmcMetadataSettings\"}"
      if api_put "${base}/api/v3/metadata/${meta_id}" "application/json" "$meta_payload" "$auth" >/dev/null 2>&1; then
        ok "${name}: enabled NFO metadata"
      else
        fail "${name}: enable NFO metadata"
      fi
    fi
  fi

  ensure_custom_format "$base" "$auth" "$name" "Reject ISO" -10000 \
    '[{"name":"ISO","implementation":"ReleaseTitleSpecification","negate":false,"required":true,"fields":[{"name":"value","value":"\\.iso$"}]}]'
}
