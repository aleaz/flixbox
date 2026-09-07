#!/usr/bin/env python3
"""
Sincroniza quirúrgicamente los puertos de acceso externo, credenciales de widgets
y el estado de protección de red (VPN vs Directo) en Homepage (services.yaml)
con las variables de entorno actuales de Flixbox (.env).

Preserva el 100% de la estructura, comentarios, widgets y servicios personalizados.
"""

import os
import re
import sys
from pathlib import Path

CORE_PORT_ENV_MAP = {
    "qBittorrent": "QBITTORRENT_PORT",
    "Prowlarr": "PROWLARR_PORT",
    "Radarr": "RADARR_PORT",
    "Sonarr": "SONARR_PORT",
    "Bazarr": "BAZARR_PORT",
    "Jellyfin": "JELLYFIN_PORT",
    "Seerr": "SEERR_PORT",
    "Maintainerr": "MAINTAINERR_PORT",
    "Byparr": "BYPARR_PORT",
}

DEFAULT_PORTS = {
    "qBittorrent": "8080",
    "Prowlarr": "9696",
    "Radarr": "7878",
    "Sonarr": "8989",
    "Bazarr": "6767",
    "Jellyfin": "8096",
    "Seerr": "5055",
    "Maintainerr": "6246",
    "Byparr": "8191",
}

OPTIONAL_WIDGET_TEMPLATES = {
    "Seerr": """widget:
  type: seerr
  url: http://seerr:5055
  key: {key}
  fields: ["pending", "approved"]
""",
    "Jellyfin": """widget:
  type: jellyfin
  url: http://jellyfin:8096
  key: {key}
  enableNowPlaying: true
""",
    "Bazarr": """widget:
  type: bazarr
  url: http://bazarr:6767
  key: {key}
""",
}


def _indent_block(block: str, spaces: int) -> str:
    pad = " " * spaces
    out = []
    for raw in block.splitlines():
        if raw.strip() == "":
            out.append("\n")
        else:
            # block uses 2-space nested indent relative to first line
            out.append(f"{pad}{raw}\n")
    return "".join(out)

DIRECT_CARD = """    - Network Status:
        href: https://github.com/aleaz/flixbox/blob/main/docs/user/07-vpn-and-direct.md
        description: Direct (No VPN) — qBit uses host IP
        icon: mdi-shield-alert
"""

VPN_CARD = """    - VPN Tunnel:
        href: https://github.com/aleaz/flixbox/blob/main/docs/user/07-vpn-and-direct.md
        description: Protected P2P Tunnel
        icon: gluetun.png
        server: local-docker
        container: flixbox-gluetun
        widget:
          type: gluetun
          url: http://qbittorrent:8000
          version: 2
"""


def sync_vpn_mode_card(content: str) -> str:
    mode = os.environ.get("FLIXBOX_MODE", "direct").strip().lower()
    vpn_enabled = os.environ.get("VPN_ENABLED", "false").strip().lower()
    is_vpn = (mode == "vpn" or vpn_enabled == "true")
    target_block = VPN_CARD if is_vpn else DIRECT_CARD

    if "Network Status:" in content or "VPN Tunnel:" in content:
        lines = content.splitlines(keepends=True)
        out = []
        skipping = False
        svc_re = re.compile(r"^(\s*-\s+)([A-Za-z0-9_-]+(\s+[A-Za-z0-9_-]+)*):")
        item_re = re.compile(r"^\s*-\s+")

        for line in lines:
            m_svc = svc_re.match(line)
            if m_svc:
                name = m_svc.group(2)
                if name in ("Network Status", "VPN Tunnel"):
                    skipping = True
                    out.append(target_block)
                    continue
                else:
                    skipping = False
            elif item_re.match(line):
                skipping = False

            if skipping:
                continue

            out.append(line)
        return "".join(out)

    lines = content.splitlines(keepends=True)
    out = []
    in_qbit = False
    inserted = False
    svc_re = re.compile(r"^(\s*-\s+)([A-Za-z0-9_-]+):")

    for line in lines:
        m_svc = svc_re.match(line)
        if m_svc:
            if in_qbit and not inserted:
                out.append(target_block)
                inserted = True
                in_qbit = False
            if m_svc.group(2) == "qBittorrent":
                in_qbit = True
        out.append(line)

    if in_qbit and not inserted:
        out.append(target_block)

    return "".join(out)


def sync_homepage_services(filepath: Path) -> bool:
    if not filepath.is_file():
        return False

    with open(filepath, "r", encoding="utf-8") as f:
        orig_content = f.read()

    content = sync_vpn_mode_card(orig_content)
    lines = content.splitlines(keepends=True)

    # Credenciales desde entorno
    profile = os.environ.get("FLIXBOX_ACCESS_PROFILE", "trusted").strip().lower()
    shared_profile = profile == "shared"

    # Under shared, Homepage is LAN-reachable without auth — do not inject admin secrets
    # (ADR 0015 / remediation R3). Consumer apps Jellyfin/Seerr may still get keys.
    qb_user = None if shared_profile else os.environ.get("QBITTORRENT_USERNAME")
    qb_pass = None if shared_profile else os.environ.get("QBITTORRENT_PASSWORD")
    radarr_key = None if shared_profile else os.environ.get("RADARR_API_KEY")
    sonarr_key = None if shared_profile else os.environ.get("SONARR_API_KEY")
    prowlarr_key = None if shared_profile else os.environ.get("PROWLARR_API_KEY")
    bazarr_key = None if shared_profile else os.environ.get("BAZARR_API_KEY")
    jellyfin_key = os.environ.get("JELLYFIN_API_KEY")
    seerr_key = os.environ.get("SEERR_API_KEY")

    admin_widget_services = {
        "qBittorrent",
        "Prowlarr",
        "Radarr",
        "Sonarr",
        "Maintainerr",
        "Byparr",
        "Bazarr",
    }

    optional_keys = {
        "Seerr": seerr_key,
        "Jellyfin": jellyfin_key,
    }
    if not shared_profile:
        optional_keys["Bazarr"] = bazarr_key


    svc_regex = re.compile(r"^(\s*-\s+)([A-Za-z0-9_-]+):")
    href_regex = re.compile(r"^(\s*href:\s*https?://[^:/]+)(?::\d+)?(.*)$")
    item_regex = re.compile(r"^\s*-\s+")
    widget_regex = re.compile(r"^(\s*)widget:\s*$")
    key_regex = re.compile(r"^(\s*key:\s*).*$")
    user_regex = re.compile(r"^(\s*username:\s*).*$")
    pass_regex = re.compile(r"^(\s*password:\s*).*$")

    # Paso 1: Eliminar bloques widget vacíos / admin widgets bajo shared
    step1_lines = []
    current_service = None
    skipping_widget = False

    for line in lines:
        m_svc = svc_regex.match(line)
        if m_svc:
            current_service = m_svc.group(2)
            skipping_widget = False
            step1_lines.append(line)
            continue

        if item_regex.match(line):
            current_service = None
            skipping_widget = False

        # shared: drop entire admin widget blocks (not just blank credentials)
        if (
            shared_profile
            and current_service in admin_widget_services
            and widget_regex.match(line)
        ):
            skipping_widget = True
            continue

        if current_service in optional_keys and widget_regex.match(line):
            if not optional_keys[current_service]:
                skipping_widget = True
                continue

        if skipping_widget:
            if line.startswith("        ") or line.startswith("          "):
                continue
            else:
                skipping_widget = False

        step1_lines.append(line)

    # Paso 2: Escanear cuáles servicios ya tienen widget
    has_widget = {}
    current_service = None
    for line in step1_lines:
        m_svc = svc_regex.match(line)
        if m_svc:
            current_service = m_svc.group(2)
            continue
        if item_regex.match(line):
            current_service = None
        if current_service and widget_regex.match(line):
            has_widget[current_service] = True

    # Paso 3: Sincronizar puertos href, credenciales existentes e inyectar widgets cuando corresponda
    final_lines = []
    current_service = None
    current_key_indent = 8
    in_widget = False

    def maybe_inject_widget(svc, key_indent: int):
        if svc in OPTIONAL_WIDGET_TEMPLATES and not has_widget.get(svc):
            k = optional_keys.get(svc)
            if k:
                body = OPTIONAL_WIDGET_TEMPLATES[svc].format(key=k)
                final_lines.append(_indent_block(body, key_indent))
                has_widget[svc] = True

    for line in step1_lines:
        m_svc = svc_regex.match(line)
        if m_svc:
            maybe_inject_widget(current_service, current_key_indent)
            current_service = m_svc.group(2)
            # Keys under "- Service:" sit 4 spaces deeper than the dash column.
            dash_col = len(line) - len(line.lstrip(" "))
            current_key_indent = dash_col + 4
            in_widget = False
            final_lines.append(line)
            continue

        if item_regex.match(line):
            maybe_inject_widget(current_service, current_key_indent)
            current_service = None
            in_widget = False

        # Actualización de puerto href
        if current_service and current_service in CORE_PORT_ENV_MAP:
            m_href = href_regex.match(line)
            if m_href:
                env_var = CORE_PORT_ENV_MAP[current_service]
                target_port = os.environ.get(env_var) or DEFAULT_PORTS.get(current_service)
                new_line = f"{m_href.group(1)}:{target_port}{m_href.group(2)}"
                if not line.endswith("\n") and line.endswith("\r\n"):
                    new_line += "\r\n"
                elif line.endswith("\n"):
                    new_line += "\n"
                line = new_line

        # Detección de bloque widget
        if current_service and widget_regex.match(line):
            in_widget = True
            final_lines.append(line)
            continue

        # Sincronización de credenciales dentro de widget
        if in_widget and current_service:
            new_val = None
            line_regex = None

            # shared: admin widgets already removed in step 1; keep blanking as safety net
            if shared_profile and current_service in admin_widget_services:
                if user_regex.match(line):
                    new_val = ""
                    line_regex = user_regex
                elif pass_regex.match(line):
                    new_val = ""
                    line_regex = pass_regex
                elif key_regex.match(line):
                    new_val = ""
                    line_regex = key_regex
            elif current_service == "qBittorrent":
                if qb_user and user_regex.match(line):
                    new_val = qb_user
                    line_regex = user_regex
                elif qb_pass and pass_regex.match(line):
                    new_val = qb_pass
                    line_regex = pass_regex
            elif current_service == "Radarr" and radarr_key and key_regex.match(line):
                new_val = radarr_key
                line_regex = key_regex
            elif current_service == "Sonarr" and sonarr_key and key_regex.match(line):
                new_val = sonarr_key
                line_regex = key_regex
            elif current_service == "Prowlarr" and prowlarr_key and key_regex.match(line):
                new_val = prowlarr_key
                line_regex = key_regex
            elif current_service in optional_keys and key_regex.match(line):
                k = optional_keys.get(current_service)
                if k:
                    new_val = k
                    line_regex = key_regex

            if new_val is not None and line_regex:
                m = line_regex.match(line)
                new_line = f"{m.group(1)}{new_val}"
                if not line.endswith("\n") and line.endswith("\r\n"):
                    new_line += "\r\n"
                elif line.endswith("\n"):
                    new_line += "\n"
                line = new_line

        final_lines.append(line)

    maybe_inject_widget(current_service, current_key_indent)

    new_content = "".join(final_lines)
    if new_content != orig_content:
        tmp_path = filepath.with_suffix(filepath.suffix + ".tmp")
        try:
            st = filepath.stat()
            orig_mode = st.st_mode
        except OSError:
            orig_mode = 0o644

        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write(new_content)

        try:
            os.chmod(tmp_path, orig_mode)
        except OSError:
            pass

        os.replace(tmp_path, filepath)
        return True

    return False


def sync_homepage_widgets(filepath: Path) -> bool:
    """Rewrite mode + profile status greetings from FLIXBOX_MODE / FLIXBOX_ACCESS_PROFILE.

    Two separate sm greetings (not a combined \"mode · profile\" chip):
      - network mode: vpn | direct
      - LAN access profile: trusted | shared
    """
    if not filepath.is_file():
        return False

    mode = (os.environ.get("FLIXBOX_MODE") or "direct").strip().lower() or "direct"
    vpn_enabled = (os.environ.get("VPN_ENABLED") or "false").strip().lower()
    if mode not in ("vpn", "direct"):
        mode = "vpn" if vpn_enabled == "true" else "direct"
    profile = (os.environ.get("FLIXBOX_ACCESS_PROFILE") or "trusted").strip().lower() or "trusted"
    if profile not in ("trusted", "shared"):
        profile = "trusted"

    with open(filepath, "r", encoding="utf-8") as f:
        orig = f.read()
    lines = orig.splitlines(keepends=True)

    out: list[str] = []
    i = 0
    changed = False
    while i < len(lines):
        line = lines[i]
        if re.match(r"^-\s*greeting:\s*$", line):
            block = [line]
            j = i + 1
            while j < len(lines) and (
                lines[j].startswith(" ") or lines[j].startswith("\t") or lines[j].strip() == ""
            ):
                if re.match(r"^-\s+\S", lines[j]):
                    break
                block.append(lines[j])
                j += 1
            # Only rewrite sm status chips — not slogan (md) or brand (xl).
            is_sm = any(re.search(r"text_size:\s*sm\b", b) for b in block)
            block_text = "\n".join(block)
            is_mode = bool(
                re.search(r'text:\s*"(?:vpn|direct)"\s*$', block_text, re.IGNORECASE | re.M)
            )
            is_profile = bool(
                re.search(r'text:\s*"(?:trusted|shared)"\s*$', block_text, re.IGNORECASE | re.M)
            )
            # Migrate legacy combined chip → mode text (profile is a sibling greeting).
            is_legacy = bool(
                re.search(
                    r'text:\s*"(?:vpn|direct)\s*·\s*(?:trusted|shared)"',
                    block_text,
                    re.IGNORECASE,
                )
            )
            target: str | None = None
            if is_sm and is_mode:
                target = mode
            elif is_sm and is_profile:
                target = profile
            elif is_sm and is_legacy:
                target = mode
            if target is not None:
                new_block: list[str] = []
                for b in block:
                    if re.match(r"^(\s*text:\s*).*$", b):
                        m = re.match(r"^(\s*text:\s*).*$", b)
                        assert m is not None
                        nl = f'{m.group(1)}"{target}"'
                        if b.endswith("\r\n"):
                            nl += "\r\n"
                        elif b.endswith("\n"):
                            nl += "\n"
                        if nl != b:
                            changed = True
                        new_block.append(nl)
                    else:
                        new_block.append(b)
                out.extend(new_block)
            else:
                out.extend(block)
            i = j
            continue
        out.append(line)
        i += 1

    if not changed:
        return False

    new_content = "".join(out)
    tmp_path = filepath.with_suffix(filepath.suffix + ".tmp")
    try:
        orig_mode = filepath.stat().st_mode
    except OSError:
        orig_mode = 0o644
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    try:
        os.chmod(tmp_path, orig_mode)
    except OSError:
        pass
    os.replace(tmp_path, filepath)
    return True


def main():
    if len(sys.argv) < 2:
        sys.exit(0)

    target_file = Path(sys.argv[1])
    if not target_file.exists():
        sys.exit(0)

    messages: list[str] = []
    if sync_homepage_services(target_file):
        messages.append(f"Synced Homepage services in {target_file}")

    widgets_file = target_file.parent / "widgets.yaml"
    if widgets_file.is_file() and sync_homepage_widgets(widgets_file):
        messages.append(f"Synced Homepage status chips in {widgets_file}")

    for msg in messages:
        print(msg)


if __name__ == "__main__":
    main()
