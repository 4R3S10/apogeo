#!/usr/bin/python3
"""
Colores de Apogeo para las apps de KDE (esquema «Apogeo»), sacados de los de Ágape (tema Berenjena oscuro, theme.js):
fondo #120d14, superficie #1e1621, texto #f1e6ea y un solo acento, el rosa #e0a9b4 (con texto #2a1c26 encima).

  colores.py [archivo]    por defecto /usr/share/color-schemes/Apogeo.colors
"""
import sys

DST = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/color-schemes/Apogeo.colors'

BG = '#120d14'
SURFACE = '#1e1621'
TEXT = '#f1e6ea'
ACCENT = '#e0a9b4'
ACCENT_TEXT = '#2a1c26'
NEGATIVE = '#e5484d'  # la ✕ de Ágape
NEUTRAL = '#f5c98b'
POSITIVE = '#9fd8a8'


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(rgb(a), rgb(b)))


def c(h):
    return ','.join(str(v) for v in rgb(h))


# Lo mismo que calcula Ágape: texto al 62 % (apagado), 38 % (tenue); «hover» = texto al 7 % sobre la superficie
MUTED = mix(SURFACE, TEXT, 0.62)
FAINT = mix(SURFACE, TEXT, 0.38)
CHROME = mix(SURFACE, TEXT, 0.03)       # --chrome-solid
HOVER = mix(SURFACE, TEXT, 0.07)
PRESS = mix(SURFACE, TEXT, 0.13)
VIEW = mix(BG, SURFACE, 0.55)           # listas y campos: entre el fondo y la superficie
ACCENT_HI = mix(ACCENT, '#ffffff', 0.28)


def group(name, bg, alt, fg=TEXT, inactive=MUTED, active=ACCENT_HI):
    return f"""[Colors:{name}]
BackgroundAlternate={c(alt)}
BackgroundNormal={c(bg)}
DecorationFocus={c(ACCENT)}
DecorationHover={c(ACCENT)}
ForegroundActive={c(active)}
ForegroundInactive={c(inactive)}
ForegroundLink={c(ACCENT)}
ForegroundNegative={c(NEGATIVE)}
ForegroundNeutral={c(NEUTRAL)}
ForegroundNormal={c(fg)}
ForegroundPositive={c(POSITIVE)}
ForegroundVisited={c(mix(ACCENT, '#9b59b6', 0.5))}
"""


def main():
    parts = [
        """# Apogeo: los colores de Ágape (Berenjena oscuro) para las apps de KDE. Generado por herramientas/colores.py.
[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=false
Enable=false
""",
        group('Button', HOVER, PRESS),
        group('Complementary', BG, SURFACE),
        group('Header', CHROME, SURFACE),
        group('Header][Inactive', SURFACE, CHROME),
        # La selección es la pastilla de Ágape: rosa con el texto oscuro
        group('Selection', ACCENT, ACCENT_HI, fg=ACCENT_TEXT, inactive=mix(ACCENT_TEXT, ACCENT, 0.3), active=ACCENT_TEXT),
        group('Tooltip', CHROME, SURFACE),
        group('View', VIEW, mix(VIEW, TEXT, 0.03)),
        group('Window', SURFACE, CHROME),
        f"""[General]
ColorScheme=Apogeo
Name=Apogeo
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground={c(CHROME)}
activeBlend={c(TEXT)}
activeForeground={c(TEXT)}
inactiveBackground={c(SURFACE)}
inactiveBlend={c(MUTED)}
inactiveForeground={c(MUTED)}
""",
    ]
    with open(DST, 'w') as f:
        f.write('\n'.join(parts))
    print('Colores: esquema Apogeo')


if __name__ == '__main__':
    main()
