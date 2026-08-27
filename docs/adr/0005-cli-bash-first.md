# ADR 0005: Bash CLI first

- **Status:** Accepted
- **Date:** 2026-08-27

## Context

A dual Bash + PowerShell CLI from day one delays the Compose MVP. Linux is the reference platform.

## Decision

- MVP ships only **`bin/flixbox`** (Bash) with: `init`, `up`, `down`, `restart`, `status`, `logs`, `vpn-test`.
- PowerShell CLI is **post-MVP**.
- Extra commands (`sync-profiles`, `backup`, `restore`, `update`) are roadmap, not MVP blockers.

## Consequences

- Windows users use WSL2 Bash or raw Compose until v0.4-ish.
- AI agents must not scaffold `bin/flixbox.ps1` during MVP work unless explicitly requested.
