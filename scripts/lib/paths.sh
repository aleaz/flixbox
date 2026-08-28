#!/usr/bin/env bash
# Shared path validation and platform defaults for Flixbox CLI/scripts.
# Source from bin/flixbox or scripts/*.sh — do not execute directly.

_paths_hint() {
  printf 'hint: %s\n' "$*" >&2
}

_paths_sed_inplace() {
  if [[ "$(uname -s)" == Darwin ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# Linux reference default (FHS /srv). Used for hints and .env.example.
flixbox_linux_data_dir() {
  printf '/srv/flixbox/data'
}

flixbox_linux_config_dir() {
  printf '/srv/flixbox/config'
}

# Default DATA_DIR for the current host OS.
flixbox_default_data_dir() {
  case "$(uname -s)" in
    Darwin) printf '%s/flixbox/data' "${HOME}" ;;
    Linux) flixbox_linux_data_dir ;;
    *) printf '%s/flixbox/data' "${HOME}" ;;
  esac
}

# Default CONFIG_DIR for the current host OS.
flixbox_default_config_dir() {
  case "$(uname -s)" in
    Darwin) printf '%s/flixbox/config' "${HOME}" ;;
    Linux) flixbox_linux_config_dir ;;
    *) printf '%s/flixbox/config' "${HOME}" ;;
  esac
}

# Write platform-appropriate DATA_DIR / CONFIG_DIR into an env file.
apply_platform_env_paths() {
  local env_file="$1"
  local data_dir config_dir

  data_dir="$(flixbox_default_data_dir)"
  config_dir="$(flixbox_default_config_dir)"

  _paths_sed_inplace "s|^DATA_DIR=.*|DATA_DIR=${data_dir}|" "${env_file}"
  _paths_sed_inplace "s|^CONFIG_DIR=.*|CONFIG_DIR=${config_dir}|" "${env_file}"
}

# Paths plus macOS PUID/PGID (linuxserver images need the host user on Docker Desktop).
apply_platform_env_defaults() {
  local env_file="$1"

  apply_platform_env_paths "${env_file}"
  if [[ "$(uname -s)" == Darwin ]]; then
    _paths_sed_inplace "s|^PUID=.*|PUID=$(id -u)|" "${env_file}"
    _paths_sed_inplace "s|^PGID=.*|PGID=$(id -g)|" "${env_file}"
  fi
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

# Guidance when Linux template paths are used on macOS without init.
warn_platform_path_mismatch() {
  local data_dir="$1"
  local config_dir="$2"
  local linux_data linux_config

  [[ "$(uname -s)" == Darwin ]] || return 0

  linux_data="$(flixbox_linux_data_dir)"
  linux_config="$(flixbox_linux_config_dir)"

  if [[ "${data_dir}" == "${linux_data}"* || "${config_dir}" == "${linux_config}"* ]]; then
    _paths_hint "on macOS, ${linux_data} is not available by default."
    _paths_hint "run: ./bin/flixbox init --force --non-interactive"
    _paths_hint "or set DATA_DIR=${HOME}/flixbox/data and CONFIG_DIR=${HOME}/flixbox/config"
  fi
}

validate_flixbox_paths() {
  local data_dir="$1"
  local config_dir="$2"

  warn_platform_path_mismatch "${data_dir}" "${config_dir}"
  validate_path_writable "${data_dir}" "DATA_DIR" || return 1
  validate_path_writable "${config_dir}" "CONFIG_DIR" || return 1
}

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
