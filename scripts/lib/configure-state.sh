#!/usr/bin/env bash
#
# Configure readiness state machine (ADR 0005, ADR 0016).
# Sourced by preflight and service modules — not executed directly.
#
# States:
#   INIT → ASSERT → PREFLIGHT_RETRY* → PREFLIGHT_PASSED → WIRING → DONE|PARTIAL
#
# Exported flags (bash dynamic scope):
#   CONFIGURE_PREFLIGHT_PASSED  — set after HTTP + keys + authenticated APIs OK
#   CONFIGURE_SOFT_WAIT         — 1 during preflight retry (soft timeouts)

configure_state_init() {
  CONFIGURE_PREFLIGHT_PASSED=false
}

configure_mark_preflight_passed() {
  CONFIGURE_PREFLIGHT_PASSED=true
}

configure_wiring_waits_satisfied() {
  [[ "${CONFIGURE_PREFLIGHT_PASSED:-false}" == true ]]
}

configure_assert_tools() {
  if ! command -v docker &>/dev/null; then
    echo "ERROR: docker not found." >&2
    exit 1
  fi
  if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 required for JSON parsing." >&2
    exit 1
  fi
}

# MVP core stack required before configure (includes Jellyfin — wired in preflight).
configure_core_container_names() {
  printf '%s\n' \
    flixbox-qbittorrent \
    flixbox-radarr \
    flixbox-sonarr \
    flixbox-prowlarr \
    flixbox-bazarr \
    flixbox-jellyfin
}

configure_assert_core_stack() {
  local missing=() c
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    flixbox_container_running "$c" || missing+=("$c")
  done < <(configure_core_container_names)
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Required containers not running: ${missing[*]}" >&2
    echo "Start the stack first: ./bin/flixbox up" >&2
    exit 1
  fi
}

# VPN: soft-fail during preflight retry; hard-fail when CONFIGURE_SOFT_WAIT unset.
configure_assert_vpn_ready() {
  [[ "${FLIXBOX_MODE:-direct}" == "vpn" ]] || return 0
  if ! flixbox_container_running flixbox-gluetun; then
    if [[ "${CONFIGURE_SOFT_WAIT:-0}" == 1 ]]; then
      info "Gluetun container not running yet — will retry"
      info "If you just switched to VPN: docker compose down && ./bin/flixbox up  (configure does not start Gluetun)"
      return 1
    fi
    echo "ERROR: FLIXBOX_MODE=vpn but flixbox-gluetun is not running." >&2
    echo "       After enabling VPN in .env: ./bin/flixbox init --non-interactive" >&2
    echo "       then: docker compose down && ./bin/flixbox up" >&2
    echo "       (or ./bin/flixbox reload once the stack is already on VPN compose)." >&2
    echo "       configure only wires APIs — it does not create Gluetun." >&2
    exit 1
  fi
  local gluetun_health
  gluetun_health=$(docker inspect -f '{{.State.Health.Status}}' flixbox-gluetun 2>/dev/null || echo unknown)
  if [[ "$gluetun_health" == "healthy" ]]; then
    return 0
  fi
  if [[ "${CONFIGURE_SOFT_WAIT:-0}" == 1 ]]; then
    info "Gluetun is '${gluetun_health}' (need healthy) — will retry"
    return 1
  fi
  echo "ERROR: Gluetun is '${gluetun_health}' (need 'healthy')." >&2
  echo "       Wait for VPN connect, then re-run. Check: ./bin/flixbox logs gluetun" >&2
  exit 1
}

configure_assert_env_writable() {
  local env_file="${ROOT_DIR}/.env"
  if [[ ! -f "$env_file" ]]; then
    echo "ERROR: missing ${env_file} — run ./bin/flixbox init" >&2
    exit 1
  fi
  if [[ ! -w "$env_file" ]]; then
    echo "ERROR: .env is not writable: ${env_file}" >&2
    exit 1
  fi
}

configure_env_write_fatal() {
  local key="$1" detail="${2:-}"
  echo "ERROR: could not write ${key} to .env${detail:+ ($detail)}" >&2
  echo "       Fix permissions on .env, then re-run ./bin/flixbox configure" >&2
  exit 1
}

# Wiring-phase waits: no-op when preflight already verified readiness.
configure_ensure_qbittorrent_ready() {
  configure_wiring_waits_satisfied && return 0
  wait_for_qbittorrent
}

configure_ensure_http() {
  configure_wiring_waits_satisfied && return 0
  wait_for_service "$@"
}

# Wait for multiple HTTP endpoints concurrently (preflight warm-up).
# Args: pairs of name url …
configure_ensure_http_parallel() {
  configure_wiring_waits_satisfied && return 0
  [[ $# -ge 2 ]] || return 0
  local -a pids=() name url failed=0 pid
  while [[ $# -ge 2 ]]; do
    name="$1"
    url="$2"
    shift 2
    # Subshell: use return codes only — ok()/fail() counter increments would be lost.
    ( wait_for_service "$name" "$url" ) &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
  done
  return $failed
}

configure_ensure_arr_api() {
  configure_wiring_waits_satisfied && return 0
  wait_for_arr_api "$@"
}

configure_ensure_bazarr_api() {
  configure_wiring_waits_satisfied && return 0
  wait_for_bazarr_api "$@"
}

# Args: quadruplets name port api_key api_version …
configure_ensure_arr_apis_parallel() {
  configure_wiring_waits_satisfied && return 0
  [[ $# -ge 4 ]] || return 0
  local -a pids=() failed=0 pid
  while [[ $# -ge 4 ]]; do
    ( wait_for_arr_api "$1" "$2" "$3" "$4" ) &
    pids+=($!)
    shift 4
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
  done
  return $failed
}

# Preflight: Sonarr + Radarr + Prowlarr + Bazarr authenticated APIs in parallel.
configure_ensure_stack_apis_parallel() {
  configure_wiring_waits_satisfied && return 0
  local -a pids=() failed=0 pid
  ( wait_for_arr_api "Sonarr" "$SONARR_PORT" "$SONARR_API_KEY" "v3" ) &
  pids+=($!)
  ( wait_for_arr_api "Radarr" "$RADARR_PORT" "$RADARR_API_KEY" "v3" ) &
  pids+=($!)
  ( wait_for_arr_api "Prowlarr" "$PROWLARR_PORT" "$PROWLARR_API_KEY" "v1" ) &
  pids+=($!)
  ( wait_for_bazarr_api "$BAZARR_PORT" "$BAZARR_API_KEY" ) &
  pids+=($!)
  for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
  done
  return $failed
}
