#!/usr/bin/env bash
# Directory ownership helpers (host chown, with alpine fallback for CI / no-sudo).

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

# After a prior PUID chown, CONFIG_DIR may not be writable by the operator/CI user.
# Reclaim it before copy_templates; apply_runtime_ownership restores PUID afterward.
flixbox_prepare_config_for_host_write() {
  local cfg="${CONFIG_DIR:?CONFIG_DIR required}"
  mkdir -p "$cfg"
  if [[ -w "$cfg" ]]; then
    return 0
  fi
  if flixbox_chown_tree "$cfg" "$(id -u)" "$(id -g)"; then
    echo "CONFIG_DIR reclaimed for host template writes (uid $(id -u))"
    return 0
  fi
  echo "Warning: CONFIG_DIR not writable and reclaim failed — template copy may fail" >&2
  return 1
}

# Container runtime ownership: linuxserver apps use PUID/PGID; Seerr is fixed 1000.
flixbox_apply_runtime_ownership() {
  local ok_data=0 ok_cfg=0
  flixbox_chown_tree "${DATA_DIR:?DATA_DIR required}" "${PUID:?PUID required}" "${PGID:?PGID required}" && ok_data=1
  flixbox_chown_tree "${CONFIG_DIR:?CONFIG_DIR required}" "${PUID}" "${PGID}" && ok_cfg=1
  [[ "$ok_data" -eq 1 ]] || echo "Warning: could not chown DATA_DIR to ${PUID}:${PGID}" >&2
  [[ "$ok_cfg" -eq 1 ]] || echo "Warning: could not chown CONFIG_DIR to ${PUID}:${PGID}" >&2
  flixbox_ensure_seerr_config_owner || true
  [[ "$ok_data" -eq 1 && "$ok_cfg" -eq 1 ]]
}

# Seerr runs as fixed UID/GID 1000 (node) and ignores PUID/PGID.
# Call after creating CONFIG_DIR/seerr and after any bulk chown of CONFIG_DIR.
flixbox_ensure_seerr_config_owner() {
  local seerr_dir="${1:-}"
  if [[ -z "$seerr_dir" ]]; then
    seerr_dir="${CONFIG_DIR:?CONFIG_DIR required}/seerr"
  fi
  mkdir -p "${seerr_dir}"
  if flixbox_chown_tree "${seerr_dir}" 1000 1000; then
    return 0
  fi
  echo "Warning: could not chown ${seerr_dir} to 1000:1000 — Seerr may restart-loop" >&2
  return 1
}
