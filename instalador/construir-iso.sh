#!/bin/bash
# Construye el USB de Apogeo (en Arch, como root): construir-iso.sh <paquete apogeo-*.pkg.tar.zst> [carpeta de salida]
# Copia el perfil (instalador/perfil) a una carpeta de trabajo fuera del proyecto, le pone el instalador y, del paquete
# de Apogeo, las piezas de Órbita que usa (el módulo QML, la letra, el logo y el sombreador del fondo), y llama a mkarchiso.
set -euo pipefail
RAIZ=$(cd "$(dirname "$0")/.." && pwd)
PAQUETE=$1
TRABAJO=${TRABAJO:-/tmp/apogeo-iso}
SALIDA=${2:-$TRABAJO/salida}
rm -rf "$TRABAJO/perfil" "$TRABAJO/w" "$TRABAJO/apogeo"
mkdir -p "$TRABAJO/apogeo" "$SALIDA"
cp -a "$RAIZ/instalador/perfil" "$TRABAJO/perfil"
A="$TRABAJO/perfil/airootfs"

# El instalador y la clave pública con la que se comprueban los paquetes de Apogeo
I="$A/usr/lib/apogeo-instalador"
install -Dm755 "$RAIZ/instalador/apogeo-instalador" "$I/apogeo-instalador"
install -Dm755 "$RAIZ/instalador/motor.py" "$I/motor.py"
install -Dm644 "$RAIZ/instalador/windows.py" "$I/windows.py"
install -Dm644 "$RAIZ/instalador/Instalador.qml" "$I/Instalador.qml"
install -Dm644 "$RAIZ/apogeo.asc" "$I/apogeo.asc"

# Las piezas de Órbita, tal cual van en Apogeo
bsdtar -xf "$PAQUETE" -C "$TRABAJO/apogeo" usr/lib/qt6/qml/Apogeo usr/share/fonts/apogeo usr/share/apogeo/logo.svg \
  usr/share/plasma/wallpapers/org.apogeo.fondo/contents/shaders
cp -a "$TRABAJO/apogeo/usr" "$A/"

mkarchiso -v -w "$TRABAJO/w" -o "$SALIDA" "$TRABAJO/perfil"
ls -la "$SALIDA"
