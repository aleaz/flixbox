# Roadmap

**Status:** Working Draft — first public release **[`v0.1.1`](https://github.com/aleaz/flixbox/releases/tag/v0.1.1)** shipped (2026-09-12).  
Versions below are planning labels; `v0.1.1` is the first public semver tag.

## Shipped — v0.1 baseline (closed MVP)

- [x] Formal docs, ADRs, AGENTS.md, Cursor rules
- [x] Audit corrections: Seerr, Byparr, port-forward contract, permissions model, Decluttarr + Maintainerr in core inventory
- [x] MIT license; hygiene defaults documented
- [x] English user guide (`docs/user/`) + Spanish mirror (`README.es.md` + full `docs/es/user/`)
- [x] Modular Compose for core inventory (including Decluttarr + Maintainerr)
- [x] Bash CLI minimum commands (`bin/flixbox`)
- [x] Hygiene/Recyclarr/Homepage/Caddy templates
- [x] Key screenshots P0 (`en/homepage-ops.png`, CLI GIF, logo) — P2 story stills optional
- [x] CI phase 1–2 (gitleaks + validate; Trivy warn-only + compose render) — [10-ci-plan.md](10-ci-plan.md)
- [x] `bin/flixbox configure` + `reload` — API wiring
- [x] Image tag pins — [14-image-pins.md](user/14-image-pins.md)
- [x] Operator verification (Linux): Direct + hardlink + VPN/Direct + `shared` + Seerr→Jellyfin — [11-smoke-test.md](user/11-smoke-test.md)
- [x] Public release notes + GitHub Release **`v0.1.1`** — [releases/v0.1.1-notes.md](releases/v0.1.1-notes.md)

## Now — v0.2

- CLI UX contract — [ADR 0021](adr/0021-cli-ux-contract.md) (**Accepted**): Phase A diagnostics + Phase B lifecycle (`backup`/`restore`/`update`/`recyclarr`/`completion`) **landed** — [17-cli.md](user/17-cli.md); Phase C taxonomy hardening ongoing
- [x] CLI: `sync-profiles`, `backup`, `restore`, `update` (names locked by ADR 0021 Phase B)
- [x] **`configure`:** clear Jellyfin `LocalNetworkAddresses` when it is only `::` — [Troubleshooting](user/10-troubleshooting.md)
- Stronger init validation (hardlink probe, config-on-NFS guard, exFAT guard) — fold into `doctor` where practical
- Optional digest pins (`@sha256:`) for stricter supply chain
- **Notifications:** optional Apprise API profile (Telegram via Apprise URL, not a Flixbox bot) — [ADR 0012](adr/0012-notifications-apprise-hub.md)
- **VPN resilience docs + optional heal:** document Gluetun internal reconnect/killswitch; evaluate optional `vpn-heal` watchdog profile; **never** auto-fallback to Direct — [ADR 0013](adr/0013-vpn-resilience-no-direct-fallback.md)
- Planning summary: [11-future-notifications-and-vpn-resilience.md](11-future-notifications-and-vpn-resilience.md)

## v0.3 — Optional media profiles

- SABnzbd / Usenet profile (Direct-friendly)
- Lidarr profile (music)
- Decide books: Readarr vs Audiobookshelf (one ADR before coding)

## v0.4 — Platform DX + access

- PowerShell CLI `bin/flixbox.ps1` (WSL2 path warnings)
- Optional Authelia/Authentik profile in front of Caddy
- Optional access profile: **Forms + LAN publish** (password on Wi‑Fi without localhost-only bind) — not in ADR 0015 matrix today (`trusted` = LAN open/no Forms; `shared` = Forms + `127.0.0.1`)
- Optional Whisper subtitle profile (resource-gated)
- Optional Profilarr profile (mutually exclusive with Recyclarr)
- Optional Autobrr / cross-seed profiles (private trackers)
- Optional Streamystats companion for Maintainerr/Jellyfin stats
- Optional MkDocs / GitHub Pages with language switcher (reads `docs/user` + `docs/es/user`)

## Explicitly not planned

- Kubernetes / Helm as primary deployment
- Migration tooling from private legacy stacks
- Replacing Gluetun with VPNGate scrapers
- Shipping Overseerr or Jellyseerr alongside Seerr
- Defaulting CF bypass to unmaintained/poorly performing images when Byparr works
- Automatic Direct (non-VPN) torrent egress when Gluetun is unhealthy (privacy leak)

## Change control

- Scope changes require updating `01-scope.md` and, for architectural choices, a new or updated ADR.
- Do not expand the **v0.1 core inventory** without an explicit maintainer decision (same closed list as [ADR 0006](adr/0006-mvp-service-inventory.md)).
