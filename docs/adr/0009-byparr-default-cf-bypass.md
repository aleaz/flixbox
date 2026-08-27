# ADR 0009: Byparr as default Cloudflare bypass

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

Prowlarr expects a FlareSolverr-compatible proxy API for Cloudflare-protected indexers. Upstream FlareSolverr still exists, but operators in 2025–2026 widely report better success with **Byparr** (and alternatives like Trawl) against modern challenges.

## Decision

- Default MVP image/service: **Byparr**, configured in Prowlarr as an indexer proxy of type “FlareSolverr” (protocol name).
- Document FlareSolverr (or Trawl) as optional drop-in replacements speaking the same API.
- Do not treat “FlareSolverr” the product as a forever-pinned default.

## Consequences

- Glossary and compose use Byparr naming.
- Prowlarr UI still says “FlareSolverr” for the proxy type — docs must explain that.
