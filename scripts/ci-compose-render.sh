#!/usr/bin/env bash
#
# Shared docker compose config render tests (direct, VPN, profiles, access profiles).
# Used by scripts/ci-validate.sh and .github/workflows/ci.yml (R4).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/env-file.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/access-profile.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/platform.sh"

CI_ENV="${ROOT_DIR}/.ci-env"
CI_ENV_SHARED="${ROOT_DIR}/.ci-env.shared"

fail() {
  printf 'FAIL compose-render: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'OK   compose-render: %s\n' "$*"
}

write_ci_env() {
  cp -f "${ROOT_DIR}/.env.example" "${CI_ENV}"
  sed_inplace \
    's|^DATA_DIR=.*|DATA_DIR=/tmp/flixbox-ci/data|; s|^CONFIG_DIR=.*|CONFIG_DIR=/tmp/flixbox-ci/config|' \
    "${CI_ENV}"
}

cleanup() {
  rm -f "${CI_ENV}" "${CI_ENV_SHARED}"
  rm -rf /tmp/flixbox-ci
}

trap cleanup EXIT

write_ci_env
COMPOSE=(docker compose --env-file "${CI_ENV}")

"${COMPOSE[@]}" config --quiet || fail "direct mode config failed"
pass "direct"

FLIXBOX_MODE=vpn "${COMPOSE[@]}" config --quiet || fail "vpn mode config failed"
pass "vpn"

"${COMPOSE[@]}" --profile plex --profile proxy --profile socket-proxy --profile recyclarr \
  config --quiet || fail "optional profiles config failed"
pass "profiles (plex, proxy, socket-proxy, recyclarr)"

# Access profile: shared derived bind + auth keys must render (ADR 0015).
cp -f "${CI_ENV}" "${CI_ENV_SHARED}"
flixbox_env_file_set "${CI_ENV_SHARED}" FLIXBOX_ACCESS_PROFILE shared
export FLIXBOX_ACCESS_PROFILE=shared
flixbox_sync_access_profile_env "${CI_ENV_SHARED}"
unset FLIXBOX_ACCESS_PROFILE
docker compose --env-file "${CI_ENV_SHARED}" config --quiet || fail "shared access profile config failed"
pass "access profile shared"

printf 'All compose render checks passed.\n'
