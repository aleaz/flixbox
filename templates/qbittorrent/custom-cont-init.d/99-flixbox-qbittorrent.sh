#!/usr/bin/with-contenv bash
# Flixbox qBittorrent bootstrap (linuxserver image).
#
# 1. WebUI: allow Docker host port maps (qBit 5.x + custom QBITTORRENT_PORT).
# 2. Paths: align with ADR 0001 (/data/torrents) instead of linuxserver /downloads defaults.
#
# Path policy (each start, before qbittorrent-nox):
#   - Set missing keys to Flixbox paths.
#   - Replace linuxserver legacy paths (/downloads/...).
#   - Leave custom paths under /data/ untouched (operator choice).
#   - FLIXBOX_QBIT_FORCE_PATHS=true → always rewrite to Flixbox paths.
#
# VPN port-forward: after first login, enable "Bypass authentication for clients on
# localhost" in the WebUI (separate from LocalHostAuth below).

set -euo pipefail

CONF="/config/qBittorrent/qBittorrent.conf"
SAVE_PATH="/data/torrents/"
INCOMPLETE_PATH="/data/torrents/incomplete/"

mkdir -p /config/qBittorrent
touch "${CONF}"

set_kv() {
  local key="$1"
  local value="$2"
  local tmp
  if grep -Fq "${key}=" "${CONF}"; then
    tmp="$(mktemp)"
    grep -Fv "${key}=" "${CONF}" > "${tmp}"
    printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
    mv "${tmp}" "${CONF}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${CONF}"
  fi
}

get_kv() {
  local key="$1"
  grep "^${key}=" "${CONF}" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

is_legacy_path() {
  case "$1" in
    "" | /downloads | /downloads/ | /downloads/incomplete | /downloads/incomplete/) return 0 ;;
    *) return 1 ;;
  esac
}

should_set_path() {
  local current="$1"
  if [[ "${FLIXBOX_QBIT_FORCE_PATHS:-false}" == "true" ]]; then
    return 0
  fi
  if is_legacy_path "${current}"; then
    return 0
  fi
  if [[ -z "${current}" ]]; then
    return 0
  fi
  return 1
}

ensure_path() {
  local key="$1"
  local want="$2"
  local current
  current="$(get_kv "${key}")"
  if should_set_path "${current}"; then
    set_kv "${key}" "${want}"
  fi
}

# --- WebUI (always enforce for Docker port maps) ---
set_kv 'WebUI\HostHeaderValidation' 'false'
set_kv 'WebUI\LocalHostAuth' 'false'

# --- Download paths (Flixbox / TRaSH contract) ---
ensure_path 'Downloads\SavePath' "${SAVE_PATH}"
ensure_path 'Downloads\TempPath' "${INCOMPLETE_PATH}"
ensure_path 'Session\DefaultSavePath' "${SAVE_PATH}"
ensure_path 'Session\TempPath' "${INCOMPLETE_PATH}"
