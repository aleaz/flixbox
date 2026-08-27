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
- [ ] Spanish user guide (`README.es.md` + `docs/es/user/`) before first public release tag
- [ ] Image tag pins + CI (gitleaks/trivy) — phase 7 / before v0.1 tag

## Next — Public v0.1 polish

Follow [06-development-guide.md](06-development-guide.md) phase 7 and remaining DoD items.

Deliverables:

- Screenshots + Spanish user guide
- Hardlink + VPN/Direct verification documented with operator checklist
- Image tags pinned before tagging v0.1

## After MVP — v0.2

- CLI: `sync-profiles`, `backup`, `restore`, `update`
- Stronger init validation (hardlink probe, config-on-NFS guard, exFAT guard)
- GitHub Actions: gitleaks (+ trivy)
- Image tag pinning policy documented and applied

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

## Change control

- Scope changes require updating `01-scope.md` and, for architectural choices, a new or updated ADR.
- Do not expand MVP mid-implementation without an explicit maintainer decision.
