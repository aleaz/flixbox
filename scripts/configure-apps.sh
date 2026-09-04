#!/usr/bin/env bash
#
# Idempotent API wiring for Flixbox after first container start (ADR 0005).
#
# Usage:
#   ./scripts/configure-apps.sh [--dry-run] [--verbose] [--sync-qbit-auth] [--sync-arr-ui]
#   ./bin/flixbox configure [--dry-run] [--verbose] [--sync-qbit-auth] [--sync-arr-ui]
#
# Module layout: scripts/configure/*.sh (preflight, arr-common, per-service modules).
# Shared helpers: scripts/lib/configure-helpers.sh
# Env loading: scripts/lib/flixbox-env.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

CONFIGURE_DIR="${ROOT_DIR}/scripts/configure"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/flixbox-env.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/configure-helpers.sh"

DRY_RUN=false
VERBOSE=false
# Exported: consumed by sourced configure modules (ShellCheck SC2034).
export SYNC_QBIT_AUTH=false
export SYNC_ARR_UI=false
export QBIT_COOKIE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --verbose|-v) VERBOSE=true; shift ;;
    --sync-qbit-auth) SYNC_QBIT_AUTH=true; shift ;;
    --sync-arr-ui) SYNC_ARR_UI=true; shift ;;
    --help|-h)
      sed -n '2,28p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--dry-run] [--verbose] [--sync-qbit-auth] [--sync-arr-ui]" >&2
      exit 1
      ;;
  esac
done

flixbox_load_configure_env

configure_runtime_init
configure_context_reset
QBIT_COOKIE=$(configure_tmpfile)
export QBIT_COOKIE

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/configure-entry.sh"
configure_entry_prepare

for _configure_module in preflight arr-common qbittorrent prowlarr bazarr jellyfin seerr hygiene; do
  # shellcheck disable=SC1090
  source "${CONFIGURE_DIR}/${_configure_module}.sh"
done

if [[ "${FLIXBOX_ACCESS_PROFILE:-trusted}" == "shared" ]]; then
  info "Access profile: shared — admin ports on 127.0.0.1; apply Forms with ./bin/flixbox credentials set arr-ui or configure --sync-arr-ui (ADR 0020)"
fi

echo "=== Flixbox app configuration ==="
echo ""

configure_preflight

configure_qbittorrent
echo ""
configure_arr_service "Sonarr" "$SONARR_PORT" "$SONARR_API_KEY" "/data/media/tv" "tv" \
  "$QBIT_ARR_HOST" "$QBIT_API_KEY" "$QBIT_USERNAME" "$QBIT_PASSWORD"
echo ""
configure_arr_service "Radarr" "$RADARR_PORT" "$RADARR_API_KEY" "/data/media/movies" "movies" \
  "$QBIT_ARR_HOST" "$QBIT_API_KEY" "$QBIT_USERNAME" "$QBIT_PASSWORD"
echo ""
configure_prowlarr
echo ""
configure_bazarr
echo ""
patch_recyclarr_keys
echo ""
configure_jellyfin
flixbox_load_configure_env
echo ""
configure_seerr
echo ""
reload_hygiene_if_needed

if [[ "${SYNC_ARR_UI:-false}" == "true" ]]; then
  echo ""
  log "Syncing *arr Forms credentials from FLIXBOX_ARR_UI_* (ADR 0020)..."
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/scripts/lib/credentials.sh"
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    if [[ "${FLIXBOX_ACCESS_PROFILE:-trusted}" == "shared" ]]; then
      dry "Apply FLIXBOX_ARR_UI_* via Host Config to Prowlarr/Radarr/Sonarr"
    else
      dry "Skip arr-ui Host Config apply (profile=${FLIXBOX_ACCESS_PROFILE:-trusted}; need shared)"
    fi
  elif flixbox_apply_arr_ui_credentials; then
    ok "arr-ui Forms sync complete"
  else
    fail "arr-ui Forms sync incomplete — see warnings above"
  fi
fi

echo ""
log "Done: ${CONFIGURED} configured, ${SKIPPED} skipped, ${FAILED} failed"
echo ""
log "Still manual:"
info "  • Prowlarr: add your indexers (tag cf on Cloudflare indexers)"
info "  • Maintainerr: connect services + enable rules deliberately"
info "  • Optional: docker compose --profile recyclarr run --rm recyclarr sync"
info "  • Guide: docs/user/05-first-run.md"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
