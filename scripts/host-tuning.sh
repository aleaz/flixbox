#!/usr/bin/env bash
# Raise common Linux limits for large media libraries (optional; needs root).
set -euo pipefail

CONF=/etc/sysctl.d/99-flixbox.conf

if [[ "${EUID}" -ne 0 ]]; then
  echo "Re-run with sudo to write ${CONF}" >&2
  exit 1
fi

cat >"${CONF}" <<'EOF'
# Flixbox host tuning
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF

sysctl --system >/dev/null
echo "Wrote ${CONF} and applied sysctl."
