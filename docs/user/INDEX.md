# Flixbox user guide

Friendly documentation for operators who want to run Flixbox at home.

**Language:** English (canonical). Spanish: [`docs/es/user/INDEX.md`](../es/user/INDEX.md) · [Quick reference (ES)](../es/user/REFERENCE.md) — see [ADR 0011](../adr/0011-documentation-i18n.md).

**Status:** Working Draft. MVP Compose + `bin/flixbox` including API-assisted `configure` (ADR 0005); add Prowlarr indexers after `up`.

## Contents

| Guide | What you will learn |
| --- | --- |
| [01 — Overview](01-overview.md) | What Flixbox is, who it is for, disclaimer |
| [02 — How it works](02-how-it-works.md) | Mental model: pipeline, `/data`, VPN vs Direct |
| [03 — Requirements](03-requirements.md) | Hardware, Docker, storage, network |
| [04 — Install](04-install.md) | Clone, `init`, `up` (~15 min) |
| [05 — First-run setup](05-first-run.md) | `configure` + indexers (~10–15 min) |
| [REFERENCE — Quick reference](REFERENCE.md) | URLs, ports, CLI cheat sheet |
| [06 — Configuration](06-configuration.md) | Paths, env, ports, **credentials & API keys**, Compose profiles |
| [07 — VPN and Direct](07-vpn-and-direct.md) | Gluetun, port forwarding, leak checks |
| [08 — Hygiene](08-hygiene.md) | Decluttarr and Maintainerr in plain language |
| [09 — Day-2 operations](09-operations.md) | Status, logs, updates, backups, **path changes**, hardlink check |
| [10 — Troubleshooting](10-troubleshooting.md) | Common failures and fixes |
| [11 — Smoke test](11-smoke-test.md) | MVP validation checklist before v0.1 |
| [12 — Torrent privacy and security](12-torrent-privacy-and-security.md) | VPN privacy, qBit settings, leak prevention, audit checklist |
| [13 — Access profiles](13-access-profiles.md) | LAN profiles (`trusted` / `shared`) |
| [14 — Image pins](14-image-pins.md) | Pinned Compose image tags (ADR 0010) |
| [15 — Credential rotation](15-credential-rotation.md) | Step-by-step recovery after password or API key changes |

## Screenshots

UI screenshots will live under [`docs/images/`](../images/README.md) once the stack runs. Diagrams that are language-neutral go in `images/shared/`.

## Other documentation

- Engineering / contributors: [docs/INDEX.md](../INDEX.md)
- AI agents: [AGENTS.md](../../AGENTS.md)
