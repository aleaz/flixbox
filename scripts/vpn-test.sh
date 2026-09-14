#!/usr/bin/env bash
# Probe public IP from the active downloader network namespace (VPN or Direct).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/flixbox-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/cli-msg.sh"

flixbox_load_env
MODE="${FLIXBOX_MODE}"
VPN="${VPN_ENABLED:-false}"

cli_kv mode "${MODE}"
cli_kv vpn_enabled "${VPN}"

expected="false"
[[ "${MODE}" == "vpn" ]] && expected="true"
if [[ "${VPN}" != "${expected}" ]]; then
  cli_warn "mode ↔ VPN misaligned (expected vpn_enabled=${expected}); Compose follows mode only"
  cli_warn "Fix: ./bin/flixbox init --non-interactive"
fi

if [[ "${MODE}" == "vpn" ]]; then
  TARGET=flixbox-gluetun
  cli_kv expect "egress IP ≠ ISP (tunnel)"
else
  TARGET=flixbox-qbittorrent
  cli_kv expect "egress IP = ISP (Direct)"
fi
cli_kv probe_target "${TARGET}"

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "${TARGET}"; then
  cli_die 5 "container ${TARGET} is not running — ./bin/flixbox up"
fi

ip=""
ip="$(docker exec "${TARGET}" wget -qO- https://ifconfig.io 2>/dev/null || true)"
if [[ -z "$ip" ]]; then
  ip="$(docker exec "${TARGET}" curl -sf https://ifconfig.io 2>/dev/null || true)"
fi
ip="$(printf '%s' "$ip" | tr -d '[:space:]')"
if [[ -z "$ip" ]]; then
  cli_die 5 "could not fetch public IP from ${TARGET}"
fi
cli_kv public_ip "${ip}"
