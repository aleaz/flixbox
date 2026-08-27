# Vision

**Project:** Flixbox  
**Status:** Working Draft

## Problem

Home media automation stacks are usually a single monolithic Compose file, manual UI wiring, fragile VPN setups, and split volume mounts that force expensive file copies instead of hardlinks. They are hard to maintain, hard to share as open source, and easy to misconfigure.

## Product

Flixbox is an open-source, containerized media suite for home / HTPC use that covers:

**request → index → download → post-process → hardlink into library → maintain → stream**

It is designed as a public GitHub project: modular Compose, documented contracts, a Bash CLI for day-0 operations, queue/library hygiene (Decluttarr + Maintainerr), and defaults aligned with [TRaSH Guides](https://trash-guides.info/) storage practices.

## Audience

- Home users who want a reproducible *arr-style stack
- Operators comfortable with Docker on Linux
- Contributors and AI-assisted development working from this documentation set

## Principles

1. **Contracts over folklore** — Storage, VPN dual-mode, and Compose layout are explicit and tested.
2. **MVP honesty** — Ship a closed service inventory first; optional media types and CLIs come later.
3. **Linux first** — Native Linux is the reference platform; WSL2 and macOS are best-effort.
4. **FOSS-first media** — Jellyfin is primary; Plex is optional.
5. **No secrets in git** — Credentials live only in local env/config volumes.
6. **Modular Compose** — Small files, profiles, no unmaintainable monolith.
7. **Safe defaults** — Killswitch in VPN mode, graceful stop for SQLite, local `/config` on SSD.
8. **Hygiene without surprises** — Decluttarr/Maintainerr ship with conservative defaults; destructive rules are opt-in.

## Non-goals (product level)

- Not a hosted SaaS or cloud media product
- Not a legal advice project; users are responsible for how they use download tooling
- Not a migration tool from any prior personal stack
- Not “enterprise compliance theater”; documentation stays practical

## Success (north star)

A new Linux host can clone the repo, run `./bin/flixbox init` and `./bin/flixbox up`, get a healthy MVP stack, verify hardlinks and (if enabled) VPN isolation, and use Seerr → Servarr → qBittorrent → Jellyfin end to end, with Decluttarr/Maintainerr available for queue and library hygiene.
