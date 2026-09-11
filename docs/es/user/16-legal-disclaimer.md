# Aviso legal y uso aceptable

**Estado:** Aviso canónico para operadores  
**Idiomas:** [English](../../user/16-legal-disclaimer.md) · Español (esta página)  
**Ver también:** [Licencia MIT](../../../LICENSE) · [Overview (EN)](../../user/01-overview.md) · [Privacidad BitTorrent (EN)](../../user/12-torrent-privacy-and-security.md)

> **Esto no es asesoramiento jurídico.** Es un aviso del proyecto, no el consejo de un abogado. Las leyes cambian según el lugar y el tiempo.

**Registro:** español neutro (tuteo estándar). No se usa voseo rioplatense.

## Posición central

**Flixbox es un ensamblador, no el fabricante de las apps.**  
Empaqueta y conecta proyectos de **terceros** ya existentes (por ejemplo Gluetun, qBittorrent, Prowlarr, Radarr, Sonarr, Jellyfin, Seerr) con Docker Compose y una CLI Bash. **No** desarrolla esas aplicaciones.

**Uso bajo tu propio riesgo.** En la máxima medida permitida por la ley:

- **Tú** ejecutas el stack en tus equipos, con tu configuración, indexers, VPN y elección de contenido.
- **Tú** eres el único responsable de cómo usas Flixbox y cada herramienta upstream que inicia.
- Los autores y contribuidores de Flixbox **declinan responsabilidad** por uso indebido, descargas o compartidos ilícitos, incumplimientos de ToS, avisos del ISP, multas, reclamaciones civiles u otras consecuencias de tu uso.
- Los autores de Flixbox **no están afiliados** a los proyectos upstream nombrados en este repositorio y **no** hablan en su nombre.

Si no aceptas esa asignación de riesgo, **no** descargues, instales ni ejecutes Flixbox.

## Aviso corto (misma sustancia que el README)

Los autores **no aprueban** la infracción de derechos de autor ni otros usos ilícitos, y **no** pretenden inducirlos. Flixbox publica **pegamento de orquestación** (Compose, scripts, docs): no archivos de medios ni un cliente BitTorrent o servidor *arr/media escrito aquí. El cumplimiento de la ley y de los términos de terceros corre **solo** por cuenta del operador. El software se ofrece **TAL CUAL (*AS IS*)** bajo la [Licencia MIT](../../../LICENSE).

## 1. Qué es Flixbox (y qué no es)

| Flixbox **es** | Flixbox **no es** |
| --- | --- |
| Una capa de conveniencia para desplegar y conectar herramientas self-hosted conocidas | El desarrollador o proveedor de qBittorrent, Radarr, Sonarr, Prowlarr, Jellyfin, Seerr, Gluetun, etc. |
| Empaquetado y automatización local que tú eliges ejecutar | Un servicio de descargas alojado, indexer, tracker, CDN o depósito de medios |
| Herramienta de doble uso para una biblioteca que **tú** controlas | Asesoramiento legal, ni una promesa de que una descarga sea lícita |
| Documentación para operadores con Docker | Una promoción de piratería o distribución no autorizada |

Flixbox **no** incluye credenciales de indexers, listas de magnets, directorios pirate ni medios con copyright. Las fuentes las agregas tú después de instalar.

## 2. Sin responsabilidad por el uso de las herramientas

En la máxima medida permitida por la ley aplicable, los autores de Flixbox:

1. **No tienen deber de supervisar** lo que pides, descargas, guardas, compartes, siembras o reproduces.  
2. **No responden por aplicaciones upstream** (errores, seguridad, cambios de política o cómo ejecutas sus imágenes).  
3. **No responden por contenido o indexers** que configures tú.  
4. **No responden por consecuencias legales o del ISP** de operar el stack.  
5. Solo otorgan derechos según la [Licencia MIT](../../../LICENSE); este aviso **no** agrega obligaciones más allá de esa licencia.

Donde la ley local prohíba excluir cierta responsabilidad, estos límites aplican solo hasta donde esa ley lo permita. Nada aquí excluye responsabilidad que no pueda excluirse legalmente.

## 3. Doble uso; sin inducción

Los clientes BitTorrent, las aplicaciones *arr, los portales de solicitudes y los servidores de medios son de **doble uso**. Existen usos lícitos (por ejemplo organizar medios que posees o estás autorizado a usar, dominio público, streaming self-hosted permitido). También existen usos ilícitos.

Los autores de Flixbox:

- Publican un ensamble **capaz de usos sustanciales no infractores**.
- **No** alientan ni instruyen la infracción de copyright como propósito del proyecto.
- **No** afirman que el modo VPN, Direct o las ayudas de bypass hagan lícita la copia no autorizada.
- **No** operan indexers públicos, trackers ni alojamiento de medios para quienes usan este repositorio.
- **No** ayudan con solicitudes orientadas a obtener contenido con copyright sin autorización (ver §6).

**Si tu uso es lícito lo decides tú** según las leyes que te aplican. Este proyecto no lo decide por ti.

## 4. Tus responsabilidades

Si instalas o ejecutas Flixbox, **solo tú** eres responsable de:

1. El contenido que pides, descargas, importas, almacenas, reproduces, compartes o siembras.  
2. Los derechos o licencias exigidos en tu jurisdicción.  
3. Los términos de indexers, trackers, VPN, registros, APIs de metadatos e ISPs que uses.  
4. Quién puede acceder a las interfaces de administración en tu LAN ([Access profiles (EN)](../../user/13-access-profiles.md)) y el uso de invitados en Seerr/Jellyfin.  
5. Copias de seguridad, mala configuración, reglas de Decluttarr/Maintainerr que actives y exponer interfaces web a Internet.

## 5. Sin garantía; privacidad ≠ permiso

Bajo la [Licencia MIT](../../../LICENSE), Flixbox se ofrece **TAL CUAL (*AS IS*)**, sin garantía de ningún tipo. Los autores no responden por reclamaciones o daños derivados del software o de su uso, incluido el uso de componentes de terceros que conecta.

[Torrent privacy and security (EN)](../../user/12-torrent-privacy-and-security.md) y el modo VPN son solo controles **técnicos**. No autorizan infracción, no garantizan anonimato ni sustituyen el cumplimiento de la ley.

## 6. Tono de la documentación y límites de soporte

La documentación describe solicitar → descargar → biblioteca → reproducir porque así se conectan las aplicaciones **upstream**. Esa descripción de arquitectura **no** es una instrucción para infringir copyright y **no** implica que los autores de Flixbox asuman responsabilidad por tus elecciones de contenido.

**No** uses issues o discusiones de GitHub para pedir índices pirate, claves pirateadas o ayuda para obtener material con copyright sin autorización. Esas solicitudes pueden cerrarse sin asistencia.

## 7. Solo problemas de este repositorio

Si **este repositorio git** aloja archivos de medios infractores (no debería: publica código, plantillas y documentación), contacta al mantenedor del repositorio. Ese canal trata del contenido del repositorio, no de cómo otras personas usan herramientas en sus equipos.

---

**Relacionado:** [Overview — Disclaimer (EN)](../../user/01-overview.md#disclaimer) · [Vision — Non-goals (EN)](../../00-vision.md#non-goals-product-level) · [README.es — Aviso legal](../../../README.es.md#aviso-legal)
