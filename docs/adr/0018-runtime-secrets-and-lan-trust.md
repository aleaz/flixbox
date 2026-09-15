# ADR 0018: Runtime secrets and LAN trust model

- **Status:** Accepted
- **Date:** 2026-09-02
- **Related:** [0015](0015-access-profiles.md), [0006](0006-mvp-service-inventory.md)

## Context

Flixbox injects API keys and passwords via Compose `environment:` blocks. Anyone with host Docker access can read them via `docker inspect`. The default `trusted` access profile exposes *arr admin UIs on the LAN without Forms login. Homepage has no built-in authentication.

This is acceptable for a single-operator homelab when the host and LAN are trusted — but must be explicit in operator docs and release checklist.

## Decision

1. **Document threat model** in [docs/user/13-access-profiles.md](../user/13-access-profiles.md) and [docs/user/06-configuration.md](../user/06-configuration.md):
   - Docker socket / `docker inspect` exposes env secrets.
   - `trusted` = RFC1918 bypass on *arr; not suitable for shared Wi‑Fi.
   - `shared` = localhost bind for admin UIs + Forms login reference values.
   - Homepage is an internal dashboard, not a security boundary.
2. **CLI banner:** `flixbox up` warns when `trusted` + `FLIXBOX_ADMIN_BIND_IP=0.0.0.0` on non-isolated LANs.
3. **Out of v0.1 baseline:** migrate all services to Docker secrets files; Decluttarr env-from-file profile; Authelia/Authentik (ADR 0006).

## Consequences

- Residual risk is documented and accepted for homelab v0.1.
- Release notes include “Manual after configure” and LAN trust checklist.
- Future hardening tracks env-from-file without breaking Decluttarr v2 contract.

## Validation

- `scripts/ci-validate.sh` C-78 (doc sections present)
- Gitleaks unchanged
