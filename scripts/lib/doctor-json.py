#!/usr/bin/env python3
"""Build flixbox doctor --json payload (schemaVersion 2). No secrets."""
from __future__ import annotations

import json
import os
import sys


def b(name: str) -> bool:
    return os.environ.get(name) == "true"


def main() -> int:
    obj = {
        "schemaVersion": 2,
        "ok": os.environ.get("HARD_FAIL") == "0",
        "cliVersion": os.environ.get("CLI_VER") or "",
        "mode": os.environ.get("MODE") or "",
        "accessProfile": os.environ.get("PROFILE") or "",
        "checks": {
            "dockerCli": b("DOCKER_CLI"),
            "dockerDaemon": b("DOCKER_DAEMON"),
            "composePlugin": b("COMPOSE_PLUGIN"),
            "envFile": b("ENV_FILE"),
            "dataDir": b("DATA_DIR_OK"),
            "configDir": b("CONFIG_DIR_OK"),
            "modeVpnAligned": b("MODE_ALIGNED"),
            "accessProfileOk": b("PROFILE_OK"),
            "hardlinkProbe": os.environ.get("HARDLINK_PROBE") or "skipped",
            "dataFs": {
                "status": os.environ.get("DATA_FS_STATUS") or "skipped",
                "type": os.environ.get("DATA_FS_TYPE") or "",
                "detail": os.environ.get("DATA_FS_DETAIL") or "",
            },
            "configFs": {
                "status": os.environ.get("CONFIG_FS_STATUS") or "skipped",
                "type": os.environ.get("CONFIG_FS_TYPE") or "",
                "detail": os.environ.get("CONFIG_FS_DETAIL") or "",
            },
            "apiKeysPresent": {
                "radarr": b("RADARR_KEY"),
                "sonarr": b("SONARR_KEY"),
                "prowlarr": b("PROWLARR_KEY"),
            },
            "gluetun": os.environ.get("GLUETUN") or "skipped",
        },
        "hint": os.environ.get("HINT") or "",
    }
    json.dump(obj, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
