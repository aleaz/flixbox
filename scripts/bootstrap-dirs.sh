#!/usr/bin/env bash
# Create Flixbox data/config directory trees.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/paths.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/flixbox-env.sh"

flixbox_load_env

echo "DATA_DIR=${DATA_DIR}"
echo "CONFIG_DIR=${CONFIG_DIR}"

validate_flixbox_paths "${DATA_DIR}" "${CONFIG_DIR}" || exit 1

mkdir -p \
  "${DATA_DIR}/torrents/incomplete" \
  "${DATA_DIR}/torrents/movies" \
  "${DATA_DIR}/torrents/tv" \
  "${DATA_DIR}/media/movies" \
  "${DATA_DIR}/media/tv" \
  "${CONFIG_DIR}/qbittorrent" \
  "${CONFIG_DIR}/qbittorrent-cont-init" \
  "${CONFIG_DIR}/qbittorrent-custom-services" \
  "${CONFIG_DIR}/gluetun" \
  "${CONFIG_DIR}/prowlarr" \
  "${CONFIG_DIR}/radarr" \
  "${CONFIG_DIR}/sonarr" \
  "${CONFIG_DIR}/bazarr" \
  "${CONFIG_DIR}/byparr" \
  "${CONFIG_DIR}/jellyfin" \
  "${CONFIG_DIR}/seerr" \
  "${CONFIG_DIR}/homepage" \
  "${CONFIG_DIR}/maintainerr" \
  "${CONFIG_DIR}/recyclarr" \
  "${CONFIG_DIR}/unpackerr" \
  "${CONFIG_DIR}/caddy/data" \
  "${CONFIG_DIR}/caddy/config" \
  "${CONFIG_DIR}/plex"

chmod g+s \
  "${DATA_DIR}" \
  "${DATA_DIR}/torrents" \
  "${DATA_DIR}/torrents/incomplete" \
  "${DATA_DIR}/torrents/movies" \
  "${DATA_DIR}/torrents/tv" \
  "${DATA_DIR}/media" \
  "${DATA_DIR}/media/movies" \
  "${DATA_DIR}/media/tv" || true

if chown -R "${PUID}:${PGID}" "${DATA_DIR}" "${CONFIG_DIR}" 2>/dev/null; then
  echo "Ownership set to ${PUID}:${PGID}"
else
  echo "Warning: could not chown (need permissions). Create dirs as your user or re-run with sudo." >&2
fi

echo "Bootstrap directories ready."
