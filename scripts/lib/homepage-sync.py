#!/usr/bin/env python3
"""
Sincroniza quirúrgicamente los puertos de acceso externo en Homepage (services.yaml)
con las variables de entorno actuales de Flixbox (.env).

Preserva el 100% de la estructura, comentarios, widgets, servicios personalizados
y URLs personalizadas (e.g. IPs LAN o nombres de host en vez de localhost).
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
}


def sync_homepage_services(filepath: Path) -> bool:
    if not filepath.is_file():
        return False

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.splitlines(keepends=True)
    new_lines = []
    current_service = None
    modified = False

    # Regex para identificar un servicio en services.yaml (ej. "    - qBittorrent:")
    svc_regex = re.compile(r"^(\s*-\s+)([A-Za-z0-9_-]+):")
    # Regex para identificar la clave href (ej. "        href: http://localhost:8080")
    href_regex = re.compile(r"^(\s*href:\s*https?://[^:/]+)(?::\d+)?(.*)$")
    # Regex para detectar cambio de nivel o nuevo item que resetea el servicio activo
    item_regex = re.compile(r"^\s*-\s+")

    for line in lines:
        m_svc = svc_regex.match(line)
        if m_svc:
            current_service = m_svc.group(2)
            new_lines.append(line)
            continue

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

                if new_line != line:
                    line = new_line
                    modified = True
                # Una vez actualizado el href de este servicio, reseteamos para no tocar widgets hijos
                current_service = None

        # Si encontramos otro guión a nivel de lista, reseteamos el servicio actual si no coincidió
        if item_regex.match(line) and not m_svc:
            current_service = None

        new_lines.append(line)

    if modified:
        tmp_path = filepath.with_suffix(filepath.suffix + ".tmp")
        try:
            st = filepath.stat()
            orig_mode = st.st_mode
        except OSError:
            orig_mode = 0o644

        with open(tmp_path, "w", encoding="utf-8") as f:
            f.writelines(new_lines)

        try:
            os.chmod(tmp_path, orig_mode)
        except OSError:
            pass

        os.replace(tmp_path, filepath)
        return True

    return False


def main():
    if len(sys.argv) < 2:
        sys.exit(0)

    target_file = Path(sys.argv[1])
    if not target_file.exists():
        sys.exit(0)

    changed = sync_homepage_services(target_file)
    if changed:
        print(f"Synced ports in {target_file}")


if __name__ == "__main__":
    main()
