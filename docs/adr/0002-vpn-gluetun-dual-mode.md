# ADR 0002: Gluetun VPN dual-mode

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-27 (ports + port-forward + anti-pattern)

## Context

Home torrent stacks need optional IP protection without locking users to one VPN vendor or forcing VPN for every use case.

## Decision

- Use **Gluetun** as the only VPN engine (native providers + custom WireGuard/OpenVPN).
- Support **dual mode** via `FLIXBOX_MODE` (exclusive Compose `include` of downloader modules; keep `VPN_ENABLED` aligned):
  - `vpn` (`VPN_ENABLED=true`): qBittorrent uses `network_mode: service:gluetun` with killswitch + DoT; publish qBit ports on **Gluetun**; client host `gluetun`.
  - `direct` (`VPN_ENABLED=false`): qBittorrent on `flixbox_net`; client host `qbittorrent`.
- Default IPv6 blocking unless explicit IPv6 VPN is configured.
- Port forwarding (when supported): `VPN_PORT_FORWARDING=on` plus Gluetun `VPN_PORT_FORWARDING_UP_COMMAND` / `DOWN_COMMAND` updating qBittorrent via localhost WebAPI.
- **Forbidden:** attaching Radarr, Sonarr, Prowlarr, Seerr, Jellyfin, Bazarr (or other UX/automation apps) to Gluetun’s netns.

## Consequences

- No custom VPNGate scrapers in-tree.
- Compose ships two downloader modules selected by `FLIXBOX_MODE` (not Compose profiles).
- Docs/CLI/Decluttarr must teach the correct download-client hostname per mode.
- Port-forward wiring is part of VPN-mode definition, not an optional afterthought.
