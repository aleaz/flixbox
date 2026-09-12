# Torrent privacy and security

Practical guidance for operators who want to **mask their home IP** from BitTorrent peers and avoid common leaks. This guide complements [VPN and Direct](07-vpn-and-direct.md) (how to switch modes) with qBittorrent settings, realistic expectations, and audit checklists.

**Status:** Working Draft.

## 1. What this guide covers

| In scope | Out of scope |
| --- | --- |
| IP masking via VPN mode | Legal advice about what you may download |
| qBittorrent WebUI privacy settings | Choosing a VPN vendor (beyond basics) |
| Leak prevention and verification | Full penetration testing |
| Network exposure of Flixbox services | Tracker-specific rules (read each tracker) |

### Privacy vs anonymity

- **Privacy (realistic goal):** Peers and trackers see your **VPN exit IP**, not your home ISP IP. Your ISP sees encrypted VPN traffic, not BitTorrent payloads to individual peers.
- **Anonymity (not guaranteed):** No one can link activity to you. BitTorrent does not provide this. Your VPN provider, trackers, timing analysis, and logged sessions can still correlate activity.

Flixbox helps with **privacy through VPN isolation**; it does not make you anonymous.

### Disclaimer

You are responsible for complying with applicable laws and terms of service for content, indexers, trackers, and VPN providers. Privacy controls here are **technical** only — they do not authorize infringement. Full notice: [Legal disclaimer](16-legal-disclaimer.md) · [Aviso legal (ES)](../es/user/16-legal-disclaimer.md). See also [Overview — Disclaimer](01-overview.md#disclaimer).

---

## 2. Who sees what

| Observer | Direct mode | VPN mode (healthy tunnel) |
| --- | --- | --- |
| BitTorrent peers | Your home public IP | VPN exit IP |
| Trackers (announce) | Your home public IP | VPN exit IP |
| Your ISP | BitTorrent traffic to many IPs | Encrypted tunnel to VPN (metadata only) |
| VPN provider | N/A | Tunnel endpoints; may log if their policy allows |
| Other Flixbox apps (*arr, Jellyfin) | LAN / Docker network only | Same — they stay off the VPN netns |

**Byparr** only proxies indexer HTTP traffic in Prowlarr (Cloudflare bypass). It does **not** affect BitTorrent peer connections.

---

## 3. How Flixbox protects torrent traffic (VPN mode)

When `FLIXBOX_MODE=vpn`:

1. **Only qBittorrent** uses `network_mode: service:gluetun`. All P2P egress goes through the tunnel.
2. **Gluetun killswitch** blocks qBit if the tunnel is down (shared network namespace + firewall).
3. **Healthcheck gate:** qBittorrent starts only after Gluetun is healthy.
4. **`BLOCK_IPV6=on`** (default): reduces IPv6 bypass leaks when the VPN does not route IPv6.
5. **`DOT=on`** (default): DNS over TLS inside Gluetun.
6. **Port-forward hook** sets `upnp: false` when updating qBit listen port — does not punch holes in your home router.

Radarr, Sonarr, Prowlarr, Seerr, Jellyfin, and the rest stay on `flixbox_net`. They talk to qBit at `http://qbittorrent:8080` (VPN: alias on Gluetun). Their own traffic does not use the VPN. See [Architecture](../03-architecture.md).

Full mode reference: [VPN and Direct](07-vpn-and-direct.md).

---

## 4. Direct mode: when and what you expose

Use `FLIXBOX_MODE=direct` when:

- A private tracker whitelists your home IP.
- You need maximum line speed and accept IP exposure.
- You are testing in a lab without sensitive egress.

In Direct mode, **your real public IP is visible** to every peer and tracker in the swarm. `./bin/flixbox vpn-test` will show your normal ISP IP — that is expected.

Download client host: `http://qbittorrent:8080`.

---

## 5. qBittorrent settings (recommended)

Configure in the WebUI after first login. Path: **Options** (gear icon) unless noted.

### 5.1 Connection

| Setting | VPN mode | Direct mode | Why |
| --- | --- | --- | --- |
| **UPnP / NAT-PMP** | Off | Off | Avoid opening ports on your real router; Flixbox/Gluetun hook already disables UPnP on port-forward update |
| **Use a proxy** | Off | Off | Flixbox uses VPN netns, not a SOCKS/HTTP proxy in qBit |
| **Interface / bind** | Default | Default | In VPN mode the Gluetun netns already restricts egress; manual bind is usually unnecessary |

**VPN port forwarding** (`VPN_PORT_FORWARDING=on` in `.env`): improves inbound connectivity and ratio on some setups. Peers still see the **VPN IP**, not your home IP. Trade-off: some trackers block known VPN ranges; your provider can correlate the forwarded port to your session.

If port forwarding is on, enable **Bypass authentication for clients on localhost** under **Options → Web UI** so Gluetun can call the WebAPI. This is separate from `LocalHostAuth` (handled by the Flixbox init hook for Docker port maps). See [First-run §2b.1](05-first-run.md#2b1-webui-stuck-on-plain-unauthorized-qbittorrent-5x).

### 5.2 BitTorrent

| Setting | Recommendation | Notes |
| --- | --- | --- |
| **Encryption mode** | Prefer encryption | Hides payload from ISP inspection; **does not hide your IP from peers** |
| **Encryption mode** | Require encryption | Stricter; may reduce peer count |
| **DHT** | On for public indexers; **off for private trackers** | Many private trackers forbid DHT |
| **PeX** | Same as DHT | Private tracker rules often require off |
| **Local Peer Discovery** | Off on shared/VPN setups | Optional; LAN discovery is rarely needed in Docker |
| **Anonymous mode** | Do not rely on it | Does **not** hide your IP; only affects some tracker peer lists |

### 5.3 Web UI

| Action | Priority |
| --- | --- |
| Change default `admin` password after first login | Required |
| Use **API key** in Radarr/Sonarr (not WebUI password) | Required — [Credentials](06-configuration.md#credentials-and-api-keys) |
| Do not publish port `8080` to the public internet | Required |
| Set `QBITTORRENT_USERNAME` / `QBITTORRENT_PASSWORD` in `.env` for Decluttarr if auth is on | When using Decluttarr |

**Docker automation network (`172.30.42.0/24`):** Flixbox pins `flixbox_net` to that CIDR and configures qBittorrent `AuthSubnetWhitelist` for it. Stack peers (and often the Docker gateway when you open the published WebUI from the host) **bypass WebUI password**. That is intentional for Decluttarr/*arr on the bridge — keep qBit off the public internet ([ADR 0008](../adr/0008-maintenance-decluttarr-maintainerr.md)). This is **not** the same as LAN profile **`trusted`** / **`shared`** ([Access profiles](13-access-profiles.md)).

---

## 6. Common leak and misconfiguration scenarios

```
Your host / Docker
    │
    ├─► Direct mode on public swarms ──────► home IP visible to peers
    │
    ├─► qBit not in Gluetun netns ─────────► home IP despite VPN container running
    │
    ├─► IPv6 active without VPN IPv6 ──────► IPv6 leak (Flixbox: BLOCK_IPV6=on)
    │
    ├─► DNS outside tunnel ────────────────► ISP sees tracker lookups (Flixbox: DOT=on)
    │
    ├─► VPN down, no killswitch ───────────► brief home-IP exposure
    │
    ├─► WebUI on 0.0.0.0 published to WAN ► remote control of your client
    │
    ├─► *arr/Jellyfin behind Gluetun ─────► broken metadata + wrong design
    │
    └─► Download client host changed off `qbittorrent` ───► *arr cannot reach qBit
        (keep host `qbittorrent` in VPN and Direct — ADR 0014)
```

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `vpn-test` shows ISP IP in VPN mode | Tunnel down, wrong mode, or qBit not in Gluetun netns | Check `FLIXBOX_MODE`, Gluetun logs, recreate stack |
| *arr cannot reach qBit after VPN switch | Missing Gluetun `qbittorrent` alias or Gluetun unhealthy | Keep download client host **`qbittorrent`**; check `docker compose ps gluetun` — [ADR 0014](../adr/0014-stable-qbit-download-hostname.md) |
| IPv6 leak on external test | `BLOCK_IPV6=off` or provider issue | Keep default `on`; test from Gluetun container |
| Home router port opened unexpectedly | UPnP enabled in qBit | Disable UPnP/NAT-PMP in qBit |

More fixes: [Troubleshooting](10-troubleshooting.md).

---

## 7. What does NOT provide anonymity

| Myth | Reality |
| --- | --- |
| Protocol encryption | Peers still see your IP (VPN or home) |
| qBit “Anonymous mode” | Misleading name; not IP hiding |
| Disabling DHT only | Trackers and connected peers still see your IP |
| IP blocklists | Block specific IPs; not anonymity |
| Random listen port without VPN | IP unchanged |
| Byparr / indexer proxies | Indexer HTTP only; not P2P |
| Free or unknown VPNs | May log, sell data, or leak |

---

## 8. Privacy audit checklist

Run after first `up`, after switching VPN provider or server, after changing `.env` or qBit settings, or after any suspected leak.

### 8.1 Quick checklist (~10 minutes)

**Flixbox / environment**

- [ ] `FLIXBOX_MODE=vpn` if you do not want your home IP in the swarm
- [ ] `VPN_ENABLED=true` matches VPN mode (`flixbox init` syncs this)
- [ ] Gluetun credentials set; `docker compose ps` shows `gluetun` healthy
- [ ] `BLOCK_IPV6=on` (default in `.env.example`)
- [ ] `DOT=on` (default)
- [ ] Radarr/Sonarr download client host is **`qbittorrent`** (port `8080`) in VPN and Direct — [ADR 0014](../adr/0014-stable-qbit-download-hostname.md)
- [ ] `DECLUTTARR_QBIT_URL=http://qbittorrent:8080` (same in VPN and Direct — ADR 0014) — `grep DECLUTTARR_QBIT_URL .env`
- [ ] `./bin/flixbox vpn-test` — VPN mode: IP **≠** your ISP; Direct: IP **is** your ISP
- [ ] qBittorrent WebUI reachable on LAN only (not port-forwarded on home router to WAN)

**qBittorrent WebUI**

- [ ] Default `admin` password changed
- [ ] API key configured in Radarr/Sonarr; username/password empty in *arr download client
- [ ] UPnP and NAT-PMP disabled
- [ ] If `VPN_PORT_FORWARDING=on`: **Bypass authentication for clients on localhost** enabled

**qBittorrent — BitTorrent**

- [ ] Encryption: Prefer (or Require if you accept fewer peers)
- [ ] DHT / PeX / LSD: off for private trackers; on for public indexers as needed
- [ ] Not relying on Anonymous mode for IP privacy

**Network exposure**

- [ ] *arr, Jellyfin, Homepage not exposed on WAN without HTTPS and auth
- [ ] Only qBittorrent uses Gluetun netns (no other service on `network_mode: service:gluetun`)

**Credentials**

- [ ] `.env` not committed to git
- [ ] No API keys or VPN keys in screenshots or issue reports

### 8.2 Verification commands

Public IP from the active downloader namespace:

```bash
./bin/flixbox vpn-test
```

Gluetun health and recent errors:

```bash
docker compose logs gluetun --tail 50
docker compose ps gluetun qbittorrent
```

Optional DNS leak probe from the Gluetun container (VPN mode):

```bash
docker exec flixbox-gluetun wget -qO- https://bash.ws/dnsleak/test/ | head -20
```

Interpret results carefully — some leak-test sites are noisy. The primary Flixbox check remains `vpn-test` (public IP via tunnel).

### 8.3 Extended audit (optional)

Use annually, after a VPN provider change, or if you suspect a leak.

| Area | Check |
| --- | --- |
| VPN provider | No-log policy you trust; jurisdiction; supports Gluetun features you need |
| Killswitch | Stop Gluetun (`docker stop flixbox-gluetun`); confirm qBit cannot fetch new peers (no long-term leak test — restore stack after) |
| Download paths | qBit saves under `/data/torrents/` — [First-run §2c](05-first-run.md#2c-download-paths-automatic) |
| Smoke test Phase D | Full VPN validation — [Smoke test § Phase D](11-smoke-test.md#phase-d--vpn-mode-optional-needs-provider-creds) |
| Reverse proxy | If using Caddy profile: TLS on; no raw *arr ports on WAN — [Requirements](03-requirements.md#network) |
| Tracker rules | Private trackers: DHT/PeX off; ratio/VPN policy per tracker |

Record results (date, `vpn-test` output redacted, checklist pass/fail) if you operate multiple hosts.

---

## 9. VPN provider considerations

Flixbox does not endorse a specific provider. When choosing one for torrent use:

| Factor | Why it matters |
| --- | --- |
| **No-logs policy** | Provider could link VPN IP to your account |
| **Jurisdiction** | Legal pressure on retention |
| **Gluetun support** | WireGuard/OpenVPN templates, port forwarding API |
| **Port forwarding** | Better connectivity; provider knows assigned port per session |
| **Tracker reputation** | Some trackers block datacenter/VPN IP ranges |
| **Killswitch behavior** | Gluetun adds a layer; provider app killswitch is irrelevant inside Docker |

Env reference: [Configuration — VPN](06-configuration.md#vpn-mode-only).

---

## 10. Beyond BitTorrent: Flixbox surface area

BitTorrent privacy does not protect other services:

| Service | Risk if exposed to WAN |
| --- | --- |
| Radarr / Sonarr / Prowlarr | Library manipulation, API key theft |
| Jellyfin | Media access |
| qBittorrent WebUI | Full download control |
| Homepage | Information disclosure |
| Byparr | Indexer proxy abuse |

**Mitigations:** LAN-only access, Caddy with HTTPS (`proxy` profile), firewall rules on the host. SSO (Authelia/Authentik) is later (v0.4) — see [Roadmap](../08-roadmap.md).

Engineering notes: [Operations risks §3](../07-operations-risks.md#3-security--privacy).

---

## 11. Quick reference

### Mode comparison

| | VPN mode | Direct mode |
| --- | --- | --- |
| `.env` | `FLIXBOX_MODE=vpn` | `FLIXBOX_MODE=direct` |
| qBit download client host | `qbittorrent` | `qbittorrent` |
| IP seen by peers | VPN exit | Home ISP |
| Gluetun running | Yes | No |
| Leak test | IP ≠ ISP | IP = ISP |

### Key `.env` variables (VPN)

| Variable | Default | Privacy role |
| --- | --- | --- |
| `BLOCK_IPV6` | `on` | Block IPv6 leak |
| `DOT` | `on` | DNS over TLS |
| `VPN_PORT_FORWARDING` | `off` | Optional; enable only with provider support |
| `FIREWALL_OUTBOUND_SUBNETS` | (empty) | LAN access through Gluetun if needed |

### qBit WebUI paths

| Task | Location |
| --- | --- |
| Encryption, DHT, PeX | Options → BitTorrent |
| UPnP, ports | Options → Connection |
| Password, API key, localhost bypass | Options → Web UI |

---

## Related guides

| Guide | Topic |
| --- | --- |
| [07 — VPN and Direct](07-vpn-and-direct.md) | Switching modes, anti-patterns |
| [06 — Configuration](06-configuration.md) | `.env`, credentials, download client URLs |
| [05 — First-run](05-first-run.md) | qBit login, paths, *arr wiring |
| [11 — Smoke test](11-smoke-test.md) | Operator validation including VPN phase |
| [10 — Troubleshooting](10-troubleshooting.md) | Common qBit and VPN failures |
| [03 — Requirements](03-requirements.md) | Network and exposure basics |
