#!/usr/bin/env bash
# Estética de Apogeo: carpetas rosa en Papirus, cursor berenjena y los valores por defecto (letra, iconos, cursor,
# colores y teclado) para todos los usuarios. Cada usuario puede cambiarlos después en los ajustes.
set -euo pipefail

# Papirus con carpetas rosa: los iconos «folder-*» son enlaces a los azules; se apuntan a los rosa (lo mismo que hace
# papirus-folders)
n=0
while IFS= read -r -d '' link; do
  target=$(readlink "$link")
  pink=${target/-blue/-pink}
  if [[ $pink != "$target" && -e "$(dirname "$link")/$pink" ]]; then
    ln -sfn "$pink" "$link"
    n=$((n + 1))
  fi
done < <(find /usr/share/icons/Papirus* -type l -lname '*-blue*' -print0)
echo "Papirus: $n carpetas en rosa"

# Cursor berenjena (a partir del Breeze del sistema)
python3 "$(dirname "$0")/cursor.py"

# Valores por defecto de Plasma
mkdir -p /etc/xdg
cat >> /etc/xdg/kdeglobals <<'EOF'

[General]
ColorScheme=Apogeo
font=Nunito,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
menuFont=Nunito,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
smallestReadableFont=Nunito,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
toolBarFont=Nunito,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[Icons]
Theme=Papirus-Dark

[WM]
activeFont=Nunito,10,-1,5,700,0,0,0,0,0,0,0,0,0,0,1

[Sounds]
Theme=apogeo
EOF
cat >> /etc/xdg/kcminputrc <<'EOF'

[Mouse]
cursorTheme=Apogeo-cursor
EOF
# Teclado ANSI: EE. UU. internacional (ñ con AltGr+n, tildes con ´ + vocal)
cat >> /etc/xdg/kxkbrc <<'EOF'

[Layout]
LayoutList=us
VariantList=intl
Use=true
EOF
# Cursor por defecto también fuera de Plasma (pantalla de inicio de sesión, apps de X)
mkdir -p /usr/share/icons/default
cat > /usr/share/icons/default/index.theme <<'EOF'
[Icon Theme]
Inherits=Apogeo-cursor
EOF
# Arranque: el diamante sobre el brillo berenjena (el initramfs se rehace al final de la receta)
plymouth-set-default-theme apogeo
echo "Estética aplicada"
