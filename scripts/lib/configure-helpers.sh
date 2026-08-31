#!/usr/bin/env bash
#
# Shared helpers for scripts/configure-apps.sh (sourced, not executed).
# Requires python3 for JSON parsing.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-file.sh"

# shellcheck disable=SC2034
CONFIGURED=0
SKIPPED=0
FAILED=0
ENV_DIRTY=false

json_extract() {
  local json="$1" expr="$2"
  echo "$json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
${expr}
" 2>/dev/null
}

log()  { echo "[configure] $*"; }
ok()   { echo "  ✓ $*"; CONFIGURED=$((CONFIGURED + 1)); }
skip() { echo "  - $* (already configured)"; SKIPPED=$((SKIPPED + 1)); }
fail() { echo "  ✗ $*"; FAILED=$((FAILED + 1)); }
info() { echo "  $*"; }
dry()  { echo "  [dry-run] Would: $*"; }

_api_request() {
  local method="$1" url="$2"
  shift 2
  local args=(-s -w '\n%{http_code}' -o -)
  if [[ "$method" != "GET" ]]; then
    local content_type="$1" data="$2"
    shift 2
    args+=(-X "$method" -H "Content-Type: ${content_type}")
    if [[ -n "$data" ]]; then
      args+=(--data "$data")
    fi
  fi
  local h
  for h in "$@"; do args+=(-H "$h"); done
  local response code body
  response=$(curl "${args[@]}" "$url")
  code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  if [[ "$code" =~ ^2 ]]; then
    echo "$body"
    return 0
  fi
  [[ "$method" != "GET" ]] && echo "$body"
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    echo "  [verbose] ${method} ${url} → HTTP ${code}" >&2
    echo "  [verbose] Response: ${body}" >&2
  fi
  return 1
}

api_get()  { _api_request GET  "$@"; }
api_post() { _api_request POST "$@"; }
api_put()  { _api_request PUT  "$@"; }

wait_for_service() {
  local name="$1" url="$2"
  local timeout="${WAIT_TIMEOUT:-180}"
  local start=$SECONDS
  local deadline=$((SECONDS + timeout))
  local last_heartbeat=$SECONDS
  local code=""
  while (( SECONDS < deadline )); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --connect-timeout 2 "$url" 2>/dev/null || true)
    if [[ "$code" =~ ^[23] ]] || [[ "$code" == "401" ]]; then
      return 0
    fi
    if (( SECONDS - last_heartbeat >= 10 )); then
      info "Still waiting for ${name} ($((SECONDS - start))s/${timeout}s, last HTTP: ${code:-none})..."
      last_heartbeat=$SECONDS
    fi
    sleep 1
  done
  fail "${name} not responding after ${timeout}s at ${url} (last HTTP: ${code:-none})"
  return 1
}

# Wait until an authenticated *arr/Prowlarr API responds (DB + config ready).
wait_for_arr_api() {
  local name="$1" port="$2" api_key="$3" api_version="${4:-v3}"
  local timeout="${WAIT_TIMEOUT:-180}"
  local start=$SECONDS deadline=$((SECONDS + timeout)) last_heartbeat=$SECONDS code=""
  local base="http://127.0.0.1:${port}"
  local status_path="/api/${api_version}/system/status"
  [[ "$api_version" == "v1" ]] && status_path="/api/v1/system/status"
  while (( SECONDS < deadline )); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --connect-timeout 2 \
      -H "X-Api-Key: ${api_key}" "${base}${status_path}" 2>/dev/null || true)
    if [[ "$code" == "200" ]]; then
      return 0
    fi
    if (( SECONDS - last_heartbeat >= 10 )); then
      info "Still waiting for ${name} API ($((SECONDS - start))s/${timeout}s, last HTTP: ${code:-none})..."
      last_heartbeat=$SECONDS
    fi
    sleep 2
  done
  fail "${name} API not ready after ${timeout}s (last HTTP: ${code:-none})"
  return 1
}

wait_for_bazarr_api() {
  local port="$1" api_key="$2"
  local timeout="${WAIT_TIMEOUT:-180}"
  local start=$SECONDS deadline=$((SECONDS + timeout)) last_heartbeat=$SECONDS code=""
  local base="http://127.0.0.1:${port}"
  while (( SECONDS < deadline )); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --connect-timeout 2 \
      -H "X-API-KEY: ${api_key}" "${base}/api/system/status" 2>/dev/null || true)
    if [[ "$code" == "200" ]]; then
      return 0
    fi
    if (( SECONDS - last_heartbeat >= 10 )); then
      info "Still waiting for Bazarr API ($((SECONDS - start))s/${timeout}s, last HTTP: ${code:-none})..."
      last_heartbeat=$SECONDS
    fi
    sleep 2
  done
  fail "Bazarr API not ready after ${timeout}s (last HTTP: ${code:-none})"
  return 1
}

# Write KEY=value into ROOT .env (always overwrite). Sets ENV_DIRTY=true on write.
env_set_key() {
  local key="$1" value="$2" env_file="${ROOT_DIR}/.env"
  [[ -f "$env_file" ]] || return 0
  [[ -n "$value" ]] || return 0
  if $DRY_RUN; then
    dry "Set ${key} in .env"
    return 0
  fi
  flixbox_env_file_set "$env_file" "$key" "$value"
  ENV_DIRTY=true
}

# Prefer live config.xml key; sync .env when wiped config was recreated on first up.
resolve_arr_api_key() {
  local env_name="$1" container="$2" env_value="$3"
  local config_key app_label="${container#flixbox-}"
  config_key=$(api_key_from_config_xml "$container")
  if [[ -z "$config_key" ]]; then
    echo "$env_value"
    return
  fi
  if [[ -n "$env_value" && "$env_value" != "$config_key" ]]; then
    info "${app_label}: ${env_name} in .env out of sync with container — updating .env"
    env_set_key "$env_name" "$config_key"
  elif [[ -z "$env_value" ]]; then
    env_set_key "$env_name" "$config_key"
  fi
  echo "$config_key"
}

prowlarr_ensure_tag_id() {
  local base="$1" auth_header="$2" label="$3"
  local tags tag_id result
  tags=$(api_get "${base}/api/v1/tag" "$auth_header") || return 1
  tag_id=$(json_extract "$tags" "
ids = [t['id'] for t in data if t.get('label', '').lower() == '''${label}'''.lower()]
print(ids[0] if ids else '')")
  if [[ -n "$tag_id" ]]; then
    echo "$tag_id"
    return 0
  fi
  result=$(api_post "${base}/api/v1/tag" "application/json" "{\"label\":\"${label}\"}" "$auth_header") || return 1
  tag_id=$(json_extract "$result" "print(data.get('id', ''))")
  if [[ -n "$tag_id" ]]; then
    echo "$tag_id"
    return 0
  fi
  return 1
}

jellyfin_startup_wizard_pending() {
  local base="$1" pub
  pub=$(curl -s --max-time 5 "${base}/System/Info/Public" 2>/dev/null || true)
  echo "$pub" | grep -qiE '"StartupWizardCompleted"[[:space:]]*:[[:space:]]*false'
}

seerr_login_json() {
  local bootstrap="$1" admin_user="$2" admin_pass="$3"
  SEERR_BOOTSTRAP="$([[ "$bootstrap" == "true" ]] && echo 1 || echo 0)" \
  SEERR_ADMIN_USER="$admin_user" SEERR_ADMIN_PASS="$admin_pass" python3 <<'PY'
import json, os
payload = {
    "username": os.environ["SEERR_ADMIN_USER"],
    "password": os.environ["SEERR_ADMIN_PASS"],
}
if os.environ.get("SEERR_BOOTSTRAP") == "1":
    payload.update({
        "hostname": "jellyfin",
        "port": 8096,
        "useSsl": False,
        "urlBase": "",
        "email": f"{os.environ['SEERR_ADMIN_USER']}@localhost",
        "serverType": 2,
    })
print(json.dumps(payload))
PY
}

qbit_auth() {
  local url="$1" username="$2" password="$3" cookie_file="$4"
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local api_url="${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}"
  local cookie_path="${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}"
  local response http_code body verify_code

  # Prefer in-container API (port 8080). Host-published QBITTORRENT_PORT sends a
  # Host header qBit 5.x rejects remapped ports unless web_ui_host_header_validation_enabled=false.
  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    docker exec "$container" rm -f "$cookie_path" 2>/dev/null || true
    response=$(docker exec "$container" curl -s -m 20 -w '\n%{http_code}' \
      -c "$cookie_path" \
      --data-urlencode "username=${username}" \
      --data-urlencode "password=${password}" \
      "${api_url}/api/v2/auth/login")
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | head -1)
    case "$http_code" in
      200) [[ "$body" == "Ok." ]] || return 1 ;;
      204) ;;
      *) return 1 ;;
    esac
    verify_code=$(docker exec "$container" curl -s -m 20 -o /dev/null -w '%{http_code}' \
      -b "$cookie_path" "${api_url}/api/v2/app/version")
    [[ "$verify_code" == "200" ]]
    return
  fi

  response=$(curl -s -m 20 -w '\n%{http_code}' \
    -c "$cookie_file" \
    -H 'Host: localhost:8080' \
    --data-urlencode "username=${username}" \
    --data-urlencode "password=${password}" \
    "${url}/api/v2/auth/login")
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -1)
  case "$http_code" in
    200) [[ "$body" == "Ok." ]] || return 1 ;;
    204) ;;
    *) return 1 ;;
  esac
  verify_code=$(curl -s -m 20 -o /dev/null -w '%{http_code}' \
    -b "$cookie_file" -H 'Host: localhost:8080' "${url}/api/v2/app/version")
  [[ "$verify_code" == "200" ]]
}

qbit_curl_authed() {
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local api_url="${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}"
  local cookie_path="${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}"
  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    docker exec "$container" curl -s -b "$cookie_path" "$@"
    return
  fi
  curl -s -H 'Host: localhost:8080' "$@"
}

qbit_curl_authed_code() {
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local api_url="${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}"
  local cookie_path="${QBIT_DOCKER_COOKIE:-/tmp/flixbox-configure-cookie.txt}"
  if docker ps --format '{{.Names}}' | grep -qx "$container"; then
    docker exec "$container" curl -s -o /dev/null -w '%{http_code}' -b "$cookie_path" "$@"
    return
  fi
  curl -s -o /dev/null -w '%{http_code}' -H 'Host: localhost:8080' "$@"
}

wait_for_qbittorrent() {
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local api_url="${QBIT_INTERNAL_API_URL:-http://127.0.0.1:8080}"
  local timeout="${WAIT_TIMEOUT:-180}"
  local start=$SECONDS deadline=$((SECONDS + timeout)) last_heartbeat=$SECONDS code=""
  while (( SECONDS < deadline )); do
    code=$(docker exec "$container" curl -s -o /dev/null -w '%{http_code}' --max-time 3 \
      "${api_url}/" 2>/dev/null || true)
    if [[ "$code" == "200" ]]; then
      return 0
    fi
    if (( SECONDS - last_heartbeat >= 10 )); then
      info "Still waiting for qBittorrent ($((SECONDS - start))s/${timeout}s, last HTTP: ${code:-none})..."
      last_heartbeat=$SECONDS
    fi
    sleep 1
  done
  fail "qBittorrent not responding after ${timeout}s (last HTTP: ${code:-none})"
  return 1
}

api_key_from_config_xml() {
  local container="$1"
  docker exec "$container" cat /config/config.xml 2>/dev/null \
    | sed -n 's:.*<ApiKey>\([^<]*\)</ApiKey>.*:\1:p' | head -1
}

qbit_api_key_from_config() {
  local container="$1"
  docker exec "$container" grep -m1 '^WebUI\\API\\APIKey=' /config/qBittorrent/qBittorrent.conf 2>/dev/null \
    | cut -d= -f2- | tr -d '\r' || true
}

bazarr_settings_post() {
  local base="$1" auth="$2"
  shift 2
  local args=(-s -w '\n%{http_code}' -o - -X POST -H "$auth")
  local kv
  for kv in "$@"; do args+=(--data-urlencode "$kv"); done
  local response code body
  response=$(curl "${args[@]}" "${base}/api/system/settings")
  code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')
  if [[ "$code" =~ ^2 ]]; then
    return 0
  fi
  if [[ "${VERBOSE:-false}" == "true" ]]; then
    echo "  [verbose] POST ${base}/api/system/settings → HTTP ${code}" >&2
    echo "  [verbose] Response: ${body}" >&2
  fi
  return 1
}

# Write KEY=value into ROOT .env when missing or empty. Sets ENV_DIRTY=true on write.
env_set_if_empty() {
  local key="$1" value="$2" env_file="${ROOT_DIR}/.env"
  local before after
  [[ -f "$env_file" ]] || return 0
  [[ -n "$value" ]] || return 0
  before="$(flixbox_env_file_get "$env_file" "$key")"
  [[ -n "$before" ]] && return 0
  if $DRY_RUN; then
    dry "Write ${key} to .env (was empty)"
    return 0
  fi
  flixbox_env_file_set_if_empty "$env_file" "$key" "$value"
  after="$(flixbox_env_file_get "$env_file" "$key")"
  if [[ -n "$after" ]]; then
    ENV_DIRTY=true
    info "Wrote ${key} to .env (was empty)"
  fi
}

# Replace REPLACE_* placeholders in recyclarr.yml only (never overwrite real keys).
patch_recyclarr_keys() {
  local file="${CONFIG_DIR}/recyclarr/recyclarr.yml"
  [[ -f "$file" ]] || return 0
  local changed=false
  if [[ -n "${RADARR_API_KEY:-}" ]] && grep -q 'REPLACE_RADARR_API_KEY' "$file" 2>/dev/null; then
    if $DRY_RUN; then
      dry "Patch Recyclarr Radarr API key placeholder"
    else
      if [[ "$(uname -s)" == Darwin ]]; then
        sed -i '' "s/REPLACE_RADARR_API_KEY/${RADARR_API_KEY}/" "$file"
      else
        sed -i "s/REPLACE_RADARR_API_KEY/${RADARR_API_KEY}/" "$file"
      fi
      changed=true
    fi
  fi
  if [[ -n "${SONARR_API_KEY:-}" ]] && grep -q 'REPLACE_SONARR_API_KEY' "$file" 2>/dev/null; then
    if $DRY_RUN; then
      dry "Patch Recyclarr Sonarr API key placeholder"
    else
      if [[ "$(uname -s)" == Darwin ]]; then
        sed -i '' "s/REPLACE_SONARR_API_KEY/${SONARR_API_KEY}/" "$file"
      else
        sed -i "s/REPLACE_SONARR_API_KEY/${SONARR_API_KEY}/" "$file"
      fi
      changed=true
    fi
  fi
  if $changed; then
    ok "Recyclarr: patched API key placeholders"
  elif grep -qE 'REPLACE_(RADARR|SONARR)_API_KEY' "$file" 2>/dev/null; then
    info "Recyclarr: placeholders remain (keys not available yet)"
  else
    skip "Recyclarr: API keys"
  fi
}

# Ensure a Reject ISO-style custom format exists and is scored (idempotent).
ensure_custom_format() {
  local base="$1" auth="$2" name="$3" cf_name="$4" cf_score="$5" cf_specs="$6"
  local formats cf_id
  formats=$(api_get "${base}/api/v3/customformat" "$auth") || true
  cf_id=$(json_extract "$formats" "
ids = [c['id'] for c in data if c.get('name') == '''${cf_name}''']
print(ids[0] if ids else '')")
  if [[ -n "$cf_id" ]]; then
    skip "${name}: ${cf_name} custom format"
  else
    local cf_payload cf_result
    cf_payload="{\"name\":\"${cf_name}\",\"includeCustomFormatWhenRenaming\":false,\"specifications\":${cf_specs}}"
    cf_result=$(api_post "${base}/api/v3/customformat" "application/json" "$cf_payload" "$auth") || true
    cf_id=$(json_extract "$cf_result" "print(data.get('id', ''))")
    if [[ -n "$cf_id" ]]; then
      ok "${name}: added ${cf_name} custom format"
    else
      fail "${name}: add ${cf_name} custom format"
      return
    fi
  fi
  local profiles profile_ids
  profiles=$(api_get "${base}/api/v3/qualityprofile" "$auth") || true
  profile_ids=$(json_extract "$profiles" "
for p in data:
    print(p['id'])")
  local pid profile updated_profile
  for pid in $profile_ids; do
    profile=$(api_get "${base}/api/v3/qualityprofile/${pid}" "$auth") || continue
    if json_extract "$profile" "
items = data.get('formatItems', [])
match = [i for i in items if i.get('format') == ${cf_id}]
sys.exit(0 if match and match[0].get('score') == ${cf_score} else 1)"; then
      continue
    fi
    updated_profile=$(json_extract "$profile" "
items = [i for i in data.get('formatItems', []) if i.get('format') != ${cf_id}]
items.insert(0, {'format': ${cf_id}, 'name': '''${cf_name}''', 'score': ${cf_score}})
data['formatItems'] = items
print(json.dumps(data))")
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

  if ! wait_for_arr_api "$name" "$port" "$api_key" "v3"; then
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

  if $DRY_RUN; then
    dry "Add root folder ${root_path}"
    dry "Add qBittorrent download client (${qbit_host}:8080, category ${category})"
    dry "Enable NFO metadata + Reject ISO custom format"
    return
  fi

  local roots
  roots=$(api_get "${base}/api/v3/rootfolder" "$auth") || true
  if json_extract "$roots" "sys.exit(0 if any(r.get('path') == '${root_path}' for r in data) else 1)"; then
    skip "${name}: root folder ${root_path}"
  else
    if api_post "${base}/api/v3/rootfolder" "application/json" "{\"path\":\"${root_path}\"}" "$auth" >/dev/null 2>&1; then
      ok "${name}: added root folder ${root_path}"
    else
      fail "${name}: add root folder ${root_path}"
    fi
  fi

  local clients
  clients=$(api_get "${base}/api/v3/downloadclient" "$auth") || true
  if json_extract "$clients" "sys.exit(0 if any(c.get('name','').lower() == 'qbittorrent' for c in data) else 1)"; then
    skip "${name}: qBittorrent download client"
  elif [[ -z "$qbit_api_key" && -z "$qbit_pass" ]]; then
    fail "${name}: add qBittorrent (need API key or QBITTORRENT_PASSWORD)"
  else
    local qbit_payload
    qbit_payload=$(cat <<QBIT_JSON
{
  "enable": true,
  "protocol": "torrent",
  "priority": 1,
  "name": "qBittorrent",
  "implementation": "QBittorrent",
  "configContract": "QBittorrentSettings",
  "fields": [
    {"name": "host", "value": "${qbit_host}"},
    {"name": "port", "value": 8080},
    {"name": "username", "value": "${qbit_user}"},
    {"name": "password", "value": "${qbit_pass}"},
    {"name": "apiKey", "value": "${qbit_api_key}"},
    {"name": "${cat_field}", "value": "${category}"},
    {"name": "${priority_recent}", "value": 0},
    {"name": "${priority_older}", "value": 0},
    {"name": "initialState", "value": 0},
    {"name": "sequentialOrder", "value": false},
    {"name": "firstAndLast", "value": false}
  ]
}
QBIT_JSON
)
    if api_post "${base}/api/v3/downloadclient" "application/json" "$qbit_payload" "$auth" >/dev/null 2>&1; then
      ok "${name}: added qBittorrent download client (${qbit_host}:8080)"
    else
      fail "${name}: add qBittorrent download client"
    fi
  fi

  # NFO metadata (Kodi/XBMC) — helps Jellyfin
  local metadata meta_id meta_enabled
  metadata=$(api_get "${base}/api/v3/metadata" "$auth") || true
  meta_id=$(json_extract "$metadata" "
xbmc = [m for m in data if m.get('implementation') == 'XbmcMetadata']
print(xbmc[0]['id'] if xbmc else '')")
  if [[ -n "$meta_id" ]]; then
    meta_enabled=$(json_extract "$metadata" "
xbmc = [m for m in data if m.get('implementation') == 'XbmcMetadata']
print(str(xbmc[0].get('enable', False)).lower() if xbmc else 'false')")
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
