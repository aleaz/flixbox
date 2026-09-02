#!/usr/bin/env bash
# Ephemeral-stack configure smoke (D5 / C-70).
# Brings up MVP core services in direct mode, runs configure once, tears down.
#
# Usage:
#   CI_CONFIGURE_SMOKE=1 ./scripts/ci-smoke-configure.sh
#   ./scripts/ci-smoke-configure.sh   # when env set or FLIXBOX_CI_CONFIGURE_SMOKE=1
#
# Requires: docker, docker compose, network (image pulls).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE_ROOT="${FLIXBOX_CI_CONFIGURE_ROOT:-/tmp/flixbox-ci-configure}"
SMOKE_DATA="${SMOKE_ROOT}/data"
SMOKE_CONFIG="${SMOKE_ROOT}/config"
SMOKE_WORKTREE="$(mktemp -d /tmp/flixbox-configure-smoke-wt.XXXXXX)"

pass() { printf 'OK   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

if [[ "${CI_CONFIGURE_SMOKE:-0}" != 1 && "${FLIXBOX_CI_CONFIGURE_SMOKE:-0}" != 1 ]]; then
  echo "Skip configure stack smoke (set CI_CONFIGURE_SMOKE=1 to run)."
  exit 0
fi

command -v docker >/dev/null || fail "docker required"
docker compose version >/dev/null 2>&1 || fail "docker compose required"

cleanup() {
  if [[ -d "${SMOKE_WORKTREE}" ]]; then
    (cd "${SMOKE_WORKTREE}" && docker compose --project-directory . down -v --remove-orphans 2>/dev/null) || true
    rm -rf "${SMOKE_WORKTREE}"
  fi
}
trap cleanup EXIT INT TERM

rsync -a --exclude='.git' --exclude='.env' "${ROOT_DIR}/" "${SMOKE_WORKTREE}/"
rm -rf "${SMOKE_ROOT}"
mkdir -p "${SMOKE_DATA}" "${SMOKE_CONFIG}"

(
  cd "${SMOKE_WORKTREE}"
  cp -f .env.example .env
  # shellcheck disable=SC1091
  source scripts/lib/env-file.sh
  flixbox_env_file_set .env DATA_DIR "${SMOKE_DATA}"
  flixbox_env_file_set .env CONFIG_DIR "${SMOKE_CONFIG}"
  flixbox_env_file_set .env FLIXBOX_MODE direct
  flixbox_env_file_set .env VPN_ENABLED false
  flixbox_env_file_set .env FLIXBOX_ACCESS_PROFILE trusted

  ./bin/flixbox init --non-interactive

  log() { echo "[configure-smoke] $*"; }
  log "Starting core stack (direct mode)..."
  docker compose --project-directory . up -d \
    qbittorrent radarr sonarr prowlarr bazarr jellyfin

  log "Waiting for containers..."
  deadline=$((SECONDS + 600))
  core=(flixbox-qbittorrent flixbox-radarr flixbox-sonarr flixbox-prowlarr flixbox-bazarr flixbox-jellyfin)
  while (( SECONDS < deadline )); do
    ready=true
    for c in "${core[@]}"; do
      docker ps --format '{{.Names}}' | grep -qx "$c" || ready=false
    done
    $ready && break
    sleep 5
  done
  $ready || fail "core containers not up within 600s"

  log "Running configure (extended preflight budget)..."
  set +e
  out="$(CONFIGURE_PREFLIGHT_TIMEOUT=1200 WAIT_TIMEOUT=300 ./bin/flixbox configure 2>&1)"
  rc=$?
  set -e
  [[ "$rc" -eq 0 ]] || fail "configure failed (rc=${rc}): ${out:0:500}"

  echo "$out" | grep -qE 'Done: [0-9]+ configured,' || \
    fail "configure missing Done summary"
  pass "configure on ephemeral stack (rc=0)"

  log "Idempotent re-run..."
  set +e
  out2="$(CONFIGURE_PREFLIGHT_TIMEOUT=600 ./bin/flixbox configure 2>&1)"
  rc2=$?
  set -e
  [[ "$rc2" -eq 0 ]] || fail "configure idempotent re-run failed (rc=${rc2})"
  pass "configure idempotent re-run on ephemeral stack"
)

printf '\nConfigure stack smoke passed.\n'
