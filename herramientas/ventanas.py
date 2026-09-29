#!/usr/bin/python3
"""
Ventanas de Apogeo, «Fina con pastilla»: barra ciruela de 24 px con el título en el centro y los tres botones juntos en
una pastilla a la derecha, del color del piso. Genera un tema de KWin (Aurorae) por piso; apogeo-pisos cambia de uno a
otro al cambiar de piso. En las ventanas de detrás la pastilla se apaga.

  ventanas.py [destino]    por defecto /usr/share/aurorae/themes
"""
import os
import sys

DST = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/aurorae/themes'
FLOORS = {'jugar': ('Jugar', '#ff8fc6'), 'navegar': ('Navegar', '#e0a9b4'), 'estudiar': ('Estudiar', '#c9b8c9')}
BAR, BAR_OFF = '#2a1f2e', '#211a25'
INK, INK_OFF = '#2a1a22', '#a9949f'
PILL_OFF, PILL_OFF_HOVER = '#3d3042', '#4a3a50'
TITLE_H, R = 24, 8                       # alto de la barra y radio de las esquinas de arriba
BTN_H, BTN_TOP = 18, 3                   # alto de la pastilla y margen de arriba
WIDTHS = {'minimize': 26, 'maximize': 24, 'restore': 24, 'close': 28}


def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(ca, cb))


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            f'{body}</svg>\n')


def decoration():
    """Marco de 9 trozos: arriba la barra (con las esquinas redondeadas) y 1 px a los lados y abajo."""
    parts = []
    for prefix, color in (('decoration', BAR), ('decoration-inactive', BAR_OFF)):
        y = 0 if prefix == 'decoration' else 40
        parts += [
            f'<path id="{prefix}-topleft" transform="translate(0 {y})" d="M0 {R} A{R} {R} 0 0 1 {R} 0 H{R} V{TITLE_H} H0 Z" fill="{color}"/>',
            f'<rect id="{prefix}-top" x="{R + 2}" y="{y}" width="10" height="{TITLE_H}" fill="{color}"/>',
            f'<path id="{prefix}-topright" transform="translate({R + 14} {y})" d="M0 0 A{R} {R} 0 0 1 {R} {R} V{TITLE_H} H0 Z" fill="{color}"/>',
            f'<rect id="{prefix}-left" x="0" y="{y + TITLE_H + 2}" width="1" height="4" fill="{color}"/>',
            f'<rect id="{prefix}-center" x="2" y="{y + TITLE_H + 2}" width="4" height="4" fill="{color}" fill-opacity="0"/>',
            f'<rect id="{prefix}-right" x="8" y="{y + TITLE_H + 2}" width="1" height="4" fill="{color}"/>',
            f'<rect id="{prefix}-bottomleft" x="0" y="{y + TITLE_H + 8}" width="1" height="1" fill="{color}"/>',
            f'<rect id="{prefix}-bottom" x="2" y="{y + TITLE_H + 8}" width="4" height="1" fill="{color}"/>',
            f'<rect id="{prefix}-bottomright" x="8" y="{y + TITLE_H + 8}" width="1" height="1" fill="{color}"/>',
        ]
    # Maximizada: sin esquinas redondeadas
    for prefix, color in (('decoration-maximized', BAR), ('decoration-maximized-inactive', BAR_OFF)):
        y = 80 if prefix == 'decoration-maximized' else 120
        for el, x in (('topleft', 0), ('top', 4), ('topright', 8)):
            parts.append(f'<rect id="{prefix}-{el}" x="{x}" y="{y}" width="2" height="{TITLE_H}" fill="{color}"/>')
        for el, x, yy in (('left', 0, 26), ('center', 4, 26), ('right', 8, 26),
                          ('bottomleft', 0, 30), ('bottom', 4, 30), ('bottomright', 8, 30)):
            parts.append(f'<rect id="{prefix}-{el}" x="{x}" y="{y + yy}" width="0.01" height="0.01" fill="{color}" fill-opacity="0"/>')
    return svg(40, 160, '\n'.join(parts) + '\n')


def shape(kind, w):
    """El trozo de pastilla de cada botón: minimizar es la punta izquierda y cerrar la derecha."""
    r = BTN_H / 2
    if kind == 'minimize':
        return f'M{r} 0 H{w} V{BTN_H} H{r} A{r} {r} 0 0 1 {r} 0 Z'
    if kind == 'close':
        return f'M0 0 H{w - r} A{r} {r} 0 0 1 {w - r} {BTN_H} H0 Z'
    return f'M0 0 H{w} V{BTN_H} H0 Z'


def glyph(kind, w, color):
    cx, cy = w / 2 + (1 if kind == 'minimize' else -1 if kind == 'close' else 0), BTN_H / 2
    s = f'stroke="{color}" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none"'
    if kind == 'minimize':
        return f'<path d="M{cx - 4} {cy} H{cx + 4}" {s}/>'
    if kind == 'maximize':
        return f'<rect x="{cx - 3.5}" y="{cy - 3.5}" width="7" height="7" rx="1.5" {s}/>'
    if kind == 'restore':
        return (f'<rect x="{cx - 4}" y="{cy - 2}" width="6" height="6" rx="1.3" {s}/>'
                f'<path d="M{cx - 1.5} {cy - 4} H{cx + 4} V{cy + 1.5}" {s}/>')
    return f'<path d="M{cx - 3.2} {cy - 3.2} L{cx + 3.2} {cy + 3.2} M{cx + 3.2} {cy - 3.2} L{cx - 3.2} {cy + 3.2}" {s}/>'


def button(kind, accent):
    w = WIDTHS[kind]
    close = kind == 'close'
    states = {
        'active': (accent, INK),
        'hover': ('#fff0f7' if close else mix(accent, '#ffffff', 0.3), '#8e2e66' if close else INK),
        'pressed': (mix(accent, '#000000', 0.15), INK),
        'inactive': (PILL_OFF, INK_OFF),
        'hover-inactive': (PILL_OFF_HOVER, '#f1e6ea'),
        'deactivated': (PILL_OFF, '#6f5f6b'),
    }
    body = []
    for k, (state, (bg, ink)) in enumerate(states.items()):
        y = k * (BTN_H + 4)
        body.append(f'<g id="{state}-center" transform="translate(0 {y})">'
                    f'<path d="{shape(kind, w)}" fill="{bg}"/>{glyph(kind, w, ink)}</g>')
    return svg(w, len(states) * (BTN_H + 4), '\n'.join(body) + '\n')


def rc(accent):
    return f"""[General]
ActiveTextColor=#f1e6ea
InactiveTextColor=#8f7d89
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=120

[Layout]
BorderLeft=1
BorderRight=1
BorderBottom=1
BorderTop=0
TitleEdgeTop=0
TitleEdgeBottom=0
TitleEdgeLeft=10
TitleEdgeRight=6
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=0
TitleEdgeLeftMaximized=10
TitleEdgeRightMaximized=6
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={TITLE_H}
ButtonHeight={BTN_H}
ButtonWidthMinimize={WIDTHS['minimize']}
ButtonWidthMaximizeRestore={WIDTHS['maximize']}
ButtonWidthClose={WIDTHS['close']}
ButtonSpacing=0
ButtonMarginTop={BTN_TOP}
ButtonMarginTopMaximized={BTN_TOP}
ExplicitButtonSpacer=0
"""


def main():
    for key, (name, accent) in FLOORS.items():
        theme = f'apogeo-{key}'
        d = os.path.join(DST, theme)
        os.makedirs(d, exist_ok=True)
        files = {
            f'{theme}rc': rc(accent),
            'decoration.svg': decoration(),
            'metadata.desktop': f"""[Desktop Entry]
Name=Apogeo · {name}
Comment=Barra fina con los botones en una pastilla (piso {name})
X-KDE-PluginInfo-Author=Ares
X-KDE-PluginInfo-Name={theme}
X-KDE-PluginInfo-Version=1.0
X-KDE-PluginInfo-License=MIT
""",
        }
        for kind in WIDTHS:
            files[f'{kind}.svg'] = button(kind, accent)
        for name_, text in files.items():
            with open(os.path.join(d, name_), 'w') as f:
                f.write(text)
    print('Ventanas: temas', ', '.join(f'apogeo-{k}' for k in FLOORS))


if __name__ == '__main__':
    main()
