#!/usr/bin/env python3
"""Build JSON (and form) payloads for configure scripts.

Secrets and user-controlled strings must be passed via environment variables,
never interpolated into shell JSON strings. See docs/05-standards.md §6.

Avoid standard shell env names for payload inputs (e.g. PATH — use JELLYFIN_LIB_PATH).
Prefix new vars when ambiguous (FLIXBOX_* / service-specific names).
"""

from __future__ import annotations

import json
import os
import sys
import urllib.parse
from typing import Callable


def _require(*keys: str) -> dict[str, str]:
    missing = [k for k in keys if not os.environ.get(k)]
    if missing:
        print(f"json-payload: missing env: {', '.join(missing)}", file=sys.stderr)
        sys.exit(2)
    return {k: os.environ[k] for k in keys}


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.lower() in ("1", "true", "yes", "on")


def _env_int(name: str, default: int | None = None) -> int:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        if default is None:
            print(f"json-payload: missing env: {name}", file=sys.stderr)
            sys.exit(2)
        return default
    return int(raw)


def _read_stdin_json() -> object:
    raw = sys.stdin.read()
    if not raw.strip():
        print("json-payload: expected JSON on stdin", file=sys.stderr)
        sys.exit(2)
    return json.loads(raw)


def jellyfin_startup_user() -> str:
    env = _require("NAME", "PASSWORD")
    return json.dumps({"Name": env["NAME"], "Password": env["PASSWORD"]})


def jellyfin_auth() -> str:
    env = _require("USERNAME", "PASSWORD")
    return json.dumps({"Username": env["USERNAME"], "Pw": env["PASSWORD"]})


def jellyfin_password_change() -> str:
    env = _require("CURRENT_PW", "NEW_PW")
    return json.dumps(
        {
            "CurrentPw": env["CURRENT_PW"],
            "NewPw": env["NEW_PW"],
            "ResetPassword": False,
        }
    )


def seerr_login() -> str:
    env = _require("USERNAME", "PASSWORD")
    payload: dict[str, object] = {
        "username": env["USERNAME"],
        "password": env["PASSWORD"],
    }
    if _env_bool("BOOTSTRAP"):
        payload.update(
            {
                "hostname": "jellyfin",
                "port": 8096,
                "useSsl": False,
                "urlBase": "",
                "email": f"{env['USERNAME']}@localhost",
                "serverType": 2,
            }
        )
    return json.dumps(payload)


def seerr_radarr_service() -> str:
    env = _require(
        "HOST",
        "PORT",
        "API_KEY",
        "PROFILE_ID",
        "PROFILE_NAME",
        "ROOT",
        "IS_DEFAULT",
    )
    return json.dumps(
        {
            "name": "Radarr",
            "hostname": env["HOST"],
            "port": int(env["PORT"]),
            "apiKey": env["API_KEY"],
            "useSsl": False,
            "baseUrl": "",
            "activeProfileId": int(env["PROFILE_ID"]),
            "activeProfileName": env["PROFILE_NAME"],
            "activeDirectory": env["ROOT"],
            "is4k": False,
            "minimumAvailability": "released",
            "isDefault": _env_bool("IS_DEFAULT"),
            "syncEnabled": True,
            "preventSearch": False,
        }
    )


def seerr_sonarr_service() -> str:
    env = _require(
        "HOST",
        "PORT",
        "API_KEY",
        "PROFILE_ID",
        "PROFILE_NAME",
        "ROOT",
        "LANG_PROFILE_ID",
        "IS_DEFAULT",
    )
    return json.dumps(
        {
            "name": "Sonarr",
            "hostname": env["HOST"],
            "port": int(env["PORT"]),
            "apiKey": env["API_KEY"],
            "useSsl": False,
            "baseUrl": "",
            "activeProfileId": int(env["PROFILE_ID"]),
            "activeProfileName": env["PROFILE_NAME"],
            "activeDirectory": env["ROOT"],
            "activeLanguageProfileId": int(env["LANG_PROFILE_ID"]),
            "activeAnimeProfileId": None,
            "activeAnimeLanguageProfileId": None,
            "activeAnimeDirectory": "",
            "is4k": False,
            "enableSeasonFolders": True,
            "isDefault": _env_bool("IS_DEFAULT"),
            "syncEnabled": True,
            "preventSearch": False,
        }
    )


def seerr_patch_arr_api_key() -> str:
    env = _require("API_KEY")
    data = _read_stdin_json()
    if not isinstance(data, list) or not data:
        print("json-payload: seerr-patch-arr-api-key expects non-empty JSON array", file=sys.stderr)
        sys.exit(2)
    item = dict(data[0])
    item["apiKey"] = env["API_KEY"]
    return json.dumps(item)


def prowlarr_tag() -> str:
    env = _require("LABEL")
    return json.dumps({"label": env["LABEL"]})


def prowlarr_byparr_proxy() -> str:
    tag_id = _env_int("TAG_ID")
    return json.dumps(
        {
            "name": "Byparr",
            "implementation": "FlareSolverr",
            "configContract": "FlareSolverrSettings",
            "fields": [
                {"name": "host", "value": "http://byparr:8191"},
                {"name": "requestTimeout", "value": 60},
            ],
            "tags": [tag_id],
        }
    )


def prowlarr_arr_app() -> str:
    env = _require("ARR_NAME", "PORT", "API_KEY", "CATEGORIES", "TAG_ID")
    name_lower = env["ARR_NAME"].lower()
    categories = json.loads(env["CATEGORIES"])
    return json.dumps(
        {
            "name": env["ARR_NAME"],
            "syncLevel": "fullSync",
            "implementation": env["ARR_NAME"],
            "configContract": f"{env['ARR_NAME']}Settings",
            "fields": [
                {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
                {"name": "baseUrl", "value": f"http://{name_lower}:{env['PORT']}"},
                {"name": "apiKey", "value": env["API_KEY"]},
                {"name": "syncCategories", "value": categories},
            ],
            "tags": [int(env["TAG_ID"])],
        }
    )


def prowlarr_patch_api_key() -> str:
    env = _require("API_KEY")
    data = _read_stdin_json()
    if not isinstance(data, dict):
        print("json-payload: prowlarr-patch-api-key expects JSON object", file=sys.stderr)
        sys.exit(2)
    for field in data.get("fields") or []:
        if field.get("name") == "apiKey":
            field["value"] = env["API_KEY"]
            break
    return json.dumps(data)


def qbit_webui_password() -> str:
    env = _require("PASSWORD")
    return json.dumps({"web_ui_password": env["PASSWORD"]})


def qbit_download_client() -> str:
    env = _require(
        "HOST",
        "CAT_FIELD",
        "CATEGORY",
        "PRIO_RECENT",
        "PRIO_OLDER",
    )
    user = os.environ.get("USER", "")
    password = os.environ.get("PASS", "")
    api_key = os.environ.get("API_KEY", "")
    if not password and not api_key:
        print(
            "json-payload: qbit-download-client needs PASS or API_KEY",
            file=sys.stderr,
        )
        sys.exit(2)
    payload: dict[str, object] = {
        "enable": True,
        "protocol": "torrent",
        "priority": 1,
        "name": "qBittorrent",
        "implementation": "QBittorrent",
        "configContract": "QBittorrentSettings",
        "fields": [
            {"name": "host", "value": env["HOST"]},
            {"name": "port", "value": 8080},
            {"name": "username", "value": user},
            {"name": "password", "value": password},
            {"name": "apiKey", "value": api_key},
            {"name": env["CAT_FIELD"], "value": env["CATEGORY"]},
            {"name": env["PRIO_RECENT"], "value": 0},
            {"name": env["PRIO_OLDER"], "value": 0},
            {"name": "initialState", "value": 0},
            {"name": "sequentialOrder", "value": False},
            {"name": "firstAndLast", "value": False},
        ],
    }
    existing_id = os.environ.get("EXISTING_ID", "").strip()
    if existing_id:
        payload["id"] = int(existing_id)
    return json.dumps(payload)


def qbit_login_form() -> str:
    """URL-encoded login body (for curl -d @file, not argv)."""
    env = _require("USER", "PASS")
    return urllib.parse.urlencode({"username": env["USER"], "password": env["PASS"]})


def jellyfin_library_options() -> str:
    env = _require("JELLYFIN_LIB_PATH")
    return json.dumps({"LibraryOptions": {"PathInfos": [{"Path": env["JELLYFIN_LIB_PATH"]}]}})


def jellyfin_url_quote() -> str:
    env = _require("VALUE")
    return urllib.parse.quote(env["VALUE"])


TEMPLATES: dict[str, Callable] = {
    "jellyfin-startup-user": jellyfin_startup_user,
    "jellyfin-auth": jellyfin_auth,
    "jellyfin-password-change": jellyfin_password_change,
    "jellyfin-library-options": jellyfin_library_options,
    "jellyfin-url-quote": jellyfin_url_quote,
    "seerr-login": seerr_login,
    "seerr-radarr-service": seerr_radarr_service,
    "seerr-sonarr-service": seerr_sonarr_service,
    "seerr-patch-arr-api-key": seerr_patch_arr_api_key,
    "prowlarr-tag": prowlarr_tag,
    "prowlarr-byparr-proxy": prowlarr_byparr_proxy,
    "prowlarr-arr-app": prowlarr_arr_app,
    "prowlarr-patch-api-key": prowlarr_patch_api_key,
    "qbit-webui-password": qbit_webui_password,
    "qbit-download-client": qbit_download_client,
    "qbit-login-form": qbit_login_form,
}


def usage() -> None:
    names = ", ".join(sorted(TEMPLATES))
    print(
        f"Usage: {os.path.basename(sys.argv[0])} TEMPLATE\n"
        f"Templates: {names}\n"
        "Pass secrets via environment variables (see script source).",
        file=sys.stderr,
    )


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] in ("-h", "--help"):
        usage()
        sys.exit(0 if len(sys.argv) == 2 and sys.argv[1] in ("-h", "--help") else 2)
    template = sys.argv[1]
    handler = TEMPLATES.get(template)
    if handler is None:
        print(f"json-payload: unknown template: {template}", file=sys.stderr)
        usage()
        sys.exit(2)
    sys.stdout.write(handler())


if __name__ == "__main__":
    main()
