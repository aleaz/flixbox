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
import errno, socket, sys
bind_ip, port = sys.argv[1], int(sys.argv[2])
host = "" if bind_ip in ("0.0.0.0", "::") else bind_ip
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind((host, port))
except OSError as e:
    if e.errno == errno.EACCES:
        # Privileged port (<1024) unprivileged bind restriction on host.
        # Check /proc/net/tcp for active LISTEN sockets, fallback to connect probe.
        hex_port = f"{port:04X}"
        found_proc = False
        for path in ("/proc/net/tcp", "/proc/net/tcp6"):
            try:
                with open(path) as f:
                    found_proc = True
                    for line in f:
                        parts = line.strip().split()
                        if len(parts) >= 4 and parts[3] == "0A":
                            if parts[1].endswith(":" + hex_port):
                                sys.exit(1)
            except Exception:
                pass
        if found_proc:
            sys.exit(0)
        c = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        c.settimeout(0.2)
        try:
            c.connect((host or "127.0.0.1", port))
            sys.exit(1)
        except OSError:
            sys.exit(0)
        finally:
            c.close()
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
      warn "Port ${port} (${service}) is already in use by another process on host (bind ${probe_host})."
      warn "  Set a free port in .env, e.g. ${env_var}=${hint}, then: ./bin/flixbox reload"
      warn "  Guide: docs/user/05-first-run.md#host-port-conflicts"
      failed=1
    fi
  }

  local port_entries=()
  _flixbox_add_port() {
    local v="$1" p="$2" s="$3" h="${4:-$bind_ip}"
    [[ -n "$p" ]] || return 0
    port_entries+=("${v}:${p}:${s}:${h}")
  }

  _flixbox_is_valid_port() {
    local p="${1:-}"
    [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 ))
  }

  _flixbox_add_port QBITTORRENT_PORT "${QBITTORRENT_PORT:-8080}" "qBittorrent WebUI" "${bind_ip}"
  _flixbox_add_port QBITTORRENT_BT_PORT "${QBITTORRENT_BT_PORT:-6881}" "qBittorrent BitTorrent" "0.0.0.0"
  _flixbox_add_port PROWLARR_PORT "${PROWLARR_PORT:-9696}" "Prowlarr" "${bind_ip}"
  _flixbox_add_port BYPARR_PORT "${BYPARR_PORT:-8191}" "Byparr" "${bind_ip}"
  _flixbox_add_port RADARR_PORT "${RADARR_PORT:-7878}" "Radarr" "${bind_ip}"
  _flixbox_add_port SONARR_PORT "${SONARR_PORT:-8989}" "Sonarr" "${bind_ip}"
  _flixbox_add_port BAZARR_PORT "${BAZARR_PORT:-6767}" "Bazarr" "${bind_ip}"
  # Jellyfin stays on all interfaces in shared profile (household app) — always probe 0.0.0.0.
  _flixbox_add_port JELLYFIN_PORT "${JELLYFIN_PORT:-8096}" "Jellyfin" "0.0.0.0"
  _flixbox_add_port SEERR_PORT "${SEERR_PORT:-5055}" "Seerr" "0.0.0.0"
  _flixbox_add_port HOMEPAGE_PORT "${HOMEPAGE_PORT:-3000}" "Homepage" "0.0.0.0"
  _flixbox_add_port MAINTAINERR_PORT "${MAINTAINERR_PORT:-6246}" "Maintainerr" "${bind_ip}"
  # Optional profiles: probe ports only when that profile is active
  local active_profiles=" $* "
  if [[ "$active_profiles" =~ (proxy|--profile[[:space:]]+proxy) ]]; then
    _flixbox_add_port CADDY_HTTP_PORT "${CADDY_HTTP_PORT:-80}" "Caddy HTTP" "0.0.0.0"
    _flixbox_add_port CADDY_HTTPS_PORT "${CADDY_HTTPS_PORT:-443}" "Caddy HTTPS" "0.0.0.0"
  fi
  if [[ "$active_profiles" =~ (plex|--profile[[:space:]]+plex) ]]; then
    _flixbox_add_port PLEX_PORT "${PLEX_PORT:-32400}" "Plex" "0.0.0.0"
  fi

  # Phase 1: Validate numeric format (1..65535)
  local entry env_var port service probe_host
  for entry in "${port_entries[@]}"; do
    IFS=':' read -r env_var port service probe_host <<< "$entry"
    if ! _flixbox_is_valid_port "$port"; then
      warn "Invalid port value for ${env_var}: '${port}' (must be an integer between 1 and 65535)."
      failed=1
    fi
  done

  # Phase 2: Detect internal port collisions within .env configuration
  local i j count="${#port_entries[@]}"
  local var_i port_i svc_i host_i var_j port_j svc_j host_j
  local conflicted_ports=()

  for (( i=0; i<count; i++ )); do
    IFS=':' read -r var_i port_i svc_i host_i <<< "${port_entries[i]}"
    _flixbox_is_valid_port "$port_i" || continue

    local already_reported=0 p
    for p in "${conflicted_ports[@]}"; do
      if [[ "$p" == "$port_i" ]]; then
        already_reported=1
        break
      fi
    done
    [[ "$already_reported" -eq 1 ]] && continue

    local duplicates=()
    for (( j=i+1; j<count; j++ )); do
      IFS=':' read -r var_j port_j svc_j host_j <<< "${port_entries[j]}"
      if [[ "$port_i" == "$port_j" ]]; then
        if [[ "$host_i" == "0.0.0.0" || "$host_j" == "0.0.0.0" || "$host_i" == "$host_j" ]]; then
          duplicates+=("${var_j} (${svc_j})")
        fi
      fi
    done

    if [[ ${#duplicates[@]} -gt 0 ]]; then
      conflicted_ports+=("$port_i")
      failed=1
      local hint
      hint=$(_flixbox_port_hint "$var_i" "$port_i")
      warn "Port collision in .env configuration:"
      warn "  Port ${port_i} is assigned to multiple services:"
      warn "    - ${var_i} (${svc_i})"
      local dup
      for dup in "${duplicates[@]}"; do
        warn "    - ${dup}"
      done
      warn "  Each service must have a unique host port. Example fix: ${var_i}=${hint}"
      warn "  Guide: docs/user/05-first-run.md#host-port-conflicts"
    fi
  done

  # Phase 3: Probe availability of valid, non-conflicted ports against the host
  for entry in "${port_entries[@]}"; do
    IFS=':' read -r env_var port service probe_host <<< "$entry"
    _flixbox_is_valid_port "$port" || continue

    local is_conflicted=0 p
    for p in "${conflicted_ports[@]}"; do
      if [[ "$p" == "$port" ]]; then
        is_conflicted=1
        break
      fi
    done
    [[ "$is_conflicted" -eq 1 ]] && continue

    _flixbox_check_port "$env_var" "$port" "$service" "$probe_host"
  done

  if [[ "$failed" -ne 0 ]]; then
    die_config "Host port preflight failed — fix .env ports before starting the stack."
  fi
}
