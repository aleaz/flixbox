# AGENTS.md — guidance for AI coding agents

Flixbox is a **docs-first, pre-implementation** open-source Docker media stack. Read this before editing anything.

## Mandatory reading order

1. [docs/01-scope.md](docs/01-scope.md) — what is in / out of MVP  
2. [docs/adr/](docs/adr/) — Accepted decisions (do not reopen)  
3. [docs/03-architecture.md](docs/03-architecture.md) — contracts  
4. [docs/05-standards.md](docs/05-standards.md) — how to write code/docs  
5. [docs/06-development-guide.md](docs/06-development-guide.md) — build order  

## Hard rules

- **No secrets in git** (`.env`, VPN keys, API tokens).
- **MVP inventory only** — see ADR 0006. Includes Seerr, Byparr, Decluttarr, Maintainerr.
- **Do not** add Lidarr, Readarr, SABnzbd, Whisper, Overseerr, Jellyseerr, Autobrr, Profilarr, Authelia, PowerShell CLI unless scope changes.
- **Never break** the `/data` hardlink contract (include `torrents/incomplete`).
- **Never break** VPN dual-mode; only qBit uses Gluetun netns; publish qBit ports on Gluetun; mode-aware client URLs for *arr and Decluttarr.
- **Maintainerr**: default Jellyfin; no destructive rules enabled by default.
- **No git commits** unless the user explicitly asks.
- **Commit messages:** public-facing only — see [docs/05-standards.md](docs/05-standards.md) §8. No phase/MVP/agent-session wording in subjects or bodies.
- Prefer **small, focused diffs** aligned with [docs/06-development-guide.md](docs/06-development-guide.md).
- Docs language: **English** for canonical technical docs.

## Current repo state

MVP Compose modules (`compose/`), templates, host scripts, and `bin/flixbox` are implemented. Operators must still complete UI first-run wiring (indexers, API keys, libraries).

## When implementing

- Follow phases in `docs/06-development-guide.md`.
- Check `docs/07-operations-risks.md` for footguns.
- Update docs/ADRs if behavior changes.

## Product one-liner

Request (Seerr) → Prowlarr/*arr → qBittorrent (VPN or Direct) → hardlink into `/data/media` → Jellyfin, with Decluttarr/Maintainerr hygiene, Homepage, and Caddy.
