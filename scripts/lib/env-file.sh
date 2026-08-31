#!/usr/bin/env bash
#
# Safe .env KEY=value helpers (ADR 0005 / remediation D1–D2).
# Sourced by CLI and scripts — not executed directly.
# Uses python3 so values may contain | & / \ and other sed metacharacters.

flixbox_env_file_set() {
  local env_file="$1" key="$2" value="$3"
  [[ -n "$key" ]] || return 1
  if ! command -v python3 >/dev/null 2>&1; then
    echo "flixbox_env_file_set: python3 is required" >&2
    return 1
  fi
  FLIXBOX_ENV_FILE="$env_file" FLIXBOX_ENV_KEY="$key" FLIXBOX_ENV_VALUE="$value" python3 <<'PY'
import os
from pathlib import Path

path = Path(os.environ["FLIXBOX_ENV_FILE"])
key = os.environ["FLIXBOX_ENV_KEY"]
value = os.environ["FLIXBOX_ENV_VALUE"]
if "\n" in value or "\r" in value:
    raise SystemExit(f"refusing newline in value for {key}")
if "=" in key or "\n" in key or "\r" in key:
    raise SystemExit(f"invalid env key: {key!r}")

prefix = f"{key}="
lines = path.read_text().splitlines() if path.exists() else []
out = []
found = False
for line in lines:
    if line.startswith(prefix):
        out.append(prefix + value)
        found = True
    else:
        out.append(line)
if not found:
    if out and out[-1] != "":
        out.append("")
    out.append(prefix + value)
path.write_text("\n".join(out) + "\n")
PY
}

flixbox_env_file_get() {
  local env_file="$1" key="$2"
  [[ -f "$env_file" ]] || return 0
  grep -E "^${key}=" "$env_file" 2>/dev/null | head -1 | cut -d= -f2- || true
}

# Write only when key is missing or empty. No-op if value is empty.
flixbox_env_file_set_if_empty() {
  local env_file="$1" key="$2" value="$3"
  local current
  [[ -f "$env_file" ]] || return 0
  [[ -n "$value" ]] || return 0
  current="$(flixbox_env_file_get "$env_file" "$key")"
  [[ -n "$current" ]] && return 0
  flixbox_env_file_set "$env_file" "$key" "$value"
}
