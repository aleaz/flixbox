#!/usr/bin/env python3
"""Parse docker compose ps --format json into a compact services array."""
from __future__ import annotations

import json
import sys


def main() -> int:
    buf = sys.stdin.read().strip()
    rows: list = []
    if not buf:
        print("[]")
        return 0
    try:
        data = json.loads(buf)
        rows = data if isinstance(data, list) else [data]
    except json.JSONDecodeError:
        for line in buf.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    out = []
    for r in rows:
        out.append(
            {
                "name": r.get("Name") or r.get("Service") or "",
                "service": r.get("Service") or "",
                "state": r.get("State") or r.get("Status") or "",
                "health": r.get("Health") or "",
            }
        )
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
