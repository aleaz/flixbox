#!/usr/bin/env bash
# Shared path validation for Flixbox CLI and bootstrap scripts.
# Source from bin/flixbox or scripts/bootstrap-dirs.sh — do not execute directly.

_paths_hint() {
  printf 'hint: %s\n' "$*" >&2
}

# True when path is an absolute path.
path_is_absolute() {
  [[ "${1:-}" == /* ]]
}

# Find the nearest existing ancestor of path.
_path_existing_ancestor() {
  local current="$1"
  while [[ ! -d "${current}" && "${current}" != "/" ]]; do
    current="$(dirname "${current}")"
  done
  printf '%s' "${current}"
}

# Validate that path can be created or is already a writable directory.
# arg1: path  arg2: label (e.g. DATA_DIR)
validate_path_writable() {
  local path="$1"
  local label="$2"

  if [[ -z "${path}" ]]; then
    printf 'error: %s is empty. Set it in .env (see docs/user/06-configuration.md).\n' "${label}" >&2
    return 1
  fi

  if ! path_is_absolute "${path}"; then
    printf 'error: %s must be an absolute path (got: %s).\n' "${label}" "${path}" >&2
    return 1
  fi

  if [[ -e "${path}" && ! -d "${path}" ]]; then
    printf 'error: %s exists but is not a directory: %s\n' "${label}" "${path}" >&2
    return 1
  fi

  if [[ -d "${path}" ]]; then
    if [[ ! -w "${path}" ]]; then
      printf 'error: %s is not writable: %s\n' "${label}" "${path}" >&2
      return 1
    fi
    return 0
  fi

  local ancestor
  ancestor="$(_path_existing_ancestor "${path}")"
  if [[ ! -w "${ancestor}" ]]; then
    printf 'error: cannot create %s at %s — cannot write under %s.\n' \
      "${label}" "${path}" "${ancestor}" >&2
    return 1
  fi

  return 0
}

# Platform-specific guidance when Linux-centric defaults are used on macOS.
warn_macos_srv_paths() {
  local data_dir="$1"
  local config_dir="$2"

  [[ "$(uname -s)" == Darwin ]] || return 0

  if [[ "${data_dir}" == /srv/flixbox/* || "${config_dir}" == /srv/flixbox/* ]]; then
    _paths_hint "on macOS, /srv is often missing or not writable."
    _paths_hint "edit .env, for example:"
    _paths_hint "  DATA_DIR=${HOME}/flixbox/data"
    _paths_hint "  CONFIG_DIR=${HOME}/flixbox/config"
    _paths_hint "or run: ./bin/flixbox init --force --non-interactive (macOS defaults)"
  fi
}

# Validate DATA_DIR and CONFIG_DIR before mkdir/bootstrap.
validate_flixbox_paths() {
  local data_dir="$1"
  local config_dir="$2"

  warn_macos_srv_paths "${data_dir}" "${config_dir}"
  validate_path_writable "${data_dir}" "DATA_DIR" || return 1
  validate_path_writable "${config_dir}" "CONFIG_DIR" || return 1
}

# Require directories created by init before compose up.
require_flixbox_dirs() {
  local data_dir="$1"
  local config_dir="$2"
  local missing=0

  if [[ ! -d "${data_dir}" ]]; then
    printf 'error: DATA_DIR does not exist: %s\n' "${data_dir}" >&2
    missing=1
  fi
  if [[ ! -d "${config_dir}" ]]; then
    printf 'error: CONFIG_DIR does not exist: %s\n' "${config_dir}" >&2
    missing=1
  fi

  if [[ "${missing}" -ne 0 ]]; then
    _paths_hint "run ./bin/flixbox init after setting writable paths in .env"
    _paths_hint "see docs/user/06-configuration.md"
    return 1
  fi

  return 0
}
