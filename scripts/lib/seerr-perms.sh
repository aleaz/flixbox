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
  echo "Warning: Unable to set ownership on ${path} to ${uid}:${gid}." >&2
  echo "  Both native chown and Docker alpine helper failed (Docker socket inaccessible or permission denied)." >&2
  echo "  Manual fix: sudo chown -R ${uid}:${gid} \"${path}\"" >&2
  echo "  Troubleshooting: docs/user/10-troubleshooting.md#storage-paths-and-permissions" >&2
  return 1
}

# Host-visible UID of a path (Linux GNU stat or BSD/macOS). Empty on failure.
flixbox_path_uid() {
  local path="${1:?path required}" uid=""
  [[ -e "$path" ]] || return 1
  uid="$(stat -c '%u' "$path" 2>/dev/null || true)"
  if [[ -z "$uid" ]]; then
    uid="$(stat -f '%u' "$path" 2>/dev/null || true)"
  fi
  [[ -n "$uid" ]] || return 1
  printf '%s\n' "$uid"
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
  # Seerr ownership is mandatory (ADR 0022); PUID tree chown remains best-effort.
  flixbox_ensure_seerr_config_owner "${CONFIG_DIR}/seerr" || return 1
  return 0
}

# After template copy on up/reload: CONFIG to PUID + Seerr 1000. Does not touch DATA_DIR.
flixbox_apply_config_runtime_ownership() {
  local ok_cfg=0
  flixbox_chown_tree "${CONFIG_DIR:?CONFIG_DIR required}" "${PUID:?PUID required}" "${PGID:?PGID required}" && ok_cfg=1
  [[ "$ok_cfg" -eq 1 ]] || echo "Warning: could not chown CONFIG_DIR to ${PUID}:${PGID}" >&2
  # Seerr ownership is mandatory (ADR 0022); PUID tree chown remains best-effort.
  flixbox_ensure_seerr_config_owner "${CONFIG_DIR}/seerr" || return 1
  return 0
}

# Optional write probe as UID 1000 — never pulls images (ADR 0022 / review F1).
# Returns 0 if writable, 1 if probe ran and failed, 2 if skipped (no local alpine).
flixbox_seerr_write_probe() {
  local seerr_dir="${1:?seerr config dir required}"
  command -v docker >/dev/null 2>&1 || return 2
  docker image inspect alpine:3.20 >/dev/null 2>&1 || return 2
  if docker run --rm --pull=never -u 1000:1000 -v "${seerr_dir}:/cfg" alpine:3.20 \
    sh -c 'touch /cfg/.flixbox-write-test && rm -f /cfg/.flixbox-write-test' 2>/dev/null; then
    return 0
  fi
  return 1
}

# Seerr runs as fixed UID/GID 1000 (node) and ignores PUID/PGID.
# Call after creating CONFIG_DIR/seerr and after any bulk chown of CONFIG_DIR.
# Fail-closed on chown failure. Write-probe only when host uid ≠ 1000 and alpine
# is already local — never pulls alpine just to verify (ADR 0022).
flixbox_ensure_seerr_config_owner() {
  local seerr_dir="${1:?seerr config dir required}"
  local uid="" probe_rc=0
  mkdir -p "${seerr_dir}"
  if ! flixbox_chown_tree "${seerr_dir}" 1000 1000; then
    echo "Error: could not chown ${seerr_dir} to 1000:1000 — Seerr would restart-loop" >&2
    echo "  Manual fix: sudo chown -R 1000:1000 \"${seerr_dir}\"" >&2
    echo "  Troubleshooting: docs/user/10-troubleshooting.md#storage-paths-and-permissions" >&2
    return 1
  fi
  if uid="$(flixbox_path_uid "${seerr_dir}")" && [[ "$uid" == "1000" ]]; then
    return 0
  fi
  # Host UID mapping may differ (e.g. Docker Desktop); probe only with cached alpine.
  flixbox_seerr_write_probe "${seerr_dir}"
  probe_rc=$?
  if [[ "$probe_rc" -eq 0 ]]; then
    return 0
  fi
  if [[ "$probe_rc" -eq 2 ]]; then
    # chown succeeded; cannot confirm via host stat or local alpine — trust chown.
    return 0
  fi
  echo "Error: ${seerr_dir} is not writable as UID 1000 after chown" >&2
  echo "  Manual fix: sudo chown -R 1000:1000 \"${seerr_dir}\"" >&2
  return 1
}
