#!/bin/bash
# Pasa un CachyOS (edición KDE Plasma) a Apogeo: añade el repositorio firmado de Apogeo e instala el paquete «apogeo».
#   curl -fsSL https://raw.githubusercontent.com/4R3S10/apogeo/main/instalar.sh | sudo bash
set -euo pipefail
REPO=https://github.com/4R3S10/apogeo
CLAVE=DF948BE0F005C7C6101BF9607CF246C5627C09B2
[ "$(id -u)" -eq 0 ] || { echo "Hay que ejecutarlo con sudo"; exit 1; }
grep -q '^ID=cachyos' /usr/lib/os-release 2>/dev/null || grep -q '^ID_LIKE=.*arch' /usr/lib/os-release \
  || { echo "Apogeo se instala sobre CachyOS"; exit 1; }

echo ">>> Clave de firma de Apogeo"
tmp=$(mktemp)
curl -fsSL https://raw.githubusercontent.com/4R3S10/apogeo/main/apogeo.asc -o "$tmp"
pacman-key --add "$tmp"
pacman-key --lsign-key "$CLAVE"
rm -f "$tmp"

if ! grep -q '^\[apogeo\]' /etc/pacman.conf; then
  echo ">>> Repositorio de Apogeo"
  printf '\n# Apogeo (%s)\n[apogeo]\nServer = %s/releases/download/repo\n' "$REPO" "$REPO" >> /etc/pacman.conf
fi

echo ">>> Instalando Apogeo"
pacman -Syu --needed apogeo </dev/tty
