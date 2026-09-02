#!/usr/bin/env bash
#
# Configure runtime: private temp dir, cleanup traps, verbose redaction.
# Sourced by configure-helpers.sh; call configure_runtime_init from configure-apps.sh.

CONFIGURE_TMPDIR=""
CONFIGURE_RUNTIME_INITIALIZED=false

configure_runtime_init() {
  if $CONFIGURE_RUNTIME_INITIALIZED; then
    return 0
  fi
  CONFIGURE_TMPDIR=$(mktemp -d)
  chmod 700 "${CONFIGURE_TMPDIR}"
  trap configure_runtime_cleanup EXIT INT TERM
  CONFIGURE_RUNTIME_INITIALIZED=true
}

configure_runtime_cleanup() {
  if [[ -n "${CONFIGURE_TMPDIR}" && -d "${CONFIGURE_TMPDIR}" ]]; then
    rm -rf "${CONFIGURE_TMPDIR}"
    CONFIGURE_TMPDIR=""
  fi
  CONFIGURE_RUNTIME_INITIALIZED=false
}

configure_tmpfile() {
  if [[ -z "${CONFIGURE_TMPDIR}" ]]; then
    configure_runtime_init
  fi
  mktemp "${CONFIGURE_TMPDIR}/flixbox.XXXXXX"
}

flixbox_json() {
  python3 "${FLIXBOX_JSON_PAYLOAD:?FLIXBOX_JSON_PAYLOAD not set}"
}

# Redact common secret keys from JSON/text for verbose configure logs.
configure_redact() {
  python3 -c '
import json, re, sys
text = sys.stdin.read()
try:
    data = json.loads(text)
except json.JSONDecodeError:
    print(re.sub(r"(password|apiKey|apikey|Pw|secret|token)(\"?\s*[:=]\s*\")([^\"]+)(\")",
                 r"\1\2***\4", text, flags=re.I))
    sys.exit(0)

def redact(obj):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            if isinstance(k, str) and k.lower() in (
                "password", "apikey", "pw", "secret", "token", "accesstoken"
            ):
                out[k] = "***"
            else:
                out[k] = redact(v)
        return out
    if isinstance(obj, list):
        return [redact(x) for x in obj]
    return obj

print(json.dumps(redact(data)))
'
}
