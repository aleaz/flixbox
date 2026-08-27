#!/usr/bin/env bash
# Backup Flixbox config directory (SQLite-safe best-effort tar).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1090
  source <(grep -E '^[A-Z_][A-Z0-9_]*=' .env | sed 's/\r$//')
  set +a
fi

CONFIG_DIR="${CONFIG_DIR:-/srv/flixbox/config}"
DEST="${1:-${ROOT_DIR}/backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${DEST}/flixbox-config-${STAMP}.tar.gz"

mkdir -p "${DEST}"
tar -C "$(dirname "${CONFIG_DIR}")" -czf "${OUT}" "$(basename "${CONFIG_DIR}")"
echo "Wrote ${OUT}"
echo "Note: for live SQLite DBs, prefer stopping services or using app-native backup when possible."
