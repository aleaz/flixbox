#!/usr/bin/env bash
# CLI lifecycle helpers (ADR 0021 Phase B). Sourced from bin/flixbox — do not execute directly.

cmd_backup() {
  if flixbox_wants_help "$@"; then
    cat <<'EOF'
Usage: flixbox backup [--include-env] [--stop] [DEST_DIR]

Archive ${CONFIG_DIR} (app SQLite / Homepage live config). Does NOT include
${DATA_DIR} (media, torrents, incomplete) — back up library data yourself
(rsync, snapshots, NAS). Optional .env via --include-env (sensitive).

Options:
  --include-env   Also archive repo .env (off by default; store like a secret)
  --stop          Stop the stack during tar for cleaner SQLite WAL (restart after)
  DEST_DIR        Output directory (default: <repo>/backups)
  -h, --help      Show this help

Exit codes: 0 success · 2 usage · 3 Docker · 4 config
Docs: docs/user/17-cli.md · ADR 0021
EOF
    return 0
  fi
  local include_env=0 stop=0 dest="" out rc=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --include-env) include_env=1; shift ;;
      --stop|-s) stop=1; shift ;;
      -h|--help) die_usage "backup: use flixbox backup --help" ;;
      -*) die_usage "backup: unknown option: $1 (try --help)" ;;
      *)
        [[ -z "$dest" ]] || die_usage "backup: unexpected argument: $1"
        dest="$1"
        shift
        ;;
    esac
  done

  load_env
  out="$(flixbox_backup_create "${dest:-${ROOT_DIR}/backups}" "$include_env" "$stop")" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    exit "$rc"
  fi
  cli_configure_line backup updated "archive ${out}"
  cli_info "DATA_DIR was not included — back up media separately if needed"
}

cmd_restore() {
  if flixbox_wants_help "$@"; then
    cat <<'EOF'
Usage: flixbox restore <archive.tar.gz> [--force]

Restore a Flixbox CONFIG archive into ${CONFIG_DIR}. Refuses to overwrite an
existing config tree without --force. Does NOT restore ${DATA_DIR} media.

Options:
  --force       Overwrite existing ${CONFIG_DIR} contents (and .env if present in archive)
  -h, --help    Show this help

Exit codes: 0 success · 2 usage (including missing --force) · 3 Docker · 4 config
Docs: docs/user/17-cli.md · ADR 0021
EOF
    return 0
  fi
  local force=0 archive="" rc=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=1; shift ;;
      -h|--help) die_usage "restore: use flixbox restore --help" ;;
      -*) die_usage "restore: unknown option: $1 (try --help)" ;;
      *)
        [[ -z "$archive" ]] || die_usage "restore: unexpected argument: $1"
        archive="$1"
        shift
        ;;
    esac
  done
  [[ -n "$archive" ]] || die_usage "restore: missing archive path (try --help)"

  load_env
  flixbox_restore_apply "$archive" "$force" || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    exit "$rc"
  fi
  cli_configure_line restore updated "CONFIG_DIR ${CONFIG_DIR}"
  cli_info "DATA_DIR was not restored — media remains operator-owned"
}

cmd_update() {
  if flixbox_wants_help "$@"; then
    cat <<'EOF'
Usage: flixbox update [--dry-run] [plex|proxy|recyclarr]...

Pull pinned image tags (ADR 0010) and reconcile containers with
`compose up -d --remove-orphans`. Never rewrites compose pins to :latest —
bump tags via docs/user/14-image-pins.md, then run update.

Optional profiles match `flixbox up` (also --profile NAME). Sticky
COMPOSE_PROFILES in .env are honored by Compose automatically.

Options:
  --dry-run     List pinned images only; do not pull or recreate
  -h, --help    Show this help

Exit codes: 0 success · 2 usage · 3 Docker · 4 config
Docs: docs/user/17-cli.md · docs/user/14-image-pins.md · ADR 0021
EOF
    return 0
  fi
  local dry_run=0
  local -a rest=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      -h|--help) die_usage "update: use flixbox update --help" ;;
      *)
        rest+=("$1")
        shift
        ;;
    esac
  done

  assert_docker_accessible
  load_env
  local profiles=()
  parse_profiles profiles "${rest[@]+"${rest[@]}"}"
  warn_legacy_socket_proxy_profile || true

  local rc=0
  flixbox_update_run "$dry_run" "${profiles[@]+"${profiles[@]}"}" || rc=$?
  [[ "$rc" -eq 0 ]] || exit "$rc"
}

cmd_recyclarr() {
  if flixbox_wants_help "$@" || [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    cat <<'EOF'
Usage: flixbox recyclarr sync [--dry-run]
       flixbox sync-profiles [--dry-run]    # alias

Run Recyclarr against the stack (Compose profile recyclarr). Explicit sync only.
Requires ${CONFIG_DIR}/recyclarr/recyclarr.yml (from init/templates).

Options:
  --dry-run     Pass --dry-run to Recyclarr (preview; no profile writes)
  -h, --help    Show this help

Exit codes: 0 success · 2 usage · 3 Docker · 4 config · 5 dependency
Docs: docs/user/17-cli.md · ADR 0021
EOF
    return 0
  fi
  local sub="${1:-}"
  [[ -n "$sub" ]] || die_usage "recyclarr: missing subcommand (try: sync or --help)"
  shift || true
  case "$sub" in
    sync)
      local dry_run=0
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run=1; shift ;;
          -h|--help) die_usage "recyclarr sync: use flixbox recyclarr --help" ;;
          -*) die_usage "recyclarr sync: unknown option: $1 (try --help)" ;;
          *) die_usage "recyclarr sync: unexpected argument: $1" ;;
        esac
      done
      assert_docker_accessible
      load_env
      local rc=0
      flixbox_recyclarr_sync "$dry_run" || rc=$?
      [[ "$rc" -eq 0 ]] || exit "$rc"
      ;;
    *) die_usage "Unknown recyclarr subcommand: ${sub} (try: sync or --help)" ;;
  esac
}

cmd_sync_profiles() {
  # Alias → recyclarr sync (ADR 0021).
  cmd_recyclarr sync "$@"
}

cmd_completion() {
  if flixbox_wants_help "$@" || [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    cat <<'EOF'
Usage: flixbox completion bash|zsh

Print a shell completion script to stdout (source it from your rc file).
Completions MUST NOT reveal secrets (never shell out to credentials show).

Examples:
  # bash
  ./bin/flixbox completion bash > ~/.local/share/bash-completion/completions/flixbox
  # or: eval "$(./bin/flixbox completion bash)"

  # zsh
  ./bin/flixbox completion zsh > "${fpath[1]}/_flixbox"
  # then: compinit

Options:
  -h, --help    Show this help

Docs: docs/user/17-cli.md · ADR 0021
EOF
    return 0
  fi
  local shell="${1:-}"
  [[ -n "$shell" ]] || die_usage "completion: missing shell (bash|zsh) — try --help"
  case "$shell" in
    bash) flixbox_completion_bash ;;
    zsh) flixbox_completion_zsh ;;
    fish) die_usage "completion: fish is deferred; use bash or zsh" ;;
    -*) die_usage "completion: unknown option: $shell (try --help)" ;;
    *) die_usage "completion: unsupported shell: ${shell} (bash|zsh)" ;;
  esac
}
