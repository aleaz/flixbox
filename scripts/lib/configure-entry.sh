#!/usr/bin/env bash
#
# Shared configure entry: access profile sync before wiring (ADR 0015).
# Used by bin/flixbox up/reload and scripts/configure-apps.sh.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cli-output.sh"

_configure_entry_generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 18 | tr -d '/+=' | head -c 20
  else
    python3 -c 'import secrets; print(secrets.token_urlsafe(16)[:20])'
  fi
}

_configure_entry_ensure_shared_ui_credentials() {
  [[ "$(flixbox_access_profile)" == "shared" ]] || return 0
  local env_file="${ROOT_DIR}/.env"
  local current
  current="$(flixbox_env_file_get "$env_file" FLIXBOX_ARR_UI_USER)"
  [[ -n "$current" ]] || flixbox_env_file_set_if_empty "$env_file" FLIXBOX_ARR_UI_USER admin
  current="$(flixbox_env_file_get "$env_file" FLIXBOX_ARR_UI_PASSWORD)"
  [[ -n "$current" ]] || flixbox_env_file_set_if_empty "$env_file" FLIXBOX_ARR_UI_PASSWORD "$(_configure_entry_generate_password)"
}

configure_entry_recreate_admin_services() {
  local svc services=()
  while IFS= read -r svc; do
    [[ -n "$svc" ]] && services+=("$svc")
  done < <(flixbox_access_profile_admin_services)
  [[ ${#services[@]} -gt 0 ]] || return 0
  warn "Recreating admin-bound services — configure may wait longer while they restart"
  log "Recreating admin-bound services (access profile derived keys changed)..."
  if docker compose --project-directory "${ROOT_DIR}" up -d --force-recreate "${services[@]}" >/dev/null 2>&1; then
    info "Admin-bound services recreated (FLIXBOX_ADMIN_BIND_IP=${FLIXBOX_ADMIN_BIND_IP})"
  else
    warn "Could not recreate all admin-bound services — run: ./bin/flixbox reload"
    return 1
  fi
}

# Idempotent: validate profile, sync derived .env keys, optional shared UI placeholders, recreate on drift.
configure_entry_prepare() {
  if ${DRY_RUN:-false}; then
    dry "Validate access profile and sync derived .env keys"
    dry "Ensure shared FLIXBOX_ARR_UI_* placeholders when profile is shared"
    dry "Recreate admin-bound services when profile derived keys drift"
    return 0
  fi

  # shellcheck disable=SC1091
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/access-profile.sh"
  flixbox_validate_access_profile || {
    echo "ERROR: Fix FLIXBOX_ACCESS_PROFILE in .env (trusted or shared)" >&2
    exit 1
  }
  local drift synced=false
  drift="$(flixbox_access_profile_drift_message || true)"
  if [[ -n "$drift" ]]; then
    warn "${drift} — syncing derived keys into .env"
    flixbox_sync_access_profile_env "${ROOT_DIR}/.env"
    synced=true
    flixbox_load_env
    info "Access profile $(flixbox_access_profile) synced (FLIXBOX_ADMIN_BIND_IP=${FLIXBOX_ADMIN_BIND_IP})"
  fi
  if [[ "$(flixbox_access_profile)" == "shared" ]]; then
    _configure_entry_ensure_shared_ui_credentials
    flixbox_load_env
  fi
  if $synced; then
    if ! configure_entry_recreate_admin_services; then
      warn "Access profile keys synced but admin service recreate failed — run: ./bin/flixbox reload"
    fi
  fi
}
