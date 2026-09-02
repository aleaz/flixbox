#!/usr/bin/env bash
#
# Host port preflight before compose up/reload.
# Requires flixbox_load_env / load_env already applied.
# Ports already published by running flixbox-* containers are allowed
# (reload / re-up of the same stack must not fail on itself).

flixbox_preflight_host_ports() {
  local bind_ip="${FLIXBOX_ADMIN_BIND_IP:-0.0.0.0}"
  local failed=0
  local ours_ports=""

  # Host ports currently published by flixbox-* containers (TCP/UDP publish maps).
  ours_ports="$(
    docker ps --filter name=flixbox- --format '{{.Ports}}' 2>/dev/null \
      | python3 -c '
import re, sys
ports = set()
for line in sys.stdin:
    for m in re.finditer(r"(?:^|[\s,])(?:[0-9.]+:)?(\d+)->", line):
        ports.add(m.group(1))
print(" ".join(sorted(ports)))
' 2>/dev/null || true
  )"

  # Returns 0 when the port is free on probe_host, 1 when already bound.
  _flixbox_port_is_free() {
    local probe_host="$1" port="$2"
    python3 - "$probe_host" "$port" <<'PY'
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
sys.exit(0)
PY
  }

  _flixbox_port_owned_by_stack() {
    local port="$1" p
    for p in ${ours_ports}; do
      [[ "$p" == "$port" ]] && return 0
    done
    return 1
  }

  _flixbox_port_hint() {
    case "$1" in
      QBITTORRENT_PORT) echo "9898" ;;
      QBITTORRENT_BT_PORT) echo "6882" ;;
      PROWLARR_PORT) echo "9697" ;;
      BYPARR_PORT) echo "8192" ;;
      RADARR_PORT) echo "7879" ;;
      SONARR_PORT) echo "8990" ;;
      BAZARR_PORT) echo "6768" ;;
      JELLYFIN_PORT) echo "8097" ;;
      SEERR_PORT) echo "5056" ;;
      HOMEPAGE_PORT) echo "3001" ;;
      MAINTAINERR_PORT) echo "6247" ;;
      *) echo "$(( ${2:-8080} + 1 ))" ;;
    esac
  }

  _flixbox_check_port() {
    local env_var="$1" port="$2" service="$3" probe_host="${4:-$bind_ip}"
    [[ -n "$port" ]] || return 0
    if ! _flixbox_port_is_free "$probe_host" "$port"; then
      # Already bound by this Flixbox stack — OK for reload / re-up.
      if _flixbox_port_owned_by_stack "$port"; then
        return 0
      fi
      local hint
      hint=$(_flixbox_port_hint "$env_var" "$port")
      warn "Port ${port} (${service}) is already in use (bind ${probe_host})."
      warn "  Set a free port in .env, e.g. ${env_var}=${hint}, then: ./bin/flixbox reload"
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
  # Jellyfin stays on all interfaces in shared profile (household app) — always probe 0.0.0.0.
  _flixbox_check_port JELLYFIN_PORT "${JELLYFIN_PORT:-8096}" "Jellyfin" "0.0.0.0"
  _flixbox_check_port SEERR_PORT "${SEERR_PORT:-5055}" "Seerr" "0.0.0.0"
  _flixbox_check_port HOMEPAGE_PORT "${HOMEPAGE_PORT:-3000}" "Homepage" "0.0.0.0"
  _flixbox_check_port MAINTAINERR_PORT "${MAINTAINERR_PORT:-6246}" "Maintainerr"

  if [[ "$failed" -ne 0 ]]; then
    die "Host port preflight failed — fix .env ports before starting the stack."
  fi
}
