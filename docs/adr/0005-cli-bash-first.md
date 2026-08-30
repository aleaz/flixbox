# ADR 0005: Bash CLI first

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-30 (first-run API wiring via `configure`; *arr External auth for LAN)

## Context

A dual Bash + PowerShell CLI from day one delays the Compose MVP. Linux is the reference platform.

After Compose MVP landed, the remaining operator pain is deterministic UI wiring (root folders, download clients, Byparr, Bazarr, secret copy-paste into `.env` / Recyclarr / Homepage, Jellyfin libraries, Seerr). Indexer credentials stay user-specific and cannot be invented by Flixbox.

Servarr v4+ requires authentication; there is no stable public “create first admin” API. For a LAN Docker stack the practical automation path is **pre-seeded API keys** plus **`AuthenticationMethod=External`** so `configure` can drive the apps without five first-run wizards. That is unsafe if *arr ports are published to the public internet.

## Decision

- MVP ships only **`bin/flixbox`** (Bash) with: `init`, `up`, `down`, `restart`, `status`, `logs`, `vpn-test`, **`configure`**, **`reload`**.
- PowerShell CLI is **post-MVP**.
- Extra commands (`sync-profiles`, `backup`, `restore`, `update`) are roadmap, not MVP blockers.
- **`configure`** is the idempotent first-run wirer (GET → skip if already correct → POST/PUT). It MUST:
  - Wire qBittorrent categories/prefs (VPN: bind BitTorrent to `tun0`), Radarr/Sonarr root folders + qBit client, Prowlarr Byparr + app sync, Bazarr connections.
  - Close the secret loop: write discovered/generated API keys into `.env` when empty; patch Recyclarr placeholders; enable Homepage widgets when keys exist; recreate Decluttarr/Unpackerr when hygiene keys change.
  - Prefer API automation for Jellyfin libraries and Seerr ↔ Jellyfin/*arr when credentials allow.
- **`init`** MAY generate random `RADARR_API_KEY` / `SONARR_API_KEY` / `PROWLARR_API_KEY` when empty and compose MUST pass them as Servarr `__AUTH__APIKEY` overrides with **`External`** auth and **`DisabledForLocalAddresses`** (LAN Docker assumption).
- **Still manual:** Prowlarr indexer credentials; optional Maintainerr destructive rules; operator-chosen admin passwords for Jellyfin/qBit when not set in `.env`.
- **Forbidden claim:** “fully zero-touch” while indexers remain manual.

## Consequences

- Windows users use WSL2 Bash or raw Compose until v0.4-ish.
- AI agents must not scaffold `bin/flixbox.ps1` during MVP work unless explicitly requested.
- Operators must not publish Radarr/Sonarr/Prowlarr/Bazarr ports to the WAN without a reverse-proxy auth layer (Caddy ± Authelia later). External *arr auth is a LAN first-run trade-off, not a general security model.
- Docs (`05-first-run.md`, REFERENCE) must list remaining manual steps honestly and keep `configure --dry-run`.
