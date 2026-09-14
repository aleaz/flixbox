# Referencia CLI (ADR 0021)

**Idiomas:** [English](../../user/17-cli.md) · Español (esta página)

**Estado:** Phase A diagnósticos **listo**; Phase **A2** help safety + `--no-color` global **listo**; stubs de help de lifecycle **listos** (alcance CONFIG-only) — cuerpos mutadores después — ver [ADR 0021](../../adr/0021-cli-ux-contract.md)
**Audiencia:** Operadores y automatización  
**Relacionado:** [ADR 0021](../../adr/0021-cli-ux-contract.md) · [REFERENCE](REFERENCE.md)

`./bin/flixbox` es el único entrypoint de operador. Phase A entregó descubribilidad (`version`, help de nivel superior), diagnóstico (`doctor`), `status --json`, presentación vía `cli-msg` y taxonomía de salidas en esas rutas. `--help` por comando es sin side effects en todos los comandos shipped (A2).

## Instalación / PATH

Desde un clone (soportado siempre):

```bash
./bin/flixbox --help
```

Instalación opcional en PATH (Linux):

```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/bin/flixbox" ~/.local/bin/flixbox
# asegúrate de que ~/.local/bin esté en PATH
flixbox version
```

Requiere **Bash 4+**. Completions: `flixbox completion bash|zsh` (help disponible ahora; scripts con el trabajo de completions).

## Flags globales

| Flag | Comportamiento | Estado |
| --- | --- | --- |
| `-h` / `--help` | Lista de comandos de nivel superior | Listo |
| `--version` | Igual que `version` | Listo |
| `-h` / `--help` por comando | Uso específico | Listo (incluye lifecycle; sin side effects) |
| `--json`, `-q` / `--quiet`, `-v` / `--verbose` | Según el comando que los documente | Listo donde está documentado |
| `NO_COLOR` / non-TTY | Tokens sin ANSI | Listo |
| `--no-color`, `-q`/`-v` globales, `--env-file`, `--project-dir` | Globals ADR 0021 | `--no-color` listo; `--env-file` / `--project-dir` / `-q`/`-v` globales aún diferidos |

## Streams (stdout vs stderr)

| Stream | Contenido |
| --- | --- |
| **stdout** | Resultado primario: identidad de `version`, reportes `doctor`/`status`, líneas de outcome de `configure` + `summary:`, secretos de `credentials show`, payloads `--json` |
| **stderr** | Progreso y tips (`INFO` / `OK` de `init`/`up`/`reload`), diagnósticos `WARN` / `FAIL`, hints `Next:` |

No dependas solo del color: los tokens (`PASS` / `FAIL` / `WARN` / `INFO` / `OK`) siguen en texto plano con `NO_COLOR` o sin TTY.

Vocabulario de outcomes de `configure` en stdout: `updated` / `unchanged` / `failed` / `dry-run`, luego `summary: N updated, M unchanged, K failed`.

## Códigos de salida (rutas tocadas)

| Código | Significado |
| --- | --- |
| `0` | Éxito (incluye help/version) |
| `2` | Error de uso (comando/flag desconocido, args faltantes) |
| `3` | Docker / Compose inalcanzable o falló una op de compose |
| `4` | Configuración inválida (falta `.env`, paths/perfil malos, desalineación mode/VPN como bloqueo) |
| `5` | Dependencia no lista (p. ej. Gluetun unhealthy en modo VPN) |

Los comandos legacy pueden seguir saliendo con `1` hasta que Phase C termine la migración de taxonomía.

## Comandos (altas de Phase A)

### `flixbox version` / `--version`

Imprime la identidad de la CLI desde `VERSION` (o `git describe`), el nombre del proyecto Compose y el modo si existe `.env`. **Sin secretos.**

### `flixbox doctor [--json]`

Diagnóstico agregado: Docker CLI/daemon, plugin Compose, `.env`, `DATA_DIR`/`CONFIG_DIR`, alineación `FLIXBOX_MODE`↔`VPN_ENABLED`, perfil de acceso, **presencia** de API keys (solo booleanos), salud de Gluetun cuando `mode=vpn`.

Salida humana con tokens `PASS` / `FAIL` / `INFO` / `OK` (el color solo pinta el token).

`--json` emite un solo objeto con `schemaVersion: 2` (`vpnEnabled` es boolean JSON). Nunca incluye valores de keys.

### `flixbox status [--json] [-q|--quiet] [-v|--verbose]`

Humano por defecto: glance `SERVICE` / `STATE` / `HEALTH`, luego contexto `key: value`.  
`-v`: también imprime el `docker compose ps` completo.  
`--json`: vista de servicios + contexto; si Docker está caído, igual imprime JSON con `error` y sale **3**.  
`-q`: solo glance (sin bloque de contexto); los warnings siguen en stderr.

## I/O de seguridad

- `version`, `doctor` y `status` nunca imprimen passwords ni valores de API keys.
- Usa `credentials show` cuando intencionalmente necesites un secreto en stdout.
- No pases secretos como argv de CLI a los helpers.

## Checklist manual

1. `./bin/flixbox version` → exit 0  
2. `./bin/flixbox nosuch` → exit 2  
3. `./bin/flixbox status --help` → exit 0  
4. `./bin/flixbox doctor` en un host configurado → hints accionables; exit 0 cuando esté listo  
5. `./bin/flixbox status --json | jq .schemaVersion` → `2` cuando Docker funciona  

## Comandos de lifecycle (en curso)

| Comando | Estado | Notas |
| --- | --- | --- |
| `backup` / `restore` | Help + flags listos; cuerpos de archivo después | Solo **`${CONFIG_DIR}`**. **`${DATA_DIR}`** (media/torrents) es **del operador** — respaldalo vos. `.env` opcional con `--include-env`. |
| `update` | Help stub | Pull de tags pineados (ADR 0010); nunca reescribe a `:latest` |
| `recyclarr sync` / `sync-profiles` | Help stub | Reemplazará Compose crudo como path primario de operador |
| `completion bash\|zsh` | Help stub | Fish diferido |

Mientras no existan archivos de `backup`, `scripts/backup.sh` sigue sirviendo y pasará a ser un **wrapper fino** de `flixbox backup` (mismo alcance CONFIG-only).

## Diferido (después)

`-q`/`-v` globales, `--env-file`, `--project-dir`; migración completa `die`→taxonomía (Phase C); completions fish; perfiles opcionales Apprise / VPN-heal — ver [08-roadmap.md](../../08-roadmap.md).
