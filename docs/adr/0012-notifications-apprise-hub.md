# ADR 0012: Notifications via Apprise hub (not a first-class Telegram bot)

- **Status:** Accepted
- **Date:** 2026-08-29
- **Updated:** 2026-09-14 (`notifications` profile shipped — `compose/notifications.yml`)
- **Related:** [0003](0003-compose-modularity.md), [0006](0006-mvp-service-inventory.md), [0008](0008-maintenance-decluttarr-maintainerr.md), [0013](0013-vpn-resilience-no-direct-fallback.md)

## Context

Operators want phone alerts for grabs, imports, health issues, and hygiene actions. Telegram is a common ask. As of 2025–2026, community media stacks converge on:

| Approach | What it is | Fit for Flixbox |
| --- | --- | --- |
| **Native Connect** | Radarr/Sonarr/Bazarr → Telegram / Discord / etc. in each app UI | Works today; zero Flixbox code; N configs to maintain |
| **Apprise API** | One Docker service; URL schemes to 100+ backends (`tgram://`, `ntfy://`, Discord, …); *arr have **Apprise** Connect (server URL + configuration key) | Channel-agnostic hub; LinuxServer image; matches modular Compose profiles |
| **Notifiarr** | Hosted + client; Discord-first ecosystem | Strong if Discord is primary; heavier product coupling |
| **Interactive Telegram bots** | Search/add/delete media from chat | High UX surface + ACL risk; not “stack status” only |

The v0.1 baseline deferred “Telegram or other bots as first-class features” and pointed operators at Seerr/Maintainerr built-ins ([01-scope.md](../01-scope.md), [09-hygiene-defaults.md](../09-hygiene-defaults.md)).

### Revalidation (2026-08-29)

Confirmed still true for Flixbox:

1. **Radarr/Sonarr** ship native **Connect → Apprise** (base URL + configuration key / tags) — hub model is first-class in *arr, not a Flixbox invention.
2. **Recyclarr** also supports Apprise notifications — aligns with the existing optional `recyclarr` profile.
3. **Seerr / Maintainerr / Unpackerr** may lack Apprise Connect; they keep native channels or webhook → Apprise — do not claim universal zero-config wiring.
4. Hub stays on **`flixbox_net` only**; do not publish Apprise UI to WAN without Caddy + future auth roadmap.
5. Prefer **stateful** Apprise config (persistent key under `${CONFIG_DIR}`) so Telegram/`ntfy` URLs live in one place; *arr only store `http://apprise-api:8000` + key.
6. Interactive bots remain out of inventory (ADR 0006).

Goals unchanged: one endpoint config, no library-mutating bot, secrets out of git, optional profile, Day-0 native Connect documented.

## Decision

1. **Do not** add a Flixbox-owned Telegram bot service (ADR 0006 stands for the core inventory and beyond as a first-class product feature).
2. **Canonical future path:** optional Compose profile **`notifications`** shipping **Apprise API** (`lscr.io/linuxserver/apprise-api` preferred for PUID/PGID/TZ consistency) on `flixbox_net`.
3. Destinations use Apprise URL schemes (Telegram = `tgram://…`; ntfy, Discord, Gotify, etc.). Wire *arr (and Recyclarr when used) via Apprise Connect; other apps use native Connect or webhook → Apprise **where supported**.
4. **Day-0 (no profile):** document native Radarr/Sonarr Telegram (and Seerr/Maintainerr channels) as the supported zero-extra-container path.
5. **Notifiarr** remains optional documentation for Discord-centric operators — not a default Flixbox service.
6. **Interactive** Telegram/Discord bots that search/add/delete titles stay out of Flixbox inventory (third-party at operator risk).
7. When ADR 0013 VPN heal notifications exist, post via Apprise (or documented webhook) rather than a second Telegram client.

## Consequences

- One optional container + bot tokens / topics in Apprise config volume (or `.env` for non-secrets only) — never git-tracked secrets.
- Operators still enable Connect triggers in each *arr UI (no false zero-touch claim).
- CI: `notifications` profile must not appear in default `compose config --services`; no interactive-bot images in default inventory.
- Hygiene docs list Apprise as preferred fan-out once the profile ships; until then, built-in channels remain the guidance.
- Implementation order: v0.1 polish → docs cookbook (native Connect) → `notifications` profile → optional VPN heal hooks (ADR 0013).

## Non-goals

- Replacing Seerr’s own request notification UX.
- SMS / PagerDuty as defaults.
- Publishing Apprise UI to the public internet without the existing Caddy/auth roadmap.
- Shipping ntfy server inside Flixbox by default (operators may point Apprise at external/public ntfy).

## Progress

- [x] Optional Compose profile `notifications` → `apprise-api` on `flixbox_net` (no host port by default)
- [x] Stateful config volume `${CONFIG_DIR}/apprise` + templates
- [x] Operator cookbook — [18-notifications.md](../user/18-notifications.md) (Day-0 native Connect + Apprise)
- [x] Image pin + CI: profile absent from default `compose config --services`
- [x] Optional VPN heal alerts via Apprise (`VPN_HEAL_APPRISE_URLS` on profile `vpn-heal`)
