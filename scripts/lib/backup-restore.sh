#!/usr/bin/env bash
# CONFIG_DIR backup/restore helpers (ADR 0021). Sourced from bin/flixbox.
# Never archives ${DATA_DIR} — media/torrents are operator-owned.

flixbox_backup_stack_running() {
  command -v docker >/dev/null 2>&1 || return 1
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qE '^flixbox-' || return 1
  return 0
}

# Stop stack for WAL-safe backup. Sets FLIXBOX_BACKUP_DID_STOP=1 when stop ran.
flixbox_backup_stop_stack() {
  FLIXBOX_BACKUP_DID_STOP=0
  if ! flixbox_backup_stack_running; then
    return 0
  fi
  assert_docker_accessible
  cli_info "Stopping Flixbox services for consistent SQLite backup..."
  if ! docker compose --project-directory "${ROOT_DIR}" stop; then
    return 1
  fi
  FLIXBOX_BACKUP_DID_STOP=1
  return 0
}

flixbox_backup_restart_stack() {
  [[ "${FLIXBOX_BACKUP_DID_STOP:-0}" -eq 1 ]] || return 0
  cli_info "Restarting Flixbox services..."
  docker compose --project-directory "${ROOT_DIR}" start || return 1
  FLIXBOX_BACKUP_DID_STOP=0
  return 0
}

flixbox_backup_warn_live() {
  if flixbox_backup_stack_running; then
    cli_warn "Stack is running — live backup may capture uncommitted SQLite WAL."
    cli_warn "Tip: ./bin/flixbox backup --stop for cleaner consistency."
  fi
}

# True if CONFIG_DIR exists and has any entries.
flixbox_config_dir_nonempty() {
  local dir="${CONFIG_DIR:-}"
  [[ -n "$dir" && -d "$dir" ]] || return 1
  local any
  any="$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null || true)"
  [[ -n "$any" ]]
}

# Create archive. Prints absolute path on stdout. Args: dest_dir include_env(0|1) stop(0|1)
flixbox_backup_create() {
  local dest_dir="$1" include_env="$2" stop="$3"
  local stamp out parent base env_file
  local -a tar_args=()

  [[ -n "${CONFIG_DIR:-}" ]] || {
    cli_configure_line backup failed "CONFIG_DIR unset"
    return 4
  }
  [[ -d "${CONFIG_DIR}" ]] || {
    cli_configure_line backup failed "CONFIG_DIR missing: ${CONFIG_DIR}"
    return 4
  }

  parent="$(dirname "${CONFIG_DIR}")"
  base="$(basename "${CONFIG_DIR}")"
  [[ -d "$parent" ]] || {
    cli_configure_line backup failed "CONFIG_DIR parent missing: ${parent}"
    return 4
  }

  env_file="${ROOT_DIR}/.env"
  if [[ "$include_env" -eq 1 ]]; then
    [[ -f "$env_file" ]] || {
      cli_configure_line backup failed ".env missing (required for --include-env)"
      return 4
    }
    cli_warn "--include-env: archive will contain secrets — store like .env"
  fi

  dest_dir="${dest_dir:-${ROOT_DIR}/backups}"
  mkdir -p "$dest_dir" || {
    cli_configure_line backup failed "cannot create DEST_DIR: ${dest_dir}"
    return 4
  }

  if [[ "$stop" -eq 1 ]]; then
    flixbox_backup_stop_stack || {
      cli_configure_line backup failed "compose stop"
      return 3
    }
  else
    flixbox_backup_warn_live
  fi

  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  out="${dest_dir}/flixbox-config-${stamp}.tar.gz"

  # Top-level members: <basename(CONFIG_DIR)>/ and optional .env (never DATA_DIR).
  # Skip runtime sockets that tar cannot archive usefully.
  tar_args=(-czf "$out" --exclude='*/ipc-socket' --exclude='*.sock' -C "$parent" "$base")
  if [[ "$include_env" -eq 1 ]]; then
    tar_args+=(-C "${ROOT_DIR}" .env)
  fi

  if ! tar "${tar_args[@]}"; then
    flixbox_backup_restart_stack || true
    cli_configure_line backup failed "tar create"
    return 1
  fi

  if ! flixbox_backup_restart_stack; then
    cli_configure_line backup failed "compose start after backup (archive ok: ${out})"
    printf '%s\n' "$out"
    return 3
  fi

  printf '%s\n' "$out"
  return 0
}

# Locate extracted config tree inside a temp extract dir. Prints path.
flixbox_restore_find_config_src() {
  local extract="$1"
  local base want
  base="$(basename "${CONFIG_DIR}")"
  want="${extract}/${base}"
  if [[ -d "$want" ]]; then
    printf '%s\n' "$want"
    return 0
  fi
  # Single top-level directory (legacy / alternate layouts), excluding a lone .env
  local -a dirs=()
  local d
  while IFS= read -r d; do
    [[ -n "$d" ]] && dirs+=("$d")
  done < <(find "$extract" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
  if [[ ${#dirs[@]} -eq 1 ]]; then
    printf '%s\n' "${dirs[0]}"
    return 0
  fi
  return 1
}

# Restore archive into CONFIG_DIR. Args: archive_path force(0|1)
flixbox_restore_apply() {
  local archive="$1" force="$2"
  local tmp src env_src has_env=0

  [[ -n "${CONFIG_DIR:-}" ]] || {
    cli_configure_line restore failed "CONFIG_DIR unset"
    return 4
  }
  [[ -f "$archive" ]] || {
    cli_configure_line restore failed "archive not found: ${archive}"
    return 4
  }

  if tar -tzf "$archive" 2>/dev/null | grep -qx '\.env'; then
    has_env=1
  fi

  if flixbox_config_dir_nonempty && [[ "$force" -ne 1 ]]; then
    die_usage "restore: ${CONFIG_DIR} is not empty — re-run with --force (try --help)"
  fi
  if [[ "$has_env" -eq 1 && -f "${ROOT_DIR}/.env" && "$force" -ne 1 ]]; then
    die_usage "restore: archive includes .env and ${ROOT_DIR}/.env exists — re-run with --force"
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/flixbox-restore.XXXXXX")" || {
    cli_configure_line restore failed "mktemp"
    return 1
  }
  # shellcheck disable=SC2064
  trap 'rm -rf -- "$tmp"' RETURN

  if ! tar -xzf "$archive" -C "$tmp"; then
    cli_configure_line restore failed "tar extract"
    return 1
  fi

  src="$(flixbox_restore_find_config_src "$tmp")" || {
    cli_configure_line restore failed "no CONFIG tree in archive"
    return 4
  }

  mkdir -p "${CONFIG_DIR}" || {
    cli_configure_line restore failed "cannot create CONFIG_DIR"
    return 4
  }

  if command -v rsync >/dev/null 2>&1; then
    if ! rsync -a --delete "${src}/" "${CONFIG_DIR}/"; then
      cli_configure_line restore failed "rsync into CONFIG_DIR"
      return 1
    fi
  else
    if flixbox_config_dir_nonempty; then
      find "${CONFIG_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    fi
    if ! cp -a "${src}/." "${CONFIG_DIR}/"; then
      cli_configure_line restore failed "cp into CONFIG_DIR"
      return 1
    fi
  fi

  env_src="${tmp}/.env"
  if [[ "$has_env" -eq 1 && -f "$env_src" ]]; then
    cli_warn "Restoring .env from archive (sensitive)"
    if ! cp -a "$env_src" "${ROOT_DIR}/.env"; then
      cli_configure_line restore failed "copy .env"
      return 1
    fi
  fi

  return 0
}
