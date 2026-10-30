#!/usr/bin/python3
"""
La letra de Apogeo para todo el sistema. La identidad «Órbita» usa Geist (interfaz) y Geist Mono (datos, rutas,
compatibilidad) y Source Serif 4 para leer y escribir apuntes; la identidad clásica sigue usando Bricolage Grotesque. Las fuentes variables se instancian en grosores
fijos, que es lo que KDE elige mejor.

  letra.py FUENTE_VARIABLE [destino]    por defecto /usr/share/fonts/apogeo

La familia y los ejes se leen de la propia fuente, así el mismo script vale para Geist, Geist Mono y Bricolage.
"""
import os
import re
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

SRC = sys.argv[1]
DST = sys.argv[2] if len(sys.argv) > 2 else '/usr/share/fonts/apogeo'
WEIGHTS = {200: 'ExtraLight', 300: 'Light', 400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold'}

_font = TTFont(SRC)
FAMILY = _font['name'].getDebugName(1) or 'Geist'
if FAMILY in ('Geist Regular', 'Geist'):
    FAMILY = 'Geist'
elif FAMILY.startswith('Geist Mono'):
    FAMILY = 'Geist Mono'
elif FAMILY.startswith('Bricolage'):
    FAMILY = 'Bricolage Grotesque'
elif FAMILY.startswith('Source Serif'):
    FAMILY = 'Source Serif 4'
AXES = {a.axisTag for a in _font['fvar'].axes} if 'fvar' in _font else set()
POSTSCRIPT = re.sub(r'\W', '', FAMILY)
_font.close()


def rename(font, style, weight):
    """Nombres de la fuente fija: la familia y el grosor como estilo."""
    name = font['name']
    name.names = [n for n in name.names if n.nameID not in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25)]
    ribbi = style in ('Regular', 'Bold')
    full = f'{FAMILY} {style}'
    ps = f'{POSTSCRIPT}-{style}'
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
        axes = {'wght': weight}
        if 'opsz' in AXES:
            axes['opsz'] = 14
        if 'wdth' in AXES:
            axes['wdth'] = 100
        font = instancer.instantiateVariableFont(TTFont(SRC), axes)
        rename(font, style, weight)
        font.save(os.path.join(DST, f'{POSTSCRIPT}-{style}.ttf'))
    print(f'Letra: {FAMILY} ({", ".join(WEIGHTS.values())})')


if __name__ == '__main__':
    main()
