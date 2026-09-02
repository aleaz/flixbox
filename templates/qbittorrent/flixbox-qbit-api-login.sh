#!/usr/bin/with-contenv bash
# shellcheck shell=bash
# qBit WebUI login without credentials on docker exec argv (configure host path).
#
# Installed to ${CONFIG_DIR}/qbittorrent/.flixbox/qbit-api-login.sh
# Usage: printf 'user\npass\n' | /config/.flixbox/qbit-api-login.sh COOKIE_PATH [API_BASE]
#
# Exit codes: 0 ok · 1 auth/network fail · 2 WebUI IP banned
# Also used by VPN bind + WebUI contract custom-services (ADR 0019).

set -euo pipefail

COOKIE="${1:?cookie path required}"
API_BASE="${2:-http://127.0.0.1:${WEBUI_PORT:-8080}}"
API="${API_BASE%/}/api/v2"
BODY="$(mktemp)"
# shellcheck disable=SC2064
trap 'rm -f "$BODY"' EXIT

QBIT_USER=""
QBIT_PASS=""

if [[ -t 0 && -n "${QBITTORRENT_USERNAME:-}" && -n "${QBITTORRENT_PASSWORD:-}" ]]; then
  QBIT_USER="${QBITTORRENT_USERNAME}"
  QBIT_PASS="${QBITTORRENT_PASSWORD}"
else
  IFS= read -r QBIT_USER || true
  IFS= read -r QBIT_PASS || true
fi

[[ -n "$QBIT_USER" && -n "$QBIT_PASS" ]] || exit 1

rm -f "$COOKIE"
code=$(curl -s -c "$COOKIE" -o "$BODY" -w '%{http_code}' --max-time 20 \
  -X POST "${API}/auth/login" \
  --data-urlencode "username=${QBIT_USER}" \
  --data-urlencode "password=${QBIT_PASS}" 2>/dev/null || echo 000)

if grep -qi 'banned' "$BODY" 2>/dev/null; then
  exit 2
fi

case "$code" in
  200|204) ;;
  *) exit 1 ;;
esac
chmod 600 "$COOKIE" 2>/dev/null || true

verify=$(curl -s -o /dev/null -w '%{http_code}' -b "$COOKIE" --max-time 20 \
  "${API}/app/version" 2>/dev/null || echo 000)
[[ "$verify" == "200" ]]
