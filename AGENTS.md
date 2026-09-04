# AGENTS.md — guidance for AI coding agents

Flixbox is a **docs-first** open-source Docker media stack (MVP Compose + CLI are implemented). Read this before editing anything.

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
- Operator secrets day-2: `./bin/flixbox credentials show|set` (ADR 0020); Forms under `shared` via Host Config / `configure --sync-arr-ui`.
- **Never break** the `/data` hardlink contract (include `torrents/incomplete`).
- **Never break** VPN dual-mode; only qBit uses Gluetun netns; publish qBit ports on Gluetun; *arr / Decluttarr download host is always `qbittorrent:8080` ([ADR 0014](docs/adr/0014-stable-qbit-download-hostname.md)).
- **Access profiles** (`trusted` / `shared`): follow [ADR 0015](docs/adr/0015-access-profiles.md); do not leave derived bind/auth keys empty under `shared`.
- **Maintainerr**: default Jellyfin; no destructive rules enabled by default.
- **No git commits** unless the user explicitly asks.
- **Commit messages:** public-facing only — see [docs/05-standards.md](docs/05-standards.md) §8. No phase/MVP/agent-session wording in subjects or bodies.
- Prefer **small, focused diffs** aligned with [docs/06-development-guide.md](docs/06-development-guide.md).
- Docs language: **English** for canonical technical docs.

## Current repo state

MVP Compose modules (`compose/`), templates, host scripts, and `bin/flixbox` (including `configure` / `reload`) are implemented. First-run is API-assisted (ADR 0005): operators still add Prowlarr indexers and enable Maintainerr rules deliberately.

## When implementing

- Follow phases in `docs/06-development-guide.md`.
- Check `docs/07-operations-risks.md` for footguns.
- Update docs/ADRs if behavior changes.

## Product one-liner

Request (Seerr) → Prowlarr/*arr → qBittorrent (VPN or Direct) → hardlink into `/data/media` → Jellyfin, with Decluttarr/Maintainerr hygiene, Homepage, and Caddy.
