#!/usr/bin/python3
"""
Iconos de Apogeo: Papirus (oscuro) con las carpetas rosa. En vez de cambiar los archivos de Papirus (se perderían en
cada actualización), es un tema aparte, «Apogeo», que solo tiene las carpetas (enlaces a las rosa de Papirus) y hereda
todo lo demás de Papirus-Dark.

  iconos.py [destino]    por defecto /usr/share/icons/Apogeo
"""
import configparser
import os
import sys

DST = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/icons/Apogeo'
ICONS = '/usr/share/icons'
THEMES = ['Papirus', 'Papirus-Dark']  # el oscuro manda cuando tiene el suyo
BLUE_APPS = ['system-file-manager', 'org.kde.dolphin', 'dolphin', 'file-manager', 'org.gnome.Nautilus']


def main():
    links = {}
    for theme in THEMES:
        root = os.path.join(ICONS, theme)
        for dirpath, _dirs, files in os.walk(root, followlinks=True):
            for name in files:
                path = os.path.join(dirpath, name)
                if not os.path.islink(path):
                    continue
                # Se sigue la cadena de enlaces entera (inode-directory → folder → folder-blue)
                real = os.path.realpath(path)
                base = os.path.basename(real)
                if '-blue' not in base:
                    continue
                pink = os.path.join(os.path.dirname(real), base.replace('-blue', '-pink'))
                if os.path.exists(pink):
                    links[os.path.relpath(path, root)] = os.path.realpath(pink)
    # Apps cuyo icono en Papirus es una carpeta azul: la carpeta rosa (Dolphin, el explorador de archivos)
    for size in os.listdir(os.path.join(ICONS, 'Papirus')):
        pink = os.path.join(ICONS, 'Papirus', size, 'places', 'folder-pink.svg')
        if not os.path.exists(pink):
            continue
        for name in BLUE_APPS:
            if os.path.exists(os.path.join(ICONS, 'Papirus', size, 'apps', name + '.svg')):
                links[os.path.join(size, 'apps', name + '.svg')] = os.path.realpath(pink)
    for rel, target in links.items():
        link = os.path.join(DST, rel)
        os.makedirs(os.path.dirname(link), exist_ok=True)
        # Enlace relativo a /usr/share/icons (sirve igual dentro del paquete que instalado)
        target_rel = os.path.relpath(target, os.path.dirname(os.path.join(ICONS, 'Apogeo', rel)))
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(target_rel, link)

    # index.theme: el de Papirus-Dark con otro nombre y heredando de él
    idx = configparser.ConfigParser(interpolation=None, strict=False)
    idx.optionxform = str
    idx.read(os.path.join(ICONS, 'Papirus-Dark', 'index.theme'))
    head = idx['Icon Theme']
    head['Name'] = 'Apogeo'
    head['Comment'] = 'Papirus oscuro con las carpetas rosa'
    head['Inherits'] = 'Papirus-Dark,breeze-dark,hicolor'
    with open(os.path.join(DST, 'index.theme'), 'w') as f:
        idx.write(f, space_around_delimiters=False)
    print(f'Iconos: {len(links)} carpetas en rosa')


if __name__ == '__main__':
    main()
