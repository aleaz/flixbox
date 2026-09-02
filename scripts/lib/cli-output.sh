#!/usr/bin/env bash
#
# Optional output helpers for scripts sourced from bin/flixbox (no [configure] prefix).
# configure-helpers.sh defines its own info/dry/log when running configure.

if ! declare -f info >/dev/null 2>&1; then
  info() {
    if declare -f log >/dev/null 2>&1; then
      log "$@"
    else
      printf '%s\n' "$*"
    fi
  }
fi

if ! declare -f dry >/dev/null 2>&1; then
  dry() { :; }
fi
