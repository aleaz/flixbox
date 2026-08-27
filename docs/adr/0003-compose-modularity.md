# ADR 0003: Compose modularity

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

Monolithic compose files drift, become unreadable, and mix optional concerns (proxy, Plex, VPN) with core services.

## Decision

- Use Docker Compose v2 **`include:`** with files under `compose/`.
- Use **profiles** for optional pieces (e.g. Plex, socket-proxy).
- No single compose YAML file may exceed **150 lines**.

## Consequences

- Slightly more files; CLI/`include` root must assemble them.
- Easier reviews and safer AI edits (narrow file scope).
- Monolithic compose is out of scope for Flixbox.
