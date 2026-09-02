#!/usr/bin/env bash
#
# Host port preflight before compose up/reload (R1 / C-72).
# Requires flixbox_load_env / load_env already applied.

flixbox_preflight_host_ports() {
  local bind_ip="${FLIXBOX_ADMIN_BIND_IP:-0.0.0.0}"
  local failed=0

  _flixbox_port_in_use() {
    local port="$1"
    python3 - "$bind_ip" "$port" <<'PY'
import socket, sys
bind_ip, port = sys.argv[1], int(sys.argv[2])
host = "" if bind_ip in ("0.0.0.0", "::") else bind_ip
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind((host, port))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
  }

  _flixbox_check_port() {
    local env_var="$1" port="$2" service="$3"
    [[ -n "$port" ]] || return 0
    if _flixbox_port_in_use "$port"; then
      warn "Port ${port} (${service}) is already in use (bind ${bind_ip})."
      warn "  Set a free port in .env, e.g. ${env_var}=9898, then: ./bin/flixbox reload"
      warn "  Guide: docs/user/05-first-run.md#host-port-conflicts"
      failed=1
    fi
  }

  _flixbox_check_port QBITTORRENT_PORT "${QBITTORRENT_PORT:-8080}" "qBittorrent WebUI"
  _flixbox_check_port QBITTORRENT_BT_PORT "${QBITTORRENT_BT_PORT:-6881}" "qBittorrent BitTorrent"
  _flixbox_check_port PROWLARR_PORT "${PROWLARR_PORT:-9696}" "Prowlarr"
  _flixbox_check_port BYPARR_PORT "${BYPARR_PORT:-8191}" "Byparr"
  _flixbox_check_port RADARR_PORT "${RADARR_PORT:-7878}" "Radarr"
  _flixbox_check_port SONARR_PORT "${SONARR_PORT:-8989}" "Sonarr"
  _flixbox_check_port BAZARR_PORT "${BAZARR_PORT:-6767}" "Bazarr"
  _flixbox_check_port JELLYFIN_PORT "${JELLYFIN_PORT:-8096}" "Jellyfin"
  _flixbox_check_port SEERR_PORT "${SEERR_PORT:-5055}" "Seerr"
  _flixbox_check_port HOMEPAGE_PORT "${HOMEPAGE_PORT:-3000}" "Homepage"
  _flixbox_check_port MAINTAINERR_PORT "${MAINTAINERR_PORT:-6246}" "Maintainerr"

  if [[ "$failed" -ne 0 ]]; then
    die "Host port preflight failed — fix .env ports before starting the stack."
  fi
}
