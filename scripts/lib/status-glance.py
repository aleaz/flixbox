#!/usr/bin/env python3
"""Print a narrow SERVICE / STATE / HEALTH glance from compose-ps-json array."""
from __future__ import annotations

import json
import os
import sys


def main() -> int:
    raw = os.environ.get("SERVICES_JSON")
    if raw is None:
        raw = sys.stdin.read()
    try:
        services = json.loads(raw or "[]")
    except json.JSONDecodeError:
        services = []
    if not isinstance(services, list):
        services = []

    print(f"{'SERVICE':<22} {'STATE':<12} {'HEALTH'}")
    if not services:
        print(f"{'(none)':<22} {'-':<12} {'-'}")
        return 0
    for row in services:
        service = (row.get("service") or row.get("name") or "-").strip() or "-"
        state = (row.get("state") or "-").strip() or "-"
        health = (row.get("health") or "").strip() or "-"
        # Compose sometimes puts "Up 2 days (healthy)" into State — keep short.
        if len(state) > 12 and "(" in state:
            state = state.split()[0]
        print(f"{service:<22} {state:<12} {health}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
