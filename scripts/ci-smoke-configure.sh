#!/usr/bin/env bash
# Ephemeral-stack configure smoke (D5 / C-70 / C-73).
# Brings up MVP core in direct mode (random free QBITTORRENT_PORT),
# runs configure twice (idempotency), tears down.
#
# Modes:
#   CI_CONFIGURE_SMOKE=1           — full stack (main push / workflow_dispatch)
#   CI_CONFIGURE_SMOKE_PR=1        — PR subset (qBit + *arr + Prowlarr + Bazarr + Jellyfin)
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

if [[ "${CI_CONFIGURE_SMOKE:-0}" != 1 && "${FLIXBOX_CI_CONFIGURE_SMOKE:-0}" != 1 && "${CI_CONFIGURE_SMOKE_PR:-0}" != 1 ]]; then
  echo "Skip configure stack smoke (set CI_CONFIGURE_SMOKE=1 or CI_CONFIGURE_SMOKE_PR=1 to run)."
  exit 0
fi

SMOKE_PR=0
[[ "${CI_CONFIGURE_SMOKE_PR:-0}" == 1 ]] && SMOKE_PR=1

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
  SMOKE_QBIT_PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')"
  flixbox_env_file_set .env QBITTORRENT_PORT "${SMOKE_QBIT_PORT}"

  ./bin/flixbox init --non-interactive

  log() { echo "[configure-smoke] $*"; }

  # GitHub Actions anonymous pulls hit Docker Hub rate limits; retry those only.
  compose_up_with_retry() {
    local attempt max=5 delay=30 out rc
    for attempt in $(seq 1 "$max"); do
      set +e
      out="$(docker compose --project-directory . up -d "$@" 2>&1)"
      rc=$?
      set -e
      printf '%s\n' "$out"
      [[ "$rc" -eq 0 ]] && return 0
      if [[ "$attempt" -lt "$max" ]] && grep -qiE 'toomanyrequests|too many requests|rate.?limit|429' <<<"$out"; then
        log "compose up hit registry rate limit (attempt ${attempt}/${max}) — retry in ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))
        continue
      fi
      return "$rc"
    done
    return 1
  }

  if [[ "$SMOKE_PR" -eq 1 ]]; then
    log "Starting PR subset (direct mode, QBITTORRENT_PORT=${SMOKE_QBIT_PORT})..."
    compose_up_with_retry qbittorrent radarr sonarr prowlarr bazarr jellyfin
    core=(
      flixbox-qbittorrent flixbox-radarr flixbox-sonarr flixbox-prowlarr flixbox-bazarr flixbox-jellyfin
    )
    preflight_timeout=600
    wait_timeout=180
  else
    log "Starting core stack (direct mode, QBITTORRENT_PORT=${SMOKE_QBIT_PORT}, Seerr + Byparr)..."
    compose_up_with_retry qbittorrent radarr sonarr prowlarr bazarr jellyfin seerr byparr
    core=(
      flixbox-qbittorrent flixbox-radarr flixbox-sonarr flixbox-prowlarr
      flixbox-bazarr flixbox-jellyfin flixbox-seerr flixbox-byparr
    )
    preflight_timeout=1200
    wait_timeout=300
  fi

  log "Waiting for containers..."
  deadline=$((SECONDS + 600))
  while (( SECONDS < deadline )); do
    ready=true
    for c in "${core[@]}"; do
      docker ps --format '{{.Names}}' | grep -qx "$c" || ready=false
    done
    $ready && break
    sleep 5
  done
  $ready || fail "core containers not up within 600s"

  dump_health() {
    echo "[configure-smoke] Health dump:" >&2
    for c in "${core[@]}"; do
      status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$c" 2>/dev/null || echo missing)
      running=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo missing)
      printf '  %s: state=%s health=%s\n' "$c" "$running" "$status" >&2
      if [[ "$status" != "healthy" && "$status" != "none" && "$status" != "missing" ]]; then
        docker inspect -f '{{range .State.Health.Log}}{{.ExitCode}} {{.Output}}{{end}}' "$c" 2>/dev/null \
          | tail -c 800 >&2 || true
        echo >&2
        echo "[configure-smoke] recent logs: ${c}" >&2
        docker logs --tail 40 "$c" 2>&1 | tail -c 2000 >&2 || true
        echo >&2
      fi
    done
  }

  log "Waiting for core healthchecks..."
  deadline=$((SECONDS + 600))
  while (( SECONDS < deadline )); do
    healthy=0
    for c in "${core[@]}"; do
      status=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$c" 2>/dev/null || echo none)
      [[ "$status" == "healthy" || "$status" == "none" ]] && healthy=$((healthy + 1))
    done
    [[ "$healthy" -eq ${#core[@]} ]] && break
    sleep 5
  done
  if [[ "$healthy" -ne ${#core[@]} ]]; then
    dump_health
    fail "core containers not healthy within 600s"
  fi

  log "Running configure (preflight budget=${preflight_timeout}s)..."
  set +e
  out="$(CONFIGURE_PREFLIGHT_TIMEOUT="${preflight_timeout}" WAIT_TIMEOUT="${wait_timeout}" ./bin/flixbox configure 2>&1)"
  rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    printf '%s\n' "$out" | tail -n 80 >&2
    fail "configure failed (rc=${rc})"
  fi

  # ADR 0021: summary: N updated, M unchanged, K failed
  if ! echo "$out" | grep -qE 'summary: [0-9]+ updated, [0-9]+ unchanged, [0-9]+ failed'; then
    printf '%s\n' "$out" | tail -n 80 >&2
    fail "configure missing summary: updated/unchanged/failed line"
  fi
  if [[ "$SMOKE_PR" -eq 0 ]]; then
    echo "$out" | grep -q 'Configuring Seerr' || \
      fail "configure did not run Seerr wiring"
    echo "$out" | grep -q 'Seerr:' || \
      fail "configure missing Seerr outcome line"
    echo "$out" | grep -qE 'Prowlarr: (added Byparr|Byparr/FlareSolverr proxy)' || \
      fail "configure missing Prowlarr Byparr proxy outcome"
  else
    echo "$out" | grep -q 'Configuring Prowlarr' || \
      fail "configure did not run Prowlarr wiring"
  fi
  pass "configure on ephemeral stack (rc=0)"

  log "Idempotent re-run..."
  set +e
  out2="$(CONFIGURE_PREFLIGHT_TIMEOUT=600 ./bin/flixbox configure 2>&1)"
  rc2=$?
  set -e
  if [[ "$rc2" -ne 0 ]]; then
    printf '%s\n' "$out2" | tail -n 80 >&2
    fail "configure idempotent re-run failed (rc=${rc2})"
  fi
  if ! echo "$out2" | grep -qE 'summary: [0-9]+ updated, [0-9]+ unchanged, [0-9]+ failed'; then
    printf '%s\n' "$out2" | tail -n 80 >&2
    fail "idempotent re-run missing summary: updated/unchanged/failed line"
  fi
  pass "configure idempotent re-run on ephemeral stack"
)

printf '\nConfigure stack smoke passed.\n'
