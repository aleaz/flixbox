#!/usr/bin/env bash
#
# Safe .env KEY=value helpers (ADR 0005 / remediation D1–D2).
# Sourced by CLI and scripts — not executed directly.
# Uses python3 so values may contain | & / \ $ ` ' and other shell metacharacters.
# Values are stored single-quoted (POSIX) so `source` of .env is safe.

flixbox_env_file_chmod() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0
  chmod 600 "$env_file" 2>/dev/null || true
}

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

def shell_single_quote(s: str) -> str:
    return "'" + s.replace("'", "'\\''") + "'"

prefix = f"{key}="
encoded = prefix + shell_single_quote(value)
lines = path.read_text().splitlines() if path.exists() else []
out = []
found = False
for line in lines:
    if line.startswith(prefix):
        out.append(encoded)
        found = True
    else:
        out.append(line)
if not found:
    if out and out[-1] != "":
        out.append("")
    out.append(encoded)
path.write_text("\n".join(out) + "\n")
path.chmod(0o600)
PY
}

flixbox_env_file_get() {
  local env_file="$1" key="$2"
  [[ -f "$env_file" ]] || return 0
  if ! command -v python3 >/dev/null 2>&1; then
    grep -E "^${key}=" "$env_file" 2>/dev/null | head -1 | cut -d= -f2- || true
    return 0
  fi
  FLIXBOX_ENV_FILE="$env_file" FLIXBOX_ENV_KEY="$key" python3 <<'PY'
import os
from pathlib import Path

path = Path(os.environ["FLIXBOX_ENV_FILE"])
key = os.environ["FLIXBOX_ENV_KEY"]
prefix = f"{key}="
if not path.exists():
    raise SystemExit(0)
for line in path.read_text().splitlines():
    if line.startswith(prefix):
        raw = line[len(prefix):]
        # Decode POSIX single-quoted form KEY='…' or legacy unquoted KEY=…
        if len(raw) >= 2 and raw[0] == "'" and raw.endswith("'"):
            inner = raw[1:-1]
            print(inner.replace("'\\''", "'"), end="")
        elif len(raw) >= 2 and raw[0] == '"' and raw.endswith('"'):
            print(raw[1:-1], end="")
        else:
            print(raw, end="")
        break
PY
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

# Print `export KEY='…'` lines for safe eval by the caller (no shell metachar expansion of values).
# Skips blank lines and comments. Only KEY=VALUE assignments with [A-Z_][A-Z0-9_]*.
flixbox_env_file_exports() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0
  if ! command -v python3 >/dev/null 2>&1; then
    echo "flixbox_env_file_exports: python3 is required" >&2
    return 1
  fi
  FLIXBOX_ENV_FILE="$env_file" python3 <<'PY'
import os
import re
import shlex
from pathlib import Path

path = Path(os.environ["FLIXBOX_ENV_FILE"])
key_re = re.compile(r"^[A-Z_][A-Z0-9_]*$")

def decode_value(raw: str) -> str:
    if len(raw) >= 2 and raw[0] == "'" and raw.endswith("'"):
        return raw[1:-1].replace("'\\''", "'")
    if len(raw) >= 2 and raw[0] == '"' and raw.endswith('"'):
        return raw[1:-1].replace('\\"', '"').replace("\\\\", "\\")
    return raw

for line in path.read_text().splitlines():
    line = line.rstrip("\r")
    if not line or line.lstrip().startswith("#"):
        continue
    if "=" not in line:
        continue
    key, _, raw = line.partition("=")
    if not key_re.match(key):
        continue
    value = decode_value(raw)
    print(f"export {key}={shlex.quote(value)}")
PY
}
