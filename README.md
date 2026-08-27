# Flixbox

Open-source, containerized home media automation for people who want a clear *arr-style stack:

**request → index → download → hardlink → maintain → stream**

Built with modular Docker Compose, Gluetun (VPN or Direct), Seerr, Jellyfin, Servarr tooling, and Decluttarr/Maintainerr hygiene — aligned with [TRaSH Guides](https://trash-guides.info/) storage practices.

> **Status: Working Draft.** Contracts and user docs are in place. Application code is not implemented yet.

<!-- When README.es.md exists, add: Also available in [Spanish](README.es.md). -->

## Why Flixbox

- **One `/data` tree** so imports hardlink instead of copying
- **VPN or Direct** for torrents (only the download client goes through Gluetun)
- **Modern defaults:** Seerr, Byparr, Recyclarr, Unpackerr, Decluttarr, Maintainerr
- **Bash CLI** for day-0 and day-2 operations (`bin/flixbox`)
- **Linux first**, MIT licensed

## Quick start (downloaders available now)

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
cp .env.example .env
# FLIXBOX_MODE=direct  or  vpn (+ VPN secrets)
./scripts/bootstrap-dirs.sh
docker compose up -d
./scripts/vpn-test.sh
```

Open http://localhost:8080 (qBittorrent). See [Install](docs/user/04-install.md) and [VPN and Direct](docs/user/07-vpn-and-direct.md).

> Servarr, Seerr, Jellyfin, and `bin/flixbox` land in later phases ([development guide](docs/06-development-guide.md)).

## Documentation

| For | Start here |
| --- | --- |
| **Operators (you)** | [User guide](docs/user/INDEX.md) |
| How the model works | [How it works](docs/user/02-how-it-works.md) |
| Contributors / design | [Docs map](docs/INDEX.md) · [ADRs](docs/adr/) |
| AI agents | [AGENTS.md](AGENTS.md) |

Spanish user docs: planned in `docs/es/user/` + `README.es.md` before the first public release ([ADR 0011](docs/adr/0011-documentation-i18n.md)).

## MVP services (planned)

Gluetun, qBittorrent, Prowlarr, Byparr, Radarr, Sonarr, Bazarr, Unpackerr, Recyclarr, Decluttarr, Maintainerr, Seerr, Jellyfin, Homepage, Caddy (optional docker-socket-proxy).

## Platforms

- **First-class:** Linux (x86_64 / ARM64)
- **Best-effort:** Windows (Docker Desktop + WSL2 ext4), macOS

## License

[MIT](LICENSE) © 2026 Alejandro Azario

## Disclaimer

You are responsible for complying with applicable laws and terms of service for any content or indexers you use with this software.
