#!/usr/bin/env bash
# Backup Flixbox config directory (SQLite-safe best-effort tar).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/paths.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/flixbox-env.sh"

flixbox_load_env

STOP_STACK=false
DEST="${ROOT_DIR}/backups"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stop|-s)
      STOP_STACK=true
      shift
      ;;
    -h|--help|help)
      cat <<EOF
Usage: backup.sh [--stop] [DEST_DIR]

Options:
  --stop, -s    Temporarily stop containers to ensure clean SQLite WAL consolidation.
  DEST_DIR      Target directory (default: ${ROOT_DIR}/backups).

EOF
      exit 0
      ;;
    *)
      DEST="$1"
      shift
      ;;
  esac
done

running_containers=()
if command -v docker >/dev/null 2>&1; then
  mapfile -t running_containers < <(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^flixbox-' || true)
fi

if $STOP_STACK; then
  if [[ ${#running_containers[@]} -gt 0 ]]; then
    echo "Stopping Flixbox services for consistent SQLite backup..."
    docker compose --project-directory "${ROOT_DIR}" stop
  fi
elif [[ ${#running_containers[@]} -gt 0 ]]; then
  echo "Warning: Flixbox stack is running. Live backup may capture uncommitted SQLite WAL transactions." >&2
  echo "Tip: Run with --stop to temporarily stop services during backup for guaranteed SQLite consistency." >&2
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${DEST}/flixbox-config-${STAMP}.tar.gz"

mkdir -p "${DEST}"
tar -C "$(dirname "${CONFIG_DIR}")" -czf "${OUT}" "$(basename "${CONFIG_DIR}")"
echo "Wrote ${OUT}"

if $STOP_STACK && [[ ${#running_containers[@]} -gt 0 ]]; then
  echo "Restarting Flixbox services..."
  docker compose --project-directory "${ROOT_DIR}" start
fi
