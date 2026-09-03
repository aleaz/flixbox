#!/usr/bin/env bash
# Directory ownership helpers (host chown, with alpine fallback for CI / no-sudo).
#
# Contract:
#   Host writes (init templates, path validation) → operator uid
#   Container runtime → PUID/PGID; Seerr is fixed 1000
#   Never reclaim or chown DATA_DIR while Compose services may be running
#     (breaks *arr root folders / qBit category paths). init only.

# Recursively chown a host path to uid:gid. Prefers native chown; falls back to
# a short-lived alpine container when the runner lacks CAP_CHOWN (GitHub Actions).
flixbox_chown_tree() {
  local path="${1:?path required}" uid="${2:?uid required}" gid="${3:?gid required}"
  [[ -e "$path" ]] || return 1
  if chown -R "${uid}:${gid}" "$path" 2>/dev/null; then
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    if docker run --rm -v "${path}:/data" alpine:3.20 \
      chown -R "${uid}:${gid}" /data 2>/dev/null; then
      echo "Ownership set to ${uid}:${gid} on ${path} (via alpine helper)"
      return 0
    fi
  fi
  return 1
}

# Reclaim a host path for the invoking user when a prior PUID chown removed write access.
flixbox_reclaim_path_for_host_write() {
  local path="${1:?path required}"
  [[ -e "$path" ]] || return 0
  if [[ -w "$path" ]]; then
    return 0
  fi
  if flixbox_chown_tree "$path" "$(id -u)" "$(id -g)"; then
    echo "Reclaimed ${path} for host writes (uid $(id -u))"
    return 0
  fi
  echo "Warning: ${path} not writable and reclaim failed" >&2
  return 1
}

# init only (stack down): reclaim DATA_DIR + CONFIG_DIR before validation / bootstrap / templates.
flixbox_prepare_paths_for_host_write() {
  local rc=0
  flixbox_reclaim_path_for_host_write "${DATA_DIR:?DATA_DIR required}" || rc=1
  flixbox_reclaim_path_for_host_write "${CONFIG_DIR:?CONFIG_DIR required}" || rc=1
  return "$rc"
}

# up/reload/configure: CONFIG_DIR only — never DATA_DIR while containers may be up.
flixbox_prepare_config_for_host_write() {
  local cfg="${CONFIG_DIR:?CONFIG_DIR required}"
  mkdir -p "$cfg"
  flixbox_reclaim_path_for_host_write "$cfg"
}

# init only: DATA + CONFIG to PUID, then Seerr 1000.
flixbox_apply_runtime_ownership() {
  local ok_data=0 ok_cfg=0
  flixbox_chown_tree "${DATA_DIR:?DATA_DIR required}" "${PUID:?PUID required}" "${PGID:?PGID required}" && ok_data=1
  flixbox_chown_tree "${CONFIG_DIR:?CONFIG_DIR required}" "${PUID}" "${PGID}" && ok_cfg=1
  [[ "$ok_data" -eq 1 ]] || echo "Warning: could not chown DATA_DIR to ${PUID}:${PGID}" >&2
  [[ "$ok_cfg" -eq 1 ]] || echo "Warning: could not chown CONFIG_DIR to ${PUID}:${PGID}" >&2
  flixbox_ensure_seerr_config_owner "${CONFIG_DIR}/seerr" || true
  [[ "$ok_data" -eq 1 && "$ok_cfg" -eq 1 ]]
}

# After template copy on up/reload: CONFIG to PUID + Seerr 1000. Does not touch DATA_DIR.
flixbox_apply_config_runtime_ownership() {
  local ok_cfg=0
  flixbox_chown_tree "${CONFIG_DIR:?CONFIG_DIR required}" "${PUID:?PUID required}" "${PGID:?PGID required}" && ok_cfg=1
  [[ "$ok_cfg" -eq 1 ]] || echo "Warning: could not chown CONFIG_DIR to ${PUID}:${PGID}" >&2
  flixbox_ensure_seerr_config_owner "${CONFIG_DIR}/seerr" || true
  [[ "$ok_cfg" -eq 1 ]]
}

# Seerr runs as fixed UID/GID 1000 (node) and ignores PUID/PGID.
# Call after creating CONFIG_DIR/seerr and after any bulk chown of CONFIG_DIR.
flixbox_ensure_seerr_config_owner() {
  local seerr_dir="${1:?seerr config dir required}"
  mkdir -p "${seerr_dir}"
  if flixbox_chown_tree "${seerr_dir}" 1000 1000; then
    return 0
  fi
  echo "Warning: could not chown ${seerr_dir} to 1000:1000 — Seerr may restart-loop" >&2
  return 1
}
