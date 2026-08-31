#!/usr/bin/env bash
#
# Access profile helpers (ADR 0015). Sourced by bin/flixbox — not executed directly.

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-file.sh"

# Valid: trusted | shared
flixbox_access_profile() {
  echo "${FLIXBOX_ACCESS_PROFILE:-trusted}"
}

flixbox_validate_access_profile() {
  case "$(flixbox_access_profile)" in
    trusted|shared) return 0 ;;
    *)
      echo "Invalid FLIXBOX_ACCESS_PROFILE=$(flixbox_access_profile) (use trusted or shared)" >&2
      return 1
      ;;
  esac
}

# Write derived auth + publish-bind env keys into .env from FLIXBOX_ACCESS_PROFILE.
flixbox_sync_access_profile_env() {
  local env_file="$1" profile
  profile="$(flixbox_access_profile)"
  [[ -f "$env_file" ]] || return 0

  case "$profile" in
    trusted)
      flixbox_env_file_set "$env_file" FLIXBOX_ARR_AUTH_METHOD External
      flixbox_env_file_set "$env_file" FLIXBOX_ARR_AUTH_REQUIRED DisabledForLocalAddresses
      flixbox_env_file_set "$env_file" FLIXBOX_ADMIN_BIND_IP 0.0.0.0
      ;;
    shared)
      flixbox_env_file_set "$env_file" FLIXBOX_ARR_AUTH_METHOD Forms
      flixbox_env_file_set "$env_file" FLIXBOX_ARR_AUTH_REQUIRED Enabled
      flixbox_env_file_set "$env_file" FLIXBOX_ADMIN_BIND_IP 127.0.0.1
      ;;
  esac
}

# Print a drift message when derived profile keys disagree with the active profile.
# Empty keys count as drift (Compose would otherwise fall back to trusted defaults).
# Empty string when coherent. Caller should sync (preferred) or die.
flixbox_access_profile_drift_message() {
  local profile expected_method expected_required expected_bind
  profile="$(flixbox_access_profile)"
  case "$profile" in
    trusted)
      expected_method=External
      expected_required=DisabledForLocalAddresses
      expected_bind=0.0.0.0
      ;;
    shared)
      expected_method=Forms
      expected_required=Enabled
      expected_bind=127.0.0.1
      ;;
  esac
  local parts=()
  if [[ "${FLIXBOX_ARR_AUTH_METHOD:-}" != "$expected_method" ]]; then
    parts+=("FLIXBOX_ARR_AUTH_METHOD=${FLIXBOX_ARR_AUTH_METHOD:-<empty>} (expected ${expected_method})")
  fi
  if [[ "${FLIXBOX_ARR_AUTH_REQUIRED:-}" != "$expected_required" ]]; then
    parts+=("FLIXBOX_ARR_AUTH_REQUIRED=${FLIXBOX_ARR_AUTH_REQUIRED:-<empty>} (expected ${expected_required})")
  fi
  if [[ "${FLIXBOX_ADMIN_BIND_IP:-}" != "$expected_bind" ]]; then
    parts+=("FLIXBOX_ADMIN_BIND_IP=${FLIXBOX_ADMIN_BIND_IP:-<empty>} (expected ${expected_bind})")
  fi
  [[ ${#parts[@]} -eq 0 ]] && return 0
  echo "Access profile ${profile} out of sync: ${parts[*]}"
}
