#!/bin/bash
# Pasa un CachyOS (edición KDE Plasma) a Apogeo: añade el repositorio firmado de Apogeo e instala el paquete «apogeo».
#   curl -fsSL https://raw.githubusercontent.com/4R3S10/apogeo/main/instalar.sh | sudo bash
set -euo pipefail
REPO=https://github.com/4R3S10/apogeo
CLAVE=DF948BE0F005C7C6101BF9607CF246C5627C09B2
[ "$(id -u)" -eq 0 ] || { echo "Hay que ejecutarlo con sudo"; exit 1; }
# CachyOS se presenta como Arch en os-release; lo que lo distingue son sus repositorios
grep -q '^\[cachyos' /etc/pacman.conf || { echo "Apogeo se instala sobre CachyOS"; exit 1; }

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

# El controlador de Vulkan de tu gráfica (y el de 32 bits, para Steam y Proton) antes que nada: así pacman no pregunta
# y no elige uno que no toca (por defecto propondría mesa-git)
vulkan=()
gpus=$(lspci -nn 2>/dev/null | grep -Ei 'vga|3d|display' || true)
grep -qi 'amd\|ati' <<<"$gpus" && vulkan+=(vulkan-radeon lib32-vulkan-radeon)
grep -qi 'intel' <<<"$gpus" && vulkan+=(vulkan-intel lib32-vulkan-intel)
grep -qi 'nvidia' <<<"$gpus" && ! pacman -Q nvidia-utils >/dev/null 2>&1 && vulkan+=(vulkan-nouveau lib32-vulkan-nouveau)
[ ${#vulkan[@]} -eq 0 ] && vulkan+=(vulkan-swrast lib32-vulkan-swrast)   # máquina virtual o sin gráfica
echo ">>> Vulkan: ${vulkan[*]}"
pacman -S --needed --noconfirm "${vulkan[@]}"

echo ">>> Instalando Apogeo"
pacman -Syu --needed apogeo </dev/tty

# El arranque (Limine) pasa a llamarse «Apogeo»: se crea su entrada y se quita la vieja de CachyOS, que comparte los
# archivos de arranque y se quedaría con la comprobación desfasada (y no arrancaría)
if command -v limine-mkinitcpio >/dev/null && [ -r /boot/limine.conf ]; then
  echo ">>> Arranque"
  grep -Eq '^/\+?Apogeo$' /boot/limine.conf || limine-mkinitcpio
  if grep -Eq '^/\+?Apogeo$' /boot/limine.conf; then
    for old in CachyOS "Arch Linux"; do
      grep -Eq "^/\+?$old\$" /boot/limine.conf && limine-entry-tool --remove-os "$old" </dev/tty
    done
  fi
fi
echo ">>> Listo. Reinicia para entrar en Apogeo."
