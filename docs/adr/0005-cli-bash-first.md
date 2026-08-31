# ADR 0005: Bash CLI first

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-08-31 (access profiles `trusted` / `shared` — ADR 0015)

## Context

A dual Bash + PowerShell CLI from day one delays the Compose MVP. Linux is the reference platform.

After Compose MVP landed, the remaining operator pain is deterministic UI wiring (root folders, download clients, Byparr, Bazarr, secret copy-paste into `.env` / Recyclarr / Homepage, Jellyfin libraries, Seerr). Indexer credentials stay user-specific and cannot be invented by Flixbox.

Servarr v4+ requires authentication; there is no stable public “create first admin” API. For a LAN Docker stack the practical automation path is **pre-seeded API keys** plus profile-driven UI auth ([ADR 0015](0015-access-profiles.md)). Profile **`trusted`** uses **`AuthenticationMethod=External`** and **`DisabledForLocalAddresses`** so `configure` avoids browser wizards on a trusted LAN. Profile **`shared`** uses **`Forms` + `Enabled`** so roommates on the same network cannot open *arr UIs without credentials; **`configure` still uses API keys only**.

## Decision

- MVP ships only **`bin/flixbox`** (Bash) with: `init`, `up`, `down`, `restart`, `status`, `logs`, `vpn-test`, **`configure`**, **`reload`**.
- PowerShell CLI is **post-MVP**.
- Extra commands (`sync-profiles`, `backup`, `restore`, `update`) are roadmap, not MVP blockers.
- **`configure`** is the idempotent first-run wirer (GET → skip if already correct → POST/PUT). It MUST:
  - Wire qBittorrent categories/prefs (VPN: bind BitTorrent to `tun0`), Radarr/Sonarr root folders + qBit client, Prowlarr Byparr + app sync, Bazarr connections.
  - Close the secret loop: write discovered/generated API keys into `.env` when empty; patch Recyclarr placeholders; enable Homepage widgets when keys exist; recreate Decluttarr/Unpackerr when hygiene keys change.
  - Prefer API automation for Jellyfin libraries and Seerr ↔ Jellyfin/*arr when credentials allow.
- **`init`** MAY generate random `RADARR_API_KEY` / `SONARR_API_KEY` / `PROWLARR_API_KEY` when empty and compose MUST pass them as Servarr `__AUTH__APIKEY` overrides. **`FLIXBOX_ACCESS_PROFILE`** (ADR 0015) sets `*__AUTH__METHOD` and `*__AUTH__REQUIRED` (`trusted` default: External + DisabledForLocalAddresses; `shared`: Forms + Enabled). **`init`** syncs derived auth vars and MAY generate `FLIXBOX_ARR_UI_USER` / `FLIXBOX_ARR_UI_PASSWORD` for `shared` as **reference values** for manual Forms signup (not applied by Compose or `configure`).
- **Still manual:** Prowlarr indexer credentials; optional Maintainerr destructive rules; operator-chosen admin passwords for Jellyfin/qBit when not set in `.env`.
- **Forbidden claim:** “fully zero-touch” while indexers remain manual.

## Consequences

- Windows users use WSL2 Bash or raw Compose until v0.4-ish.
- AI agents must not scaffold `bin/flixbox.ps1` during MVP work unless explicitly requested.
- Operators must not publish Radarr/Sonarr/Prowlarr/Bazarr ports to the WAN without a reverse-proxy auth layer (future). Profile **`trusted`** on a shared LAN is insecure — use **`shared`**. Gluetun is torrent egress only (ADR 0002), not remote UI access.
- Docs (`05-first-run.md`, REFERENCE) must list remaining manual steps honestly and keep `configure --dry-run`.
