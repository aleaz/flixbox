#!/usr/bin/env bash
# VPN structural smoke (ADR 0013 / C-74).
# Validates VPN compose contract without live provider credentials.
#
# Usage:
#   CI_VPN_SMOKE=1 ./scripts/ci-smoke-vpn.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CI_ENV="${ROOT_DIR}/.ci-vpn-env"

pass() { printf 'OK   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }

if [[ "${CI_VPN_SMOKE:-0}" != 1 && "${FLIXBOX_CI_VPN_SMOKE:-0}" != 1 ]]; then
  echo "Skip VPN structural smoke (set CI_VPN_SMOKE=1 to run)."
  exit 0
fi

command -v docker >/dev/null || fail "docker required"
docker compose version >/dev/null 2>&1 || fail "docker compose required"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/env-file.sh"

cleanup() {
  rm -f "${CI_ENV}"
}
trap cleanup EXIT

cp -f "${ROOT_DIR}/.env.example" "${CI_ENV}"
flixbox_env_file_set "${CI_ENV}" DATA_DIR /tmp/flixbox-ci-vpn/data
flixbox_env_file_set "${CI_ENV}" CONFIG_DIR /tmp/flixbox-ci-vpn/config
flixbox_env_file_set "${CI_ENV}" FLIXBOX_MODE vpn
flixbox_env_file_set "${CI_ENV}" VPN_ENABLED true
flixbox_env_file_set "${CI_ENV}" VPN_SERVICE_PROVIDER protonvpn
flixbox_env_file_set "${CI_ENV}" VPN_TYPE wireguard

COMPOSE=(docker compose --env-file "${CI_ENV}")

"${COMPOSE[@]}" config --quiet || fail "vpn mode compose config failed"
pass "vpn compose config render"

config_yaml="$("${COMPOSE[@]}" config)"
echo "$config_yaml" | grep -q 'network_mode: service:gluetun' || \
  fail "qbittorrent must use network_mode: service:gluetun in VPN mode"
echo "$config_yaml" | grep -q 'container_name: flixbox-gluetun' || \
  fail "gluetun service missing in VPN mode"
pass "vpn qbit netns contract"

services="$("${COMPOSE[@]}" config --services)"
echo "$services" | grep -qx gluetun || fail "vpn services must include gluetun"
echo "$services" | grep -qx qbittorrent || fail "vpn services must include qbittorrent"
pass "vpn service inventory"

# Gluetun network alias qbittorrent (ADR 0014)
net_cfg="$("${COMPOSE[@]}" config --format json)"
python3 -c '
import json, sys
cfg = json.load(sys.stdin)
gluetun = cfg.get("services", {}).get("gluetun", {})
aliases = (gluetun.get("networks") or {}).get("flixbox_net", {})
if isinstance(aliases, dict):
    aliases = aliases.get("aliases") or []
if "qbittorrent" not in aliases:
    sys.exit("gluetun must alias qbittorrent on flixbox_net")
' <<<"$net_cfg" || fail "gluetun qbittorrent alias missing"
pass "gluetun qbittorrent alias"

printf '\nVPN structural smoke passed.\n'
