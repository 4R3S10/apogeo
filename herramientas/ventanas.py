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
PAD = 18                                 # margen de la sombra alrededor de la ventana
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
    """Marco de 9 trozos: arriba la barra (con las esquinas redondeadas), 1 px a los lados y abajo, y alrededor una
    sombra suave (el margen P). Maximizada no hay sombra ni esquinas redondeadas."""
    P = PAD
    grads = []

    def shadow(gid, alpha, kind):
        # kind: l/r/t/b = degradado hacia la ventana; tl/tr/bl/br = esquina (circular)
        stops = (f'<stop offset="0" stop-color="#000" stop-opacity="{alpha}"/>'
                 f'<stop offset="0.45" stop-color="#000" stop-opacity="{alpha * 0.35:.3f}"/>'
                 f'<stop offset="1" stop-color="#000" stop-opacity="0"/>')
        if len(kind) == 1:
            x1, y1, x2, y2 = {'l': (1, 0, 0, 0), 'r': (0, 0, 1, 0), 't': (0, 1, 0, 0), 'b': (0, 0, 0, 1)}[kind]
            grads.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{stops}</linearGradient>')
        else:
            cx = 1 if kind[1] == 'l' else 0
            cy = 1 if kind[0] == 't' else 0
            grads.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="1">{stops}</radialGradient>')
        return f'url(#{gid})'

    parts = []
    col = 0
    for prefix, color, alpha in (('decoration', BAR, 0.32), ('decoration-inactive', BAR_OFF, 0.2)):
        ox, oy = col, 0
        col += 3 * (P + R) + 20
        g = lambda k: shadow(f'{prefix}-s{k}', alpha, k)  # noqa: E731
        W = P + R  # ancho de las esquinas de arriba
        H = P + TITLE_H  # alto del trozo de arriba
        # Arriba a la izquierda: sombra de esquina, sombra del lado y la barra con la esquina redondeada
        parts.append(
            f'<g id="{prefix}-topleft" transform="translate({ox} {oy})">'
            f'<rect x="0" y="0" width="{W}" height="{W}" fill="{g("tl")}"/>'
            f'<rect x="0" y="{W}" width="{P}" height="{H - W}" fill="{g("l")}"/>'
            f'<path d="M{P} {P + R} A{R} {R} 0 0 1 {P + R} {P} V{H} H{P} Z" fill="{color}"/></g>')
        parts.append(
            f'<g id="{prefix}-top" transform="translate({ox + W + 4} {oy})">'
            f'<rect x="0" y="0" width="10" height="{P}" fill="{g("t")}"/>'
            f'<rect x="0" y="{P}" width="10" height="{TITLE_H}" fill="{color}"/></g>')
        parts.append(
            f'<g id="{prefix}-topright" transform="translate({ox + W + 18} {oy})">'
            f'<rect x="0" y="0" width="{W}" height="{W}" fill="{g("tr")}"/>'
            f'<rect x="{R}" y="{W}" width="{P}" height="{H - W}" fill="{g("r")}"/>'
            f'<path d="M0 {P} A{R} {R} 0 0 1 {R} {P + R} V{H} H0 Z" fill="{color}"/></g>')
        y = oy + H + 4
        # Los lados miden lo mismo que las esquinas (W): KSvg encaja cada esquina en el ancho del lado. Lo que pasa
        # de la sombra y el borde de 1 px queda transparente (debajo de la ventana).
        clear = f'fill="#000" fill-opacity="0"'
        parts.append(
            f'<g id="{prefix}-left" transform="translate({ox} {y})">'
            f'<rect x="0" y="0" width="{P}" height="4" fill="{g("l")}"/>'
            f'<rect x="{P}" y="0" width="1" height="4" fill="{color}"/>'
            f'<rect x="{P + 1}" y="0" width="{R - 1}" height="4" {clear}/></g>')
        parts.append(f'<rect id="{prefix}-center" x="{ox + W + 4}" y="{y}" width="4" height="4" {clear}/>')
        parts.append(
            f'<g id="{prefix}-right" transform="translate({ox + W + 12} {y})">'
            f'<rect x="0" y="0" width="{R - 1}" height="4" {clear}/>'
            f'<rect x="{R - 1}" y="0" width="1" height="4" fill="{color}"/>'
            f'<rect x="{R}" y="0" width="{P}" height="4" fill="{g("r")}"/></g>')
        y += 8
        parts.append(
            f'<g id="{prefix}-bottomleft" transform="translate({ox} {y})">'
            f'<rect x="0" y="0" width="{P + 1}" height="{P + 1}" fill="{g("bl")}"/>'
            f'<rect x="{P}" y="0" width="{R}" height="1" fill="{color}"/>'
            f'<rect x="{P + 1}" y="1" width="{R - 1}" height="{P}" fill="{g("b")}"/></g>')
        parts.append(
            f'<g id="{prefix}-bottom" transform="translate({ox + W + 4} {y})">'
            f'<rect x="0" y="0" width="4" height="1" fill="{color}"/>'
            f'<rect x="0" y="1" width="4" height="{P}" fill="{g("b")}"/></g>')
        parts.append(
            f'<g id="{prefix}-bottomright" transform="translate({ox + W + 12} {y})">'
            f'<rect x="{R - 1}" y="0" width="{P + 1}" height="{P + 1}" fill="{g("br")}"/>'
            f'<rect x="0" y="0" width="{R}" height="1" fill="{color}"/>'
            f'<rect x="0" y="1" width="{R - 1}" height="{P}" fill="{g("b")}"/></g>')

    # Maximizada: el mismo margen, pero transparente, y la barra recta
    for prefix, color in (('decoration-maximized', BAR), ('decoration-maximized-inactive', BAR_OFF)):
        ox, oy = col, 0
        col += 3 * (P + 4) + 20
        clear = lambda x, y, w, h: f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>'  # noqa: E731
        for el, x in (('topleft', 0), ('top', P + 6), ('topright', 2 * P + 12)):
            parts.append(f'<g id="{prefix}-{el}" transform="translate({ox + x} {oy})">{clear(0, 0, P + 2, P)}'
                         f'<rect x="0" y="{P}" width="{P + 2}" height="{TITLE_H}" fill="{color}"/></g>')
        y = oy + P + TITLE_H + 4
        for el, x, w, h in (('left', 0, P + 1, 4), ('center', P + 6, 4, 4), ('right', 2 * P + 12, P + 1, 4),
                            ('bottomleft', 0, P + 1, P + 1), ('bottom', P + 6, 4, P + 1),
                            ('bottomright', 2 * P + 12, P + 1, P + 1)):
            yy = y if el in ('left', 'center', 'right') else y + 8
            parts.append(f'<g id="{prefix}-{el}" transform="translate({ox + x} {yy})">{clear(0, 0, w, h)}</g>')
    body = '<defs>' + ''.join(grads) + '</defs>\n' + '\n'.join(parts) + '\n'
    return svg(col, 2 * (P + TITLE_H) + 2 * P + 40, body)


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
PaddingLeft={PAD}
PaddingRight={PAD}
PaddingTop={PAD}
PaddingBottom={PAD}
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
