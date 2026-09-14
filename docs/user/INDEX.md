# Flixbox user guide

Run a home media pipeline: request a title, download it (optionally over VPN), hardlink it into your library, and stream on Jellyfin — with a single CLI and sane defaults.

**Language:** English (canonical). Full Spanish mirror: [`docs/es/user/INDEX.md`](../es/user/INDEX.md) · [Quick reference (ES)](../es/user/REFERENCE.md).

**Start here:** [Overview](01-overview.md) → [How it works](02-how-it-works.md) → [Install](04-install.md) (~15 min to `up`) → [First-run](05-first-run.md) (indexers + wiring).

Writers: tone and visuals follow the [documentation style guide](../00-doc-style.md).

## Contents

| Guide | What you will learn |
| --- | --- |
| [01 — Overview](01-overview.md) | What Flixbox is, who it is for, short disclaimer |
| [16 — Legal disclaimer](16-legal-disclaimer.md) | Lawful use, operator liability, no endorsement of infringement ([ES](../es/user/16-legal-disclaimer.md)) |
| [17 — CLI reference](17-cli.md) | version, doctor, status --json, exit codes (ADR 0021 Phase A) ([ES](../es/user/17-cli.md)) |
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
| [11 — Smoke test](11-smoke-test.md) | Operator validation checklist (v0.1 baseline) |
| [12 — Torrent privacy and security](12-torrent-privacy-and-security.md) | VPN privacy, qBit settings, leak prevention, audit checklist |
| [13 — Access profiles](13-access-profiles.md) | LAN profiles (`trusted` / `shared`) |
| [14 — Image pins](14-image-pins.md) | Pinned Compose image tags (ADR 0010) |
| [15 — Credential rotation](15-credential-rotation.md) | Step-by-step recovery after password or API key changes |

## Screenshots and demos

Capture checklist (Homepage, CLI tape): [`docs/images/README.md`](../images/README.md).  
Concept diagrams: Mermaid in [How it works](02-how-it-works.md) / [Architecture](../03-architecture.md) ([style §7](../00-doc-style.md#7-diagram-style-line)).  
UI screenshots → `images/en/` (and `es/` later).

## Other documentation

- Engineering / contributors: [docs/INDEX.md](../INDEX.md)
- Doc brand & page templates: [00-doc-style.md](../00-doc-style.md)
- AI agents: [AGENTS.md](../../AGENTS.md)
