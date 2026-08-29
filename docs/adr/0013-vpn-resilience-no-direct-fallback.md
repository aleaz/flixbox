# ADR 0013: VPN resilience — Gluetun heal, optional watchdog, no Direct fallback

- **Status:** Proposed (post-MVP — target ~v0.2)
- **Date:** 2026-08-29
- **Related:** [0002](0002-vpn-gluetun-dual-mode.md), [0012](0012-notifications-apprise-hub.md)

## Context

Operators ask: if the VPN drops, does Flixbox restart something? Is there a “safe” or secondary path?

### What Gluetun already does (upstream, 2025–2026)

Gluetun runs **internal VPN auto-healing** separate from Docker recreate ([gluetun-wiki healthcheck FAQ](https://github.com/qdm12/gluetun-wiki/blob/main/faq/healthcheck.md)):

- Startup + periodic small (~1 min) and full (~5 min) connectivity checks.
- On failure, **restarts the VPN process inside the same container** (`HEALTH_RESTART_VPN` default `yes`).
- Docker `HEALTHCHECK` reflects unhealthy state; Flixbox already gates qBit start on Gluetun healthy.

Shared netns + Gluetun firewall = **killswitch**: when the tunnel is down, qBittorrent should not egress on the host ISP path (ADR 0002 / NFR-4). That is the privacy “safe” mode — fail closed, not fail open.

### Gaps the community still hits

1. **Container recreate:** if Gluetun’s *container* is recreated, dependents with `network_mode: service:gluetun` can be **stranded** (namespace id changed). Plain `docker restart` on qBit is not enough; need `compose up -d` recreate. Watchdogs: [gluetun-autoheal](https://github.com/Pardo24/gluetun-autoheal), [gluetun-monitor](https://github.com/csmarshall/gluetun-monitor) (need Docker API access).
2. **No multi-provider failover** in Gluetun. One `VPN_SERVICE_PROVIDER` per instance. Secondary commercial provider = second stack or manual `.env` switch ([upstream discussion](https://github.com/qdm12/gluetun/discussions/1694)).
3. **Server lists** (`SERVER_COUNTRIES=A,B,C`) are a **pool** (typically random), not ordered primary→secondary failover ([feature request](https://github.com/qdm12/gluetun/issues/3401)).
4. **“Fallback to Direct”** when VPN dies would expose the home IP on BitTorrent — contradicts Flixbox privacy contract.

### Flixbox today (MVP)

- Healthcheck gate Gluetun → qBit; peers wait on qBit healthy.
- `restart: unless-stopped` on Gluetun/qBit.
- No autoheal sidecar; no secondary Direct path; no second provider module.

## Decision

1. **Primary resilience = Gluetun built-in VPN restart + killswitch.** Document this as the expected safe behavior. Do not invent a Flixbox-specific VPN engine.
2. **Forbidden:** automatic switch from `FLIXBOX_MODE=vpn` to Direct (or dual egress) when the tunnel fails. Privacy fail-closed stays mandatory.
3. **Operator “secondary” (documented, manual):**
   - Widen server filters within one trusted provider (`SERVER_COUNTRIES` / regions) for more reconnect targets.
   - Keep a second provider’s credentials ready; switch via `.env` + `init` + recreate (human-driven).
   - Explicit rollback to Direct only when the operator chooses privacy trade-off (lab / private trackers).
4. **Future optional profile (working name `vpn-heal`):** evaluate a single maintained watchdog (prefer projects that recreate dependents with Compose, not only `docker restart`) behind Compose profile + **read/write Docker access minimized** (socket-proxy policy to be designed). Default **off**.
5. **Tune, don’t hide:** expose common Gluetun health env knobs in `.env.example` comments when implementing (`HEALTH_RESTART_VPN`, targets) — defaults remain upstream.
6. **Notify, don’t silently open:** when ADR 0012 lands, optional alert on prolonged Gluetun unhealthy / heal actions via Apprise. Until then, Homepage widgets + `flixbox status` / logs remain the UX.
7. **Not in scope:** multi-hop as Flixbox feature; VPNGate as secondary “safe” provider; shipping two Gluetun containers racing for qBit.

## Consequences

- Operators understand: tunnel blip → Gluetun reconnects internally; torrents stall briefly; IP should stay masked. Prolonged failure → unhealthy Gluetun, downloads stop — **by design**.
- After host sleep / Gluetun recreate, may need `docker compose up -d qbittorrent` (or future heal profile) — document in troubleshooting.
- Watchdog profile increases blast radius (Docker socket); requires threat-model note and CI “profile off by default”.
- ADR 0002 dual-mode remains exclusive; this ADR does not reopen “Direct + VPN side by side.”

## Acceptance sketch (when implementing)

- [ ] User doc section: “What happens when VPN drops”
- [ ] Troubleshooting: stranded qBit after Gluetun recreate
- [ ] Optional profile compose + contract checks (absent from default services)
- [ ] Explicit regression: no path auto-sets `FLIXBOX_MODE=direct` on health failure
