# Future: notifications and VPN resilience

**Status:** Planning only — **no Compose implementation yet.**  
**ADRs:** [0012](adr/0012-notifications-apprise-hub.md) (**Accepted**), [0013](adr/0013-vpn-resilience-no-direct-fallback.md) (**Accepted**; optional `vpn-heal` profile still post-v0.1).  
**Roadmap:** [08-roadmap.md](08-roadmap.md).

This note captures industry patterns (2025–2026) and Flixbox fit so we do not re-debate from scratch when implementing.

## 1. Notifications (“what is happening”)

### Landscape

- **Per-app Connect** (Radarr/Sonarr Telegram/Discord/…): simplest; already available without Flixbox changes.
- **Apprise API:** one hub → Telegram (`tgram://`), ntfy, Discord, Gotify, email, … Widely used with *arr Apprise Connect and self-hosted stacks.
- **Notifiarr:** rich Discord-oriented ecosystem; optional for Discord-first operators.
- **Interactive Telegram bots:** library search/add from chat — powerful but ACL/security heavy; out of Flixbox inventory.

### Flixbox direction (ADR 0012 — Accepted)

| Do | Don’t |
| --- | --- |
| Document native Connect for Day-0 Telegram | Ship a Flixbox Telegram bot in MVP |
| Later: optional `notifications` profile → Apprise API (LinuxServer) | Lock product to Telegram-only |
| Stateful Apprise config key; *arr Connect → hub | Interactive bots that mutate *arr |
| Fan-out VPN heal alerts through Apprise when both exist | Publish Apprise UI to WAN by default |

**Sums:** one optional service, many channels, matches modular profiles.  
**Does not sum:** another bot with Docker + library write access by default.

## 2. VPN drop behavior (“safe / secondary”)

### What already happens in Flixbox VPN mode

```text
Tunnel fails
  → Gluetun internal health checks fail
  → Gluetun restarts VPN inside the same container (upstream default)
  → Killswitch: qBit has no ISP egress while tunnel is down
  → Docker marks gluetun unhealthy if checks keep failing
  → Downloads stall / fail closed (privacy-preserving)
```

Gluetun does **not** need Flixbox to “restart the container” on every blip; process-level reconnect is the designed path. See [Gluetun healthcheck FAQ](https://github.com/qdm12/gluetun-wiki/blob/main/faq/healthcheck.md).

### What is *not* available upstream

| Wish | Reality |
| --- | --- |
| Ordered country failover A→B→C | Lists are usually a **pool**, not priority tiers |
| Auto secondary **provider** | One provider per Gluetun instance |
| Auto fall back to **Direct** | Would leak home IP — **forbidden** in Flixbox (ADR 0013) |
| qBit always heals after Gluetun **recreate** | Shared netns can strand dependents; community uses watchdogs |

### Flixbox direction (ADR 0013)

| Do | Don’t |
| --- | --- |
| Document Gluetun heal + killswitch as the safe default | Auto-switch to Direct on VPN failure |
| Document manual provider/server switch | Dual Gluetun racing for one qBit |
| Later optional `vpn-heal` watchdog profile (off by default) | Promise zero-downtime VPN without a trusted commercial provider |
| Wider `SERVER_*` filters for reconnect diversity | Treat VPNGate free relays as a “safe secondary” |

**Sums:** honest fail-closed privacy; optional heal for edge cases (host sleep, recreate).  
**Does not sum:** silent Direct fallback marketed as “safe.”

## 3. Suggested implementation order (future)

1. Docs-only: “VPN drops” + native Connect Telegram cookbook (cheap, unblocks operators now conceptually).
2. Apprise profile (ADR 0012) after v0.1 polish.
3. Wire optional heal alerts → Apprise.
4. Evaluate one watchdog image for `vpn-heal` profile; socket threat model + CI.

## 4. Operator workarounds today (no code)

**Telegram now:** Radarr/Sonarr → Settings → Connect → Telegram (bot token + chat id). Same idea in Seerr/Maintainerr if the channel exists.

**VPN stuck after recreate:**

```bash
docker compose up -d gluetun
# wait healthy
docker compose up -d qbittorrent
./bin/flixbox vpn-test
```

**Broader server pool (same provider):** set multiple `SERVER_COUNTRIES` / regions in `.env`, recreate Gluetun.

**True secondary provider:** keep alternate secrets offline; change `VPN_SERVICE_PROVIDER` + keys; `init`/`up` — human decision.
