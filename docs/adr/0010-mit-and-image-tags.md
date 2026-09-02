# ADR 0010: Image tags and license

- **Status:** Accepted
- **Date:** 2026-08-27
- **Updated:** 2026-09-02 — pins applied for pre-release

## Context

Flixbox needs a public license and a clear Docker image tagging policy before implementation. The maintainer chose maximum permissiveness for adoption and simplicity for early development.

## Decision

1. **License:** MIT (see root `LICENSE`), copyright Alejandro Azario.
2. **Image tags:** pin to explicit semver tags in `compose/*.yml` for pre-release and v0.1.0 onward. The pin table lives in [docs/user/14-image-pins.md](../user/14-image-pins.md).
3. **`:latest` is forbidden** in tracked Compose files — enforced by CI rule C-43.
4. **Release hygiene:** optional digest lock file via `scripts/ci-pin-digests.sh` on version tags (see [10-ci-plan.md](../10-ci-plan.md) C-75).

## Consequences

- Compose files use pinned semver tags; operators bump via release notes and the pin table.
- CI fails on `:latest` in `compose/`.
- Downstream users who need reproducibility should keep pins (and optionally digests) when bumping versions.
