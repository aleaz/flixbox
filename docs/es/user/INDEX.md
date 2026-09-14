<a id="flixbox-user-guide"></a>
# Guía de usuario Flixbox

Pipeline de medios en casa: pide un título, descárgalo (opcionalmente por VPN), hardlink a la biblioteca y reproduce en Jellyfin — con una sola CLI y defaults sensatos.

**Idioma:** español (espejo). Canónico: [`docs/user/INDEX.md`](../../user/INDEX.md) ([ADR 0011](../../adr/0011-documentation-i18n.md)).  
**Registro:** español neutro (tú estándar; sin voseo).

**Empieza aquí:** [Overview](01-overview.md) → [Cómo funciona](02-how-it-works.md) → [Instalación](04-install.md) (~15 min hasta `up`) → [First-run](05-first-run.md) (indexers + cableado).

<a id="contents"></a>
## Contenidos

| Guía | Qué aprenderás |
| --- | --- |
| [01 — Overview](01-overview.md) | Qué es Flixbox, para quién, aviso corto |
| [16 — Aviso legal](16-legal-disclaimer.md) | Uso lícito, responsabilidad del operador ([EN](../../user/16-legal-disclaimer.md)) |
| [17 — CLI](17-cli.md) | version, doctor, status --json, códigos de salida (ADR 0021 Phase A) ([EN](../../user/17-cli.md)) |
| [02 — Cómo funciona](02-how-it-works.md) | Modelo mental: pipeline, `/data`, VPN vs Direct |
| [03 — Requisitos](03-requirements.md) | Hardware, Docker, almacenamiento, red |
| [04 — Instalación](04-install.md) | Clone, `init`, `up` (~15 min) |
| [05 — First-run](05-first-run.md) | `configure` + indexers (~10–15 min) |
| [REFERENCE — Referencia rápida](REFERENCE.md) | URLs, puertos, CLI |
| [06 — Configuración](06-configuration.md) | Rutas, env, puertos, **credenciales y API keys**, perfiles Compose |
| [07 — VPN y Direct](07-vpn-and-direct.md) | Gluetun, port forwarding, fugas |
| [08 — Higiene](08-hygiene.md) | Decluttarr y Maintainerr en lenguaje claro |
| [09 — Operación día a día](09-operations.md) | Status, logs, updates, backups, hardlinks |
| [10 — Troubleshooting](10-troubleshooting.md) | Fallos comunes y arreglos |
| [11 — Smoke test](11-smoke-test.md) | Checklist de validación |
| [12 — Privacidad y seguridad BitTorrent](12-torrent-privacy-and-security.md) | VPN, qBit, fugas, auditoría |
| [13 — Perfiles de acceso](13-access-profiles.md) | Perfiles LAN (`trusted` / `shared`) |
| [14 — Image pins](14-image-pins.md) | Tags de imagen Compose (ADR 0010) |
| [15 — Rotación de credenciales](15-credential-rotation.md) | Recuperación tras cambio de password o API key |
| [18 — Notificaciones](18-notifications.md) | Connect nativo Day-0 + Apprise opcional (`notifications`) |

<a id="screenshots-and-demos"></a>
## Capturas y demos

Checklist: [`docs/images/README.md`](../../images/README.md).  
Diagramas de concepto: Mermaid en [Cómo funciona](02-how-it-works.md) / [Architecture (EN)](../../03-architecture.md).  
Capturas de UI: `docs/images/en/` (espejo `es/` cuando exista).

<a id="other-documentation"></a>
## Otra documentación

- Ingeniería / contribuidores: [docs/INDEX.md](../../INDEX.md) (inglés)
- Estilo de docs: [00-doc-style.md](../../00-doc-style.md) (inglés)
- Agentes IA: [AGENTS.md](../../../AGENTS.md)
