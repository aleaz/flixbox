#!/usr/bin/env bash
# Backup Flixbox config directory (SQLite-safe best-effort tar).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/paths.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/env-file.sh"

if [[ -f .env ]]; then
  eval "$(flixbox_env_file_exports "${ROOT_DIR}/.env")"
fi

CONFIG_DIR="${CONFIG_DIR:-$(flixbox_default_config_dir)}"
DEST="${1:-${ROOT_DIR}/backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${DEST}/flixbox-config-${STAMP}.tar.gz"

mkdir -p "${DEST}"
tar -C "$(dirname "${CONFIG_DIR}")" -czf "${OUT}" "$(basename "${CONFIG_DIR}")"
echo "Wrote ${OUT}"
echo "Note: for live SQLite DBs, prefer stopping services or using app-native backup when possible."
