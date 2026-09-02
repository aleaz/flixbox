#!/usr/bin/env python3
"""Named JSON queries for configure scripts (ADR 0016).

Parameters are passed via JSON in JSON_QUERY_PARAMS (never interpolated into Python source).
JSON payload is read from stdin.
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any, Callable


def _params() -> dict[str, Any]:
    raw = os.environ.get("JSON_QUERY_PARAMS", "{}")
    try:
        value = json.loads(raw)
    except json.JSONDecodeError:
        print("json-query: invalid JSON_QUERY_PARAMS", file=sys.stderr)
        sys.exit(2)
    if not isinstance(value, dict):
        print("json-query: JSON_QUERY_PARAMS must be a JSON object", file=sys.stderr)
        sys.exit(2)
    return value


def _require_param(params: dict[str, Any], *keys: str) -> dict[str, Any]:
    missing = [k for k in keys if params.get(k) in (None, "")]
    if missing:
        print(f"json-query: missing params: {', '.join(missing)}", file=sys.stderr)
        sys.exit(2)
    return params


def _read_data() -> Any:
    raw = sys.stdin.read()
    if not raw.strip():
        print("json-query: expected JSON on stdin", file=sys.stderr)
        sys.exit(2)
    return json.loads(raw)


def arr_cf_id_by_name(data: list, params: dict[str, Any]) -> str:
    p = _require_param(params, "cf_name")
    name = p["cf_name"]
    ids = [c["id"] for c in data if c.get("name") == name]
    return str(ids[0]) if ids else ""


def arr_cf_scored_in_profile(data: dict, params: dict[str, Any]) -> None:
    p = _require_param(params, "cf_id", "cf_score")
    cf_id = int(p["cf_id"])
    cf_score = int(p["cf_score"])
    items = data.get("formatItems", [])
    match = [i for i in items if i.get("format") == cf_id]
    if match and match[0].get("score") == cf_score:
        sys.exit(0)
    sys.exit(1)


def arr_cf_patch_profile(data: dict, params: dict[str, Any]) -> str:
    p = _require_param(params, "cf_id", "cf_name", "cf_score")
    cf_id = int(p["cf_id"])
    cf_name = p["cf_name"]
    cf_score = int(p["cf_score"])
    items = [i for i in data.get("formatItems", []) if i.get("format") != cf_id]
    items.insert(0, {"format": cf_id, "name": cf_name, "score": cf_score})
    data["formatItems"] = items
    return json.dumps(data)


def arr_root_folder_exists(data: list, params: dict[str, Any]) -> None:
    p = _require_param(params, "root_path")
    root_path = p["root_path"]
    if any(r.get("path") == root_path for r in data):
        sys.exit(0)
    sys.exit(1)


def arr_qbit_client_id(data: list, _params: dict[str, Any]) -> str:
    ids = [
        c["id"]
        for c in data
        if c.get("name", "").lower() == "qbittorrent"
        or c.get("implementation") == "QBittorrent"
    ]
    return str(ids[0]) if ids else ""


def arr_qbit_client_api_key(data: dict, _params: dict[str, Any]) -> str:
    fields = data.get("fields") or []
    vals = [f.get("value") for f in fields if f.get("name") == "apiKey"]
    if not vals or vals[0] is None:
        return ""
    return str(vals[0])


def arr_xbmc_meta_id(data: list, _params: dict[str, Any]) -> str:
    xbmc = [m for m in data if m.get("implementation") == "XbmcMetadata"]
    return str(xbmc[0]["id"]) if xbmc else ""


def arr_xbmc_enabled(data: list, _params: dict[str, Any]) -> str:
    xbmc = [m for m in data if m.get("implementation") == "XbmcMetadata"]
    if not xbmc:
        return "false"
    return str(bool(xbmc[0].get("enable", False))).lower()


def arr_profile_ids(data: list, _params: dict[str, Any]) -> str:
    return "\n".join(str(p["id"]) for p in data)


def bazarr_conn_diff(data: dict, params: dict[str, Any]) -> str:
    p = _require_param(params, "sonarr_key", "radarr_key")
    want = {
        "sonarr": {
            "ip": "sonarr",
            "port": 8989,
            "base_url": "",
            "ssl": False,
            "apikey": p["sonarr_key"],
        },
        "radarr": {
            "ip": "radarr",
            "port": 7878,
            "base_url": "",
            "ssl": False,
            "apikey": p["radarr_key"],
        },
    }
    general = data.get("general", {})
    diff: list[str] = []
    for section, fields in sorted(want.items()):
        current = data.get(section, {})
        if not general.get("use_" + section):
            diff.append("general.use_" + section)
        for field, expected in sorted(fields.items()):
            if field == "apikey" and not expected:
                continue
            actual = current.get(field)
            if field == "port":
                actual = int(actual) if str(actual).isdigit() else actual
            if actual != expected:
                diff.append(f"{section}.{field}")
    return " ".join(diff) if diff else "MATCH"


def bazarr_subsync_diff(data: dict, _params: dict[str, Any]) -> str:
    want = {
        "use_subsync": True,
        "use_subsync_threshold": True,
        "subsync_threshold": 90,
        "use_subsync_movie_threshold": True,
        "subsync_movie_threshold": 70,
    }
    current = data.get("subsync", {})
    diff = [k for k, v in sorted(want.items()) if current.get(k) != v]
    return " ".join(diff) if diff else "MATCH"


def jellyfin_library_exists(data: list, params: dict[str, Any]) -> None:
    p = _require_param(params, "lib_name", "path")
    lib_name = p["lib_name"].lower()
    path = p["path"]
    if any(
        item.get("Name", "").lower() == lib_name
        or path in (item.get("Locations") or [])
        for item in data
    ):
        sys.exit(0)
    sys.exit(1)


def prowlarr_has_cf_proxy(data: list, _params: dict[str, Any]) -> None:
    if any(
        "byparr" in p.get("name", "").lower()
        or "flaresolverr" in p.get("name", "").lower()
        for p in data
    ):
        sys.exit(0)
    sys.exit(1)


def prowlarr_app_id_by_name(data: list, params: dict[str, Any]) -> str:
    p = _require_param(params, "name_lower")
    name_lower = p["name_lower"].lower()
    ids = [a["id"] for a in data if a.get("name", "").lower() == name_lower]
    return str(ids[0]) if ids else ""


def prowlarr_app_api_key(data: dict, _params: dict[str, Any]) -> str:
    fields = data.get("fields") or []
    vals = [f.get("value") for f in fields if f.get("name") == "apiKey"]
    if not vals or vals[0] is None:
        return ""
    return str(vals[0])


def prowlarr_tag_id_by_label(data: list, params: dict[str, Any]) -> str:
    p = _require_param(params, "label")
    label = p["label"].lower()
    ids = [t["id"] for t in data if t.get("label", "").lower() == label]
    return str(ids[0]) if ids else ""


def print_field(data: Any, params: dict[str, Any]) -> str:
    p = _require_param(params, "field")
    field = p["field"]
    if isinstance(data, dict):
        value = data.get(field, "")
    else:
        value = ""
    return "" if value is None else str(value)


QueryFn = Callable[[Any, dict[str, Any]], str | None]

QUERIES: dict[str, QueryFn] = {
    "arr-cf-id-by-name": arr_cf_id_by_name,
    "arr-cf-scored-in-profile": arr_cf_scored_in_profile,
    "arr-cf-patch-profile": arr_cf_patch_profile,
    "arr-root-folder-exists": arr_root_folder_exists,
    "arr-qbit-client-id": arr_qbit_client_id,
    "arr-qbit-client-api-key": arr_qbit_client_api_key,
    "arr-xbmc-meta-id": arr_xbmc_meta_id,
    "arr-xbmc-enabled": arr_xbmc_enabled,
    "arr-profile-ids": arr_profile_ids,
    "bazarr-conn-diff": bazarr_conn_diff,
    "bazarr-subsync-diff": bazarr_subsync_diff,
    "jellyfin-library-exists": jellyfin_library_exists,
    "prowlarr-has-cf-proxy": prowlarr_has_cf_proxy,
    "prowlarr-app-id-by-name": prowlarr_app_id_by_name,
    "prowlarr-app-api-key": prowlarr_app_api_key,
    "prowlarr-tag-id-by-label": prowlarr_tag_id_by_label,
    "print-field": print_field,
}


def usage() -> None:
    names = ", ".join(sorted(QUERIES))
    print(
        f"Usage: {os.path.basename(sys.argv[0])} QUERY\n"
        f"Queries: {names}\n"
        "JSON on stdin; parameters via JSON_QUERY_PARAMS env (object).",
        file=sys.stderr,
    )


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "--help"):
        usage()
        sys.exit(0 if len(sys.argv) == 2 and sys.argv[1] in ("-h", "--help") else 2)
    query = sys.argv[1]
    handler = QUERIES.get(query)
    if handler is None:
        print(f"json-query: unknown query: {query}", file=sys.stderr)
        usage()
        sys.exit(2)
    data = _read_data()
    params = _params()
    result = handler(data, params)
    if result is not None:
        sys.stdout.write(result)


if __name__ == "__main__":
    main()
