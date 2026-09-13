#!/usr/bin/env bash
# CLI Phase A helpers (ADR 0021): version, doctor, status --json, exit taxonomy.
# Sourced from bin/flixbox — do not execute directly.

flixbox_exit_ok() { exit 0; }
flixbox_exit_usage() { exit 2; }
flixbox_exit_docker() { exit 3; }
flixbox_exit_config() { exit 4; }
flixbox_exit_deps() { exit 5; }

# Resolve CLI version string (no secrets).
flixbox_cli_version() {
  local ver=""
  if [[ -f "${ROOT_DIR}/VERSION" ]]; then
    ver="$(tr -d '[:space:]' <"${ROOT_DIR}/VERSION")"
  fi
  if [[ -z "$ver" ]] && command -v git >/dev/null 2>&1 && [[ -d "${ROOT_DIR}/.git" ]]; then
    ver="$(git -C "${ROOT_DIR}" describe --tags --always --dirty 2>/dev/null || true)"
  fi
  [[ -n "$ver" ]] || ver="0.0.0-dev"
  printf '%s' "$ver"
}

# True if string looks like a non-empty secret/token (presence only).
flixbox_secret_present() {
  local v="${1:-}"
  [[ -n "$v" && "$v" != "changeme" && "$v" != "replace-me" ]]
}

# Pretty-print a JSON string on stdout.
flixbox_emit_json() {
  FLIXBOX_JSON_PAYLOAD="$1" python3 - <<'PY'
import json, os, sys
raw = os.environ.get("FLIXBOX_JSON_PAYLOAD", "")
try:
    obj = json.loads(raw)
except json.JSONDecodeError as e:
    print(f"flixbox: invalid JSON payload: {e}", file=sys.stderr)
    sys.exit(1)
print(json.dumps(obj, indent=2, sort_keys=False))
PY
}
