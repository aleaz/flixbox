#!/usr/bin/env bash
#
# Operator credentials CLI helpers (ADR 0020).
# Sourced by bin/flixbox — not executed directly.
#
# Requires ROOT_DIR, logging helpers (log/ok/warn/die), generate_password,
# flixbox_load_env, flixbox_env_file_*, flixbox_access_profile, assert_docker_accessible.

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/env-file.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/access-profile.sh"

# Set by flixbox_apply_arr_ui_credentials for caller decisions.
ARR_UI_APPLY_OK=0
ARR_UI_APPLY_FAIL=0

credentials_usage() {
  cat <<EOF
Usage:
  flixbox credentials show <target>
  flixbox credentials set  <target> --generate|--prompt

Targets:
  qbit              QBITTORRENT_USERNAME / QBITTORRENT_PASSWORD
  arr-ui            FLIXBOX_ARR_UI_* (shared profile; Host Config apply)
  admin             FLIXBOX_ADMIN_USER / FLIXBOX_ADMIN_PASSWORD
  api radarr|sonarr|prowlarr   show API key only (no set)

Secret values print on stdout; hints on stderr. Do not paste into issues.
EOF
}

credentials_warn_leak() {
  warn "Secret on stdout — avoid shell history, screenshots, and issue reports (ADR 0018)."
}

# Print KEY=value lines for operator passwords; API keys print the raw key only.
credentials_show() {
  local target="${1:-}"
  [[ -n "$target" ]] || { credentials_usage >&2; return 1; }
  shift || true
  load_env
  credentials_warn_leak
  case "$target" in
    qbit)
      printf 'QBITTORRENT_USERNAME=%s\n' "${QBITTORRENT_USERNAME:-}"
      printf 'QBITTORRENT_PASSWORD=%s\n' "${QBITTORRENT_PASSWORD:-}"
      ;;
    arr-ui)
      printf 'FLIXBOX_ARR_UI_USER=%s\n' "${FLIXBOX_ARR_UI_USER:-}"
      printf 'FLIXBOX_ARR_UI_PASSWORD=%s\n' "${FLIXBOX_ARR_UI_PASSWORD:-}"
      if [[ "$(flixbox_access_profile)" != "shared" ]]; then
        warn "Access profile is $(flixbox_access_profile) — Forms login applies under shared only."
      fi
      ;;
    admin)
      printf 'FLIXBOX_ADMIN_USER=%s\n' "${FLIXBOX_ADMIN_USER:-}"
      printf 'FLIXBOX_ADMIN_PASSWORD=%s\n' "${FLIXBOX_ADMIN_PASSWORD:-}"
      ;;
    api)
      local which="${1:-}"
      case "$which" in
        radarr) printf '%s\n' "${RADARR_API_KEY:-}" ;;
        sonarr) printf '%s\n' "${SONARR_API_KEY:-}" ;;
        prowlarr) printf '%s\n' "${PROWLARR_API_KEY:-}" ;;
        *) die "Usage: flixbox credentials show api radarr|sonarr|prowlarr" ;;
      esac
      ;;
    *)
      die "Unknown credentials target: ${target} (try qbit|arr-ui|admin|api)"
      ;;
  esac
}

credentials_read_password() {
  local mode="$1" out_var="$2" value=""
  case "$mode" in
    --generate)
      value="$(generate_password)"
      ;;
    --prompt)
      if [[ ! -t 0 ]]; then
        die "credentials set --prompt requires a TTY"
      fi
      local confirm=""
      printf 'New password: ' >&2
      # shellcheck disable=SC2162
      read -s value
      printf '\n' >&2
      printf 'Confirm password: ' >&2
      # shellcheck disable=SC2162
      read -s confirm
      printf '\n' >&2
      [[ -n "$value" ]] || die "Password must not be empty"
      [[ "$value" == "$confirm" ]] || die "Passwords do not match"
      ;;
    *)
      die "credentials set requires --generate or --prompt"
      ;;
  esac
  printf -v "$out_var" '%s' "$value"
}

# Apply Forms via Host Config. Password from FLIXBOX_ARR_UI_PASSWORD_OVERRIDE or .env.
# Sets ARR_UI_APPLY_OK / ARR_UI_APPLY_FAIL. Returns 0 only if all three apps succeed.
flixbox_apply_arr_ui_credentials() {
  ARR_UI_APPLY_OK=0
  ARR_UI_APPLY_FAIL=0
  if declare -F load_env >/dev/null 2>&1; then
    load_env
  elif declare -F flixbox_load_configure_env >/dev/null 2>&1; then
    flixbox_load_configure_env
  fi
  if [[ "$(flixbox_access_profile)" != "shared" ]]; then
    warn "arr-ui apply skipped — FLIXBOX_ACCESS_PROFILE=$(flixbox_access_profile) (need shared)"
    return 1
  fi
  local user="${FLIXBOX_ARR_UI_USER:-admin}"
  local pass="${FLIXBOX_ARR_UI_PASSWORD_OVERRIDE:-${FLIXBOX_ARR_UI_PASSWORD:-}}"
  [[ -n "$pass" ]] || { warn "FLIXBOX_ARR_UI_PASSWORD empty — nothing to apply"; return 1; }

  local name port key api_path
  for name in prowlarr radarr sonarr; do
    case "$name" in
      prowlarr)
        port="${PROWLARR_PORT:-9696}"
        key="${PROWLARR_API_KEY:-}"
        api_path="/api/v1/config/host"
        ;;
      radarr)
        port="${RADARR_PORT:-7878}"
        key="${RADARR_API_KEY:-}"
        api_path="/api/v3/config/host"
        ;;
      sonarr)
        port="${SONARR_PORT:-8989}"
        key="${SONARR_API_KEY:-}"
        api_path="/api/v3/config/host"
        ;;
    esac
    if [[ -z "$key" ]]; then
      warn "${name}: missing API key in .env"
      ARR_UI_APPLY_FAIL=$((ARR_UI_APPLY_FAIL + 1))
      continue
    fi
    if ! USERNAME="$user" PASSWORD="$pass" ARR_API_KEY="$key" \
      ARR_HOST_CONFIG_URL="http://127.0.0.1:${port}${api_path}" \
      python3 "${ROOT_DIR}/scripts/lib/arr-host-config-auth.py"; then
      warn "${name}: Host Config Forms apply failed"
      ARR_UI_APPLY_FAIL=$((ARR_UI_APPLY_FAIL + 1))
      continue
    fi
    ok "${name}: Forms credentials applied (Host Config)"
    ARR_UI_APPLY_OK=$((ARR_UI_APPLY_OK + 1))
  done
  [[ "$ARR_UI_APPLY_FAIL" -eq 0 && "$ARR_UI_APPLY_OK" -eq 3 ]]
}

# Exit codes from qbit-password-rotate.sh: 0 verified, 1 unchanged, 3 committed-unverified.
flixbox_apply_qbit_password_rotate() {
  local old_pass="$1" new_pass="$2" rc=0
  [[ -n "$new_pass" ]] || return 1
  QBIT_OLD_PASSWORD="$old_pass" QBIT_NEW_PASSWORD="$new_pass" \
    QBITTORRENT_USERNAME="${QBITTORRENT_USERNAME:-admin}" \
    QBITTORRENT_PORT="${QBITTORRENT_PORT:-8080}" \
    bash "${ROOT_DIR}/scripts/lib/qbit-password-rotate.sh" || rc=$?
  return "$rc"
}

credentials_recreate_decluttarr() {
  if ! docker inspect flixbox-decluttarr >/dev/null 2>&1; then
    warn "Decluttarr container not found — skip recreate"
    return 0
  fi
  log "Recreating Decluttarr to pick up QBITTORRENT_PASSWORD..."
  if docker compose --project-directory "${ROOT_DIR}" up -d --force-recreate --no-deps decluttarr >/dev/null 2>&1; then
    ok "Decluttarr recreated"
  else
    warn "Could not recreate Decluttarr — run: ./bin/flixbox reload"
    return 1
  fi
}

credentials_persist_qbit_password() {
  local env_file="$1" new_pass="$2"
  flixbox_env_file_set "$env_file" QBITTORRENT_PASSWORD "$new_pass"
  [[ -n "$(flixbox_env_file_get "$env_file" QBITTORRENT_USERNAME)" ]] || \
    flixbox_env_file_set "$env_file" QBITTORRENT_USERNAME admin
  ok "Wrote QBITTORRENT_PASSWORD to .env"
  load_env
  credentials_recreate_decluttarr || true
}

credentials_apply_jellyfin_admin_password() {
  local old_pass="$1" new_pass="$2"
  local user="${FLIXBOX_ADMIN_USER:-admin}"
  local port="${JELLYFIN_PORT:-8096}"
  local base="http://127.0.0.1:${port}"

  local auth_body auth_json token user_id code
  auth_body="$(USERNAME="$user" PASSWORD="$old_pass" python3 "${ROOT_DIR}/scripts/lib/json-payload.py" jellyfin-auth)"
  auth_json="$(curl -sS -X POST "${base}/Users/AuthenticateByName" \
    -H 'Content-Type: application/json' \
    -H 'X-Emby-Authorization: MediaBrowser Client="Flixbox", Device="CLI", DeviceId="flixbox-credentials", Version="0.1.0"' \
    --data "$auth_body" 2>/dev/null || true)"
  token="$(echo "$auth_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("AccessToken") or "")' 2>/dev/null || true)"
  user_id="$(echo "$auth_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); u=d.get("User") or {}; print(u.get("Id") or "")' 2>/dev/null || true)"
  if [[ -z "$token" || -z "$user_id" ]]; then
    warn "Jellyfin: could not authenticate with previous FLIXBOX_ADMIN_PASSWORD — .env updated; align password in Jellyfin UI"
    return 1
  fi
  local pw_body
  pw_body="$(CURRENT_PW="$old_pass" NEW_PW="$new_pass" python3 "${ROOT_DIR}/scripts/lib/json-payload.py" jellyfin-password-change)"
  code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST "${base}/Users/${user_id}/Password" \
    -H "Content-Type: application/json" \
    -H "X-Emby-Token: ${token}" \
    --data "$pw_body" 2>/dev/null || echo 000)"
  if [[ "$code" =~ ^2 ]]; then
    ok "Jellyfin: admin password updated"
    return 0
  fi
  warn "Jellyfin: password change HTTP ${code} — .env updated; align in Jellyfin UI if login fails"
  return 1
}

credentials_set() {
  local target="${1:-}"
  [[ -n "$target" ]] || { credentials_usage >&2; return 1; }
  shift
  local mode=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --generate|--prompt) mode="$1"; shift ;;
      *) die "Unknown credentials set option: $1" ;;
    esac
  done
  [[ -n "$mode" ]] || die "credentials set requires --generate or --prompt"

  load_env
  local env_file="${ROOT_DIR}/.env"
  [[ -f "$env_file" ]] || die "Missing .env — run ./bin/flixbox init first"

  local new_pass=""
  credentials_read_password "$mode" new_pass

  case "$target" in
    qbit)
      local old_pass="${QBITTORRENT_PASSWORD:-}"
      local rc=0
      assert_docker_accessible
      log "Rotating qBit WebUI password (auth with current password, then apply new)..."
      flixbox_apply_qbit_password_rotate "$old_pass" "$new_pass" || rc=$?
      case "$rc" in
        0)
          credentials_persist_qbit_password "$env_file" "$new_pass"
          cli_configure_line credentials updated "qbit WebUI password"
          cli_info "If *arr download-client Test fails: ./bin/flixbox configure --sync-qbit-auth"
          ;;
        3)
          warn "qBit accepted the new password but re-auth verify failed — persisting .env so Decluttarr stays aligned"
          credentials_persist_qbit_password "$env_file" "$new_pass"
          cli_configure_line credentials updated "qbit WebUI password (verify incomplete)"
          warn "Confirm WebUI login with: ./bin/flixbox credentials show qbit"
          ;;
        *)
          cli_configure_line credentials failed "qbit rotate"
          die "qBit rotate failed — .env left unchanged. Fix WebUI login / temp password, then retry."
          ;;
      esac
      ;;
    arr-ui)
      if [[ "$(flixbox_access_profile)" != "shared" ]]; then
        die "arr-ui set requires FLIXBOX_ACCESS_PROFILE=shared (current: $(flixbox_access_profile))"
      fi
      assert_docker_accessible
      cli_info "Applying Forms via Host Config before writing .env..."
      FLIXBOX_ARR_UI_PASSWORD_OVERRIDE="$new_pass" \
        FLIXBOX_ARR_UI_USER="${FLIXBOX_ARR_UI_USER:-admin}" \
        flixbox_apply_arr_ui_credentials || true
      if [[ "$ARR_UI_APPLY_OK" -eq 3 ]]; then
        flixbox_env_file_set "$env_file" FLIXBOX_ARR_UI_PASSWORD "$new_pass"
        [[ -n "$(flixbox_env_file_get "$env_file" FLIXBOX_ARR_UI_USER)" ]] || \
          flixbox_env_file_set "$env_file" FLIXBOX_ARR_UI_USER admin
        cli_configure_line credentials updated "arr-ui Forms + .env (3/3)"
        load_env
      elif [[ "$ARR_UI_APPLY_OK" -gt 0 ]]; then
        flixbox_env_file_set "$env_file" FLIXBOX_ARR_UI_PASSWORD "$new_pass"
        [[ -n "$(flixbox_env_file_get "$env_file" FLIXBOX_ARR_UI_USER)" ]] || \
          flixbox_env_file_set "$env_file" FLIXBOX_ARR_UI_USER admin
        cli_configure_line credentials updated "arr-ui .env (partial ${ARR_UI_APPLY_OK}/3)"
        load_env
        die "arr-ui: applied on ${ARR_UI_APPLY_OK}/3 apps — retry: ./bin/flixbox configure --sync-arr-ui"
      else
        cli_configure_line credentials failed "arr-ui Host Config apply"
        die "arr-ui: Host Config apply failed on all apps — .env left unchanged"
      fi
      ;;
    admin)
      local old_pass="${FLIXBOX_ADMIN_PASSWORD:-}"
      flixbox_env_file_set "$env_file" FLIXBOX_ADMIN_PASSWORD "$new_pass"
      [[ -n "$(flixbox_env_file_get "$env_file" FLIXBOX_ADMIN_USER)" ]] || \
        flixbox_env_file_set "$env_file" FLIXBOX_ADMIN_USER admin
      cli_configure_line credentials updated "admin password in .env"
      load_env
      if [[ -n "$old_pass" ]]; then
        if credentials_apply_jellyfin_admin_password "$old_pass" "$new_pass"; then
          cli_configure_line credentials updated "Jellyfin admin password"
        else
          cli_configure_line credentials failed "Jellyfin admin password API ( .env already written )"
        fi
      else
        cli_configure_line credentials skipped "Jellyfin API (no previous password)"
        warn "No previous FLIXBOX_ADMIN_PASSWORD — skipped Jellyfin API change; complete/align in Jellyfin UI"
      fi
      cli_info "If Seerr Jellyfin login breaks: ./bin/flixbox configure"
      ;;
    api)
      die "credentials set api is not supported — regenerate in the app UI then ./bin/flixbox configure"
      ;;
    *)
      die "Unknown credentials target: ${target}"
      ;;
  esac
}

cmd_credentials() {
  local sub="${1:-}"
  [[ -n "$sub" ]] || { credentials_usage; return 1; }
  shift || true
  case "$sub" in
    show) credentials_show "$@" ;;
    set) credentials_set "$@" ;;
    -h|--help|help) credentials_usage ;;
    *) die "Unknown credentials subcommand: ${sub} (show|set)" ;;
  esac
}
