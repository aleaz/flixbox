#!/usr/bin/env bash
# Shell completions for flixbox (ADR 0021). Sourced from bin/flixbox.
# MUST NOT shell out to credentials show or embed secrets.

flixbox_completion_bash() {
  cat <<'EOF'
# flixbox bash completion — source from ~/.bashrc
_flixbox_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local cmd="${COMP_WORDS[1]:-}"
  local cmds="version doctor status logs vpn-test init up down restart reload homepage configure credentials backup restore update recyclarr sync-profiles completion help"
  local profiles="plex proxy recyclarr"

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${cmds}" -- "${cur}") )
    return
  fi

  case "${cmd}" in
    status)
      COMPREPLY=( $(compgen -W "--json -q --quiet -v --verbose -h --help" -- "${cur}") )
      ;;
    doctor)
      COMPREPLY=( $(compgen -W "--json -h --help" -- "${cur}") )
      ;;
    backup)
      COMPREPLY=( $(compgen -W "--include-env --stop -h --help" -- "${cur}") )
      ;;
    restore)
      COMPREPLY=( $(compgen -W "--force -h --help" -- "${cur}") )
      ;;
    update|up|reload)
      COMPREPLY=( $(compgen -W "--dry-run -h --help ${profiles} --profile" -- "${cur}") )
      ;;
    configure)
      COMPREPLY=( $(compgen -W "--dry-run --verbose --sync-qbit-auth --sync-arr-ui -h --help" -- "${cur}") )
      ;;
    credentials)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "show set -h --help" -- "${cur}") )
      elif [[ ${COMP_WORDS[2]} == show || ${COMP_WORDS[2]} == set ]]; then
        COMPREPLY=( $(compgen -W "qbit arr-ui admin api -h --help --generate --prompt" -- "${cur}") )
      fi
      ;;
    recyclarr)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "sync -h --help" -- "${cur}") )
      else
        COMPREPLY=( $(compgen -W "--dry-run -h --help" -- "${cur}") )
      fi
      ;;
    sync-profiles)
      COMPREPLY=( $(compgen -W "--dry-run -h --help" -- "${cur}") )
      ;;
    homepage)
      if [[ ${COMP_CWORD} -eq 2 ]]; then
        COMPREPLY=( $(compgen -W "refresh -h --help" -- "${cur}") )
      else
        COMPREPLY=( $(compgen -W "--dry-run -h --help" -- "${cur}") )
      fi
      ;;
    completion)
      COMPREPLY=( $(compgen -W "bash zsh -h --help" -- "${cur}") )
      ;;
    logs|restart)
      COMPREPLY=( $(compgen -W "-h --help -f" -- "${cur}") )
      ;;
    *)
      COMPREPLY=( $(compgen -W "-h --help" -- "${cur}") )
      ;;
  esac
}
complete -F _flixbox_completions flixbox
EOF
}

flixbox_completion_zsh() {
  cat <<'EOF'
# flixbox zsh completion — add to fpath or source from ~/.zshrc
#compdef flixbox

_flixbox() {
  local -a cmds profiles
  cmds=(
    'version:CLI identity'
    'doctor:Readiness checks'
    'status:Health glance'
    'logs:Tail logs'
    'vpn-test:VPN egress check'
    'init:Create .env and dirs'
    'up:Start stack'
    'down:Stop stack'
    'restart:Restart one service'
    'reload:Recreate after .env/compose changes'
    'homepage:Homepage template refresh'
    'configure:Idempotent API wiring'
    'credentials:Show or set operator secrets'
    'backup:Archive CONFIG_DIR'
    'restore:Restore CONFIG archive'
    'update:Pull pinned images and reconcile'
    'recyclarr:Recyclarr sync'
    'sync-profiles:Alias for recyclarr sync'
    'completion:Print shell completion script'
    'help:Show help'
  )
  profiles=(plex proxy recyclarr)

  _arguments -C \
    '1:command:->cmds' \
    '*::arg:->args'

  case $state in
    cmds)
      _describe -t commands 'flixbox command' cmds
      ;;
    args)
      case $words[1] in
        status)
          _arguments '--json' '-q' '--quiet' '-v' '--verbose' '-h' '--help'
          ;;
        doctor)
          _arguments '--json' '-h' '--help'
          ;;
        backup)
          _arguments '--include-env' '--stop' '-h' '--help' '*:dest dir:_files -/'
          ;;
        restore)
          _arguments '--force' '-h' '--help' '*:archive:_files'
          ;;
        update|up|reload)
          _arguments '--dry-run' '-h' '--help' '--profile:profile:(plex proxy recyclarr)' '*:profile:(plex proxy recyclarr)'
          ;;
        configure)
          _arguments '--dry-run' '--verbose' '--sync-qbit-auth' '--sync-arr-ui' '-h' '--help'
          ;;
        credentials)
          _arguments '1:action:(show set)' '2:target:(qbit arr-ui admin api)' '--generate' '--prompt' '-h' '--help'
          ;;
        recyclarr)
          _arguments '1:action:(sync)' '--dry-run' '-h' '--help'
          ;;
        sync-profiles)
          _arguments '--dry-run' '-h' '--help'
          ;;
        homepage)
          _arguments '1:action:(refresh)' '--dry-run' '-h' '--help'
          ;;
        completion)
          _arguments '1:shell:(bash zsh)' '-h' '--help'
          ;;
        *)
          _arguments '-h' '--help'
          ;;
      esac
      ;;
  esac
}

_flixbox "$@"
EOF
}
