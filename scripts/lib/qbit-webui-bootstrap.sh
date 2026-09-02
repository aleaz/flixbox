#!/usr/bin/env bash
# Host-side qBit WebUI bootstrap (ADR 0019).
# Session temp passwords appear in docker logs only (never written to disk).
# shellcheck shell=bash

flixbox_qbit_webui_repo_root() {
  local candidate
  if [[ -n "${ROOT_DIR:-}" && -f "${ROOT_DIR}/templates/qbittorrent/webui-security-prefs.json" ]]; then
    printf '%s\n' "$ROOT_DIR"
    return 0
  fi
  # bash-only; when sourced under zsh without ROOT_DIR, fall back to PWD
  if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    if [[ -f "${candidate}/templates/qbittorrent/webui-security-prefs.json" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi
  if [[ -f "${PWD}/templates/qbittorrent/webui-security-prefs.json" ]]; then
    printf '%s\n' "$PWD"
    return 0
  fi
  return 1
}

flixbox_qbit_webui_security_prefs_file() {
  local root
  root="$(flixbox_qbit_webui_repo_root)" || return 1
  if [[ "${VPN_PORT_FORWARDING:-off}" == "on" ]]; then
    printf '%s\n' "${root}/templates/qbittorrent/webui-security-prefs-portforward.json"
  else
    printf '%s\n' "${root}/templates/qbittorrent/webui-security-prefs.json"
  fi
}

flixbox_qbit_webui_bootstrap() {
  local container="${QBIT_DOCKER_CONTAINER:-flixbox-qbittorrent}"
  local user="${QBITTORRENT_USERNAME:-admin}"
  local pass="${QBITTORRENT_PASSWORD:-}"
  local config_dir="${CONFIG_DIR:-}"
  local temp prefs_json prefs_file
  local api="http://127.0.0.1:8080/api/v2"
  local cookie="/tmp/flixbox-host-bootstrap-cookie.txt"
  local login_script="/config/.flixbox/qbit-api-login.sh"

  if [[ -z "$config_dir" ]] || ! docker inspect "$container" >/dev/null 2>&1; then
    return 0
  fi

  # Wait briefly for WebUI (health may already be green).
  for _ in $(seq 1 30); do
    if docker exec "$container" curl -fsS -o /dev/null --max-time 3 http://127.0.0.1:8080/ 2>/dev/null; then
      break
    fi
    sleep 2
  done

  mkdir -p "${config_dir}/qbittorrent/.flixbox"
  # Remove legacy plaintext temp-password file from older builds.
  rm -f "${config_dir}/qbittorrent/.flixbox/session-temp-password" 2>/dev/null || true

  temp="$(
    docker logs "$container" 2>&1 \
      | grep -iE 'temporary password is provided for this session:' \
      | tail -1 \
      | awk '{print $NF}' || true
  )"

  if [[ -z "$pass" ]]; then
    if command -v warn >/dev/null 2>&1; then
      warn "qBit WebUI bootstrap: QBITTORRENT_PASSWORD empty — skip"
    fi
    return 0
  fi

  _flixbox_bootstrap_login() {
    local try_pass="$1" rc=0
    docker exec "$container" rm -f "$cookie" 2>/dev/null || true
    # Credentials via stdin to login helper — never on docker exec argv.
    # Helper exit 2 = WebUI IP banned.
    printf '%s\n%s\n' "$user" "$try_pass" | docker exec -i "$container" \
      "$login_script" "$cookie" "http://127.0.0.1:8080" 2>/dev/null || rc=$?
    case "$rc" in
      0) return 0 ;;
      2) return 2 ;;
      *) return 1 ;;
    esac
  }

  local rc=1
  _flixbox_bootstrap_login "$pass"
  rc=$?
  if [[ "$rc" -eq 2 ]]; then
    if command -v warn >/dev/null 2>&1; then
      warn "qBit WebUI banned — ./bin/flixbox restart qbittorrent then re-run up/configure"
    fi
    return 1
  fi
  if [[ "$rc" -ne 0 && -n "$temp" && "$temp" != "$pass" ]]; then
    _flixbox_bootstrap_login "$temp"
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      local pw_json
      pw_json="$(PASSWORD="$pass" python3 -c 'import json,os; print(json.dumps({"web_ui_password":os.environ["PASSWORD"]}))')"
      printf '%s' "$pw_json" | docker exec -i "$container" sh -c \
        "curl -sf -b '$cookie' -o /dev/null --max-time 15 -X POST --data-urlencode json@- '${api}/app/setPreferences'" \
        >/dev/null 2>&1 || true
      docker exec "$container" rm -f "$cookie" 2>/dev/null || true
      _flixbox_bootstrap_login "$pass"
      rc=$?
      if [[ "$rc" -eq 0 ]]; then
        if command -v ok >/dev/null 2>&1; then
          ok "qBit WebUI password aligned from temporary session"
        fi
      fi
    elif [[ "$rc" -eq 2 ]]; then
      if command -v warn >/dev/null 2>&1; then
        warn "qBit WebUI banned — ./bin/flixbox restart qbittorrent then re-run up/configure"
      fi
      return 1
    fi
  fi

  if [[ "$rc" -ne 0 ]]; then
    if command -v warn >/dev/null 2>&1; then
      warn "qBit WebUI bootstrap: auth pending — configure --sync-qbit-auth"
    fi
    return 1
  fi

  prefs_file="$(flixbox_qbit_webui_security_prefs_file)"
  if [[ ! -f "$prefs_file" ]]; then
    if command -v warn >/dev/null 2>&1; then
      warn "qBit WebUI bootstrap: missing prefs template ${prefs_file}"
    fi
    return 1
  fi
  prefs_json="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1], encoding="utf-8"))))' "$prefs_file")"
  if printf '%s' "$prefs_json" | docker exec -i "$container" sh -c \
    "curl -sf -b '$cookie' -o /dev/null --max-time 15 -X POST --data-urlencode json@- '${api}/app/setPreferences'" \
    >/dev/null 2>&1; then
    if command -v ok >/dev/null 2>&1; then
      ok "qBit WebUI security contract applied"
    fi
  else
    if command -v warn >/dev/null 2>&1; then
      warn "qBit WebUI bootstrap: security prefs not applied"
    fi
  fi
  docker exec "$container" rm -f "$cookie" 2>/dev/null || true
  return 0
}
