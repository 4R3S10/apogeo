#!/usr/bin/env bash
# shellcheck disable=SC2034
# El USB de Apogeo (archiso, a partir de «releng»): arranca solo en UEFI (Windows 11 también lo necesita) y abre el
# instalador de Órbita a pantalla completa. Lo construye .github/workflows/iso.yml (instalador/construir-iso.sh).

iso_name="apogeo"
iso_label="APOGEO_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Apogeo <https://github.com/4R3S10/apogeo>"
iso_application="Instalar Apogeo"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/lib/apogeo-instalador/apogeo-instalador"]="0:0:755"
  ["/usr/lib/apogeo-instalador/motor.py"]="0:0:755"
)
