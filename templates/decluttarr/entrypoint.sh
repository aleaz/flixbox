#!/bin/sh
# Flixbox Decluttarr entrypoint — idle until qBit WebUI credentials exist.
#
# Mounted from ${CONFIG_DIR}/decluttarr-entrypoint.sh (copied by flixbox init).
# Reads QBITTORRENT_* from the container environment at runtime (never bake
# secrets into Compose `command:` — Compose would interpolate ${VAR} at create).
#
# See ADR 0008.

set -eu

if [ -z "${QBITTORRENT_PASSWORD:-}" ] || [ -z "${QBITTORRENT_USERNAME:-}" ]; then
  echo "flixbox: Decluttarr idle — set QBITTORRENT_USERNAME and QBITTORRENT_PASSWORD in .env after qBit WebUI login, then: docker compose up -d --force-recreate decluttarr"
  exec sleep infinity
fi

cd /app
exec python main.py
