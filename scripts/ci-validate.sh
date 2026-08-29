#!/usr/bin/env bash
# Enforce Flixbox architecture contracts in CI and locally.
# See docs/10-ci-plan.md for check IDs (C-01 … C-42).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CI_ENV="${ROOT_DIR}/.ci-env"
COMPOSE=(docker compose --env-file "${CI_ENV}")

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  exit 1
}

pass() {
  printf 'OK   %s\n' "$1"
}

sed_inplace() {
  if [[ "$(uname -s)" == Darwin ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

write_ci_env() {
  cp -f "${ROOT_DIR}/.env.example" "${CI_ENV}"
  sed_inplace \
    's|^DATA_DIR=.*|DATA_DIR=/tmp/flixbox-ci/data|; s|^CONFIG_DIR=.*|CONFIG_DIR=/tmp/flixbox-ci/config|' \
    "${CI_ENV}"
}

cleanup() {
  rm -f "${CI_ENV}"
  rm -rf /tmp/flixbox-ci
}

trap cleanup EXIT

write_ci_env

# --- C-01: compose file line limits (ADR 0003) ---
for f in compose/*.yml compose.yaml; do
  lines="$(wc -l <"${f}")"
  if [[ "${lines}" -gt 150 ]]; then
    fail C-01 "${f} has ${lines} lines (max 150)"
  fi
done
pass C-01

# --- C-02: root uses include ---
grep -q '^include:' compose.yaml || fail C-02 'compose.yaml missing include:'
pass C-02

# --- C-03: FLIXBOX_MODE downloader include ---
grep -qE 'downloaders-\$\{FLIXBOX_MODE' compose.yaml || \
  fail C-03 'compose.yaml missing downloaders FLIXBOX_MODE include'
pass C-03

# --- C-10: /data mount on download and *arr services ---
for f in compose/downloaders-direct.yml compose/downloaders-vpn.yml compose/servarr.yml; do
  grep -qE '\$\{DATA_DIR[^}]*\}:/data' "${f}" || \
    fail C-10 "${f} missing DATA_DIR:/data mount"
done
pass C-10

# --- C-11: torrents/incomplete in bootstrap ---
grep -q 'torrents/incomplete' scripts/bootstrap-dirs.sh || \
  fail C-11 'bootstrap-dirs.sh missing torrents/incomplete'
pass C-11

# --- C-12: Unpackerr torrent path ---
grep -q '/data/torrents' compose/optimization.yml || \
  fail C-12 'optimization.yml missing /data/torrents for Unpackerr'
pass C-12

# --- C-20: Gluetun netns only on qBittorrent in VPN module ---
gluetun_hits="$(grep -rl 'network_mode: service:gluetun' compose/ || true)"
if [[ "${gluetun_hits}" != "compose/downloaders-vpn.yml" ]]; then
  fail C-20 "network_mode: service:gluetun must appear only in downloaders-vpn.yml (found: ${gluetun_hits:-none})"
fi
pass C-20

# --- C-21: *arr / Seerr / Jellyfin not on Gluetun netns ---
for f in compose/servarr.yml compose/requests.yml compose/media-servers.yml; do
  if grep -q 'network_mode: service:gluetun' "${f}"; then
    fail C-21 "${f} must not use Gluetun netns"
  fi
done
pass C-21

# --- C-22: Gluetun publishes qBit ports ---
grep -q 'QBITTORRENT_PORT' compose/downloaders-vpn.yml || \
  fail C-22 'downloaders-vpn.yml missing published qBit ports on gluetun'
pass C-22

# --- C-23: Gluetun healthcheck + qBit depends_on ---
grep -q 'healthcheck:' compose/downloaders-vpn.yml || fail C-23 'missing Gluetun healthcheck'
grep -q 'condition: service_healthy' compose/downloaders-vpn.yml || \
  fail C-23 'missing qBittorrent depends_on gluetun healthy'
pass C-23

# --- C-24: qBit cont-init mounted at linuxserver path (not legacy /config/...) ---
for f in compose/downloaders-direct.yml compose/downloaders-vpn.yml; do
  grep -q 'qbittorrent-cont-init:/custom-cont-init.d' "${f}" || \
    fail C-24 "${f} missing qbittorrent-cont-init:/custom-cont-init.d mount"
done
[[ -f templates/qbittorrent/custom-cont-init.d/99-flixbox-qbittorrent.sh ]] || \
  fail C-24 'missing templates/qbittorrent/custom-cont-init.d/99-flixbox-qbittorrent.sh'
pass C-24

# --- C-25: flixbox_net fixed subnet + qBit auth whitelist (ADR 0008) ---
grep -q '172.30.42.0/24' compose/network-base.yml || \
  fail C-25 'flixbox_net missing fixed subnet 172.30.42.0/24'
grep -q "WebUI\\\\AuthSubnetWhitelistEnabled" templates/qbittorrent/custom-cont-init.d/99-flixbox-qbittorrent.sh || \
  fail C-25 'qBit cont-init missing AuthSubnetWhitelistEnabled'
grep -q '172.30.42.0/24' templates/qbittorrent/custom-cont-init.d/99-flixbox-qbittorrent.sh || \
  fail C-25 'qBit cont-init missing flixbox_net whitelist CIDR'
pass C-25

# --- C-26: Decluttarr idle entrypoint (runtime env; no Compose command secrets) ---
[[ -f templates/decluttarr/entrypoint.sh ]] || \
  fail C-26 'missing templates/decluttarr/entrypoint.sh'
grep -q 'decluttarr-entrypoint.sh:/flixbox-entrypoint.sh' compose/optimization.yml || \
  fail C-26 'Decluttarr missing entrypoint mount'
grep -q 'entrypoint: \["/bin/sh", "/flixbox-entrypoint.sh"\]' compose/optimization.yml || \
  fail C-26 'Decluttarr missing flixbox entrypoint'
# Guard against baking secrets into Compose command: strings
if grep -A20 'decluttarr:' compose/optimization.yml | grep -q 'command:'; then
  if grep -A40 'decluttarr:' compose/optimization.yml | grep -q '\${QBITTORRENT_PASSWORD'; then
    fail C-26 'Decluttarr must not interpolate QBITTORRENT_PASSWORD into command'
  fi
fi
pass C-26

# --- C-27: qBit WebUI healthcheck + consumers wait ---
for f in compose/downloaders-direct.yml compose/downloaders-vpn.yml; do
  grep -q 'healthcheck:' "${f}" || fail C-27 "${f} missing qBittorrent healthcheck"
  grep -q 'api/v2/app/version' "${f}" || fail C-27 "${f} healthcheck must probe WebUI API"
done
for f in compose/servarr.yml compose/optimization.yml; do
  grep -q 'condition: service_healthy' "${f}" || \
    fail C-27 "${f} missing depends_on qbittorrent healthy"
done
pass C-27

# --- C-30: banned default images ---
while IFS= read -r line; do
  lower="$(echo "${line}" | tr '[:upper:]' '[:lower:]')"
  if echo "${lower}" | grep -qE 'image:.*(jellyseerr|overseerr|flaresolverr)'; then
    fail C-30 "banned image reference: ${line}"
  fi
done < <(grep -h '^[[:space:]]*image:' compose/*.yml || true)
pass C-30

# --- C-31: core services in direct mode ---
direct_services="$("${COMPOSE[@]}" config --services | sort)"
required_direct=(
  bazarr byparr decluttarr homepage jellyfin maintainerr
  prowlarr qbittorrent radarr seerr sonarr unpackerr
)
for svc in "${required_direct[@]}"; do
  echo "${direct_services}" | grep -qx "${svc}" || \
    fail C-31 "direct mode missing service: ${svc}"
done
pass C-31

# --- C-32: VPN mode adds gluetun ---
vpn_services="$(FLIXBOX_MODE=vpn "${COMPOSE[@]}" config --services | sort)"
echo "${vpn_services}" | grep -qx gluetun || fail C-32 'vpn mode missing gluetun'
pass C-32

# --- C-33: Seerr init ---
grep -q 'init: true' compose/requests.yml || fail C-33 'Seerr missing init: true'
pass C-33

# --- C-40 / C-41: Decluttarr hygiene defaults ---
grep -qE '(NO_STALLED_REMOVAL_QBIT_TAG|PROTECTED_TAG): flixbox-keep' compose/optimization.yml || \
  fail C-40 'Decluttarr missing flixbox-keep protect tag'
grep -q 'REMOVE_UNMONITORED: "False"' compose/optimization.yml || \
  fail C-41 'Decluttarr REMOVE_UNMONITORED must be False'
pass C-40
pass C-41

# --- C-42: stop_grace_period on stateful services ---
grace_count=0
for f in compose/*.yml; do
  n="$(grep -c 'stop_grace_period:' "${f}" || true)"
  grace_count=$((grace_count + n))
done
if [[ "${grace_count}" -lt 10 ]]; then
  fail C-42 "expected ≥10 stop_grace_period entries, found ${grace_count}"
fi
pass C-42

# --- Compose quiet config (direct + vpn + profiles) ---
"${COMPOSE[@]}" config --quiet
FLIXBOX_MODE=vpn "${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" --profile plex --profile proxy --profile socket-proxy --profile recyclarr config --quiet
pass compose-config

printf 'All contract checks passed.\n'
