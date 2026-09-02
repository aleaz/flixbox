#!/usr/bin/env bash
# Enforce Flixbox architecture contracts in CI and locally.
# See docs/10-ci-plan.md for check IDs (C-01 … C-63).
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

# --- C-28: CLI warns when FLIXBOX_MODE and VPN_ENABLED disagree ---
grep -q 'warn_mode_vpn_mismatch' bin/flixbox || \
  fail C-28 'bin/flixbox missing warn_mode_vpn_mismatch'
grep -A80 '^cmd_up()' bin/flixbox | grep -q 'warn_mode_vpn_mismatch' || \
  fail C-28 'cmd_up must call warn_mode_vpn_mismatch'
grep -A40 '^cmd_status()' bin/flixbox | grep -q 'warn_mode_vpn_mismatch' || \
  fail C-28 'cmd_status must call warn_mode_vpn_mismatch'
grep -A60 '^cmd_init()' bin/flixbox | grep -q 'mode_vpn_aligned\|warn_mode_vpn_mismatch' || \
  fail C-28 'cmd_init must check mode/VPN_ENABLED alignment'
pass C-28

# --- C-29: VPN mode Gluetun alias qbittorrent (ADR 0014) ---
grep -q 'aliases:' compose/downloaders-vpn.yml || fail C-29 'downloaders-vpn.yml missing network aliases'
grep -A3 'aliases:' compose/downloaders-vpn.yml | grep -q 'qbittorrent' || \
  fail C-29 'Gluetun missing qbittorrent network alias'
pass C-29

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

# --- C-24b: VPN-only tun0 bind sidecar (ADR 0002) ---
grep -q 'qbittorrent-custom-services:/custom-services.d' compose/downloaders-vpn.yml || \
  fail C-24b 'downloaders-vpn.yml missing qbittorrent-custom-services mount'
grep -q 'QBITTORRENT_PASSWORD' compose/downloaders-vpn.yml || \
  fail C-24b 'downloaders-vpn.yml qbittorrent missing QBITTORRENT_PASSWORD for bind-vpn sidecar'
[[ -f templates/qbittorrent/custom-services.d/99-flixbox-bind-vpn-interface.sh ]] || \
  fail C-24b 'missing VPN bind-vpn-interface custom-services script'
if grep -q 'qbittorrent-custom-services' compose/downloaders-direct.yml; then
  fail C-24b 'tun0 sidecar must not mount in Direct mode'
fi
pass C-24b

# --- C-24c: Servarr External auth + API key env (ADR 0005 / 0015) ---
for app in RADARR SONARR PROWLARR; do
  grep -q "${app}__AUTH__APIKEY:" compose/servarr.yml || \
    fail C-24c "servarr.yml missing ${app}__AUTH__APIKEY"
  grep -q "${app}__AUTH__METHOD: \${FLIXBOX_ARR_AUTH_METHOD" compose/servarr.yml || \
    fail C-24c "servarr.yml missing profile-driven ${app}__AUTH__METHOD"
  grep -q "${app}__AUTH__REQUIRED: \${FLIXBOX_ARR_AUTH_REQUIRED" compose/servarr.yml || \
    fail C-24c "servarr.yml missing profile-driven ${app}__AUTH__REQUIRED"
done
[[ -f scripts/lib/access-profile.sh ]] || fail C-24c 'missing scripts/lib/access-profile.sh'
[[ -f scripts/lib/env-file.sh ]] || fail C-24c 'missing scripts/lib/env-file.sh'
grep -q 'FLIXBOX_ACCESS_PROFILE' .env.example || fail C-24c '.env.example missing FLIXBOX_ACCESS_PROFILE'
grep -q 'FLIXBOX_ADMIN_BIND_IP' compose/servarr.yml || \
  fail C-24c 'servarr.yml missing FLIXBOX_ADMIN_BIND_IP on admin ports'
grep -q 'FLIXBOX_ADMIN_BIND_IP' compose/downloaders-direct.yml || \
  fail C-24c 'downloaders-direct.yml missing FLIXBOX_ADMIN_BIND_IP on qBit WebUI'
grep -q 'FLIXBOX_ADMIN_BIND_IP' compose/downloaders-vpn.yml || \
  fail C-24c 'downloaders-vpn.yml missing FLIXBOX_ADMIN_BIND_IP on Gluetun WebUI publish'
grep -q 'FLIXBOX_ADMIN_BIND_IP' compose/optimization.yml || \
  fail C-24c 'optimization.yml missing FLIXBOX_ADMIN_BIND_IP on Maintainerr'
grep -q 'healthcheck:' compose/servarr.yml || fail C-24c 'servarr.yml missing byparr healthcheck'
grep -A12 '^  byparr:' compose/servarr.yml | grep -q '8191/health' || \
  fail C-24c 'byparr healthcheck must probe /health with short timeout'
grep -q 'FLIXBOX_ADMIN_BIND_IP' scripts/lib/access-profile.sh || \
  fail C-24c 'access-profile.sh missing FLIXBOX_ADMIN_BIND_IP sync'
grep -q 'flixbox_env_file_exports' scripts/lib/env-file.sh || \
  fail C-24c 'env-file.sh missing flixbox_env_file_exports (safe .env load)'
grep -q 'ensure_access_profile' bin/flixbox || \
  fail C-24c 'bin/flixbox missing ensure_access_profile'
grep -A20 'cmd_reload' bin/flixbox | grep -q 'ensure_access_profile' || \
  fail C-24c 'cmd_reload must call ensure_access_profile'
pass C-24c

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
  # Literal compose interpolation token — not shell expansion (SC2016).
  # shellcheck disable=SC2016
  if grep -A40 'decluttarr:' compose/optimization.yml | grep -q '\${QBITTORRENT_PASSWORD'; then
    fail C-26 'Decluttarr must not interpolate QBITTORRENT_PASSWORD into command'
  fi
fi
pass C-26

# --- C-27: qBit WebUI healthcheck + consumers wait ---
for f in compose/downloaders-direct.yml compose/downloaders-vpn.yml; do
  grep -q 'healthcheck:' "${f}" || fail C-27 "${f} missing qBittorrent healthcheck"
  grep -qE '127\.0\.0\.1:8080' "${f}" || fail C-27 "${f} healthcheck must probe qBit WebUI on 127.0.0.1:8080"
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

# --- C-43: no :latest image tags (ADR 0010 — v0.1 pin set) ---
if grep -R --include='*.yml' -E '^\s*image:.*:latest\s*$' compose/; then
  fail C-43 'compose image tags must be pinned (no :latest) — see docs/user/14-image-pins.md'
fi
[[ -f docs/user/14-image-pins.md ]] || fail C-43 'missing docs/user/14-image-pins.md'
pass C-43

# --- C-61: configure JSON payload contract (R1 — no shell-interpolated secrets) ---
[[ -f scripts/lib/json-payload.py ]] || fail C-61 'missing scripts/lib/json-payload.py'
[[ -f scripts/lib/configure-runtime.sh ]] || fail C-61 'missing scripts/lib/configure-runtime.sh'
[[ -f templates/qbittorrent/flixbox-qbit-api-login.sh ]] || fail C-61 'missing qbit-api-login.sh template'
grep -q 'flixbox_json' scripts/lib/configure-helpers.sh || \
  fail C-61 'configure-helpers must use flixbox_json'
grep -q 'configure_runtime_init' scripts/configure-apps.sh || \
  fail C-61 'configure-apps must call configure_runtime_init'
if grep -E '(-d "\{.*\$\{|cat <<EOF.*\{")' scripts/configure-apps.sh scripts/configure/*.sh 2>/dev/null; then
  fail C-61 'configure scripts must not interpolate secrets into JSON strings'
fi
if grep -E 'docker exec .*--data-urlencode "password=\$\{' scripts/lib/configure-helpers.sh; then
  fail C-61 'qbit_auth must not pass password on docker exec argv'
fi
pass C-61

# --- C-62: configure module layout (R2) ---
[[ -f scripts/lib/flixbox-env.sh ]] || fail C-62 'missing scripts/lib/flixbox-env.sh'
[[ -f scripts/configure/preflight.sh ]] || fail C-62 'missing scripts/configure/preflight.sh'
[[ -f scripts/configure/qbittorrent.sh ]] || fail C-62 'missing scripts/configure/qbittorrent.sh'
grep -q 'source "${CONFIGURE_DIR}/' scripts/configure-apps.sh || \
  fail C-62 'configure-apps.sh must source scripts/configure modules'
grep -q 'flixbox_load_configure_env' scripts/configure-apps.sh || \
  fail C-62 'configure-apps.sh must use flixbox_load_configure_env'
grep -q 'flixbox_load_env' bin/flixbox || \
  fail C-62 'bin/flixbox must use flixbox_load_env'
pass C-62

# --- C-63: access profile recreate + UI credential sync (R3) ---
grep -q 'flixbox_access_profile_admin_services' scripts/lib/access-profile.sh || \
  fail C-63 'access-profile.sh missing admin service list'
grep -q 'recreate_admin_bound_services' bin/flixbox || \
  fail C-63 'bin/flixbox missing recreate_admin_bound_services'
grep -q 'ensure_shared_ui_credentials' bin/flixbox || \
  fail C-63 'bin/flixbox missing ensure_shared_ui_credentials'
grep -q 'Admin surface matrix' docs/adr/0015-access-profiles.md || \
  fail C-63 'ADR 0015 missing admin surface matrix'
pass C-63

# --- C-64: CI workflow alignment + shared compose render + Trivy (R4) ---
[[ -f scripts/ci-compose-render.sh ]] || fail C-64 'missing scripts/ci-compose-render.sh'
[[ -f scripts/ci-trivy.sh ]] || fail C-64 'missing scripts/ci-trivy.sh'
[[ -f .github/dependabot.yml ]] || fail C-64 'missing .github/dependabot.yml'
grep -q 'ci-compose-render.sh' .github/workflows/ci.yml || \
  fail C-64 'ci.yml must call scripts/ci-compose-render.sh'
grep -qE '^  security:' .github/workflows/ci.yml || \
  fail C-64 'ci.yml missing security job'
grep -q 'ci-trivy.sh' .github/workflows/ci.yml || \
  fail C-64 'ci.yml must call scripts/ci-trivy.sh'
grep -q 'access profile shared' scripts/ci-compose-render.sh || \
  fail C-64 'ci-compose-render must test shared access profile'
pass C-64

# --- C-65: Maintainerr rule pack + credential runbook + ADR 0011 ES scope (R5) ---
[[ -f templates/maintainerr/rule-pack.md ]] || fail C-65 'missing templates/maintainerr/rule-pack.md'
grep -q 'rule-pack.md' bin/flixbox || fail C-65 'bin/flixbox must copy maintainerr/rule-pack.md'
[[ -f docs/user/15-credential-rotation.md ]] || fail C-65 'missing docs/user/15-credential-rotation.md'
grep -q '15-credential-rotation' docs/user/06-configuration.md || \
  fail C-65 '06-configuration must link credential rotation runbook'
grep -q 'ES scope' docs/adr/0011-documentation-i18n.md || \
  fail C-65 'ADR 0011 missing ES scope section'
pass C-65

# --- Compose render (shared script — R4) ---
"${ROOT_DIR}/scripts/ci-compose-render.sh" || exit 1
pass compose-config

printf 'All contract checks passed.\n'
