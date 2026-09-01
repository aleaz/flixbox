#!/usr/bin/env bash
# MVP smoke test helper — see docs/user/11-smoke-test.md
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/env-file.sh"

SMOKE_ROOT="${SMOKE_ROOT:-/tmp/flixbox-smoke}"
SMOKE_DATA="${SMOKE_DATA:-${SMOKE_ROOT}/data}"
SMOKE_CONFIG="${SMOKE_CONFIG:-${SMOKE_ROOT}/config}"
ENV_BACKUP=""

sed_inplace() {
  if [[ "$(uname -s)" == Darwin ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

die() {
  printf 'smoke-test: %s\n' "$*" >&2
  exit 1
}

ok() {
  printf 'OK   %s\n' "$*"
}

restore_env() {
  if [[ -n "${ENV_BACKUP}" && -f "${ENV_BACKUP}" ]]; then
    cp -f "${ENV_BACKUP}" "${ROOT_DIR}/.env"
    rm -f "${ENV_BACKUP}"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

http_ok() {
  local url="$1"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "${url}" || true)"
  [[ "${code}" =~ ^[23] ]] || [[ "${code}" == "401" ]]
}

cmd_preflight() {
  need_cmd docker
  need_cmd curl
  docker compose version >/dev/null || die "docker compose v2 required"
  ok "docker + compose available"

  docker compose --env-file .env.example config --quiet
  ok "compose config (direct)"

  FLIXBOX_MODE=vpn docker compose --env-file .env.example config --quiet
  ok "compose config (vpn)"

  if [[ -x "${ROOT_DIR}/scripts/ci-validate.sh" ]]; then
    "${ROOT_DIR}/scripts/ci-validate.sh"
    ok "ci-validate.sh"
  fi
}

write_smoke_env() {
  cp -f "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
  flixbox_env_file_set "${ROOT_DIR}/.env" DATA_DIR "${SMOKE_DATA}"
  flixbox_env_file_set "${ROOT_DIR}/.env" CONFIG_DIR "${SMOKE_CONFIG}"
  flixbox_env_file_set "${ROOT_DIR}/.env" FLIXBOX_MODE direct
  flixbox_env_file_set "${ROOT_DIR}/.env" VPN_ENABLED false
  ok "wrote .env for smoke test (${SMOKE_ROOT})"
}

cmd_run() {
  need_cmd docker
  need_cmd curl
  need_cmd python3

  trap restore_env EXIT
  if [[ -f "${ROOT_DIR}/.env" ]]; then
    ENV_BACKUP="$(mktemp)"
    cp -f "${ROOT_DIR}/.env" "${ENV_BACKUP}"
    ok "backed up existing .env (restored on exit)"
  fi

  write_smoke_env
  "${ROOT_DIR}/bin/flixbox" init --non-interactive

  [[ -d "${SMOKE_DATA}/torrents/incomplete" ]] || die "missing torrents/incomplete"
  [[ -f "${SMOKE_CONFIG}/homepage/services.yaml" ]] || die "homepage template not copied"
  ok "init bootstrap"

  "${ROOT_DIR}/bin/flixbox" up
  ok "stack started"

  printf '\nWaiting 30s for containers to settle...\n'
  sleep 30

  "${ROOT_DIR}/bin/flixbox" status

  local failed=0
  local checks=(
    "http://127.0.0.1:8080|qBittorrent"
    "http://127.0.0.1:9696|Prowlarr"
    "http://127.0.0.1:7878|Radarr"
    "http://127.0.0.1:8989|Sonarr"
    "http://127.0.0.1:6767|Bazarr"
    "http://127.0.0.1:8096|Jellyfin"
    "http://127.0.0.1:5055|Seerr"
    "http://127.0.0.1:3000|Homepage"
    "http://127.0.0.1:6246|Maintainerr"
  )

  printf '\nHTTP probes:\n'
  local item url name
  for item in "${checks[@]}"; do
    url="${item%%|*}"
    name="${item##*|}"
    if http_ok "${url}"; then
      ok "${name} (${url})"
    else
      printf 'FAIL %s (%s)\n' "${name}" "${url}" >&2
      failed=1
    fi
  done

  printf '\n--- Manual steps (see docs/user/11-smoke-test.md) ---\n'
  printf '  Phase C: hardlink test after *arr import\n'
  printf '  Phase E: API keys, Decluttarr/Maintainerr wiring\n'
  printf '  Phase F: Seerr → download → Jellyfin playback\n'

  if [[ "${failed}" -ne 0 ]]; then
    die "one or more HTTP probes failed — check ./bin/flixbox logs"
  fi

  ok "automated smoke test passed (Direct mode)"
}

cmd_down() {
  if [[ -f "${ROOT_DIR}/.env" ]]; then
    "${ROOT_DIR}/bin/flixbox" down || true
    ok "stack stopped"
  else
    die "no .env — nothing to stop"
  fi
}

usage() {
  cat <<EOF
Usage: smoke-test.sh <command>

Commands:
  preflight   Docker, compose config, ci-validate (no containers)
  run         init + up + HTTP probes (Direct mode, ${SMOKE_ROOT}); restores .env on exit
  down        ./bin/flixbox down

See docs/user/11-smoke-test.md for the full checklist.

EOF
}

main() {
  local cmd="${1:-}"
  [[ -n "${cmd}" ]] || { usage; exit 1; }
  shift || true
  case "${cmd}" in
    preflight) cmd_preflight "$@" ;;
    run) cmd_run "$@" ;;
    down) cmd_down "$@" ;;
    -h|--help|help) usage ;;
    *) die "unknown command: ${cmd}" ;;
  esac
}

main "$@"
