# ADR 0002: Gluetun VPN dual-mode

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-30 (download-client host unified — superseded for *arr URLs by ADR 0014)

## Context

Home torrent stacks need optional IP protection without locking users to one VPN vendor or forcing VPN for every use case. Operators often assume `VPN_ENABLED` is a second independent switch; it is not.

## Decision

- Use **Gluetun** as the only VPN engine (native providers + custom WireGuard/OpenVPN).
- Support **dual mode** via `FLIXBOX_MODE` only (exclusive Compose `include` of downloader modules). Modes are mutually exclusive — no Direct egress with Flixbox Gluetun protecting qBit.
- Keep `VPN_ENABLED` aligned as a **mirror** for docs/CLI (`init` syncs it). Compose must not read `VPN_ENABLED` for stack shape.
  - `vpn` (`VPN_ENABLED=true`): qBittorrent uses `network_mode: service:gluetun` with killswitch + DoT; publish qBit ports on **Gluetun**; download-client host `qbittorrent` via Gluetun network alias (ADR 0014).
  - `direct` (`VPN_ENABLED=false`): qBittorrent on `flixbox_net`; download-client host `qbittorrent`.
- Default IPv6 blocking unless explicit IPv6 VPN is configured.
- Port forwarding (when supported): `VPN_PORT_FORWARDING=on` plus Gluetun `VPN_PORT_FORWARDING_UP_COMMAND` / `DOWN_COMMAND` updating qBittorrent via localhost WebAPI.
- **Forbidden:** attaching Radarr, Sonarr, Prowlarr, Seerr, Jellyfin, Bazarr (or other UX/automation apps) to Gluetun’s netns.

## Consequences

- No custom VPNGate scrapers in-tree.
- Compose ships two downloader modules selected by `FLIXBOX_MODE` (not Compose profiles).
- Docs/CLI/Decluttarr must teach the correct download-client hostname per mode.
- Port-forward wiring is part of VPN-mode definition, not an optional afterthought.
