#!/usr/bin/env bash
#
# Unified .env loading for bin/flixbox and scripts/.
# Caller must set ROOT_DIR to the repo root before sourcing.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/paths.sh"

# Load core Flixbox variables from .env (safe export; no secret interpolation).
# Optional arg: path to env file (default: ${ROOT_DIR}/.env).
flixbox_load_env() {
  local env_file="${1:-${ROOT_DIR}/.env}"
  if [[ -f "${env_file}" ]]; then
    eval "$(flixbox_env_file_exports "${env_file}")"
  fi
  DATA_DIR="${DATA_DIR:-$(flixbox_default_data_dir)}"
  CONFIG_DIR="${CONFIG_DIR:-$(flixbox_default_config_dir)}"
  PUID="${PUID:-1000}"
  PGID="${PGID:-1000}"
  FLIXBOX_MODE="${FLIXBOX_MODE:-direct}"
  VPN_ENABLED="${VPN_ENABLED:-false}"
}

# Published service ports used by configure (host → container publish maps).
flixbox_apply_configure_port_defaults() {
  QBITTORRENT_PORT="${QBITTORRENT_PORT:-8080}"
  RADARR_PORT="${RADARR_PORT:-7878}"
  SONARR_PORT="${SONARR_PORT:-8989}"
  PROWLARR_PORT="${PROWLARR_PORT:-9696}"
  BAZARR_PORT="${BAZARR_PORT:-6767}"
  JELLYFIN_PORT="${JELLYFIN_PORT:-8096}"
  SEERR_PORT="${SEERR_PORT:-5055}"
}

# configure-apps.sh entry: core env + port defaults.
flixbox_load_configure_env() {
  flixbox_load_env "${1:-}"
  flixbox_apply_configure_port_defaults
}

flixbox_container_running() {
  docker ps --format '{{.Names}}' | grep -qx "$1"
}
