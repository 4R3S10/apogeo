#!/usr/bin/python3
"""
La letra de Ágape (Bricolage Grotesque, OFL) para todo el sistema. La fuente variable tiene tamaño óptico, grosor y
anchura; KDE elige mejor con archivos fijos, así que se sacan los grosores que usa Ágape en el tamaño óptico de letra
de interfaz (14 pt), a lo ancho normal, todos con el nombre «Bricolage Grotesque».

  letra.py FUENTE_VARIABLE [destino]    por defecto /usr/share/fonts/apogeo
"""
import os
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

SRC = sys.argv[1]
DST = sys.argv[2] if len(sys.argv) > 2 else '/usr/share/fonts/apogeo'
FAMILY = 'Bricolage Grotesque'
WEIGHTS = {300: 'Light', 400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold'}


def rename(font, style, weight):
    """Nombres de la fuente fija: familia «Bricolage Grotesque» y el grosor como estilo."""
    name = font['name']
    name.names = [n for n in name.names if n.nameID not in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25)]
    ribbi = style in ('Regular', 'Bold')
    full = f'{FAMILY} {style}'
    ps = f'BricolageGrotesque-{style}'
    for nid, value in ((1, FAMILY if ribbi else f'{FAMILY} {style}'), (2, style if ribbi else 'Regular'),
                       (3, f'Apogeo;{ps}'), (4, full), (6, ps), (16, FAMILY), (17, style)):
        name.setName(value, nid, 3, 1, 0x409)
    font['OS/2'].usWeightClass = weight
    font['OS/2'].fsSelection = (font['OS/2'].fsSelection & ~0b1100001) | (0b100000 if style == 'Bold' else 0) \
        | (0b1000000 if style == 'Regular' else 0)
    font['head'].macStyle = 1 if style == 'Bold' else 0
    if 'STAT' in font:
        del font['STAT']


def main():
    os.makedirs(DST, exist_ok=True)
    for weight, style in WEIGHTS.items():
        font = instancer.instantiateVariableFont(TTFont(SRC), {'opsz': 14, 'wght': weight, 'wdth': 100})
        rename(font, style, weight)
        font.save(os.path.join(DST, f'BricolageGrotesque-{style}.ttf'))
    print('Letra:', ', '.join(WEIGHTS.values()))


if __name__ == '__main__':
    main()
