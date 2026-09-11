#!/usr/bin/env bash
#
# Access profile helpers (ADR 0015). Sourced by bin/flixbox — not executed directly.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-file.sh"

# Valid: trusted | shared
flixbox_access_profile() {
  echo "${FLIXBOX_ACCESS_PROFILE:-trusted}"
}

flixbox_validate_access_profile() {
  case "$(flixbox_access_profile)" in
    trusted|shared) return 0 ;;
    *)
      echo "Invalid FLIXBOX_ACCESS_PROFILE=$(flixbox_access_profile) (use trusted or shared)" >&2
      return 1
      ;;
  esac
}

# Write derived auth + publish-bind env keys into .env from FLIXBOX_ACCESS_PROFILE.
flixbox_sync_access_profile_env() {
  local env_file="$1" profile
  profile="$(flixbox_access_profile)"
  [[ -f "$env_file" ]] || return 0

  case "$profile" in
    trusted)
      flixbox_env_file_set "$env_file" FLIXBOX_ARR_AUTH_METHOD External
      flixbox_env_file_set "$env_file" FLIXBOX_ARR_AUTH_REQUIRED DisabledForLocalAddresses
      flixbox_env_file_set "$env_file" FLIXBOX_ADMIN_BIND_IP 0.0.0.0
      ;;
    shared)
      flixbox_env_file_set "$env_file" FLIXBOX_ARR_AUTH_METHOD Forms
      flixbox_env_file_set "$env_file" FLIXBOX_ARR_AUTH_REQUIRED Enabled
      flixbox_env_file_set "$env_file" FLIXBOX_ADMIN_BIND_IP 127.0.0.1
      ;;
  esac
}

# Print a drift message when derived profile keys disagree with the active profile.
# Empty keys count as drift (Compose would otherwise fall back to trusted defaults).
# Empty string when coherent. Caller should sync (preferred) or die.
flixbox_access_profile_drift_message() {
  local profile expected_method expected_required expected_bind
  profile="$(flixbox_access_profile)"
  case "$profile" in
    trusted)
      expected_method=External
      expected_required=DisabledForLocalAddresses
      expected_bind=0.0.0.0
      ;;
    shared)
      expected_method=Forms
      expected_required=Enabled
      expected_bind=127.0.0.1
      ;;
  esac
  local parts=()
  if [[ "${FLIXBOX_ARR_AUTH_METHOD:-}" != "$expected_method" ]]; then
    parts+=("FLIXBOX_ARR_AUTH_METHOD=${FLIXBOX_ARR_AUTH_METHOD:-<empty>} (expected ${expected_method})")
  fi
  if [[ "${FLIXBOX_ARR_AUTH_REQUIRED:-}" != "$expected_required" ]]; then
    parts+=("FLIXBOX_ARR_AUTH_REQUIRED=${FLIXBOX_ARR_AUTH_REQUIRED:-<empty>} (expected ${expected_required})")
  fi
  if [[ "${FLIXBOX_ADMIN_BIND_IP:-}" != "$expected_bind" ]]; then
    parts+=("FLIXBOX_ADMIN_BIND_IP=${FLIXBOX_ADMIN_BIND_IP:-<empty>} (expected ${expected_bind})")
  fi
  [[ ${#parts[@]} -eq 0 ]] && return 0
  echo "Access profile ${profile} out of sync: ${parts[*]}"
}

# Compose service names whose host publish or *arr auth env depend on the access profile.
# VPN: WebUI publish is on gluetun; qBit container must follow gluetun recreate.
flixbox_access_profile_admin_services() {
  local mode="${FLIXBOX_MODE:-direct}"
  if [[ "$mode" == "vpn" ]]; then
    printf '%s\n' gluetun qbittorrent prowlarr byparr radarr sonarr bazarr maintainerr
  else
    printf '%s\n' qbittorrent prowlarr byparr radarr sonarr bazarr maintainerr
  fi
}

# Strip scheme/path/port → host only. Keeps IPv6 (multiple colons) intact.
flixbox_normalize_public_host() {
  local host="${1:-}"
  host="${host#"${host%%[![:space:]]*}"}"
  host="${host%"${host##*[![:space:]]}"}"
  [[ -n "$host" ]] || return 0
  host="${host#http://}"
  host="${host#https://}"
  host="${host%%/*}"
  # Drop trailing :port for hostname/IPv4 only (IPv6 has multiple colons).
  if [[ "$host" != *:*:* && "$host" == *:* ]]; then
    host="${host%:*}"
  fi
  printf '%s' "$host"
}

# When FLIXBOX_PUBLIC_HOST is set: ensure HOMEPAGE_ALLOWED_HOSTS includes host:port,
# and set JELLYFIN_PUBLISHED_URL if empty. Idempotent. Sets:
#   FLIXBOX_HOMEPAGE_ENV_CHANGED=1 / FLIXBOX_JELLYFIN_URL_ENV_CHANGED=1 when .env written.
flixbox_sync_public_host_env() {
  local env_file="${1:-}"
  local host port entry current jf_port jf_url new_allow
  FLIXBOX_HOMEPAGE_ENV_CHANGED=0
  FLIXBOX_JELLYFIN_URL_ENV_CHANGED=0
  export FLIXBOX_HOMEPAGE_ENV_CHANGED FLIXBOX_JELLYFIN_URL_ENV_CHANGED
  [[ -n "$env_file" && -f "$env_file" ]] || return 0

  host="$(flixbox_normalize_public_host "$(flixbox_env_file_get "$env_file" FLIXBOX_PUBLIC_HOST)")"
  if [[ -z "$host" ]]; then
    host="$(flixbox_normalize_public_host "${FLIXBOX_PUBLIC_HOST:-}")"
  fi
  [[ -n "$host" ]] || return 0

  # Persist normalized host if .env had scheme/port noise
  if [[ "$(flixbox_env_file_get "$env_file" FLIXBOX_PUBLIC_HOST)" != "$host" ]]; then
    flixbox_env_file_set "$env_file" FLIXBOX_PUBLIC_HOST "$host"
  fi
  export FLIXBOX_PUBLIC_HOST="$host"

  port="$(flixbox_env_file_get "$env_file" HOMEPAGE_PORT)"
  port="${port:-${HOMEPAGE_PORT:-3000}}"
  entry="${host}:${port}"
  current="$(flixbox_env_file_get "$env_file" HOMEPAGE_ALLOWED_HOSTS)"
  if [[ -z "$current" ]]; then
    current="localhost:3000,127.0.0.1:3000"
  fi
  # Match entry as a comma-separated token (ignore spaces)
  if ! printf '%s' ",${current}," | tr -d '[:space:]' | grep -Fq ",${entry},"; then
    new_allow="${current},${entry}"
    flixbox_env_file_set "$env_file" HOMEPAGE_ALLOWED_HOSTS "$new_allow"
    export HOMEPAGE_ALLOWED_HOSTS="$new_allow"
    FLIXBOX_HOMEPAGE_ENV_CHANGED=1
    export FLIXBOX_HOMEPAGE_ENV_CHANGED
  else
    export HOMEPAGE_ALLOWED_HOSTS="$current"
  fi

  jf_url="$(flixbox_env_file_get "$env_file" JELLYFIN_PUBLISHED_URL)"
  if [[ -z "$jf_url" ]]; then
    jf_port="$(flixbox_env_file_get "$env_file" JELLYFIN_PORT)"
    jf_port="${jf_port:-${JELLYFIN_PORT:-8096}}"
    flixbox_env_file_set_if_empty "$env_file" JELLYFIN_PUBLISHED_URL "http://${host}:${jf_port}"
    if [[ -n "$(flixbox_env_file_get "$env_file" JELLYFIN_PUBLISHED_URL)" ]]; then
      export JELLYFIN_PUBLISHED_URL="http://${host}:${jf_port}"
      FLIXBOX_JELLYFIN_URL_ENV_CHANGED=1
      export FLIXBOX_JELLYFIN_URL_ENV_CHANGED
    fi
  fi
}
