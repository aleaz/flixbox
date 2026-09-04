#!/usr/bin/env python3
"""Apply Servarr Forms username/password via Host Config API (ADR 0020).

Secrets via environment only (never argv):
  USERNAME, PASSWORD, ARR_API_KEY
  ARR_HOST_CONFIG_URL  (e.g. http://127.0.0.1:7878/api/v3/config/host)

Usage:
  USERNAME=... PASSWORD=... ARR_API_KEY=... ARR_HOST_CONFIG_URL=... \\
    python3 arr-host-config-auth.py
"""
from __future__ import annotations

import http.cookiejar
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

_SECRET_KEY_RE = re.compile(
    r'("?(?:password|passwordConfirmation|apiKey|apikey)"?\s*:\s*")([^"]*)(")',
    re.IGNORECASE,
)


def _require(name: str) -> str:
    val = os.environ.get(name, "")
    if not val:
        print(f"arr-host-config-auth: missing env {name}", file=sys.stderr)
        raise SystemExit(2)
    return val


def _redact(raw: bytes | str) -> str:
    if isinstance(raw, bytes):
        text = raw.decode("utf-8", errors="replace")
    else:
        text = raw
    return _SECRET_KEY_RE.sub(r"\1***\3", text)[:300]


def _request(url: str, api_key: str, method: str = "GET", data: dict | None = None) -> tuple[int, bytes]:
    headers = {
        "X-Api-Key": api_key,
        "Accept": "application/json",
    }
    body = None
    if data is not None:
        body = json.dumps(data).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()


def main() -> None:
    if len(sys.argv) > 1:
        print(
            "arr-host-config-auth: do not pass URL/API key on argv "
            "(use ARR_HOST_CONFIG_URL and ARR_API_KEY env)",
            file=sys.stderr,
        )
        raise SystemExit(2)

    base_url = _require("ARR_HOST_CONFIG_URL").rstrip("/")
    api_key = _require("ARR_API_KEY")
    username = _require("USERNAME")
    password = _require("PASSWORD")

    code, raw = _request(base_url, api_key)
    if code != 200:
        print(
            f"arr-host-config-auth: GET failed HTTP {code}: {_redact(raw)}",
            file=sys.stderr,
        )
        raise SystemExit(1)
    host = json.loads(raw)
    host_id = host.get("id")
    if host_id is None:
        print("arr-host-config-auth: host config missing id", file=sys.stderr)
        raise SystemExit(1)

    # Compose may override authenticationMethod/Required via env; still set
    # credentials. Under shared, env already forces Forms + Enabled.
    host["username"] = username
    host["password"] = password
    host["passwordConfirmation"] = password

    put_url = f"{base_url}/{host_id}"
    code, raw = _request(put_url, api_key, method="PUT", data=host)
    if code not in (200, 202):
        print(
            f"arr-host-config-auth: PUT failed HTTP {code}: {_redact(raw)}",
            file=sys.stderr,
        )
        raise SystemExit(1)

    # Verify Forms login without restart (spike 2026-09-04).
    login_url = base_url.split("/api/")[0] + "/login"
    form = urllib.parse.urlencode(
        {"username": username, "password": password, "rememberMe": "false"}
    ).encode()
    login_req = urllib.request.Request(
        login_url,
        data=form,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    jar_cookies: list[str] = []
    try:
        jar = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
        with opener.open(login_req, timeout=20) as resp:
            _ = resp.status
        jar_cookies = [c.name for c in jar]
    except urllib.error.HTTPError as exc:
        print(f"arr-host-config-auth: login verify HTTP {exc.code}", file=sys.stderr)
        raise SystemExit(1) from exc
    except Exception as exc:  # noqa: BLE001 — surface verify failure clearly
        print(f"arr-host-config-auth: login verify failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc

    if not any("auth" in name.lower() for name in jar_cookies):
        print(
            "arr-host-config-auth: login verify produced no *Auth cookie",
            file=sys.stderr,
        )
        raise SystemExit(1)


if __name__ == "__main__":
    main()
