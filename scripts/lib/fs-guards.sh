#!/usr/bin/env bash
# Filesystem guards for doctor/init (hardlink, NFS/SMB, exFAT, WSL NTFS).
# Sourced from bin/flixbox — do not execute directly.
# Globals below are read by cmd_doctor after calling guard helpers.
# shellcheck disable=SC2034

# Print filesystem type for path (best-effort). Empty if unknown.
flixbox_fs_type() {
  local path="$1" fst=""
  [[ -e "$path" || -d "$path" ]] || return 0
  if command -v findmnt >/dev/null 2>&1; then
    fst="$(findmnt -n -o FSTYPE --target "$path" 2>/dev/null || true)"
  fi
  if [[ -z "$fst" ]]; then
    fst="$(df -T "$path" 2>/dev/null | awk 'NR==2 { print $2 }' || true)"
  fi
  printf '%s' "$fst"
}

flixbox_fs_is_remote() {
  local t="${1,,}"
  case "$t" in
    nfs|nfs4|nfs3|cifs|smb|smb3|fuse.sshfs|fuse.davfs|9p|afs) return 0 ;;
  esac
  return 1
}

flixbox_fs_is_exfat() {
  local t="${1,,}"
  case "$t" in
    exfat|fuseexfat|fuse.exfat) return 0 ;;
  esac
  return 1
}

flixbox_fs_is_mergerfs() {
  local t="${1,,}"
  case "$t" in
    fuse.mergerfs|mergerfs) return 0 ;;
  esac
  return 1
}

flixbox_path_is_wsl_ntfs() {
  local path="$1"
  [[ "$path" == /mnt/c/* || "$path" == /mnt/d/* || "$path" == /mnt/e/* ]]
}

# Hardlink probe under dir. Sets FLIXBOX_HARDLINK_PROBE=ok|fail|skipped
# and optional FLIXBOX_HARDLINK_DETAIL.
flixbox_probe_hardlink() {
  local root="$1"
  local probe_dir a b
  FLIXBOX_HARDLINK_PROBE=skipped
  FLIXBOX_HARDLINK_DETAIL=""

  [[ -n "$root" && -d "$root" ]] || {
    FLIXBOX_HARDLINK_PROBE=skipped
    FLIXBOX_HARDLINK_DETAIL="directory missing"
    return 0
  }
  if [[ ! -w "$root" ]]; then
    FLIXBOX_HARDLINK_PROBE=skipped
    FLIXBOX_HARDLINK_DETAIL="not writable"
    return 0
  fi

  probe_dir="${root}/.flixbox-probe"
  mkdir -p "$probe_dir" 2>/dev/null || {
    FLIXBOX_HARDLINK_PROBE=skipped
    FLIXBOX_HARDLINK_DETAIL="cannot create probe dir"
    return 0
  }
  a="${probe_dir}/a.$$"
  b="${probe_dir}/b.$$"

  if ! printf 'x' >"$a" 2>/dev/null; then
    FLIXBOX_HARDLINK_PROBE=skipped
    FLIXBOX_HARDLINK_DETAIL="cannot write probe file"
    return 0
  fi
  if ln "$a" "$b" 2>/dev/null; then
    FLIXBOX_HARDLINK_PROBE=ok
    FLIXBOX_HARDLINK_DETAIL=""
    rm -f -- "$a" "$b" 2>/dev/null || true
    rmdir "$probe_dir" 2>/dev/null || true
    return 0
  fi
  FLIXBOX_HARDLINK_PROBE=fail
  FLIXBOX_HARDLINK_DETAIL="ln failed (EXDEV/EPERM or unsupported FS)"
  rm -f -- "$a" "$b" 2>/dev/null || true
  rmdir "$probe_dir" 2>/dev/null || true
  return 0
}

# Evaluate DATA_DIR layout. Sets:
#   FLIXBOX_DATA_FS_TYPE, FLIXBOX_DATA_FS_STATUS=ok|fail|warn
#   FLIXBOX_DATA_FS_DETAIL, FLIXBOX_HARDLINK_*
# Returns 1 if hard fail, 0 otherwise.
flixbox_guard_data_dir() {
  local path="$1"
  local fst
  FLIXBOX_DATA_FS_TYPE=""
  FLIXBOX_DATA_FS_STATUS=ok
  FLIXBOX_DATA_FS_DETAIL=""

  fst="$(flixbox_fs_type "$path")"
  FLIXBOX_DATA_FS_TYPE="$fst"

  if flixbox_path_is_wsl_ntfs "$path"; then
    FLIXBOX_DATA_FS_STATUS=fail
    FLIXBOX_DATA_FS_DETAIL="WSL NTFS mount (/mnt/c|d) — keep DATA_DIR on ext4 (docs/user/03-requirements.md)"
    flixbox_probe_hardlink "$path"
    return 1
  fi

  if flixbox_fs_is_exfat "$fst"; then
    FLIXBOX_DATA_FS_STATUS=fail
    FLIXBOX_DATA_FS_DETAIL="exFAT (${fst}) cannot hardlink — docs/user/03-requirements.md · docs/07-operations-risks.md §1.4"
    FLIXBOX_HARDLINK_PROBE=fail
    FLIXBOX_HARDLINK_DETAIL="exFAT"
    return 1
  fi

  if [[ -z "$fst" && "$path" == *exfat* ]]; then
    FLIXBOX_DATA_FS_STATUS=warn
    FLIXBOX_DATA_FS_DETAIL="path name suggests exFAT; confirm FS type"
  fi

  if flixbox_fs_is_mergerfs "$fst"; then
    if [[ "$FLIXBOX_DATA_FS_STATUS" == ok ]]; then
      FLIXBOX_DATA_FS_STATUS=warn
      FLIXBOX_DATA_FS_DETAIL="MergerFS detected — use path-preserving policy (docs/07-operations-risks.md §4.1)"
    fi
  fi

  flixbox_probe_hardlink "$path"
  if [[ "$FLIXBOX_HARDLINK_PROBE" == fail ]]; then
    FLIXBOX_DATA_FS_STATUS=fail
    FLIXBOX_DATA_FS_DETAIL="hardlink probe failed — ${FLIXBOX_HARDLINK_DETAIL} (docs/adr/0001 · docs/user/02-how-it-works.md)"
    return 1
  fi
  if [[ "$FLIXBOX_HARDLINK_PROBE" == skipped && "$FLIXBOX_DATA_FS_STATUS" == ok ]]; then
    FLIXBOX_DATA_FS_STATUS=warn
    FLIXBOX_DATA_FS_DETAIL="hardlink probe skipped (${FLIXBOX_HARDLINK_DETAIL:-unknown})"
  fi
  [[ "$FLIXBOX_DATA_FS_STATUS" == fail ]] && return 1
  return 0
}

# Evaluate CONFIG_DIR layout. Sets FLIXBOX_CONFIG_FS_*.
# Returns 1 if hard fail (clear remote FS), 0 otherwise.
flixbox_guard_config_dir() {
  local path="$1"
  local fst
  FLIXBOX_CONFIG_FS_TYPE=""
  FLIXBOX_CONFIG_FS_STATUS=ok
  FLIXBOX_CONFIG_FS_DETAIL=""

  fst="$(flixbox_fs_type "$path")"
  FLIXBOX_CONFIG_FS_TYPE="$fst"

  if flixbox_path_is_wsl_ntfs "$path"; then
    FLIXBOX_CONFIG_FS_STATUS=fail
    FLIXBOX_CONFIG_FS_DETAIL="WSL NTFS mount — SQLite config needs Linux FS (docs/user/03-requirements.md)"
    return 1
  fi

  if flixbox_fs_is_remote "$fst"; then
    FLIXBOX_CONFIG_FS_STATUS=fail
    FLIXBOX_CONFIG_FS_DETAIL="remote FS (${fst}) unsafe for SQLite — docs/07-operations-risks.md §4.2"
    return 1
  fi

  if [[ -z "$fst" ]]; then
    FLIXBOX_CONFIG_FS_STATUS=warn
    FLIXBOX_CONFIG_FS_DETAIL="could not detect FS type — prefer local SSD/NVMe for CONFIG_DIR"
  fi
  return 0
}
