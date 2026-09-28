#!/usr/bin/env bash
# Pone el nombre de Apogeo sin tocar el ID del sistema (Bazzite y Fedora lo usan para sus actualizaciones)
set -euo pipefail
f=/usr/lib/os-release
sed -i \
  -e 's/^PRETTY_NAME=.*/PRETTY_NAME="Apogeo"/' \
  -e 's/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="apogeo"/' \
  "$f"
grep -q '^VARIANT=' "$f" && sed -i 's/^VARIANT=.*/VARIANT="Apogeo"/' "$f" || echo 'VARIANT="Apogeo"' >> "$f"
grep -q '^DEFAULT_HOSTNAME=' "$f" || echo 'DEFAULT_HOSTNAME="apogeo"' >> "$f"
# Logo (el diamante): lo usan «Acerca de este sistema» y otras pantallas
grep -q '^LOGO=' "$f" && sed -i 's/^LOGO=.*/LOGO=apogeo/' "$f" || echo 'LOGO=apogeo' >> "$f"
