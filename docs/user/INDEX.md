# Flixbox user guide

Friendly documentation for operators who want to run Flixbox at home.

**Language:** English (canonical). A Spanish translation is planned before the first public release — see [ADR 0011](../adr/0011-documentation-i18n.md).

**Status:** Working Draft. The stack is not implemented yet; install steps describe the **target** experience.

## Contents

| Guide | What you will learn |
| --- | --- |
| [01 — Overview](01-overview.md) | What Flixbox is, who it is for, disclaimer |
| [02 — How it works](02-how-it-works.md) | Mental model: pipeline, `/data`, VPN vs Direct |
| [03 — Requirements](03-requirements.md) | Hardware, Docker, storage, network |
| [04 — Install](04-install.md) | Clone, `init`, `up` (target UX) |
| [05 — First-run setup](05-first-run.md) | Recommended UI wiring order |
| [06 — Configuration](06-configuration.md) | Paths, env, ports, Compose profiles |
| [07 — VPN and Direct](07-vpn-and-direct.md) | Gluetun, port forwarding, leak checks |
| [08 — Hygiene](08-hygiene.md) | Decluttarr and Maintainerr in plain language |
| [09 — Day-2 operations](09-operations.md) | Status, logs, updates, backups, hardlink check |
| [10 — Troubleshooting](10-troubleshooting.md) | Common failures and fixes |

## Screenshots

UI screenshots will live under [`docs/images/`](../images/README.md) once the stack runs. Diagrams that are language-neutral go in `images/shared/`.

## Other documentation

- Engineering / contributors: [docs/INDEX.md](../INDEX.md)
- AI agents: [AGENTS.md](../../AGENTS.md)
