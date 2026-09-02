#!/usr/bin/env bash
# Seerr runs as fixed UID/GID 1000 (node) and ignores PUID/PGID.
# Call after creating CONFIG_DIR/seerr and after any bulk chown of CONFIG_DIR.

flixbox_ensure_seerr_config_owner() {
  local seerr_dir="${1:-}"
  if [[ -z "$seerr_dir" ]]; then
    seerr_dir="${CONFIG_DIR:?CONFIG_DIR required}/seerr"
  fi
  mkdir -p "${seerr_dir}"
  if chown -R 1000:1000 "${seerr_dir}" 2>/dev/null; then
    return 0
  fi
  if command -v docker >/dev/null 2>&1; then
    if docker run --rm -v "${seerr_dir}:/data" alpine:3.20 \
      chown -R 1000:1000 /data 2>/dev/null; then
      echo "Seerr config ownership set to 1000:1000 (via alpine helper)"
      return 0
    fi
  fi
  echo "Warning: could not chown ${seerr_dir} to 1000:1000 — Seerr may restart-loop" >&2
  return 1
}
