#!/usr/bin/env bash
# Thin wrapper → ./bin/flixbox backup (ADR 0021). Same CONFIG-only scope; DATA_DIR is operator-owned.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${ROOT_DIR}/bin/flixbox" backup "$@"
