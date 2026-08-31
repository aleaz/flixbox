#!/usr/bin/env bash
#
# Access profile helpers (ADR 0015). Sourced by bin/flixbox — not executed directly.

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

# Write derived *arr auth env keys into .env from FLIXBOX_ACCESS_PROFILE.
flixbox_sync_access_profile_env() {
  local env_file="$1" profile
  profile="$(flixbox_access_profile)"
  [[ -f "$env_file" ]] || return 0

  case "$profile" in
    trusted)
      flixbox_env_set "$env_file" FLIXBOX_ARR_AUTH_METHOD External
      flixbox_env_set "$env_file" FLIXBOX_ARR_AUTH_REQUIRED DisabledForLocalAddresses
      ;;
    shared)
      flixbox_env_set "$env_file" FLIXBOX_ARR_AUTH_METHOD Forms
      flixbox_env_set "$env_file" FLIXBOX_ARR_AUTH_REQUIRED Enabled
      ;;
  esac
}

# Set KEY=value in .env (always overwrite — for derived profile keys).
flixbox_env_set() {
  local env_file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "$env_file" 2>/dev/null; then
    if [[ "$(uname -s)" == Darwin ]]; then
      sed -i '' "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
      sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    fi
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$env_file"
  fi
}
