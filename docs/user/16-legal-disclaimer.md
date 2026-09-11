# Legal disclaimer and acceptable use

**Status:** Canonical operator notice  
**Languages:** English (this page) · [Español](../es/user/16-legal-disclaimer.md)  
**Also see:** [MIT License](../../LICENSE) · [Overview](01-overview.md) · [Torrent privacy](12-torrent-privacy-and-security.md)

> **Not legal advice.** This is a project notice, not advice from a lawyer. Laws vary by place and over time.

## Core position

**Flixbox is an assembler, not an app vendor.**  
It packages and wires **existing** third-party projects (for example Gluetun, qBittorrent, Prowlarr, Radarr, Sonarr, Jellyfin, Seerr) with Docker Compose and a Bash CLI. It does **not** develop those applications.

**Use at your own risk.** To the maximum extent permitted by law:

- **You** run the stack on your machines, with your config, indexers, VPN, and content choices.
- **You** are solely responsible for how you use Flixbox and every upstream tool it starts.
- The Flixbox authors and contributors **disclaim responsibility** for misuse, unlawful downloading or sharing, ToS breaches, ISP notices, fines, civil claims, or other outcomes of your use.
- Flixbox authors are **not affiliated with**, and are **not** speaking for, the upstream projects named in this repo.

If you do not accept that allocation of risk, do **not** download, install, or run Flixbox.

## Short notice (same substance as the README)

The authors **do not condone** copyright infringement or other unlawful use, and **do not** intend to induce it. Flixbox ships **orchestration glue** (Compose, scripts, docs) — not media files and not a new BitTorrent client or *arr/media server written here. Operators alone must comply with applicable law and third-party terms. Software is **AS IS** under the [MIT License](../../LICENSE).

## 1. What Flixbox is (and is not)

| Flixbox **is** | Flixbox **is not** |
| --- | --- |
| A convenience layer to deploy and connect known self-hosted tools | The developer or vendor of qBittorrent, Radarr, Sonarr, Prowlarr, Jellyfin, Seerr, Gluetun, etc. |
| Local packaging and automation you choose to run | A hosted download service, indexer, tracker, CDN, or media warehouse |
| Dual-use tooling for a library **you** control | Legal advice, or a promise that any given download is lawful |
| Docs for Docker-capable operators | An endorsement of piracy or unauthorized distribution |

Flixbox does **not** ship indexer credentials, magnet lists, pirate directories, or copyrighted media. You add sources after install.

## 2. No liability for how the tools are used

To the maximum extent permitted by applicable law, Flixbox authors:

1. Have **no duty to supervise** what you request, download, store, share, seed, or stream.  
2. Have **no liability for upstream apps** (bugs, security, policy changes, or how you run their images).  
3. Have **no liability for content or indexers** you configure yourself.  
4. Have **no liability for legal or ISP outcomes** of your operation of the stack.  
5. Grant rights only as stated in the [MIT License](../../LICENSE); this notice does **not** add duties beyond that license.

Where local law forbids excluding certain liability, these limits apply only as far as that law allows. Nothing here excludes liability that cannot legally be excluded.

## 3. Dual-use; no inducement

BitTorrent clients, *arr apps, request UIs, and media servers are **dual-use**. Lawful uses exist (for example organizing media you own or are licensed to use, public-domain works, self-hosted streaming you are allowed to do). Unlawful uses also exist.

Flixbox authors:

- Publish an assembly **capable of substantial non-infringing use**.
- **Do not** encourage or instruct copyright infringement as a project purpose.
- **Do not** claim that VPN mode, Direct mode, or bypass helpers make unauthorized copying lawful.
- **Do not** run public indexers, trackers, or media hosting for users of this repository.
- **Do not** help with requests aimed at obtaining unauthorized copyrighted content (see §6).

**Whether your use is lawful is your call** under the laws that apply to you. This project does not decide that for you.

## 4. Your responsibilities

If you install or run Flixbox, **you alone** are responsible for:

1. Content you request, download, import, store, stream, share, or seed.  
2. Rights or licenses required in your jurisdiction.  
3. Terms of indexers, trackers, VPNs, registries, metadata APIs, and ISPs you use.  
4. Who can reach admin UIs on your LAN ([Access profiles](13-access-profiles.md)) and guest use of Seerr/Jellyfin.  
5. Backups, misconfiguration, Decluttarr/Maintainerr rules you enable, and exposing WebUIs to the internet.

## 5. No warranty; privacy ≠ permission

Under the [MIT License](../../LICENSE), Flixbox is provided **AS IS**, without warranty of any kind. Authors are not liable for claims or damages arising from the software or its use, including use of wired third-party components.

[Torrent privacy and security](12-torrent-privacy-and-security.md) and VPN mode are **technical** controls only. They do not authorize infringement, guarantee anonymity, or replace following the law.

## 6. Docs tone and support limits

Docs describe request → download → library → stream because that is how the **upstream** apps connect. That architecture description is **not** an instruction to infringe copyright and **not** an assumption of responsibility for your content choices.

Do **not** use GitHub issues or discussions to ask for pirate indexes, cracked keys, or help obtaining unauthorized copyrighted material. Those requests may be closed without help.

## 7. Issues with this repository only

If **this git repository** itself hosts infringing media files (it should not: it ships code, templates, and docs), contact the maintainer on the repo. That channel is about repository contents — not about how other people run tools on their own machines.

---

**Related:** [Overview — Disclaimer](01-overview.md#disclaimer) · [Vision — Non-goals](../00-vision.md#non-goals-product-level) · [README Disclaimer](../../README.md#disclaimer)
