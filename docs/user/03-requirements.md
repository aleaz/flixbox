# Requirements

## Software

| Requirement | Notes |
| --- | --- |
| Docker Engine 24+ | Non-root daemon access required (`docker` group on Linux); or **OrbStack** / Docker Desktop on macOS |
| Compose plugin ≥ 2.20 | `docker compose version` |
| Git | To clone the repo |
| Bash 4+ | For `bin/flixbox` on Linux / WSL2 / macOS |

## Platforms

| Platform | Support |
| --- | --- |
| Linux x86_64 / ARM64 | **First-class** (user in `docker` group) |
| Windows + WSL2 (ext4 data path) | Best-effort |
| macOS OrbStack / Docker Desktop | Best-effort dev; Linux for release smoke |

On Linux, ensure your regular user can access the Docker daemon without `sudo` (`sudo usermod -aG docker "$USER"`).
Store `${DATA_DIR}` on a filesystem that supports hardlinks (**not exFAT**). On WSL2, keep data on the Linux filesystem — not `/mnt/c/...`.

## Hardware (practical)

| Role | Suggestion |
| --- | --- |
| OS + `${CONFIG_DIR}` | SSD/NVMe |
| `${DATA_DIR}` (media) | Large disk or single-filesystem pool |
| Transcoding | Optional GPU (Intel QSV / Nvidia / AMD); otherwise CPU |
| RAM | **4 GB** floor (tight); **8 GB** comfortable; more if 4K transcode / Byparr |

## Network

- LAN access to service ports (or Caddy on 80/443)
- Outbound HTTPS for metadata and indexers
- VPN credentials if you enable VPN mode
- **Do not** expose raw *arr ports to the public internet without auth (SSO is later / v0.4; prefer LAN or a hardened reverse proxy)

Torrent-specific privacy (VPN mode, qBit settings, leak checks): [Torrent privacy and security](12-torrent-privacy-and-security.md).

## Accounts you will need later

- Indexer / tracker credentials (Prowlarr)
- Optional VPN provider (Gluetun)
- Optional OpenSubtitles (Bazarr)
- Jellyfin users for Seerr / Maintainerr

## Next

[Install](04-install.md)
