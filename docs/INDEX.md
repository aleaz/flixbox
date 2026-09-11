# Flixbox documentation map

**Languages:** English is canonical. Spanish user docs are reserved under [`docs/es/`](es/README.md) ([ADR 0011](adr/0011-documentation-i18n.md)).

**Status:** Implemented (operator guide + stack; MVP Definition of Done met on Linux verification); engineering notes may still say Working Draft where unfinished.

## Operators (start here)

| Doc | Purpose |
| --- | --- |
| [User guide](user/INDEX.md) | How to understand, install, and operate Flixbox |
| [Legal disclaimer](user/16-legal-disclaimer.md) | Lawful use and operator liability ([ES](es/user/16-legal-disclaimer.md)) |
| [How it works](user/02-how-it-works.md) | Mental model: pipeline, `/data`, VPN/Direct |
| [Documentation style guide](00-doc-style.md) | Brand, tone, page shape, and asset rules (README + user docs) |

## Engineering

| Doc | Purpose |
| --- | --- |
| [00-vision.md](00-vision.md) | Why Flixbox exists, audience, principles |
| [01-scope.md](01-scope.md) | MVP in/out/later and definition of done |
| [02-glossary.md](02-glossary.md) | Shared vocabulary |
| [03-architecture.md](03-architecture.md) | System design and topology |
| [04-requirements.md](04-requirements.md) | Functional and non-functional requirements |
| [05-standards.md](05-standards.md) | Engineering standards |
| [06-development-guide.md](06-development-guide.md) | Implementation phases |
| [07-operations-risks.md](07-operations-risks.md) | Edge cases and mitigations |
| [08-roadmap.md](08-roadmap.md) | MVP → later releases |
| [09-hygiene-defaults.md](09-hygiene-defaults.md) | Decluttarr + Maintainerr thresholds |
| [10-ci-plan.md](10-ci-plan.md) | GitHub Actions plan and contract checks |
| [11-future-notifications-and-vpn-resilience.md](11-future-notifications-and-vpn-resilience.md) | Post-MVP planning: Apprise hub + VPN heal (ADRs 0012/0013) |

## Decisions

Architecture Decision Records: [adr/](adr/)

## Images

[docs/images/](images/README.md) — `shared/` · `en/` · `es/` · brand-first capture checklist

## For AI agents

Project root: [AGENTS.md](../AGENTS.md) and [.cursor/rules/](../.cursor/rules/)
