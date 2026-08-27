# Overview

Flixbox is an open-source, Docker-based home media suite. You request a movie or show, Flixbox finds a release, downloads it (optionally through a VPN), organizes it into a library with **hardlinks** (no double disk use while seeding), keeps queues and libraries tidy, and streams with **Jellyfin**.

## Who it is for

- People comfortable with Linux and Docker who want a modern *arr-style stack
- Operators who want clear contracts (storage, VPN/Direct) instead of a fragile copy-paste compose
- Homes that prefer **Jellyfin** (FOSS) with optional Plex later

## Who it is not for

- Turnkey appliances with zero Docker knowledge (yet — the CLI aims to help, but you still configure indexers and APIs)
- People who need Kubernetes or multi-node cloud HA as the primary model
- Anyone expecting Flixbox to decide legal questions about what you download

## What you get (MVP)

| Piece | Role |
| --- | --- |
| Seerr | Request portal |
| Prowlarr + Byparr | Indexers + Cloudflare bypass |
| Radarr / Sonarr | Movies / TV automation |
| qBittorrent + Gluetun (optional) | Downloads, VPN or Direct |
| Unpackerr / Recyclarr | Archives + TRaSH quality sync |
| Decluttarr / Maintainerr | Queue + library hygiene |
| Bazarr | Subtitles |
| Jellyfin | Streaming |
| Homepage + Caddy | Dashboard + HTTPS ingress |
| `bin/flixbox` | Bash CLI for init/up/status/vpn-test |

## Honest expectations

Flixbox automates plumbing and sane defaults. You will still:

- Add indexer credentials in Prowlarr
- Confirm the download client URL (`gluetun` vs `qbittorrent`)
- Connect Seerr to Jellyfin / Radarr / Sonarr
- Review Maintainerr cleanup rules before they delete library items

## Disclaimer

You are responsible for complying with applicable laws and terms of service for any content, indexers, or VPN providers you use with this software.

## Next

Read [How it works](02-how-it-works.md) for the mental model, then [Requirements](03-requirements.md).
