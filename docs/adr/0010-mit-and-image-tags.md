# ADR 0010: Image tags and license

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

Flixbox needs a public license and a clear Docker image tagging policy before implementation. The maintainer chose maximum permissiveness for adoption and simplicity for early development.

## Decision

1. **License:** MIT (see root `LICENSE`), copyright Alejandro Azario.
2. **Image tags during development / early MVP:** use vendor **`latest`** (or the image’s documented rolling default, e.g. Seerr `latest`) so bootstrap stays simple.
3. **Before public v0.1 release (or when stability matters):** pin images to explicit version tags or digests; document the pin list in release notes. `:latest` is not the long-term production recommendation.

## Consequences

- Early compose files may use `:latest` without violating standards.
- Phase 7 / release hygiene still requires pinning.
- Downstream users who need reproducibility should pin even if upstream examples use `latest`.
