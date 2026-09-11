#!/usr/bin/env python3
"""Clear Jellyfin LocalNetworkAddresses when it is only IPv6 any (::).

A bind of "::" makes Jellyfin advertise stream URLs on ::1, so playback fails on
localhost and LAN. Empty LocalNetworkAddresses lets Jellyfin auto-detect.

This is not a listen/firewall change — Compose still publishes :8096.

Exit codes:
  0 — printed status is cleared|skip|missing
  2 — parse/write error
"""
from __future__ import annotations

import argparse
import sys
import xml.etree.ElementTree as ET


def status_for(path: str) -> tuple[str, ET.ElementTree | None]:
    try:
        tree = ET.parse(path)
    except FileNotFoundError:
        return "missing", None
    except ET.ParseError as exc:
        raise SystemExit(f"error: parse failed: {exc}") from exc

    root = tree.getroot()
    addrs = root.find("LocalNetworkAddresses")
    if addrs is None:
        return "skip", tree

    values = [(node.text or "").strip() for node in addrs.findall("string")]
    non_empty = [v for v in values if v]
    if non_empty and all(v == "::" for v in non_empty):
        return "clear", tree
    return "skip", tree


def apply_clear(tree: ET.ElementTree) -> None:
    root = tree.getroot()
    addrs = root.find("LocalNetworkAddresses")
    if addrs is None:
        return
    for child in list(addrs):
        addrs.remove(child)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", help="Path to Jellyfin network.xml")
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write changes when status would be clear",
    )
    args = parser.parse_args()

    try:
        status, tree = status_for(args.path)
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        return 2

    if status == "clear" and args.apply:
        assert tree is not None
        apply_clear(tree)
        try:
            tree.write(args.path, encoding="utf-8", xml_declaration=True)
        except OSError as exc:
            print(f"error: write failed: {exc}", file=sys.stderr)
            return 2
        print("cleared")
        return 0

    print(status if status != "clear" else "clear")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
