#!/usr/bin/env bash
#
# Cross-platform shell helpers for Flixbox scripts. Sourced, not executed.

sed_inplace() {
  if [[ "$(uname -s)" == Darwin ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}
