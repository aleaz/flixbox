<a id="requirements"></a>
# Requisitos

**Idiomas:** [English](../../user/03-requirements.md) · Español (esta página)

## Software

| Requisito | Notas |
| --- | --- |
| Docker Engine 24+ | Se requiere acceso al daemon sin root (`docker` group en Linux); o **OrbStack** / Docker Desktop en macOS |
| Compose plugin ≥ 2.20 | `docker compose version` |
| Git | Para clonar el repo |
| Bash 4+ | Para `bin/flixbox` en Linux / WSL2 / macOS |

<a id="platforms"></a>
## Plataformas

| Plataforma | Soporte |
| --- | --- |
| Linux x86_64 / ARM64 | **De primera clase** (usuario en el grupo `docker`) |
| Windows + WSL2 (ruta de datos en ext4) | Mejor esfuerzo |
| macOS OrbStack / Docker Desktop | Dev mejor esfuerzo; Linux para smoke de release |

En Linux, asegúrate de que tu usuario habitual pueda acceder al daemon de Docker sin `sudo` (`sudo usermod -aG docker "$USER"`).
Guarda `${DATA_DIR}` en un filesystem que soporte hardlinks (**no exFAT**). En WSL2, mantén los datos en el filesystem de Linux — no en `/mnt/c/...`.

<a id="hardware-practical"></a>
## Hardware (práctico)

| Rol | Sugerencia |
| --- | --- |
| OS + `${CONFIG_DIR}` | SSD/NVMe |
| `${DATA_DIR}` (media) | Disco grande o pool de un solo filesystem |
| Transcoding | GPU opcional (Intel QSV / Nvidia / AMD); si no, CPU |
| RAM | Piso **4 GB** (ajustado); **8 GB** cómodo; más si transcodificas 4K / Byparr |

<a id="network"></a>
## Red

- Acceso LAN a los puertos de los servicios (o Caddy en 80/443)
- HTTPS saliente para metadatos e indexers
- Credenciales VPN si activas el modo VPN
- **No** expongas puertos *arr crudos a Internet pública sin auth (SSO es post-MVP; preferir LAN o un reverse proxy endurecido)

Privacidad específica de torrents (modo VPN, ajustes de qBit, chequeos de fugas): [Torrent privacy and security](12-torrent-privacy-and-security.md).

<a id="accounts-you-will-need-later"></a>
## Cuentas que necesitarás después

- Credenciales de indexer / tracker (Prowlarr)
- Proveedor VPN opcional (Gluetun)
- OpenSubtitles opcional (Bazarr)
- Usuarios de Jellyfin para Seerr / Maintainerr

<a id="next"></a>
## Siguiente

[Install](04-install.md)
