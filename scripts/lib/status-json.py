#!/usr/bin/env python3
"""Build flixbox status --json payload (schemaVersion 2). No secrets."""
from __future__ import annotations

import json
import os
import sys


def _as_bool(raw: str) -> bool:
    return raw.strip().lower() in ("true", "1", "yes", "on")


def main() -> int:
    services_raw = os.environ.get("SERVICES_JSON") or "[]"
    try:
        services = json.loads(services_raw)
    except json.JSONDecodeError:
        services = []
    err = os.environ.get("ERR") or ""
    docker_ok = os.environ.get("DOCKER_OK") == "true"
    obj = {
        "schemaVersion": 2,
        "ok": docker_ok and not err,
        "cliVersion": os.environ.get("CLI_VER") or "",
        "mode": os.environ.get("FLIXBOX_MODE") or "direct",
        "vpnEnabled": _as_bool(os.environ.get("VPN_ENABLED") or "false"),
        "modeVpnAligned": os.environ.get("MODE_ALIGNED") == "true",
        "accessProfile": os.environ.get("PROFILE") or "",
        "adminBindIp": os.environ.get("FLIXBOX_ADMIN_BIND_IP") or "",
        "dataDir": os.environ.get("DATA_DIR") or "",
        "configDir": os.environ.get("CONFIG_DIR") or "",
        "downloadClientUrl": "http://qbittorrent:8080",
        "services": services,
    }
    if err:
        obj["error"] = err
    json.dump(obj, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
