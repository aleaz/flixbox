# Flixbox

Open-source, containerized home media automation:

**request → index → download → hardlink → maintain → stream**

Modular Docker Compose, Gluetun (VPN or Direct), Seerr, Jellyfin, Servarr tooling, Decluttarr/Maintainerr — aligned with [TRaSH Guides](https://trash-guides.info/).

> **Status: Working Draft (MVP stack scaffolding).** Core Compose modules and `bin/flixbox` are in-tree. Complete the [first-run](docs/user/05-first-run.md) UI wiring after `up`.

<!-- When README.es.md exists: Also available in [Spanish](README.es.md). -->

## Quick start

```bash
git clone https://github.com/aleaz/flixbox.git
cd flixbox
./bin/flixbox init --non-interactive
# Edit .env as needed (FLIXBOX_MODE=direct|vpn, paths, VPN secrets)
./bin/flixbox up
./bin/flixbox status
```

Open Homepage http://localhost:3000 · Seerr :5055 · Jellyfin :8096 · qBittorrent :8080

## Documentation

| For | Start here |
| --- | --- |
| **Operators** | [User guide](docs/user/INDEX.md) |
| How it works | [How it works](docs/user/02-how-it-works.md) |
| Contributors | [Docs map](docs/INDEX.md) · [ADRs](docs/adr/) |
| AI agents | [AGENTS.md](AGENTS.md) |

Spanish user docs: `docs/es/user/` + `README.es.md` before first public release ([ADR 0011](docs/adr/0011-documentation-i18n.md)).

## MVP services

Gluetun, qBittorrent, Prowlarr, Byparr, Radarr, Sonarr, Bazarr, Unpackerr, Recyclarr, Decluttarr, Maintainerr, Seerr, Jellyfin, Homepage, Caddy (optional), docker-socket-proxy (optional).

## Platforms

- **First-class:** Linux (x86_64 / ARM64)
- **Best-effort:** Windows (Docker Desktop + WSL2 ext4), macOS

## License

[MIT](LICENSE) © 2026 Alejandro Azario

## Disclaimer

You are responsible for complying with applicable laws and terms of service for any content or indexers you use with this software.
