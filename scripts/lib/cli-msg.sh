#!/usr/bin/env bash
# Flixbox CLI messaging (ADR 0021 output contract).
# Sourced from bin/flixbox — do not execute directly.
#
# Streams: progress/warnings → stderr; primary human results → stdout.
# Color paints tokens only (PASS/FAIL/…); never color-only meaning.
# Tokens are left-aligned in a fixed 4-column field so OK/INFO/FAIL lines share
# the same message column (visible width, independent of ANSI).
# Honor NO_COLOR, TERM=dumb, and non-TTY on the target stream.

# Optional: set FLIXBOX_NO_COLOR=1 or pass --no-color (caller) before sourcing.
FLIXBOX_NO_COLOR="${FLIXBOX_NO_COLOR:-}"
FLIXBOX_CLI_TOKEN_WIDTH=4

flixbox_cli_color_enabled() {
  local fd="${1:-2}"
  [[ -z "${FLIXBOX_NO_COLOR}" && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" && -t "$fd" ]]
}

# Paint token + right-pad to FLIXBOX_CLI_TOKEN_WIDTH using spaces *after* ANSI reset.
# Usage: flixbox_cli_token <fd> <ansi> <token>
flixbox_cli_token() {
  local fd="$1" ansi="$2" token="$3"
  local width="${FLIXBOX_CLI_TOKEN_WIDTH}"
  local pad=$((width - ${#token}))
  (( pad < 0 )) && pad=0
  if flixbox_cli_color_enabled "$fd"; then
    printf '%b%s%b%*s' "$ansi" "$token" '\033[0m' "$pad" ''
  else
    printf '%-*s' "$width" "$token"
  fi
}

# --- stderr: progress / diagnostics ---

cli_info() {
  local tok
  tok="$(flixbox_cli_token 2 '\033[36m' 'INFO')"
  printf '%s  %s\n' "$tok" "$*" >&2
}

cli_ok() {
  # Progress success on stderr (mutators / lifecycle). Checklist uses cli_pass.
  local tok
  tok="$(flixbox_cli_token 2 '\033[32m' 'OK')"
  printf '%s  %s\n' "$tok" "$*" >&2
}

cli_warn() {
  local tok
  tok="$(flixbox_cli_token 2 '\033[33m' 'WARN')"
  printf '%s  %s\n' "$tok" "$*" >&2
}

cli_die() {
  local code="${1:-1}"
  shift || true
  local tok
  tok="$(flixbox_cli_token 2 '\033[31m' 'FAIL')"
  printf '%s  %s\n' "$tok" "$*" >&2
  exit "$code"
}

# --- stdout: primary results (doctor / status / configure lines) ---

cli_pass() {
  local label="$1" detail="${2:-}"
  local tok
  tok="$(flixbox_cli_token 1 '\033[32m' 'PASS')"
  if [[ -n "$detail" ]]; then
    printf '%s  %-18s %s\n' "$tok" "$label" "$detail"
  else
    printf '%s  %s\n' "$tok" "$label"
  fi
}

cli_fail_line() {
  local label="$1" detail="${2:-}"
  local tok
  tok="$(flixbox_cli_token 1 '\033[31m' 'FAIL')"
  if [[ -n "$detail" ]]; then
    printf '%s  %-18s %s\n' "$tok" "$label" "$detail"
  else
    printf '%s  %s\n' "$tok" "$label"
  fi
}

cli_info_out() {
  # INFO line that is part of the primary report (stdout).
  local label="$1" detail="${2:-}"
  local tok
  tok="$(flixbox_cli_token 1 '\033[36m' 'INFO')"
  if [[ -n "$detail" ]]; then
    printf '%s  %-18s %s\n' "$tok" "$label" "$detail"
  else
    printf '%s  %s\n' "$tok" "$label"
  fi
}

cli_result_ok() {
  local tok
  tok="$(flixbox_cli_token 1 '\033[32m' 'OK')"
  printf '%s  %s\n' "$tok" "$*"
}

cli_kv() {
  # Aligned key: value (version grammar). stdout.
  local key="$1" value="$2"
  printf '%-16s %s\n' "${key}:" "$value"
}

cli_outcome() {
  # Mutator vocabulary on stderr: scope verb detail
  local scope="$1" verb="$2" detail="${3:-}"
  local tok
  case "$verb" in
    failed) tok="$(flixbox_cli_token 2 '\033[31m' 'FAIL')" ;;
    skipped|unchanged) tok="$(flixbox_cli_token 2 '\033[36m' 'INFO')" ;;
    *) tok="$(flixbox_cli_token 2 '\033[32m' 'OK')" ;;
  esac
  if [[ -n "$detail" ]]; then
    printf '%s  %s %-10s %s\n' "$tok" "$scope" "$verb" "$detail" >&2
  else
    printf '%s  %s %-10s\n' "$tok" "$scope" "$verb" >&2
  fi
}

# Configure / mutator report line on stdout (fixed token + verb columns).
cli_configure_line() {
  local verb="$1" detail="$2"
  local tok color
  case "$verb" in
    failed)
      color='\033[31m'
      tok="$(flixbox_cli_token 1 "$color" 'FAIL')"
      ;;
    unchanged|skipped|dry-run)
      color='\033[36m'
      tok="$(flixbox_cli_token 1 "$color" 'INFO')"
      ;;
    *)
      color='\033[32m'
      tok="$(flixbox_cli_token 1 "$color" 'OK')"
      ;;
  esac
  printf '%s  configure %-10s %s\n' "$tok" "$verb" "$detail"
}

cli_summary() {
  # Primary summary line on stdout, same token column as outcomes.
  local tok
  tok="$(flixbox_cli_token 1 '\033[32m' 'OK')"
  printf '%s  summary: %s\n' "$tok" "$*"
}
