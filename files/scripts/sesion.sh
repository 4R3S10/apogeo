#!/usr/bin/env bash
# Inicio de sesión con SDDM y el tema de Apogeo (el de Plasma no deja cambiar su diseño)
set -euo pipefail
systemctl disable plasmalogin.service || true
rm -f /etc/systemd/system/display-manager.service
systemctl enable sddm.service
# Solo se ofrecen las sesiones de Apogeo (una por piso); la de Plasma normal sigue existiendo por si acaso
echo "Inicio de sesión: SDDM con el tema de Apogeo"
