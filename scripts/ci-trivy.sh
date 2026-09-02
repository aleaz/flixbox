#!/usr/bin/env bash
#
# Trivy config + image scans (warn-only until v0.1 pin policy tightens — docs/10-ci-plan.md §4.3).
# Used by .github/workflows/ci.yml security job; optional locally when trivy is installed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/lib/platform.sh"

CI_ENV="${ROOT_DIR}/.ci-env"
TRIVY_BLOCK="${TRIVY_BLOCK:-0}"

if ! command -v trivy >/dev/null 2>&1; then
  echo "WARN: trivy not installed — skipping security scans (install for local parity)" >&2
  exit 0
fi

fail() {
  printf 'FAIL trivy: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'OK   trivy: %s\n' "$*"
}

trivy_or_warn() {
  local label="$1"
  shift
  if "$@"; then
    return 0
  fi
  if [[ "$TRIVY_BLOCK" == "1" ]]; then
    fail "${label}"
  fi
  echo "WARN: trivy ${label} reported issues (warn-only; set TRIVY_BLOCK=1 to fail)" >&2
  return 0
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

trivy_or_warn "config scan compose/" \
  trivy config --severity CRITICAL,HIGH --exit-code 1 compose/
trivy_or_warn "config scan compose.yaml" \
  trivy config --severity CRITICAL,HIGH --exit-code 1 compose.yaml
pass "config scan (compose/)"

mapfile -t images < <(docker compose --env-file "${CI_ENV}" config --images 2>/dev/null | sort -u)
[[ ${#images[@]} -gt 0 ]] || fail "no images from docker compose config --images"

scanned=0
for img in "${images[@]}"; do
  [[ -n "$img" ]] || continue
  printf 'Scanning image: %s\n' "$img"
  trivy_or_warn "image scan ${img}" \
    trivy image --severity CRITICAL,HIGH --exit-code 1 "$img"
  scanned=$((scanned + 1))
done

pass "image scan (${scanned} images from compose config)"
printf 'Trivy scans completed (policy: %s).\n' "$([[ "$TRIVY_BLOCK" == "1" ]] && echo block || echo warn-only)"
