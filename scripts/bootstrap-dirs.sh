#!/usr/bin/env bash
# Create Flixbox data/config directory trees (Phase 0b helper until bin/flixbox init exists).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "${ROOT_DIR}/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  # Prefer simple KEY=VAL lines; ignore comments/blank
  # shellcheck disable=SC1090
  source <(grep -E '^[A-Z_]+=.*' "${ROOT_DIR}/.env" | sed 's/\r$//')
  set +a
fi

DATA_DIR="${DATA_DIR:-/srv/flixbox/data}"
CONFIG_DIR="${CONFIG_DIR:-/srv/flixbox/config}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

echo "DATA_DIR=${DATA_DIR}"
echo "CONFIG_DIR=${CONFIG_DIR}"

mkdir -p \
  "${DATA_DIR}/torrents/incomplete" \
  "${DATA_DIR}/torrents/movies" \
  "${DATA_DIR}/torrents/tv" \
  "${DATA_DIR}/media/movies" \
  "${DATA_DIR}/media/tv" \
  "${CONFIG_DIR}/qbittorrent"

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
