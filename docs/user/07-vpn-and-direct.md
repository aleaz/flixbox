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

There is no “Direct traffic with VPN still up” design. If you previously ran VPN and switch to Direct, run `./bin/flixbox down` then `./bin/flixbox up` so a leftover `flixbox-gluetun` container is not mistaken for an active dual mode.

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
2. Fill Gluetun vars under **[VPN ONLY]** (native provider or `custom` + `OPENVPN_CUSTOM_CONFIG` — see [examples below](#vpn-provider-examples) and `.env.example`).
3. `./bin/flixbox init --non-interactive` (updates `DECLUTTARR_QBIT_URL` and syncs `VPN_ENABLED`).
4. **Recreate the stack** so Gluetun appears (Direct → VPN is a compose include change):
   - Preferred: `./bin/flixbox down` → `./bin/flixbox up`
   - Or: `./bin/flixbox reload` if the stack is already up (after host port preflight allows self-owned ports)
5. Wait until Gluetun is **healthy** (`./bin/flixbox status` / `logs gluetun`).
6. `./bin/flixbox configure` (wires apps; does **not** start Gluetun by itself).
7. `./bin/flixbox vpn-test`.

If you run `configure` right after editing `.env` without `down`/`up`, you will see *Gluetun container not running* — that is expected.

### VPN bring-up (dependency chain)

When `FLIXBOX_MODE=vpn`, Compose waits on health in this order:

```text
gluetun (healthy) → qbittorrent (WebUI healthy) → radarr / sonarr / decluttarr / unpackerr
```

If Gluetun is unhealthy, qBit and those peers fail with dependency errors. That is intentional (fail closed for torrent path). Seerr, Jellyfin, Prowlarr, and similar apps do not depend on Gluetun and may still start. Fix Gluetun first (`docker compose logs gluetun`), then recreate; or roll back to Direct (`FLIXBOX_MODE=direct`, `VPN_ENABLED=false`, `init`, `down`, `up`, download client host `qbittorrent`).

### What happens when the VPN drops

Gluetun reconnects **inside the same container** (upstream default). While the tunnel is down, the killswitch blocks qBit egress — downloads stall, your home IP should stay masked. This is **fail closed**, not a fallback to Direct.

| Event | Expected behavior |
| --- | --- |
| Brief tunnel blip | Gluetun auto-restarts VPN; qBit resumes when healthy |
| Prolonged outage | Gluetun stays `unhealthy`; qBit and *arr health checks fail until VPN returns |
| Gluetun **container recreated** | qBit may be **stranded** (netns changed) — see [Troubleshooting](10-troubleshooting.md) |

Flixbox will **never** auto-switch `FLIXBOX_MODE` to Direct on VPN failure ([ADR 0013](../adr/0013-vpn-resilience-no-direct-fallback.md)).

## VPN provider examples

After setting `FLIXBOX_MODE=vpn` and `VPN_ENABLED=true`, fill the **[VPN ONLY]** block in `.env`. Use the Gluetun provider id from the [Gluetun wiki](https://github.com/qdm12/gluetun-wiki). Never commit real keys.

Then: `./bin/flixbox init --non-interactive` → `./bin/flixbox down` → `./bin/flixbox up` → `./bin/flixbox vpn-test`.

### WireGuard (native provider)

Typical for Proton, Mullvad, and most modern providers. Get the private key and address from the provider’s WireGuard config (or account UI).

```env
FLIXBOX_MODE=vpn
VPN_ENABLED=true

VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=your_private_key_here
WIREGUARD_ADDRESSES=10.2.0.2/32
# Optional filters (provider-dependent):
# SERVER_COUNTRIES=Netherlands
# SERVER_CITIES=Amsterdam
VPN_PORT_FORWARDING=off
```

### OpenVPN (native provider)

Use when your provider issues OpenVPN credentials instead of WireGuard.

```env
FLIXBOX_MODE=vpn
VPN_ENABLED=true

VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=openvpn
OPENVPN_USER=your_openvpn_username
OPENVPN_PASSWORD=your_openvpn_password
# Optional filters:
# SERVER_COUNTRIES=Netherlands
VPN_PORT_FORWARDING=off
```

### Custom OpenVPN file (lab / special configs)

For a `.ovpn` you supply yourself (not a substitute for a commercial no-logs provider):

1. Place the file under `${CONFIG_DIR}/gluetun/` (volume already mounted).
2. In the `.ovpn`, `remote` must be an **IP address** (not a hostname) — Gluetun requirement.
3. Set:

```env
FLIXBOX_MODE=vpn
VPN_ENABLED=true

VPN_SERVICE_PROVIDER=custom
VPN_TYPE=openvpn
OPENVPN_CUSTOM_CONFIG=/gluetun/custom.conf
# OPENVPN_USER=…
# OPENVPN_PASSWORD=…
VPN_PORT_FORWARDING=off
```

Full comment block and variable list: [`.env.example`](../../.env.example) **[VPN ONLY]**.

## VPN mode essentials

1. Only **qBittorrent** uses `network_mode: service:gluetun`.
2. WebUI / BT ports are published on **Gluetun**, not on the qBittorrent service.
3. Radarr/Sonarr/Decluttarr must use host **`qbittorrent`** (same in Direct — [ADR 0014](../adr/0014-stable-qbit-download-hostname.md)).
4. IPv6 blocked by default (`BLOCK_IPV6=on`); DNS over TLS on (`DOT=on`).
5. Optional port forwarding: `VPN_PORT_FORWARDING=on` (supported providers). `./bin/flixbox configure` sets qBittorrent **Bypass authentication for clients on localhost** when port forwarding is enabled (Gluetun hooks need unauthenticated localhost API access).
6. Put provider credentials only in `.env` or files under `${CONFIG_DIR}/gluetun` — never in git.
7. Prefer WireGuard when the provider supports it (simpler keys, usually faster). Use OpenVPN when that is all the account offers.

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
