#!/usr/bin/env bash
# Probe public IP from the active downloader network namespace (VPN or Direct).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1090
  source <(grep -E '^[A-Z_]+=.*' .env | sed 's/\r$//')
  set +a
fi

MODE="${FLIXBOX_MODE:-direct}"
VPN_ENABLED="${VPN_ENABLED:-false}"
echo "FLIXBOX_MODE=${MODE}"
echo "VPN_ENABLED=${VPN_ENABLED}"

expected="false"
[[ "${MODE}" == "vpn" ]] && expected="true"
if [[ "${VPN_ENABLED}" != "${expected}" ]]; then
  echo "Warning: FLIXBOX_MODE and VPN_ENABLED disagree (expected VPN_ENABLED=${expected})." >&2
  echo "Compose follows FLIXBOX_MODE only. Run: ./bin/flixbox init --non-interactive" >&2
fi

if [[ "${MODE}" == "vpn" ]]; then
  TARGET=flixbox-gluetun
  echo "Expect: public IP differs from your ISP (tunnel up)."
else
  TARGET=flixbox-qbittorrent
  echo "Expect: public IP is your normal ISP (Direct mode)."
fi

if ! docker ps --format '{{.Names}}' | grep -qx "${TARGET}"; then
  echo "Error: container ${TARGET} is not running. Start with: docker compose up -d" >&2
  exit 1
fi

echo "--- public IP (ifconfig.io) ---"
docker exec "${TARGET}" wget -qO- https://ifconfig.io || docker exec "${TARGET}" curl -sf https://ifconfig.io || {
  echo "Error: could not fetch public IP from ${TARGET}" >&2
  exit 1
}
echo
