#!/usr/bin/env bash
# Ágape como navegador del sistema (Firefox se queda de reserva)
set -euo pipefail
for f in /usr/share/applications/mimeapps.list /etc/xdg/mimeapps.list; do
  [ -f "$f" ] || continue
  sed -i -E 's#^(text/html|application/xhtml\+xml|x-scheme-handler/https?)=.*#\1=ares.desktop;org.mozilla.firefox.desktop;#' "$f"
done
grep -h 'x-scheme-handler/https=' /usr/share/applications/mimeapps.list /etc/xdg/mimeapps.list || true
