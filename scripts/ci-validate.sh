#!/usr/bin/env bash
# Enforce Flixbox architecture contracts in CI and locally.
# See docs/10-ci-plan.md for check IDs (C-01 … C-71).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/platform.sh"

CI_ENV="${ROOT_DIR}/.ci-env"
COMPOSE=(docker compose --env-file "${CI_ENV}")

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  exit 1
}

pass() {
  printf 'OK   %s\n' "$1"
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
grep -A120 '^cmd_status()' bin/flixbox | grep -q 'warn_mode_vpn_mismatch' || \
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

# --- C-11: torrents/incomplete + ownership (DATA only while stack is down) ---
grep -q 'torrents/incomplete' scripts/bootstrap-dirs.sh || \
  fail C-11 'bootstrap-dirs.sh missing torrents/incomplete'
grep -q 'flixbox_chown_tree' scripts/bootstrap-dirs.sh || \
  fail C-11 'bootstrap-dirs.sh must chown DATA_DIR via flixbox_chown_tree (alpine fallback)'
grep -q 'flixbox_prepare_paths_for_host_write' bin/flixbox || \
  fail C-11 'bin/flixbox init must reclaim DATA_DIR/CONFIG_DIR before path validation'
grep -q 'flixbox_apply_runtime_ownership' bin/flixbox || \
  fail C-11 'bin/flixbox init must apply PUID ownership after copy_templates'
grep -q 'flixbox_apply_config_runtime_ownership' bin/flixbox || \
  fail C-11 'bin/flixbox up/reload must apply CONFIG PUID ownership without touching DATA_DIR'
grep -q 'flixbox_prepare_config_for_host_write' bin/flixbox || \
  fail C-11 'bin/flixbox up/reload must reclaim CONFIG_DIR only (not DATA_DIR)'
grep -q 'flixbox_reclaim_path_for_host_write' scripts/lib/configure-helpers.sh || \
  fail C-11 'configure must reclaim recyclarr/ only before host writes'
grep -q 'flixbox_chown_tree "${CONFIG_DIR}/recyclarr"' scripts/lib/configure-helpers.sh || \
  fail C-11 'configure must restore recyclarr/ to PUID after host writes'
if grep -q 'flixbox_apply_runtime_ownership' scripts/configure-apps.sh; then
  fail C-11 'configure-apps.sh must not chown DATA_DIR/CONFIG_DIR while the stack is running'
fi
if grep -q 'flixbox_prepare_paths_for_host_write' scripts/configure-apps.sh; then
  fail C-11 'configure-apps.sh must not reclaim DATA_DIR while the stack is running'
fi
_up_start=$(grep -n '^cmd_up()' bin/flixbox | head -1 | cut -d: -f1)
[[ -n "$_up_start" ]] || fail C-11 'cmd_up not found'
while IFS= read -r _ln; do
  [[ "${_ln}" -lt "${_up_start}" ]] || \
    fail C-11 'flixbox_prepare_paths_for_host_write must only run in init (stack down), not up/reload'
done < <(grep -n 'flixbox_prepare_paths_for_host_write' bin/flixbox | cut -d: -f1)
if awk '/^cmd_up\(\)/,/^parse_profiles\(\)/' bin/flixbox | grep -q 'flixbox_apply_runtime_ownership'; then
  fail C-11 'cmd_up must not chown DATA_DIR (use flixbox_apply_config_runtime_ownership)'
fi
if awk '/^cmd_reload\(\)/,/^cmd_configure\(\)/' bin/flixbox | grep -q 'flixbox_apply_runtime_ownership'; then
  fail C-11 'cmd_reload must not chown DATA_DIR (use flixbox_apply_config_runtime_ownership)'
fi
grep -q 'flixbox_ensure_seerr_config_owner' scripts/lib/seerr-perms.sh || \
  fail C-11 'seerr-perms.sh must ensure Seerr config is UID 1000'
[[ -f scripts/lib/seerr-perms.sh ]] || fail C-11 'missing scripts/lib/seerr-perms.sh'
grep -q 'flixbox_chown_tree' scripts/lib/seerr-perms.sh || \
  fail C-11 'seerr-perms.sh must define flixbox_chown_tree'
awk '/^cmd_up\(\)/,/^parse_profiles\(\)/' bin/flixbox | grep -q -- '--remove-orphans' || \
  fail C-11 'cmd_up must use --remove-orphans (ADR 0022)'
awk '/^cmd_reload\(\)/,/^cmd_homepage\(\)/' bin/flixbox | grep -q -- '--remove-orphans' || \
  fail C-11 'cmd_reload must use --remove-orphans (ADR 0022)'
pass C-11

# --- C-89: Homepage Docker API via always-on socket-proxy (ADR 0022) ---
grep -q 'profiles:.*"socket-proxy"' compose/dashboard.yml && \
  fail C-89 'docker-socket-proxy must not use socket-proxy profile'
if grep -qi 'socket-proxy' compose.yaml; then
  fail C-89 'compose.yaml must not reference obsolete socket-proxy profile'
fi
grep -q '/var/run/docker.sock:/var/run/docker.sock' compose/dashboard.yml || \
  fail C-89 'docker-socket-proxy must mount host docker.sock'
if awk '/^  homepage:/,/^  [a-z]/' compose/dashboard.yml | grep -q 'docker.sock'; then
  fail C-89 'homepage must not mount docker.sock'
fi
grep -q 'healthcheck:' compose/dashboard.yml || \
  fail C-89 'docker-socket-proxy must define a healthcheck'
grep -q 'condition: service_healthy' compose/dashboard.yml || \
  fail C-89 'homepage must wait for healthy docker-socket-proxy'
grep -q 'host: docker-socket-proxy' templates/homepage/docker.yaml || \
  fail C-89 'docker.yaml must point at docker-socket-proxy'
grep -qE 'socket:[[:space:]]*/var/run/docker\.sock' templates/homepage/docker.yaml && \
  fail C-89 'docker.yaml must not use raw docker.sock'
grep -q 'Seerr requires UID 1000' bin/flixbox || \
  fail C-89 'CLI must fail closed when Seerr UID 1000 ownership fails'
awk '/flixbox_apply_config_runtime_ownership/,/compose /' bin/flixbox | grep -q 'die' || \
  fail C-89 'up/reload must die when Seerr ownership fails'
grep -q 'flixbox_seerr_write_probe\|flixbox_path_uid' scripts/lib/seerr-perms.sh || \
  fail C-89 'seerr-perms must use path uid / optional write probe'
grep -q -- '--pull=never' scripts/lib/seerr-perms.sh || \
  fail C-89 'Seerr write probe must use --pull=never (no alpine pull to verify)'
grep -q 'docker.yaml → docker-socket-proxy' bin/flixbox || \
  fail C-89 'copy_templates must log docker.yaml ADR 0022 rewrites'
grep -q 'Phase G' docs/user/11-smoke-test.md || \
  fail C-89 'smoke-test must include Phase G (ADR 0022)'
[[ -f docs/adr/0022-operator-footgun-remediations.md ]] || fail C-89 'missing ADR 0022'
pass C-89

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

# --- C-24b: VPN tun0 bind sidecar (ADR 0002); Direct must not install it ---
grep -q 'qbittorrent-custom-services:/custom-services.d' compose/downloaders-vpn.yml || \
  fail C-24b 'downloaders-vpn.yml missing qbittorrent-custom-services mount'
grep -q 'QBITTORRENT_PASSWORD' compose/downloaders-vpn.yml || \
  fail C-24b 'downloaders-vpn.yml qbittorrent missing QBITTORRENT_PASSWORD for custom-services'
[[ -f templates/qbittorrent/custom-services.d/99-flixbox-bind-vpn-interface.sh ]] || \
  fail C-24b 'missing VPN bind-vpn-interface custom-services script'
# init installs bind-vpn only when FLIXBOX_MODE=vpn
grep -q '99-flixbox-bind-vpn-interface.sh' bin/flixbox || \
  fail C-24b 'bin/flixbox must install/remove bind-vpn custom-service by mode'
pass C-24b

# --- C-84: qBit WebUI contract reconciler (ADR 0019) — Direct + VPN ---
for f in compose/downloaders-direct.yml compose/downloaders-vpn.yml; do
  grep -q 'qbittorrent-custom-services:/custom-services.d' "${f}" || \
    fail C-84 "${f} missing qbittorrent-custom-services mount for WebUI contract"
  grep -q 'QBITTORRENT_PASSWORD' "${f}" || \
    fail C-84 "${f} qbittorrent missing QBITTORRENT_PASSWORD for webui-contract"
done
[[ -f templates/qbittorrent/custom-services.d/98-flixbox-webui-contract.sh ]] || \
  fail C-84 'missing templates/qbittorrent/custom-services.d/98-flixbox-webui-contract.sh'
grep -q 'web_ui_host_header_validation_enabled' \
  templates/qbittorrent/custom-services.d/98-flixbox-webui-contract.sh || \
  fail C-84 'webui-contract must set web_ui_host_header_validation_enabled'
grep -q '172.30.42.0/24' templates/qbittorrent/custom-services.d/98-flixbox-webui-contract.sh || \
  fail C-84 'webui-contract must whitelist flixbox_net 172.30.42.0/24'
grep -q '98-flixbox-webui-contract.sh' bin/flixbox || \
  fail C-84 'bin/flixbox must install webui-contract custom-service'
grep -q 'flixbox_qbit_webui_bootstrap' bin/flixbox || \
  fail C-84 'bin/flixbox must call flixbox_qbit_webui_bootstrap after up/reload'
[[ -f scripts/lib/qbit-webui-bootstrap.sh ]] || \
  fail C-84 'missing scripts/lib/qbit-webui-bootstrap.sh'
[[ -f templates/qbittorrent/webui-security-prefs.json ]] || \
  fail C-84 'missing templates/qbittorrent/webui-security-prefs.json'
[[ -f templates/qbittorrent/webui-security-prefs-portforward.json ]] || \
  fail C-84 'missing templates/qbittorrent/webui-security-prefs-portforward.json'
grep -q 'webui-security-prefs.json' templates/qbittorrent/custom-services.d/98-flixbox-webui-contract.sh || \
  fail C-84 'webui-contract must load prefs from webui-security-prefs.json'
grep -q 'force-recreate --no-deps decluttarr' bin/flixbox || \
  fail C-84 'up/reload must recreate Decluttarr after successful WebUI bootstrap'
[[ -f docs/adr/0019-qbit-webui-runtime-contract.md ]] || \
  fail C-84 'missing ADR 0019 qBit WebUI runtime contract'
pass C-84

# --- C-85: WebUI contract OK-check + prefs drift guards (QA remediation) ---
grep -A12 'security_prefs_ok()' templates/qbittorrent/custom-services.d/98-flixbox-webui-contract.sh \
  | grep -q '"web_ui_host_header_validation_enabled":false' || \
  fail C-85 'webui-contract security_prefs_ok must require explicit host_header false (match json-query)'
grep -q 'qbit-api-login.sh' templates/qbittorrent/custom-services.d/98-flixbox-webui-contract.sh || \
  fail C-85 'webui-contract must login via qbit-api-login.sh'
grep -q 'exit 2' templates/qbittorrent/flixbox-qbit-api-login.sh || \
  fail C-85 'qbit-api-login.sh must exit 2 on WebUI ban'
# up/reload must refresh custom-services before compose (mode flip)
awk '/^cmd_up\(\)/,/^}/' bin/flixbox | grep -q 'copy_templates' || \
  fail C-85 'cmd_up must call copy_templates before compose'
awk '/^cmd_reload\(\)/,/^}/' bin/flixbox | grep -q 'copy_templates' || \
  fail C-85 'cmd_reload must call copy_templates before compose'
# Single-source prefs templates + consumers
for key in web_ui_host_header_validation_enabled bypass_auth_subnet_whitelist_enabled \
  bypass_auth_subnet_whitelist web_ui_max_auth_fail_count web_ui_ban_duration; do
  grep -q "\"${key}\"" templates/qbittorrent/webui-security-prefs.json || \
    fail C-85 "webui-security-prefs.json missing ${key}"
  grep -q "\"${key}\"" templates/qbittorrent/webui-security-prefs-portforward.json || \
    fail C-85 "webui-security-prefs-portforward.json missing ${key}"
done
grep -q 'webui-security-prefs' scripts/lib/configure-helpers.sh || \
  fail C-85 'configure-helpers must load webui-security-prefs templates'
grep -q 'webui-security-prefs' scripts/lib/qbit-webui-bootstrap.sh || \
  fail C-85 'qbit-webui-bootstrap must load webui-security-prefs templates'
# Must not persist session temp password on disk
if grep 'session-temp-password' scripts/lib/qbit-webui-bootstrap.sh | grep -vq 'rm -f'; then
  fail C-85 'bootstrap must not write session-temp-password (rm-only cleanup allowed)'
fi
if grep -q 'session-temp-password' templates/qbittorrent/custom-services.d/98-flixbox-webui-contract.sh; then
  fail C-85 'webui-contract must not depend on session-temp-password file'
fi
if grep -q 'password=x' scripts/lib/qbit-webui-bootstrap.sh; then
  fail C-85 'qbit-webui-bootstrap must not use dummy password=x ban probe'
fi
pass C-85

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
grep -A14 '^  byparr:' compose/servarr.yml | grep -q '8191/' || \
  fail C-24c 'byparr healthcheck must probe container port 8191'
grep -A14 '^  byparr:' compose/servarr.yml | grep -q -- '-m 3' || \
  fail C-24c 'byparr healthcheck must use short curl max-time (avoid /health hang)'
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
  bazarr byparr decluttarr docker-socket-proxy homepage jellyfin maintainerr
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
[[ -f scripts/configure/arr-common.sh ]] || fail C-62 'missing scripts/configure/arr-common.sh'
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
grep -q 'configure_entry_recreate_admin_services' scripts/lib/configure-entry.sh || \
  fail C-63 'configure-entry must recreate admin-bound services on drift'
grep -q 'configure_entry_prepare' scripts/lib/configure-entry.sh || \
  fail C-63 'configure-entry must expose configure_entry_prepare'
grep -q 'configure_entry_sync_homepage' scripts/lib/configure-entry.sh || \
  fail C-63 'configure-entry must sync Homepage (shared admin widget purge)'
grep -q 'homepage-sync.py' scripts/lib/configure-entry.sh || \
  fail C-63 'configure-entry Homepage sync must call homepage-sync.py'
grep -q 'ensure_shared_ui_credentials' bin/flixbox || \
  fail C-63 'bin/flixbox must ensure shared UI credentials on init'
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

# --- C-66: .env.example access-profile placeholders (in-place sync, no append) ---
for _c66_key in \
  FLIXBOX_ARR_AUTH_METHOD \
  FLIXBOX_ARR_AUTH_REQUIRED \
  FLIXBOX_ADMIN_BIND_IP \
  FLIXBOX_ARR_UI_USER \
  FLIXBOX_ARR_UI_PASSWORD; do
  grep -qE "^${_c66_key}=" .env.example || \
    fail C-66 ".env.example missing active assignment: ${_c66_key}="
done
pass C-66

# --- C-67: configure waits before API key discovery (first-start race) ---
grep -q 'configure_wait_for_first_start' scripts/configure/preflight.sh || \
  fail C-67 'preflight must wait for first-start before discover'
_preflight_discover_line="$(grep -n '^configure_discover_api_keys()' scripts/configure/preflight.sh | head -1 | cut -d: -f1)"
_preflight_wait_line="$(grep -n '^configure_wait_for_first_start()' scripts/configure/preflight.sh | head -1 | cut -d: -f1)"
[[ -n "$_preflight_discover_line" && -n "$_preflight_wait_line" ]] || \
  fail C-67 'preflight missing discover/wait functions'
[[ "$_preflight_wait_line" -lt "$_preflight_discover_line" ]] || \
  fail C-67 'configure must wait for first-start before discover'
grep -A5 '^configure_preflight_pass()' scripts/configure/preflight.sh | grep -q 'configure_wait_for_first_start' || \
  fail C-67 'preflight pass must call wait before discover'
grep -q 'CONFIGURE_PREFLIGHT_TIMEOUT' scripts/configure/preflight.sh || \
  fail C-67 'preflight must support CONFIGURE_PREFLIGHT_TIMEOUT retry budget'
grep -q 'CONFIGURE_SOFT_WAIT' scripts/lib/configure-state.sh || \
  fail C-67 'configure-state must support CONFIGURE_SOFT_WAIT for retries'
grep -q 'CONFIGURE_PREFLIGHT_DEADLINE' scripts/configure/preflight.sh || \
  fail C-67 'preflight must export CONFIGURE_PREFLIGHT_DEADLINE to cap waits'
grep -q 'configure_wait_window' scripts/lib/configure-helpers.sh || \
  fail C-67 'wait helpers must clamp via configure_wait_window'
pass C-67

# --- C-68: configure readiness state machine (structural contract) ---
[[ -f scripts/lib/configure-state.sh ]] || fail C-68 'missing scripts/lib/configure-state.sh'
[[ -f scripts/lib/configure-entry.sh ]] || fail C-68 'missing scripts/lib/configure-entry.sh'
grep -q 'flixbox-jellyfin' scripts/lib/configure-state.sh || \
  fail C-68 'core stack assert must include Jellyfin'
grep -q 'configure_assert_vpn_ready' scripts/lib/configure-state.sh || \
  fail C-68 'configure-state must assert VPN readiness with soft retry'
grep -q 'configure_env_write_fatal' scripts/lib/configure-state.sh || \
  fail C-68 'configure-state must fast-fail .env write errors'
grep -q 'configure_entry_prepare' scripts/configure-apps.sh || \
  fail C-68 'configure-apps must call configure_entry_prepare (access profile on direct invoke)'
grep -q 'configure_mark_preflight_passed' scripts/configure/preflight.sh || \
  fail C-68 'preflight must mark PREFLIGHT_PASSED before wiring'
grep -A6 '^configure_mark_preflight_passed()' scripts/lib/configure-state.sh | grep -q 'CONFIGURE_SOFT_WAIT=0' || \
  fail C-68 'mark PREFLIGHT_PASSED must clear CONFIGURE_SOFT_WAIT for wiring'
grep -q 'configure_ensure_qbittorrent_ready' scripts/configure/qbittorrent.sh || \
  fail C-68 'qBit module must use configure_ensure_* (skip duplicate waits)'
grep -q 'configure_ensure_arr_api' scripts/configure/arr-common.sh || \
  fail C-68 'arr module must use configure_ensure_arr_api'
_qbit_dry_line="$(grep -n 'if \$DRY_RUN; then' scripts/configure/qbittorrent.sh | head -1 | cut -d: -f1)"
_qbit_wait_line="$(grep -n 'configure_ensure_qbittorrent_ready' scripts/configure/qbittorrent.sh | head -1 | cut -d: -f1)"
[[ -n "$_qbit_dry_line" && -n "$_qbit_wait_line" && "$_qbit_dry_line" -lt "$_qbit_wait_line" ]] || \
  fail C-68 'qBit module must short-circuit dry-run before waits'
grep -q 'flixbox-byparr' scripts/configure/prowlarr.sh || \
  fail C-68 'Prowlarr must skip Byparr proxy when Byparr is down'
grep -q 'configure_assert_tools' scripts/lib/configure-state.sh || \
  fail C-68 'configure-state must assert docker/python3 tools'
pass C-68

# --- C-69: configure pre-release hardening (dry-run, parallel waits, fail contract) ---
grep -q '\${DRY_RUN:-false}' scripts/lib/configure-entry.sh || \
  fail C-69 'configure-entry must respect --dry-run (no .env/recreate side effects)'
grep -q 'configure_ensure_http_parallel' scripts/configure/preflight.sh || \
  fail C-69 'preflight must parallelize HTTP warm-up waits'
grep -q 'configure_ensure_stack_apis_parallel' scripts/configure/preflight.sh || \
  fail C-69 'preflight must parallelize authenticated API waits'
grep -q 'FAILED=\$((FAILED + 1))' scripts/lib/configure-helpers.sh || \
  fail C-69 'configure fail() must increment FAILED'
sed -n '/^fail() {/,/^}/p' scripts/lib/configure-helpers.sh | grep -q 'return 0' || \
  fail C-69 'configure fail() must return 0 under set -e (PARTIAL wiring; ADR 0016)'
grep -q 'wait_for_bazarr_api' scripts/configure/bazarr.sh || \
  fail C-69 'Bazarr must re-wait for API after restart'
grep -B2 -A2 'wait_for_bazarr_api' scripts/configure/bazarr.sh | grep -q 'CONFIGURE_SOFT_WAIT=1' || \
  fail C-69 'Bazarr post-restart wait must be soft (warn-only, no FAILED inflate)'
if grep -E 'API key: \$\{[A-Z_]*:0:8\}' scripts/configure/preflight.sh scripts/configure/qbittorrent.sh 2>/dev/null; then
  fail C-69 'configure must not log API key prefixes (ADR 0020)'
fi
[[ -f docs/adr/0016-configure-state-machine.md ]] || \
  fail C-69 'missing ADR 0016 configure state machine'
pass C-69

# --- C-70: configure hardening follow-ups (json-query, context, stack smoke script) ---
[[ -f scripts/lib/json-query.py ]] || fail C-70 'missing scripts/lib/json-query.py'
[[ -f scripts/lib/configure-context.sh ]] || fail C-70 'missing scripts/lib/configure-context.sh'
[[ -f scripts/ci-smoke-configure.sh ]] || fail C-70 'missing scripts/ci-smoke-configure.sh'
grep -q 'json_query' scripts/lib/configure-helpers.sh || \
  fail C-70 'configure-helpers must expose json_query'
grep -q 'configure_context_reset' scripts/configure-apps.sh || \
  fail C-70 'configure-apps must reset context at start'
grep -q 'json_query bazarr-conn-diff' scripts/configure/bazarr.sh || \
  fail C-70 'bazarr must use json_query for API key compare'
if grep -E 'json_extract.*\$\{' scripts/configure/arr-common.sh scripts/configure/bazarr.sh 2>/dev/null; then
  fail C-70 'arr/bazarr must not shell-interpolate into json_extract'
fi
pass C-70

# --- C-71: configure JSON/env footgun guards (post-audit) ---
if grep -E 'JSON_QUERY_PARAMS="\$params" echo' scripts/lib/configure-helpers.sh; then
  fail C-71 'json_query must not bind JSON_QUERY_PARAMS to echo (apply to python3)'
fi
grep -q 'echo "\$json" | JSON_QUERY_PARAMS=' scripts/lib/configure-helpers.sh || \
  fail C-71 'json_query must pipe JSON stdin to python3 with JSON_QUERY_PARAMS on python'
grep -q 'settings-sonarr-port=8989' scripts/configure/bazarr.sh || \
  fail C-71 'bazarr must use internal port 8989 for Sonarr'
grep -q 'settings-radarr-port=7878' scripts/configure/bazarr.sh || \
  fail C-71 'bazarr must use internal port 7878 for Radarr'
grep -q 'add_seerr_arr radarr radarr "\$RADARR_PORT" 7878' scripts/configure/seerr.sh || \
  fail C-71 'seerr must use probe port with internal port 7878 for Radarr'
grep -q 'add_seerr_arr sonarr sonarr "\$SONARR_PORT" 8989' scripts/configure/seerr.sh || \
  fail C-71 'seerr must use probe port with internal port 8989 for Sonarr'
grep -q 'arr_container_port=7878' scripts/configure/prowlarr.sh || \
  fail C-71 'prowlarr must use internal port 7878 for Radarr'
grep -q 'qbit-web-ui-api-key' scripts/lib/configure-helpers.sh || \
  fail C-71 'qbit_api_key_from_config must read web_ui_api_key via json_query fallback'
pass C-71

# --- C-72: host port preflight before up/reload ---
[[ -f scripts/lib/preflight-host.sh ]] || fail C-72 'missing scripts/lib/preflight-host.sh'
grep -q 'flixbox_preflight_host_ports' bin/flixbox || \
  fail C-72 'bin/flixbox must call flixbox_preflight_host_ports'
grep -q '_flixbox_port_is_free' scripts/lib/preflight-host.sh || \
  fail C-72 'preflight-host must probe port availability before bind'
grep -q 'if ! _flixbox_port_is_free' scripts/lib/preflight-host.sh || \
  fail C-72 'preflight-host must warn only when port bind fails (in use)'
grep -q 'Host port conflicts' docs/user/05-first-run.md || \
  fail C-72 'first-run doc must document host port conflicts'
pass C-72

# --- C-73: configure smoke on pull requests ---
grep -q 'configure-smoke-pr' .github/workflows/ci.yml || \
  fail C-73 'ci.yml must define configure-smoke-pr job for pull_request'
grep -q 'CI_CONFIGURE_SMOKE_PR' scripts/ci-smoke-configure.sh || \
  fail C-73 'ci-smoke-configure must support CI_CONFIGURE_SMOKE_PR subset'
pass C-73

# --- C-74: VPN structural smoke ---
[[ -f scripts/ci-smoke-vpn.sh ]] || fail C-74 'missing scripts/ci-smoke-vpn.sh'
grep -q 'CI_VPN_SMOKE' .github/workflows/ci.yml || \
  fail C-74 'ci.yml must run ci-smoke-vpn.sh'
grep -q 'network_mode: service:gluetun' compose/downloaders-vpn.yml || \
  fail C-74 'VPN compose must use gluetun netns for qbittorrent'
pass C-74

# --- C-75: release gate (Trivy block + digests) ---
[[ -f .github/workflows/release.yml ]] || fail C-75 'missing .github/workflows/release.yml'
grep -q 'TRIVY_BLOCK' .github/workflows/release.yml || \
  fail C-75 'release workflow must set TRIVY_BLOCK=1'
[[ -f scripts/ci-pin-digests.sh ]] || fail C-75 'missing scripts/ci-pin-digests.sh'
pass C-75

# --- C-76: core MVP HTTP healthchecks ---
for _svc in prowlarr radarr sonarr bazarr; do
  grep -A25 "  ${_svc}:" compose/servarr.yml | grep -q 'healthcheck:' || \
    fail C-76 "compose/servarr.yml ${_svc} must define healthcheck"
done
grep -A25 '  jellyfin:' compose/media-servers.yml | grep -q 'healthcheck:' || \
  fail C-76 'compose/media-servers.yml jellyfin must define healthcheck'
[[ -f docs/adr/0017-compose-health-and-start-order.md ]] || \
  fail C-76 'missing ADR 0017 compose healthchecks'
pass C-76

# --- C-77: Bazarr depends_on Sonarr/Radarr healthy ---
grep -A20 '  bazarr:' compose/servarr.yml | grep -q 'condition: service_healthy' || \
  fail C-77 'bazarr must depend_on sonarr/radarr with service_healthy'
pass C-77

# --- C-78: runtime secrets + LAN trust documentation ---
[[ -f docs/adr/0018-runtime-secrets-and-lan-trust.md ]] || \
  fail C-78 'missing ADR 0018 runtime secrets'
grep -q 'Threat model' docs/user/13-access-profiles.md || \
  fail C-78 'access profiles doc must include threat model section'
grep -q '0018-runtime-secrets' docs/user/06-configuration.md || \
  fail C-78 'configuration doc must reference ADR 0018'
pass C-78

# --- C-87: operator credentials CLI (ADR 0020) ---
grep -q 'credentials' bin/flixbox || \
  fail C-87 'bin/flixbox must expose credentials command'
grep -q 'cmd_credentials' bin/flixbox || \
  fail C-87 'bin/flixbox must dispatch credentials'
grep -q 'flixbox_apply_arr_ui_credentials' scripts/lib/credentials.sh || \
  fail C-87 'credentials.sh must apply arr-ui via Host Config'
grep -q 'flixbox_apply_qbit_password_rotate' scripts/lib/credentials.sh || \
  fail C-87 'credentials.sh must rotate qBit before writing .env'
grep -q 'qbit-password-rotate.sh' scripts/lib/credentials.sh || \
  fail C-87 'credentials must call qbit-password-rotate.sh'
[[ -f scripts/lib/qbit-password-rotate.sh ]] || \
  fail C-87 'missing qbit-password-rotate.sh'
grep -q 'exit 3' scripts/lib/qbit-password-rotate.sh || \
  fail C-87 'qbit-password-rotate must exit 3 when setPreferences committed but re-auth fails'
grep -qE 'case "\$rc" in' scripts/lib/credentials.sh || \
  fail C-87 'credentials set qbit must branch on rotate exit codes'
grep -qE '^\s*3\)' scripts/lib/credentials.sh || \
  fail C-87 'credentials must persist .env on rotate exit 3'
grep -q 'FLIXBOX_ARR_UI_PASSWORD_OVERRIDE' scripts/lib/credentials.sh || \
  fail C-87 'arr-ui set must apply with in-memory password override'
grep -q 'Host Config apply failed on all apps — .env left unchanged' scripts/lib/credentials.sh || \
  fail C-87 'arr-ui must leave .env unchanged when all Host Config applies fail'
if grep -q 'configure-apps.sh" --sync-qbit-auth' scripts/lib/credentials.sh; then
  fail C-87 'credentials set qbit must not call full configure --sync-qbit-auth'
fi
grep -q 'Rotate vs align' docs/user/06-configuration.md || \
  fail C-87 '06-configuration must document rotate vs align'
grep -Fq '*Auth cookie' scripts/lib/arr-host-config-auth.py || \
  fail C-87 'arr-host-config-auth must require *Auth cookie on login verify'
grep -q 'QBIT_API_KEY=' scripts/configure/preflight.sh || \
  fail C-87 'dry-run preflight must export QBIT_API_KEY placeholder'
grep -q 'admin widgets' docs/user/06-configuration.md || \
  fail C-87 '06-configuration Homepage row must describe trusted vs shared widgets'
grep -q 'also syncs Homepage' docs/user/06-configuration.md || \
  fail C-87 '06-configuration must note configure syncs Homepage on profile change'
grep -q 'ARR_API_KEY' scripts/lib/arr-host-config-auth.py || \
  fail C-87 'arr-host-config-auth must read ARR_API_KEY from env'
if grep -q 'sys.argv\[2\]' scripts/lib/arr-host-config-auth.py; then
  fail C-87 'arr-host-config-auth must not take API key from argv'
fi
grep -q 'do not pass URL/API key on argv' scripts/lib/arr-host-config-auth.py || \
  fail C-87 'arr-host-config-auth must reject argv secrets'
grep -q '_redact' scripts/lib/arr-host-config-auth.py || \
  fail C-87 'arr-host-config-auth must redact error bodies'
grep -q 'ARR_HOST_CONFIG_URL' scripts/lib/credentials.sh || \
  fail C-87 'credentials must pass ARR_HOST_CONFIG_URL via env'
grep -q 'arr-host-config-auth.py' scripts/lib/credentials.sh || \
  fail C-87 'credentials must call arr-host-config-auth.py'
[[ -f scripts/lib/arr-host-config-auth.py ]] || \
  fail C-87 'missing arr-host-config-auth.py'
grep -q 'sync-arr-ui' scripts/configure-apps.sh || \
  fail C-87 'configure must support --sync-arr-ui'
grep -q '0020-operator-credentials' docs/adr/README.md || \
  fail C-87 'ADR index must list 0020'
grep -q 'credentials show' docs/user/REFERENCE.md || \
  fail C-87 'REFERENCE must document credentials CLI'
grep -q 'ADR 0020' docs/user/15-credential-rotation.md || \
  fail C-87 'credential rotation must reference ADR 0020'
grep -q 'rotate' docs/user/15-credential-rotation.md || \
  fail C-87 'credential rotation must describe qBit rotate vs align'
pass C-87

# --- C-79: configure modules use json_query only (no json_extract) ---
if grep -r 'json_extract' scripts/configure/ 2>/dev/null; then
  fail C-79 'scripts/configure must not use json_extract (use json_query)'
fi
if grep -E 'json_params field=[a-zA-Z]+"\)' scripts/configure/seerr.sh 2>/dev/null; then
  fail C-79 'seerr json_params must bind field names via env vars (FIELD=id json_params field=FIELD)'
fi
grep -q 'seerr-initialized' scripts/lib/json-query.py || \
  fail C-79 'json-query must include seerr-initialized handler'
grep -q 'local key_json new_key=""' scripts/configure/jellyfin.sh || \
  fail C-79 'jellyfin must initialize new_key under set -u before empty-body API key fallback'
grep -q 'jellyfin_remediate_network_bind' scripts/configure/jellyfin.sh || \
  fail C-79 'jellyfin configure must remediate LocalNetworkAddresses :: bind'
[[ -f scripts/lib/jellyfin-network-bind.py ]] || \
  fail C-79 'missing scripts/lib/jellyfin-network-bind.py'
pass C-79

# --- C-79b: jellyfin-network-bind.py clears only lone :: ---
_jf_bind_tmp="$(mktemp -d)"
cat >"${_jf_bind_tmp}/network.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<NetworkConfiguration>
  <LocalNetworkAddresses>
    <string>::</string>
  </LocalNetworkAddresses>
</NetworkConfiguration>
EOF
_jf_status="$(python3 scripts/lib/jellyfin-network-bind.py "${_jf_bind_tmp}/network.xml")"
[[ "${_jf_status}" == "clear" ]] || { rm -rf "${_jf_bind_tmp}"; fail C-79b "expected clear, got ${_jf_status}"; }
python3 scripts/lib/jellyfin-network-bind.py --apply "${_jf_bind_tmp}/network.xml" >/dev/null
_jf_status="$(python3 scripts/lib/jellyfin-network-bind.py "${_jf_bind_tmp}/network.xml")"
[[ "${_jf_status}" == "skip" ]] || { rm -rf "${_jf_bind_tmp}"; fail C-79b "expected skip after apply, got ${_jf_status}"; }
if grep -q '<string>::</string>' "${_jf_bind_tmp}/network.xml"; then
  rm -rf "${_jf_bind_tmp}"
  fail C-79b ':: string must be removed after --apply'
fi
cat >"${_jf_bind_tmp}/keep.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<NetworkConfiguration>
  <LocalNetworkAddresses>
    <string>192.168.1.10</string>
  </LocalNetworkAddresses>
</NetworkConfiguration>
EOF
python3 scripts/lib/jellyfin-network-bind.py --apply "${_jf_bind_tmp}/keep.xml" >/dev/null
grep -q '<string>192.168.1.10</string>' "${_jf_bind_tmp}/keep.xml" || {
  rm -rf "${_jf_bind_tmp}"
  fail C-79b 'must not clear non-:: LocalNetworkAddresses'
}
rm -rf "${_jf_bind_tmp}"
pass C-79b

# --- C-81: remove deprecated json_extract from configure helpers ---
if grep -q '^json_extract()' scripts/lib/configure-helpers.sh 2>/dev/null; then
  fail C-81 'configure-helpers must not define json_extract (use json_query)'
fi
pass C-81

# --- C-82: shared CLI output when configure-entry runs from bin/flixbox ---
[[ -f scripts/lib/cli-output.sh ]] || fail C-82 'missing scripts/lib/cli-output.sh'
grep -q 'cli-output.sh' scripts/lib/configure-entry.sh || \
  fail C-82 'configure-entry must source cli-output.sh for info/dry fallbacks'
grep -q 'declare -f info' scripts/lib/cli-output.sh || \
  fail C-82 'cli-output must define info only when missing'
pass C-82

# --- C-83: host port preflight hints and household app bind probe ---
grep -q '_flixbox_port_owned_by_stack' scripts/lib/preflight-host.sh || \
  fail C-83 'preflight must allow ports already published by flixbox-* containers'
grep -q '_flixbox_port_hint' scripts/lib/preflight-host.sh || \
  fail C-83 'preflight-host must suggest per-service alternate ports'
grep -q 'Jellyfin" "0.0.0.0"' scripts/lib/preflight-host.sh || \
  fail C-83 'preflight must probe Jellyfin on 0.0.0.0 (household app)'
grep -q 'SEERR_PORT.*"0.0.0.0"' scripts/lib/preflight-host.sh || \
  fail C-83 'preflight must probe Seerr on 0.0.0.0 (household app)'
pass C-83

# --- C-80: ADR 0013 Accepted + VPN operator docs ---
grep -qE 'Status:\*\* Accepted' docs/adr/0013-vpn-resilience-no-direct-fallback.md || \
  fail C-80 'ADR 0013 must be Accepted'
grep -q 'What happens when the VPN drops' docs/user/07-vpn-and-direct.md || \
  fail C-80 'VPN doc must explain VPN drop behavior'
grep -q 'Gluetun recreate' docs/user/10-troubleshooting.md || \
  fail C-80 'troubleshooting must cover Gluetun recreate'
pass C-80

# --- C-86: Homepage port & widget sync (ADR 0014 / services.yaml non-destructive sync) ---
[[ -f scripts/lib/homepage-sync.py ]] || fail C-86 'missing scripts/lib/homepage-sync.py'
[[ -x scripts/lib/homepage-sync.py ]] || fail C-86 'homepage-sync.py must be executable'
grep -q 'homepage-sync.py' bin/flixbox || fail C-86 'bin/flixbox must invoke homepage-sync.py'
grep -q 'sync_homepage_widgets' scripts/lib/homepage-sync.py || \
  fail C-86 'homepage-sync must sync status chips in widgets.yaml'
grep -q 'text: "Flixbox"' templates/homepage/widgets.yaml || \
  fail C-86 'widgets.yaml must show Flixbox as brand greeting'
grep -q 'From request to play' templates/homepage/widgets.yaml || \
  fail C-86 'widgets.yaml must use product slogan as subtitle'
grep -q 'timeStyle: short' templates/homepage/widgets.yaml || \
  fail C-86 'widgets.yaml datetime must prefer time-only'
if grep -qE 'dateStyle:' templates/homepage/widgets.yaml; then
  fail C-86 'widgets.yaml datetime must not show dateStyle (time-only header)'
fi
grep -q 'Household:' templates/homepage/services.yaml || \
  fail C-86 'services must nest Watch/Request under Household'
grep -q 'tab: Ops' templates/homepage/settings.yaml || \
  fail C-86 'settings must use Ops tab for primary glance'
grep -q 'tab: Docs' templates/homepage/settings.yaml || \
  fail C-86 'settings must put Docs on a secondary tab'
grep -q 'headerStyle: clean' templates/homepage/settings.yaml || \
  fail C-86 'settings headerStyle must be clean (Option A: demoted hardware)'
if grep -q 'headerStyle: boxedWidgets' templates/homepage/settings.yaml; then
  fail C-86 'boxedWidgets makes /data compete with Flixbox title'
fi
grep -q 'label: /data' templates/homepage/widgets.yaml || \
  fail C-86 'header resources must prefer /data disk over CPU/RAM hero'
grep -q 'disk: /data' templates/homepage/widgets.yaml || \
  fail C-86 'widgets.yaml must monitor /data storage'
if grep -qE '^\s+cpu:\s*true' templates/homepage/widgets.yaml; then
  fail C-86 'widgets.yaml must not put CPU in the brand header'
fi
grep -q 'Docs:' templates/homepage/bookmarks.yaml || \
  fail C-86 'bookmarks must be Flixbox docs (not social filler)'
grep -q 'header: false' templates/homepage/settings.yaml || \
  fail C-86 'Docs layout must hide duplicate Docs group heading'
grep -qE 'icon: (mdi|si)-' templates/homepage/bookmarks.yaml || \
  fail C-86 'Docs bookmarks must use mdi-/si- icons (not abbr tiles)'
[[ -f templates/homepage/custom.js ]] || \
  fail C-86 'missing templates/homepage/custom.js (header refresh + chip status)'
grep -q 'flixbox-header-refresh' templates/homepage/custom.js || \
  fail C-86 'custom.js must relocate #revalidate beside the clock'
grep -q 'flixbox-chip--vpn' templates/homepage/custom.js || \
  fail C-86 'custom.js must tag vpn/direct chip classes'
grep -q 'flixbox-chip--profile' templates/homepage/custom.js || \
  fail C-86 'custom.js must tag LAN access-profile chip'
grep -qE 'text: "(direct|vpn)"' templates/homepage/widgets.yaml || \
  fail C-86 'widgets.yaml must have a separate network-mode chip (vpn|direct)'
grep -qE 'text: "(trusted|shared)"' templates/homepage/widgets.yaml || \
  fail C-86 'widgets.yaml must have a separate access-profile chip (trusted|shared)'
if grep -qE 'text: "(vpn|direct)\s*·\s*(trusted|shared)"' templates/homepage/widgets.yaml; then
  fail C-86 'mode and profile must be separate chips (not combined with ·)'
fi
grep -q 'custom.js' bin/flixbox || \
  fail C-86 'copy_templates must install custom.js'
grep -q 'server: local-docker' templates/homepage/services.yaml || \
  fail C-86 'services must bind Docker status via local-docker'
grep -q 'container: flixbox-jellyfin' templates/homepage/services.yaml || \
  fail C-86 'Jellyfin must expose Docker container status'
grep -q 'siteMonitor: http://jellyfin:8096' templates/homepage/services.yaml || \
  fail C-86 'Jellyfin must use internal siteMonitor'
grep -q 'siteMonitor: http://byparr:8191/health' templates/homepage/services.yaml || \
  fail C-86 'Byparr must use siteMonitor (HTTP health), not ICMP ping'
grep -q 'numberOfGrabs' templates/homepage/services.yaml || \
  fail C-86 'Prowlarr fields must use Homepage keys numberOfGrabs/numberOfQueries'
grep -q 'useEqualHeights: true' templates/homepage/settings.yaml || \
  fail C-86 'Ops cards must useEqualHeights for row rhythm'
grep -q 'min-height: 6.75rem' templates/homepage/custom.css || \
  fail C-86 'Ops cards must share min-height rhythm (6.75rem)'
grep -q 'flex: 1 1 0' templates/homepage/custom.css || \
  fail C-86 'metric chips must share card width evenly (flex 1 1 0)'
grep -q 'fields: \["itemsHandled", "reclaimable"\]' templates/homepage/services.yaml || \
  fail C-86 'Maintainerr must limit glance fields to itemsHandled + reclaimable'
if grep -qE '^\s+ping:\s*http' templates/homepage/services.yaml; then
  fail C-86 'HTTP health checks must use siteMonitor, not ping:'
fi
grep -q 'FLIXBOX_PUBLIC_HOST' .env.example || \
  fail C-86 '.env.example must document FLIXBOX_PUBLIC_HOST'
grep -q 'HOMEPAGE_ALLOWED_HOSTS=localhost:3000,127.0.0.1:3000,192.168.1.50:3000' .env.example || \
  fail C-86 '.env.example must show commented LAN HOMEPAGE_ALLOWED_HOSTS example'
grep -q 'FLIXBOX_PUBLIC_HOST' docs/user/13-access-profiles.md || \
  fail C-86 'access-profiles must document FLIXBOX_PUBLIC_HOST for Homepage LAN links'
grep -q 'FLIXBOX_PUBLIC_HOST' scripts/lib/homepage-sync.py || \
  fail C-86 'homepage-sync must honor FLIXBOX_PUBLIC_HOST'
grep -q 'SHARED_ADMIN_DESCRIPTION' scripts/lib/homepage-sync.py || \
  fail C-86 'homepage-sync must rewrite shared admin descriptions'
grep -q '127.0.0.1' scripts/lib/homepage-sync.py || \
  fail C-86 'homepage-sync must point shared admin hrefs at 127.0.0.1'
grep -q 'flixbox_sync_public_host_env' scripts/lib/access-profile.sh || \
  fail C-86 'access-profile must sync HOMEPAGE_ALLOWED_HOSTS from FLIXBOX_PUBLIC_HOST'
grep -q 'flixbox_sync_public_host_env' scripts/lib/configure-entry.sh || \
  fail C-86 'configure-entry must call flixbox_sync_public_host_env'
grep -q 'FLIXBOX_PUBLIC_HOST' bin/flixbox || \
  fail C-86 'bin/flixbox must warn when FLIXBOX_PUBLIC_HOST is unset'
grep -q 'FLIXBOX_PUBLIC_HOST' docs/adr/0015-access-profiles.md || \
  fail C-86 'ADR 0015 must document FLIXBOX_PUBLIC_HOST LAN URL sync'
# Unit: public-host env sync appends allowlist + fills empty Jellyfin URL
_ph_tmp="$(mktemp -d)"
cat >"${_ph_tmp}/.env" <<'EOF'
FLIXBOX_PUBLIC_HOST=http://192.168.1.50:9999
HOMEPAGE_PORT=3000
HOMEPAGE_ALLOWED_HOSTS=localhost:3000,127.0.0.1:3000
JELLYFIN_PORT=8096
JELLYFIN_PUBLISHED_URL=
EOF
# shellcheck disable=SC1091
ROOT_DIR="$(pwd)" source scripts/lib/access-profile.sh
flixbox_sync_public_host_env "${_ph_tmp}/.env"
_ph_host="$(flixbox_env_file_get "${_ph_tmp}/.env" FLIXBOX_PUBLIC_HOST)"
_ph_allow="$(flixbox_env_file_get "${_ph_tmp}/.env" HOMEPAGE_ALLOWED_HOSTS)"
_ph_jf="$(flixbox_env_file_get "${_ph_tmp}/.env" JELLYFIN_PUBLISHED_URL)"
[[ "${_ph_host}" == "192.168.1.50" ]] || { rm -rf "${_ph_tmp}"; fail C-86 "normalize PUBLIC_HOST got ${_ph_host}"; }
[[ "${_ph_allow}" == *'192.168.1.50:3000'* ]] || { rm -rf "${_ph_tmp}"; fail C-86 "allowlist missing public host: ${_ph_allow}"; }
[[ "${_ph_jf}" == "http://192.168.1.50:8096" ]] || { rm -rf "${_ph_tmp}"; fail C-86 "Published URL got ${_ph_jf}"; }
# Idempotent second pass
flixbox_sync_public_host_env "${_ph_tmp}/.env"
[[ "${FLIXBOX_HOMEPAGE_ENV_CHANGED}" == "0" ]] || { rm -rf "${_ph_tmp}"; fail C-86 'second sync must not re-flag allowlist change'; }
# Do not overwrite custom Published URL
flixbox_env_file_set "${_ph_tmp}/.env" JELLYFIN_PUBLISHED_URL 'https://jellyfin.example.com'
flixbox_sync_public_host_env "${_ph_tmp}/.env"
_ph_jf="$(flixbox_env_file_get "${_ph_tmp}/.env" JELLYFIN_PUBLISHED_URL)"
[[ "${_ph_jf}" == "https://jellyfin.example.com" ]] || { rm -rf "${_ph_tmp}"; fail C-86 'must preserve custom JELLYFIN_PUBLISHED_URL'; }
rm -rf "${_ph_tmp}"

grep -q 'bookmarks.yaml' bin/flixbox || \
  fail C-86 'copy_templates must install bookmarks.yaml'
python3 - <<'PY' || fail C-86 'homepage-sync unit test failed'
import os, subprocess, tempfile
from pathlib import Path

sample = """---
- Media:
    - Jellyfin:
        href: http://localhost:8096
    - Seerr:
        href: http://nas.local:5055
- Downloads:
    - qBittorrent:
        href: http://localhost:8080
        description: Downloads
        widget:
          type: qbittorrent
          url: http://qbittorrent:8080
          username: admin
          password: password
    - Radarr:
        href: http://localhost:7878
        description: Movies
        siteMonitor: http://radarr:7878
        widget:
          type: radarr
          url: http://radarr:7878
          key: ""
          fields: ["wanted", "queued"]
          highlight:
            wanted:
              numeric:
                - level: warn
                  when: gte
                  value: 10
                - level: danger
                  when: gte
                  value: 25
    - Byparr:
        href: http://localhost:8191
        description: Cloudflare bypass
        siteMonitor: http://byparr:8191/health
        widget:
          type: customapi
          url: http://byparr:8191/health
          mappings:
            - field: msg
              label: Status
              format: text
    - Custom App:
        href: http://localhost:8080
"""

with tempfile.NamedTemporaryFile("w+", delete=False) as f:
    f.write(sample)
    f.flush()
    path = f.name

try:
    env = {
        **os.environ,
        "FLIXBOX_ACCESS_PROFILE": "trusted",
        "FLIXBOX_PUBLIC_HOST": "",
        "JELLYFIN_API_KEY": "",
        "SEERR_API_KEY": "",
        "BAZARR_API_KEY": "",
        "QBITTORRENT_PORT": "9898",
        "QBITTORRENT_USERNAME": "testuser",
        "QBITTORRENT_PASSWORD": "testpassword",
        "RADARR_API_KEY": "secret_radarr_key",
        "JELLYFIN_PORT": "8097",
        "SEERR_PORT": "5056",
    }
    res = subprocess.run(["python3", "scripts/lib/homepage-sync.py", path], env=env, capture_output=True, text=True)
    if res.returncode != 0:
        raise AssertionError(f"homepage-sync.py exited with {res.returncode}")

    content = Path(path).read_text()
    assert "href: http://localhost:9898" in content, "qBittorrent port not updated"
    assert "username: testuser" in content, "qBittorrent username not updated"
    assert "password: testpassword" in content, "qBittorrent password not updated"
    assert "key: secret_radarr_key" in content, "Radarr API key not updated"
    assert "href: http://localhost:8097" in content, "Jellyfin port not updated"
    assert "href: http://nas.local:5056" in content, "Seerr custom host not preserved"
    assert "url: http://qbittorrent:8080" in content, "qBit widget URL was incorrectly altered"
    assert "Custom App:\n        href: http://localhost:8080" in content, "Custom app was altered"

    # shared: must not inject/retain admin widget secrets; drop admin widget blocks
    Path(path).write_text(sample)
    env_shared = {
        **env,
        "FLIXBOX_ACCESS_PROFILE": "shared",
        "FLIXBOX_PUBLIC_HOST": "192.168.1.50",
        "QBITTORRENT_PASSWORD": "should-not-appear",
        "RADARR_API_KEY": "should-not-appear-radarr",
    }
    res_s = subprocess.run(
        ["python3", "scripts/lib/homepage-sync.py", path],
        env=env_shared,
        capture_output=True,
        text=True,
    )
    if res_s.returncode != 0:
        raise AssertionError(f"homepage-sync shared exited {res_s.returncode}: {res_s.stderr}")
    shared_content = Path(path).read_text()
    assert "should-not-appear" not in shared_content, "shared profile injected admin secrets"
    assert "password: password" not in shared_content, "shared profile left sample qBit password"
    assert "href: http://192.168.1.50:8097" in shared_content, "shared must rewrite Jellyfin href to PUBLIC_HOST"
    assert "href: http://192.168.1.50:5056" in shared_content, "shared + PUBLIC_HOST pins Seerr to PUBLIC_HOST"
    assert "href: http://127.0.0.1:9898" in shared_content, "shared admin qBit href must be 127.0.0.1 + port"
    assert "href: http://127.0.0.1:7878" in shared_content, "shared admin Radarr href must be 127.0.0.1"
    assert "Host-only in shared" in shared_content, "shared admin descriptions must say host-only"
    assert "href: http://localhost:9898" not in shared_content, "shared must not leave localhost admin hrefs"
    assert "href: http://192.168.1.50:7878" not in shared_content, "shared must not publish admin hrefs on LAN IP"
    assert "type: qbittorrent" not in shared_content, "shared must remove qBit admin widget"
    assert "type: radarr" not in shared_content, "shared must remove Radarr admin widget"
    assert "type: customapi" not in shared_content, "shared must remove Byparr admin widget"
    assert "- level: warn" not in shared_content, "shared must not leave orphaned highlight YAML"
    assert "- field: msg" not in shared_content, "shared must not leave orphaned mappings YAML"
    assert "siteMonitor: http://radarr:7878" in shared_content, "shared must keep Radarr siteMonitor"
    assert "qBittorrent:" in shared_content and "Radarr:" in shared_content
    import yaml
    yaml.safe_load(shared_content)  # must remain valid YAML after admin widget purge

    # trusted + PUBLIC_HOST: rewrite consumer and admin localhost hrefs
    Path(path).write_text(sample)
    env_pub = {**env, "FLIXBOX_PUBLIC_HOST": "flixbox.lan"}
    res_p = subprocess.run(
        ["python3", "scripts/lib/homepage-sync.py", path],
        env=env_pub,
        capture_output=True,
        text=True,
    )
    if res_p.returncode != 0:
        raise AssertionError(f"homepage-sync PUBLIC_HOST exited {res_p.returncode}")
    pub_content = Path(path).read_text()
    assert "href: http://flixbox.lan:8097" in pub_content, "trusted PUBLIC_HOST must rewrite Jellyfin"
    assert "href: http://flixbox.lan:9898" in pub_content, "trusted PUBLIC_HOST must rewrite qBit"
    assert "href: http://flixbox.lan:5056" in pub_content, "trusted PUBLIC_HOST pins Seerr host"

    # PUBLIC_HOST change must update already-rewritten consumer hrefs (no stale IP)
    Path(path).write_text(pub_content)
    env_pub2 = {**env, "FLIXBOX_PUBLIC_HOST": "192.168.9.9"}
    res_p2 = subprocess.run(
        ["python3", "scripts/lib/homepage-sync.py", path],
        env=env_pub2,
        capture_output=True,
        text=True,
    )
    if res_p2.returncode != 0:
        raise AssertionError(f"homepage-sync PUBLIC_HOST rotate exited {res_p2.returncode}")
    pub2 = Path(path).read_text()
    assert "href: http://192.168.9.9:8097" in pub2, "PUBLIC_HOST rotate must update Jellyfin"
    assert "flixbox.lan" not in pub2, "old PUBLIC_HOST must not linger in managed hrefs"

    # widgets.yaml: rewrite mode + profile chips separately; keep brand + slogan
    with tempfile.TemporaryDirectory() as td:
        tdir = Path(td)
        target_services = tdir / "services.yaml"
        target_widgets = tdir / "widgets.yaml"
        target_services.write_text(sample)
        target_widgets.write_text(
            """---
- logo:
    icon: /images/logo.png
- greeting:
    text: "Flixbox"
    text_size: xl
- greeting:
    text: "From request to play"
    text_size: md
- greeting:
    text: "direct"
    text_size: sm
- greeting:
    text: "trusted"
    text_size: sm
- datetime:
    text_size: sm
    format:
      timeStyle: short
- resources:
    label: /data
    disk: /data
"""
        )
        env_vpn = {**env, "FLIXBOX_MODE": "vpn", "FLIXBOX_ACCESS_PROFILE": "trusted"}
        res_w = subprocess.run(
            ["python3", "scripts/lib/homepage-sync.py", str(target_services)],
            env=env_vpn,
            capture_output=True,
            text=True,
        )
        if res_w.returncode != 0:
            raise AssertionError(f"widgets sync exited {res_w.returncode}: {res_w.stderr}")
        w = target_widgets.read_text()
        assert 'text: "Flixbox"' in w, "brand greeting must stay Flixbox"
        assert "From request to play" in w, "slogan must not be overwritten by chip sync"
        assert 'text: "vpn"' in w, "mode chip must sync to vpn"
        assert 'text: "trusted"' in w, "profile chip must sync to trusted"
        assert "vpn · trusted" not in w, "must not recombine mode·profile into one chip"

    # Test idempotency (no modifications on re-run)
    Path(path).write_text(content)
    res2 = subprocess.run(["python3", "scripts/lib/homepage-sync.py", path], env=env, capture_output=True, text=True)
    assert res2.stdout.strip() == "", "homepage-sync.py is not idempotent"
finally:
    Path(path).unlink(missing_ok=True)
PY
pass C-86

# --- C-88: Homepage template refresh (warn + opt-in apply) ---
[[ -f templates/homepage/.flixbox-template-rev ]] || \
  fail C-88 'missing templates/homepage/.flixbox-template-rev'
rev="$(tr -d '[:space:]' <templates/homepage/.flixbox-template-rev)"
[[ "$rev" =~ ^[0-9]+$ ]] || fail C-88 "template-rev must be a positive integer (got: ${rev})"
[[ -f scripts/lib/homepage-templates.sh ]] || fail C-88 'missing scripts/lib/homepage-templates.sh'
[[ -x scripts/lib/homepage-templates.sh ]] || fail C-88 'homepage-templates.sh must be executable'
grep -q 'flixbox_homepage_refresh' scripts/lib/homepage-templates.sh || \
  fail C-88 'homepage-templates.sh must define flixbox_homepage_refresh'
grep -q 'homepage-templates.sh' bin/flixbox || \
  fail C-88 'bin/flixbox must source homepage-templates.sh'
grep -q 'cmd_homepage' bin/flixbox || fail C-88 'bin/flixbox must define cmd_homepage'
grep -q 'homepage refresh' bin/flixbox || fail C-88 'bin/flixbox usage must mention homepage refresh'
grep -q -- '--reset-homepage' bin/flixbox || \
  fail C-88 'bin/flixbox reload must support --reset-homepage'
grep -q 'flixbox_homepage_warn_if_stale' bin/flixbox || \
  fail C-88 'up/reload/status must warn when Homepage templates are stale'
grep -q 'flixbox_homepage_stamp_applied_from_template' bin/flixbox || \
  fail C-88 'copy_templates must stamp applied-rev only on first services.yaml create'
grep -q 'homepage refresh' docs/user/REFERENCE.md || \
  fail C-88 'REFERENCE must document homepage refresh'
# Managed files listed in lib must exist in templates
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  [[ -f "templates/homepage/${rel}" ]] || \
    fail C-88 "managed Homepage template missing: ${rel}"
done < <(bash -c 'source scripts/lib/homepage-templates.sh; flixbox_homepage_managed_files')
# Unit: stale warn + refresh stamp in temp CONFIG_DIR
bash -c '
set -euo pipefail
ROOT_DIR="$(pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/homepage-templates.sh"
log() { :; }
ok() { :; }
warn() { printf "%s\n" "$*" >&2; }
CONFIG_DIR="$(mktemp -d)"
export CONFIG_DIR ROOT_DIR
trap "rm -rf \"$CONFIG_DIR\"" EXIT
mkdir -p "${CONFIG_DIR}/homepage/images"
cp templates/homepage/services.yaml "${CONFIG_DIR}/homepage/services.yaml"
cp templates/homepage/settings.yaml "${CONFIG_DIR}/homepage/settings.yaml"
cp templates/homepage/widgets.yaml "${CONFIG_DIR}/homepage/widgets.yaml"
cp templates/homepage/bookmarks.yaml "${CONFIG_DIR}/homepage/bookmarks.yaml"
cp templates/homepage/docker.yaml "${CONFIG_DIR}/homepage/docker.yaml"
cp templates/homepage/custom.css "${CONFIG_DIR}/homepage/custom.css"
cp templates/homepage/custom.js "${CONFIG_DIR}/homepage/custom.js"
cp templates/homepage/images/logo.png "${CONFIG_DIR}/homepage/images/logo.png"
cp templates/homepage/images/background.jpg "${CONFIG_DIR}/homepage/images/background.jpg"
# No applied-rev → stale
flixbox_homepage_templates_stale
out="$(flixbox_homepage_warn_if_stale 2>&1 || true)"
echo "$out" | grep -q "homepage refresh" || { echo "warn missing refresh hint"; exit 1; }
# Dry-run must not stamp
flixbox_homepage_refresh --dry-run >/dev/null
! flixbox_homepage_applied_rev >/dev/null 2>&1
# Apply (skip docker restart by temporarily shadowing restart fn)
flixbox_homepage_restart_container() { return 0; }
flixbox_homepage_refresh >/dev/null
applied="$(flixbox_homepage_applied_rev)"
tmpl="$(flixbox_homepage_template_rev)"
[[ "$applied" == "$tmpl" ]] || { echo "stamp mismatch $applied vs $tmpl"; exit 1; }
! flixbox_homepage_templates_stale
flixbox_homepage_refresh >/dev/null
[[ "$(flixbox_homepage_applied_rev)" == "$tmpl" ]]
ls -d "${CONFIG_DIR}"/homepage.bak.* >/dev/null
' || fail C-88 'homepage template refresh unit test failed'
# If git can see origin/main and managed templates changed, rev must change too
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  if git diff --name-only origin/main...HEAD -- \
      templates/homepage/services.yaml \
      templates/homepage/settings.yaml \
      templates/homepage/widgets.yaml \
      templates/homepage/bookmarks.yaml \
      templates/homepage/docker.yaml \
      templates/homepage/custom.css \
      templates/homepage/custom.js \
      templates/homepage/images/logo.png \
      templates/homepage/images/background.jpg \
      | grep -q .; then
    if ! git diff origin/main...HEAD -- templates/homepage/.flixbox-template-rev | grep -qE '^\+[0-9]+$'; then
      # Allow first introduction of the rev file itself
      if git cat-file -e origin/main:templates/homepage/.flixbox-template-rev 2>/dev/null; then
        fail C-88 'managed Homepage templates changed without bumping .flixbox-template-rev'
      fi
    fi
  fi
fi
pass C-88

# --- C-90: Decluttarr defaults (VPN-safe REMOVE_SLOW off; longer stalled grace) ---
grep -q 'REMOVE_SLOW: ${DECLUTTARR_REMOVE_SLOW:-False}' compose/optimization.yml || \
  fail C-90 'optimization.yml must default REMOVE_SLOW to False'
grep -q 'TIMER: ${DECLUTTARR_REMOVE_TIMER:-15}' compose/optimization.yml || \
  fail C-90 'optimization.yml must default TIMER to 15'
grep -q 'max_strikes: ${DECLUTTARR_STRIKES:-12}' compose/optimization.yml || \
  fail C-90 'optimization.yml must default max_strikes to 12'
grep -qE '^DECLUTTARR_REMOVE_SLOW=False' .env.example || \
  fail C-90 '.env.example must ship DECLUTTARR_REMOVE_SLOW=False'
grep -qE '^DECLUTTARR_REMOVE_TIMER=15' .env.example || \
  fail C-90 '.env.example must ship DECLUTTARR_REMOVE_TIMER=15'
grep -qE '^DECLUTTARR_STRIKES=12' .env.example || \
  fail C-90 '.env.example must ship DECLUTTARR_STRIKES=12'
grep -qE '^DECLUTTARR_MIN_SPEED=' .env.example && \
  fail C-90 '.env.example must not ship DECLUTTARR_MIN_SPEED (not wired in Compose)'
grep -q 'warn_decluttarr_vpn_slow' bin/flixbox || \
  fail C-90 'bin/flixbox missing warn_decluttarr_vpn_slow'
grep -A80 '^cmd_up()' bin/flixbox | grep -q 'warn_decluttarr_vpn_slow' || \
  fail C-90 'cmd_up must call warn_decluttarr_vpn_slow'
grep -A80 '^cmd_reload()' bin/flixbox | grep -q 'warn_decluttarr_vpn_slow' || \
  fail C-90 'cmd_reload must call warn_decluttarr_vpn_slow'
grep -A120 '^cmd_status()' bin/flixbox | grep -q 'warn_decluttarr_vpn_slow' || \
  fail C-90 'cmd_status must call warn_decluttarr_vpn_slow'
grep -qE 'Remove slow \| \*\*off\*\*' docs/09-hygiene-defaults.md || \
  fail C-90 'docs/09-hygiene-defaults.md must document REMOVE_SLOW off'
pass C-90

# --- Compose render (shared script — R4) ---
"${ROOT_DIR}/scripts/ci-compose-render.sh" || exit 1
pass compose-config

# --- Local ShellCheck parity (if installed) ---
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S warning -e SC1091 "${ROOT_DIR}/bin/flixbox" "${ROOT_DIR}"/scripts/*.sh "${ROOT_DIR}"/scripts/lib/*.sh "${ROOT_DIR}"/scripts/configure/*.sh \
    "${ROOT_DIR}"/scripts/ci-validate.sh "${ROOT_DIR}"/scripts/ci-smoke-init.sh "${ROOT_DIR}"/scripts/ci-compose-render.sh \
    "${ROOT_DIR}"/scripts/ci-trivy.sh "${ROOT_DIR}"/scripts/ci-smoke-configure.sh "${ROOT_DIR}"/scripts/ci-smoke-vpn.sh \
    "${ROOT_DIR}"/scripts/ci-pin-digests.sh || fail shellcheck 'shellcheck reported warnings or errors'
  pass shellcheck
fi


# --- C-91: ADR 0021 Phase A CLI contract (Q-01..Q-06) ---
grep -q 'cmd_version()' bin/flixbox || fail C-91 'bin/flixbox missing cmd_version'
grep -q 'cmd_doctor()' bin/flixbox || fail C-91 'bin/flixbox missing cmd_doctor'
grep -q 'cmd_logs()' bin/flixbox || fail C-91 'bin/flixbox missing cmd_logs (must stay wired to usage)'
grep -q 'cmd_vpn_test()' bin/flixbox || fail C-91 'bin/flixbox missing cmd_vpn_test (must stay wired to usage)'
grep -q 'cli-msg.sh' bin/flixbox || fail C-91 'bin/flixbox must source cli-msg.sh'
[[ -f scripts/lib/cli-msg.sh ]] || fail C-91 'missing scripts/lib/cli-msg.sh'
[[ -f scripts/lib/status-glance.py ]] || fail C-91 'missing scripts/lib/status-glance.py'
grep -q 'die_usage()' bin/flixbox || fail C-91 'bin/flixbox missing die_usage (exit 2)'
grep -q 'die_docker()' bin/flixbox || fail C-91 'bin/flixbox missing die_docker (exit 3)'
grep -q 'cli-phase-a.sh' bin/flixbox || fail C-91 'bin/flixbox must source cli-phase-a.sh'
[[ -f scripts/lib/cli-phase-a.sh ]] || fail C-91 'missing scripts/lib/cli-phase-a.sh'
[[ -f VERSION ]] || fail C-91 'missing VERSION file'
[[ -f docs/user/17-cli.md ]] || fail C-91 'missing docs/user/17-cli.md'
# Q-01 unknown command → exit 2
rc=0; ./bin/flixbox __no_such_command__ >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 2 ]] || fail C-91 "unknown command exit want 2 got ${rc}"
# Q-02 version / --version → exit 0; stdout non-empty
out="$(./bin/flixbox version 2>/dev/null)" || fail C-91 'version failed'
[[ -n "$out" ]] || fail C-91 'version stdout empty'
./bin/flixbox --version >/dev/null || fail C-91 '--version failed'
# Q-03 help and status --help → exit 0
./bin/flixbox help >/dev/null || fail C-91 'help failed'
./bin/flixbox status --help >/dev/null || fail C-91 'status --help failed'
# Q-04/Q-05 status --json: schemaVersion present; Docker-down → exit 3 (this environment may lack daemon)
rc=0
json="$(./bin/flixbox status --json 2>/dev/null)" || rc=$?
echo "$json" | grep -q '"schemaVersion"[[:space:]]*:[[:space:]]*1' || fail C-91 'status --json missing schemaVersion 1'
if ! docker info >/dev/null 2>&1; then
  [[ "$rc" -eq 3 ]] || fail C-91 "status --json without Docker want exit 3 got ${rc}"
fi
# Human doctor tokens remain meaningful without color
doctor_out="$(NO_COLOR=1 ./bin/flixbox doctor 2>/dev/null || true)"
echo "$doctor_out" | grep -qE '^PASS  ' || fail C-91 'doctor human output missing PASS tokens under NO_COLOR'
# Q-06 ShellCheck covers bin/flixbox via existing shellcheck block
pass C-91


printf 'All contract checks passed.\n'
