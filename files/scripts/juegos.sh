#!/usr/bin/env bash
# Hydra Launcher: la última versión de su GitHub oficial (hydralauncher/hydra). Como la imagen se construye cada día, se
# actualiza sola con ella. Apogeo no añade ninguna fuente de descargas.
set -euo pipefail
url=$(curl -fsSL https://api.github.com/repos/hydralauncher/hydra/releases/latest \
  | python3 -c 'import sys, json; print(next(a["browser_download_url"] for a in json.load(sys.stdin)["assets"] if a["name"].endswith(".x86_64.rpm")))')
echo "Hydra: $url"
curl -fL --retry 3 -o /tmp/hydra.rpm "$url"
dnf install -y /tmp/hydra.rpm
rm -f /tmp/hydra.rpm
command -v hydralauncher
