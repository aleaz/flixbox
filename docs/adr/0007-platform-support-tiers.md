# ADR 0007: Platform support tiers

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

Claiming identical behavior on Linux, Windows, and macOS conflicts with filesystem and GPU realities (NTFS hardlinks, VirtioFS, transcode support).

## Decision

- **First-class:** Linux x86_64 and ARM64.
- **Best-effort:** Docker Desktop on Windows (WSL2 ext4 data paths) and macOS.
- Documentation must state limitations; NFRs must not require “identical without code changes” across all three.

## Consequences

- CI and primary testing target Linux.
- WSL2 NTFS paths (`/mnt/c`) are unsupported for `${DATA_DIR}`.
- macOS is accepted for experimentation, not as the design reference.
