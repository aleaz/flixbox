#!/usr/bin/env bash
#
# Shared helpers for scripts/configure-apps.sh (sourced, not executed).
# Requires python3 for JSON parsing.

# shellcheck disable=SC2034
CONFIGURED=0
SKIPPED=0
FAILED=0

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
  if [[ "$method" == "GET" ]]; then
    return 1
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

qbit_auth() {
  local url="$1" username="$2" password="$3" cookie_file="$4"
  local response http_code body
  response=$(curl -s -m 20 -w '\n%{http_code}' \
    -c "$cookie_file" \
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
  local verify_code
  verify_code=$(curl -s -m 20 -o /dev/null -w '%{http_code}' \
    -b "$cookie_file" "${url}/api/v2/app/version")
  [[ "$verify_code" == "200" ]]
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

# $1=name $2=port $3=api_key $4=root_path $5=category $6=qbit_host $7=qbit_api_key
configure_arr_service() {
  local name="$1" port="$2" api_key="$3" root_path="$4" category="$5" qbit_host="$6" qbit_api_key="$7"

  log "Configuring ${name}..."

  if [[ -z "$api_key" ]]; then
    fail "${name}: no API key, skipping"
    return
  fi

  local base="http://127.0.0.1:${port}"
  local auth="X-Api-Key: ${api_key}"

  if ! wait_for_service "$name" "${base}/api/v3/system/status"; then
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
  elif [[ -z "$qbit_api_key" ]]; then
    fail "${name}: add qBittorrent (no qBit API key — set password in WebUI first, or re-run after login)"
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
    {"name": "username", "value": ""},
    {"name": "password", "value": ""},
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
}
