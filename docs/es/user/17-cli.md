# Referencia CLI (Phase A)

**Idiomas:** [English](../../user/17-cli.md) · Español (esta página)

**Estado:** Implementado (ADR 0021 Phase A)  
**Audiencia:** Operadores y automatización  
**Relacionado:** [ADR 0021](../../adr/0021-cli-ux-contract.md) · [REFERENCE](REFERENCE.md)

`./bin/flixbox` es el único entrypoint de operador. Phase A agrega descubribilidad (`version`, `--help` por comando), diagnóstico (`doctor`) y `status --json` para scripts, más una taxonomía estable de códigos de salida en esas rutas.

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

Requiere **Bash 4+**. Las completions llegan en Phase B.

## Flags globales

| Flag | Comportamiento |
| --- | --- |
| `-h` / `--help` | Lista de comandos de nivel superior |
| `--version` | Igual que `version` |
| `-h` / `--help` por comando | Uso específico del comando (`status`, `doctor`, `version`, …) |

`--json`, `-q` / `--quiet` aplican a los comandos que los documentan (`status`, `doctor`).

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

`--json` emite un solo objeto con `schemaVersion: 1`. Nunca incluye valores de keys.

### `flixbox status [--json] [-q|--quiet]`

Humano: `docker compose ps` más modo / perfil de acceso / paths.  
`--json`: vista de servicios + contexto; si Docker está caído, igual imprime JSON con `error` y sale **3**.  
`-q`: suprime líneas informativas humanas; los warnings siguen en stderr.

## I/O de seguridad

- `version`, `doctor` y `status` nunca imprimen passwords ni valores de API keys.
- Usa `credentials show` cuando intencionalmente necesites un secreto en stdout.
- No pases secretos como argv de CLI a los helpers.

## Checklist manual

1. `./bin/flixbox version` → exit 0  
2. `./bin/flixbox nosuch` → exit 2  
3. `./bin/flixbox status --help` → exit 0  
4. `./bin/flixbox doctor` en un host configurado → hints accionables; exit 0 cuando esté listo  
5. `./bin/flixbox status --json | jq .schemaVersion` → `1` cuando Docker funciona  

## Diferido (Phase B+)

`backup` / `restore` / `update` / `recyclarr sync` / completions de shell / migración completa `die`→taxonomía — ver [08-roadmap.md](../../08-roadmap.md).
