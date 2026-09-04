#!/usr/bin/env bash
#
# Narrow qBit WebUI password rotate (ADR 0020).
# Auth with OLD (or session temp), set NEW, verify re-auth.
# Does not write .env — caller persists on exit 0 or 3.
#
# Env:
#   ROOT_DIR (optional)
#   QBIT_OLD_PASSWORD, QBIT_NEW_PASSWORD (NEW required)
#   QBITTORRENT_USERNAME / QBIT_USERNAME (default admin)
#   QBITTORRENT_PORT (default 8080)
#
# Exit codes (no secrets on stdout/stderr beyond status text):
#   0 — setPreferences OK and re-auth with NEW OK
#   1 — nothing applied (auth failed, or setPreferences failed)
#   3 — setPreferences OK but re-auth with NEW failed (qBit likely has NEW;
#       caller MUST persist NEW to .env)

set -euo pipefail

ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/flixbox-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/configure-helpers.sh"

flixbox_load_configure_env
configure_runtime_init

export QBIT_URL="http://127.0.0.1:${QBITTORRENT_PORT:-8080}"
export QBIT_INTERNAL_API_URL="http://127.0.0.1:8080"
export QBIT_DOCKER_CONTAINER="flixbox-qbittorrent"
export QBIT_DOCKER_COOKIE="/tmp/flixbox-credentials-qbit-cookie.txt"
export QBIT_USERNAME="${QBITTORRENT_USERNAME:-${QBIT_USERNAME:-admin}}"
export QBIT_COOKIE
QBIT_COOKIE=$(configure_tmpfile)

cleanup_cookies() {
  docker exec "${QBIT_DOCKER_CONTAINER}" rm -f "${QBIT_DOCKER_COOKIE}" 2>/dev/null || true
  rm -f "${QBIT_COOKIE:-}" 2>/dev/null || true
}

old_pass="${QBIT_OLD_PASSWORD:-}"
new_pass="${QBIT_NEW_PASSWORD:-}"
[[ -n "$new_pass" ]] || {
  echo "qbit-password-rotate: QBIT_NEW_PASSWORD required" >&2
  exit 1
}

if ! flixbox_container_running "${QBIT_DOCKER_CONTAINER}"; then
  echo "qbit-password-rotate: container ${QBIT_DOCKER_CONTAINER} is not running" >&2
  exit 1
fi

temp_pass=""
temp_pass=$(docker logs "${QBIT_DOCKER_CONTAINER}" 2>&1 \
  | grep -iE 'temporary password|password is' | tail -1 \
  | grep -oE '[^ ]+$' || true)

authed=false
auth_with=""
if [[ -n "$old_pass" ]] && qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$old_pass" "$QBIT_COOKIE"; then
  authed=true
  auth_with="env"
elif [[ -n "$temp_pass" ]] && qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$temp_pass" "$QBIT_COOKIE"; then
  authed=true
  auth_with="temp"
fi

if ! $authed; then
  echo "qbit-password-rotate: authentication failed with current .env password (and no usable session temp password)" >&2
  echo "qbit-password-rotate: align WebUI login first, or check: docker compose logs qbittorrent" >&2
  cleanup_cookies
  exit 1
fi

http_code=$(qbit_set_webui_password "$new_pass")
if [[ "$http_code" != "200" ]]; then
  echo "qbit-password-rotate: setPreferences failed (HTTP ${http_code})" >&2
  cleanup_cookies
  exit 1
fi

# Password change is committed on qBit from here. Prefer verify; on failure
# try rollback to the password we authenticated with, then still signal commit.
committed=true

cleanup_cookies
QBIT_COOKIE=$(configure_tmpfile)

reauthed=false
for attempt in 1 2 3 4 5; do
  if qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$new_pass" "$QBIT_COOKIE"; then
    reauthed=true
    break
  fi
  if [[ "$attempt" -lt 5 ]]; then
    sleep 1
  fi
done

if $reauthed; then
  cleanup_cookies
  exit 0
fi

echo "qbit-password-rotate: re-auth with new password failed after setPreferences" >&2

# Best-effort rollback using a fresh login with NEW (if it intermittently works)
# or re-set OLD if we can still auth somehow. Prefer restoring OLD when possible.
rollback_cookie=$(configure_tmpfile)
export QBIT_COOKIE="$rollback_cookie"
rolled_back=false
if qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$new_pass" "$QBIT_COOKIE"; then
  # Session with NEW works now — not a verify flake; treat as success path below.
  reauthed=true
elif [[ -n "$old_pass" ]] && qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$old_pass" "$QBIT_COOKIE"; then
  rb_code=$(qbit_set_webui_password "$old_pass")
  if [[ "$rb_code" == "200" ]]; then
    echo "qbit-password-rotate: rolled back WebUI password to previous value" >&2
    rolled_back=true
    committed=false
  fi
elif [[ "$auth_with" == "temp" && -n "$temp_pass" ]] && qbit_auth "$QBIT_URL" "$QBIT_USERNAME" "$temp_pass" "$QBIT_COOKIE"; then
  rb_code=$(qbit_set_webui_password "$temp_pass")
  if [[ "$rb_code" == "200" ]]; then
    echo "qbit-password-rotate: rolled back WebUI password to session temp" >&2
    rolled_back=true
    committed=false
  fi
fi

cleanup_cookies

if $reauthed; then
  exit 0
fi
if $rolled_back; then
  echo "qbit-password-rotate: rotate aborted; WebUI restored — .env unchanged" >&2
  exit 1
fi
if $committed; then
  echo "qbit-password-rotate: qBit likely has the NEW password; caller must persist .env (exit 3)" >&2
  exit 3
fi
exit 1
