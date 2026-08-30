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
- [ ] Key screenshots in `docs/images/en/`
- [x] Spanish user guide (`README.es.md` + `docs/es/user/`) — partial (REFERENCE + INDEX); full mirror before v0.1 tag
- [x] CI phase 1 (gitleaks + validate) — [10-ci-plan.md](10-ci-plan.md)
- [x] `bin/flixbox configure` + `reload` — API wiring (roots, clients, Byparr, Bazarr, Jellyfin/Seerr, secret loop)
- [ ] Image tag pins before public v0.1 tag

## Next — Public v0.1 polish

Follow [06-development-guide.md](06-development-guide.md) phase 7 and remaining DoD items.

Deliverables:

- Screenshots + complete Spanish user guide mirror
- `bin/flixbox configure` — idempotent API wiring (ADR 0005); indexers remain manual
- Hardlink + VPN/Direct verification documented with operator checklist
- Image tags pinned before tagging v0.1
- VPN `tun0` bind sidecar verified on a live Gluetun install

## After MVP — v0.2

- CLI: `sync-profiles`, `backup`, `restore`, `update`
- Stronger init validation (hardlink probe, config-on-NFS guard, exFAT guard)
- CI phase 2: Trivy + init smoke — [10-ci-plan.md](10-ci-plan.md)
- Image tag pinning policy documented and applied
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
