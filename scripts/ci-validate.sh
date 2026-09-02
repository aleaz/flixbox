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
grep -q 'flixbox_ensure_seerr_config_owner' scripts/bootstrap-dirs.sh || \
  fail C-11 'bootstrap-dirs.sh must ensure Seerr config is UID 1000'
grep -q 'flixbox_ensure_seerr_config_owner' bin/flixbox || \
  fail C-11 'bin/flixbox init must re-apply Seerr UID 1000 after CONFIG_DIR chown'
[[ -f scripts/lib/seerr-perms.sh ]] || fail C-11 'missing scripts/lib/seerr-perms.sh'
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
pass C-79

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

# --- Compose render (shared script — R4) ---
"${ROOT_DIR}/scripts/ci-compose-render.sh" || exit 1
pass compose-config

printf 'All contract checks passed.\n'
