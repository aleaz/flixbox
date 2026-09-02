#!/usr/bin/env bash
configure_jellyfin() {
  log "Configuring Jellyfin..."

  if ! flixbox_container_running flixbox-jellyfin; then
    fail "Jellyfin: container not running"
    return
  fi

  if $DRY_RUN; then
    dry "Complete Jellyfin startup if needed; add movie/TV libraries; create API key"
    return
  fi

  local base="http://127.0.0.1:${JELLYFIN_PORT}"
  if ! configure_ensure_http "Jellyfin" "${base}/System/Info/Public"; then
    return
  fi

  local admin_user="${FLIXBOX_ADMIN_USER:-admin}"
  local admin_pass="${FLIXBOX_ADMIN_PASSWORD:-}"

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
    local startup_payload
    startup_payload=$(NAME="$admin_user" PASSWORD="$admin_pass" flixbox_json jellyfin-startup-user)
    user_code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "${base}/Startup/User" \
      -H 'Content-Type: application/json' \
      -d "$startup_payload")
    if [[ "$user_code" =~ ^2 ]]; then
      ok "Jellyfin: startup user ${admin_user} configured"
    else
      fail "Jellyfin: startup user setup failed (HTTP ${user_code})"
      return
    fi
    # Seerr bootstrap requires Jellyfin admin; ensure flag on first user (Jellyfin 10.11 quirk).
    local jf_auth_json jf_token jf_user_id jf_is_admin
    local jf_auth_body
    jf_auth_body=$(USERNAME="$admin_user" PASSWORD="$admin_pass" flixbox_json jellyfin-auth)
    jf_auth_json=$(curl -s -X POST "${base}/Users/AuthenticateByName" \
      -H 'Content-Type: application/json' \
      -H 'X-Emby-Authorization: MediaBrowser Client="Flixbox", Device="configure", DeviceId="flixbox-configure", Version="1.0.0"' \
      -d "$jf_auth_body" 2>/dev/null || true)
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

  local auth_body auth_json token
  auth_body=$(USERNAME="$admin_user" PASSWORD="$admin_pass" flixbox_json jellyfin-auth)
  auth_json=$(curl -s -X POST "${base}/Users/AuthenticateByName" \
    -H 'Content-Type: application/json' \
    -H 'X-Emby-Authorization: MediaBrowser Client="Flixbox", Device="configure", DeviceId="flixbox-configure", Version="1.0.0"' \
    -d "$auth_body" 2>/dev/null || true)
  token=$(json_extract "$auth_json" "print(data.get('AccessToken',''))" || true)
  if [[ -z "$token" ]]; then
    fail "Jellyfin: login failed (check FLIXBOX_ADMIN_USER/PASSWORD)"
    return
  fi

  local libs
  libs=$(curl -s "${base}/Library/VirtualFolders" -H "X-Emby-Token: ${token}" 2>/dev/null || true)

  ensure_jf_library() {
    local lib_name="$1" collection_type="$2" path="$3"
    LIB_NAME="$lib_name" LIB_PATH="$path"
    if json_query jellyfin-library-exists "$libs" "$(json_params lib_name=LIB_NAME,path=LIB_PATH)" >/dev/null 2>&1; then
      skip "Jellyfin: library ${lib_name}"
      return
    fi
    local code lib_body lib_q
    lib_body=$(PATH="$path" flixbox_json jellyfin-library-options)
    lib_q=$(VALUE="$lib_name" flixbox_json jellyfin-url-quote)
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
      "${base}/Library/VirtualFolders?name=${lib_q}&collectionType=${collection_type}&refreshLibrary=true" \
      -H "X-Emby-Token: ${token}" \
      -H 'Content-Type: application/json' \
      -d "$lib_body")
    if [[ "$code" =~ ^2 ]]; then
      ok "Jellyfin: added library ${lib_name} → ${path}"
    else
      # Alternate body shape
      code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
        "${base}/Library/VirtualFolders?name=${lib_q}&collectionType=${collection_type}&paths=${path}&refreshLibrary=true" \
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
