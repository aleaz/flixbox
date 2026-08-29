#!/usr/bin/with-contenv bash
# Flixbox qBittorrent bootstrap (linuxserver image).
#
# Installed to ${CONFIG_DIR}/qbittorrent-cont-init/ and mounted at /custom-cont-init.d
# (linuxserver ignores the legacy path /config/custom-cont-init.d).
#
# 1. WebUI: allow Docker host port maps (qBit 5.x + custom QBITTORRENT_PORT).
# 2. WebUI: whitelist flixbox_net (172.30.42.0/24) so stack peers are not
#    banned after failed logins; auth is bypassed for that Docker subnet only.
#    Must match compose/network-base.yml (hardcoded — see that file’s “Why”).
# 3. Paths: align with ADR 0001 (/data/torrents) instead of linuxserver /downloads defaults.
#
# Path policy (each start, before qbittorrent-nox):
#   - Set missing keys to Flixbox paths.
#   - Replace linuxserver legacy paths (/downloads/...).
#   - Leave custom paths under /data/ untouched (operator choice).
#   - FLIXBOX_QBIT_FORCE_PATHS=true → always rewrite to Flixbox paths.
#
# VPN port-forward: after first login, enable "Bypass authentication for clients on
# localhost" in the WebUI (separate from LocalHostAuth below).
#
# Do not publish qBit WebUI to the public internet — Docker-gateway clients on
# flixbox_net may skip WebUI password (auth subnet whitelist).

set -euo pipefail

CONF="/config/qBittorrent/qBittorrent.conf"
SAVE_PATH="/data/torrents/"
INCOMPLETE_PATH="/data/torrents/incomplete/"

mkdir -p /config/qBittorrent
touch "${CONF}"

# qBittorrent uses INI sections; keys appended at EOF land under the wrong group
# (e.g. [RSS]) and are ignored — WebUI keeps linuxserver /downloads/ defaults.
set_section_kv() {
  local section="$1"
  local key="$2"
  local value="$3"
  local header="[${section}]"
  local entry="${key}=${value}"
  local tmp

  tmp="$(mktemp)"
  grep -Fv "${key}=" "${CONF}" > "${tmp}" || true
  mv "${tmp}" "${CONF}"

  if grep -Fxq "${header}" "${CONF}"; then
    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "${line}" ]]; do
      printf '%s\n' "${line}"
      if [[ "${line}" == "${header}" ]]; then
        printf '%s\n' "${entry}"
      fi
    done < "${CONF}" > "${tmp}"
    mv "${tmp}" "${CONF}"
  else
    printf '\n%s\n%s\n' "${header}" "${entry}" >> "${CONF}"
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
    set_section_kv 'BitTorrent' "${key}" "${want}"
  fi
}

# --- WebUI (always enforce for Docker port maps) ---
set_section_kv 'Preferences' 'WebUI\HostHeaderValidation' 'false'
set_section_kv 'Preferences' 'WebUI\LocalHostAuth' 'false'
# flixbox_net fixed subnet — MUST match compose/network-base.yml (not env-driven).
# AuthSubnetWhitelist = bypass WebUI password for clients in CIDR (Docker peers).
# Do not widen to home LAN ranges; keep in sync with network-base or peers get banned.
set_section_kv 'Preferences' 'WebUI\AuthSubnetWhitelistEnabled' 'true'
set_section_kv 'Preferences' 'WebUI\AuthSubnetWhitelist' '172.30.42.0/24'
# Softer lockout if something outside the whitelist still fails auth (first-run)
set_section_kv 'Preferences' 'WebUI\MaxAuthenticationFailCount' '20'
set_section_kv 'Preferences' 'WebUI\BanDuration' '300'

# --- Download paths (Flixbox / TRaSH contract) ---
ensure_path 'Downloads\SavePath' "${SAVE_PATH}"
ensure_path 'Downloads\TempPath' "${INCOMPLETE_PATH}"
ensure_path 'Session\DefaultSavePath' "${SAVE_PATH}"
ensure_path 'Session\TempPath' "${INCOMPLETE_PATH}"
