# Roadmap

**Status:** Working Draft  
Versions below are planning labels, not semver promises until the first public tag.

## Now — MVP scaffolding (current)

- [x] Formal docs, ADRs, AGENTS.md, Cursor rules
- [x] Audit corrections: Seerr, Byparr, port-forward contract, permissions model, Decluttarr + Maintainerr in MVP
- [x] MIT license; `:latest` allowed for early compose; hygiene defaults documented
- [x] English user guide (`docs/user/`) + i18n layout reserved (`docs/es/`, `images/{shared,en,es}/`)
- [x] Modular Compose for MVP inventory (including Decluttarr + Maintainerr)
- [x] Bash CLI minimum commands (`bin/flixbox`)
- [x] Hygiene/Recyclarr/Homepage/Caddy templates
- [x] Key screenshots P0 (`en/homepage-ops.png`, CLI GIF, logo) — P2 story stills optional
- [x] Spanish user guide mirror (`README.es.md` + full `docs/es/user/`)
- [x] CI phase 1 (gitleaks + validate) — [10-ci-plan.md](10-ci-plan.md)
- [x] CI phase 2 (Trivy warn-only + compose render) — [10-ci-plan.md](10-ci-plan.md)
- [x] `bin/flixbox configure` + `reload` — API wiring (roots, clients, Byparr, Bazarr, Jellyfin/Seerr, secret loop)
- [x] Image tag pins before public v0.1 tag — [14-image-pins.md](user/14-image-pins.md)
- [x] Operator verification (Linux): Direct smoke + hardlink + VPN/Direct + `shared` access profile + Seerr→Jellyfin path — [11-smoke-test.md](user/11-smoke-test.md); checklist in [06-development-guide.md](06-development-guide.md)

## Next — Public v0.1 polish

MVP Definition of Done is met. Before announcing a public `v0.1.0` tag:

- [x] Key screenshots P0 in `docs/images/` (P2 `seerr-request` / `jellyfin-library` optional)
- [x] Complete Spanish user guide mirror (`docs/es/user/`)
- [x] Finalize [releases/v0.1.0-notes.md](releases/v0.1.0-notes.md) with the release commit SHA

Already done for that gate: pinned images, CI phase 1–2, idempotent `configure`, VPN `tun0` bind path exercised on a live Gluetun install, EN+ES user guides.

## After MVP — v0.2

- CLI UX contract — [ADR 0021](adr/0021-cli-ux-contract.md) (**Accepted**, full UX/QA/security contract): Phase A `version`/help/exits/`doctor`/`status --json`; Phase B `backup`/`restore`/`update`/`recyclarr`/completions; Phase C taxonomy hardening
- CLI: `sync-profiles`, `backup`, `restore`, `update` (names locked by ADR 0021 Phase B)
- [x] **`configure`:** clear Jellyfin `LocalNetworkAddresses` when it is only `::` (stream URLs break on localhost and LAN; not a listen/firewall setting) — [Troubleshooting](user/10-troubleshooting.md)
- Stronger init validation (hardlink probe, config-on-NFS guard, exFAT guard) — fold into `doctor` where practical
- [x] CI phase 2: Trivy (warn-only) + shared compose render — [10-ci-plan.md](10-ci-plan.md)
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
- Do not expand MVP mid-implementation without an explicit maintainer decision.
