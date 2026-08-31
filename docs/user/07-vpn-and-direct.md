# VPN and Direct mode

## Choose a mode

Flixbox has **one** download-mode switch. Modes are **exclusive** — you cannot run Direct egress and a Flixbox Gluetun tunnel for qBittorrent at the same time.

### `FLIXBOX_MODE` vs `VPN_ENABLED`

| Variable | Does Compose use it? | Role |
| --- | --- | --- |
| `FLIXBOX_MODE` | **Yes** | Selects `compose/downloaders-direct.yml` **or** `compose/downloaders-vpn.yml` |
| `VPN_ENABLED` | **No** | Mirror / legacy label. `flixbox init` syncs it from `FLIXBOX_MODE`. Kept for docs and future CLI |

**Set both together** so `.env` does not lie to you:

| Intended mode | Set this |
| --- | --- |
| Direct | `FLIXBOX_MODE=direct` and `VPN_ENABLED=false` |
| VPN | `FLIXBOX_MODE=vpn` and `VPN_ENABLED=true` |

| Mismatch | What actually runs |
| --- | --- |
| `FLIXBOX_MODE=direct` + `VPN_ENABLED=true` | **Direct** — Gluetun is not in the Compose project |
| `FLIXBOX_MODE=vpn` + `VPN_ENABLED=false` | **VPN** — Gluetun + qBit in Gluetun netns |

`flixbox init` rewrites `VPN_ENABLED` from `FLIXBOX_MODE` (and warns if they disagreed). `flixbox up`, `status`, and `vpn-test` warn on mismatch but still follow `FLIXBOX_MODE`.

There is no “Direct traffic with VPN still up” design. If you previously ran VPN and switch to Direct, run `docker compose down` then `up` so a leftover `flixbox-gluetun` container is not mistaken for an active dual mode.

| `.env` | Behavior | *arr download client |
| --- | --- | --- |
| `FLIXBOX_MODE=direct` | qBittorrent on `flixbox_net`; Gluetun not started | `http://qbittorrent:8080` |
| `FLIXBOX_MODE=vpn` | qBittorrent shares Gluetun netns; **alias** `qbittorrent` on Gluetun | `http://qbittorrent:8080` |

**Same hostname in both modes** (ADR 0014). Radarr/Sonarr download client host is always `qbittorrent` — no UI change when switching modes. `gluetun` still works for debugging.

| Choose **VPN** if… | Choose **Direct** if… |
| --- | --- |
| You want torrent egress masked | Private trackers with IP auth |
| Your provider works with Gluetun | Max line speed / lab testing |

Switching to VPN:

1. In `.env` **[REQUIRED]** (top): `FLIXBOX_MODE=vpn` and `VPN_ENABLED=true` (not only the Gluetun block at the bottom).
2. Fill Gluetun vars under **[VPN ONLY]** (native provider or `custom` + `OPENVPN_CUSTOM_CONFIG` — see `.env.example`).
3. `./bin/flixbox init --non-interactive` (updates `DECLUTTARR_QBIT_URL` and syncs `VPN_ENABLED`).
4. `docker compose down` → `./bin/flixbox up`.
5. Point Radarr/Sonarr download client at host **`qbittorrent`**, port **8080** (same as Direct — no rename on mode switch).
6. `./bin/flixbox vpn-test`.

### VPN bring-up (dependency chain)

When `FLIXBOX_MODE=vpn`, Compose waits on health in this order:

```text
gluetun (healthy) → qbittorrent (WebUI healthy) → radarr / sonarr / decluttarr / unpackerr
```

If Gluetun is unhealthy, qBit and those peers fail with dependency errors. That is intentional (fail closed for torrent path). Seerr, Jellyfin, Prowlarr, and similar apps do not depend on Gluetun and may still start. Fix Gluetun first (`docker compose logs gluetun`), then recreate; or roll back to Direct (`FLIXBOX_MODE=direct`, `VPN_ENABLED=false`, `init`, `down`, `up`, download client host `qbittorrent`).

## VPN mode essentials

1. Only **qBittorrent** uses `network_mode: service:gluetun`.
2. WebUI / BT ports are published on **Gluetun**, not on the qBittorrent service.
3. Radarr/Sonarr/Decluttarr must use host **`qbittorrent`** (same in Direct — [ADR 0014](../adr/0014-stable-qbit-download-hostname.md)).
4. IPv6 blocked by default (`BLOCK_IPV6=on`); DNS over TLS on (`DOT=on`).
5. Optional port forwarding: `VPN_PORT_FORWARDING=on` (supported providers). Enable qBittorrent **Bypass authentication for clients on localhost**.
6. Put provider credentials only in `.env` or files under `${CONFIG_DIR}/gluetun` — never in git.
7. Custom OpenVPN (e.g. a VPNGate `.ovpn` for lab tests): `VPN_SERVICE_PROVIDER=custom`, file under `${CONFIG_DIR}/gluetun/`, `OPENVPN_CUSTOM_CONFIG=/gluetun/<file>`, and `remote` must be an **IP** (Gluetun). Free relays are not a privacy substitute for a real no-logs provider.

## Direct mode essentials

1. Gluetun is not started.
2. Download client host is **`qbittorrent`**.
3. Still use the single `/data` hardlink layout.

## Verify

```bash
./scripts/vpn-test.sh
```

VPN mode: public IP should **not** be your home ISP.  
Direct mode: public IP is your normal egress.

## Privacy and qBittorrent settings

For IP masking expectations, qBit WebUI recommendations, leak scenarios, and an audit checklist, see [Torrent privacy and security](12-torrent-privacy-and-security.md).

## Anti-patterns

- Treating `VPN_ENABLED` as an independent on/off for Gluetun (Compose ignores it)
- Putting Radarr/Sonarr/Seerr/Jellyfin behind Gluetun
- Split Docker mounts for torrents vs media
- Storing `${CONFIG_DIR}` on NFS/SMB
- Running both modes at once (unsupported — exclusive compose include)

## Next

[Hygiene](08-hygiene.md)
