#!/usr/bin/python3
"""
Ventanas de Apogeo con la barra de Ágape: la barra del color del cromo de Ágape, el título en el centro, apagado, y a la
derecha los botones de Ágape (iconos de línea planos; al pasar el ratón, un fondo suave y la ✕ en rojo). Esquinas de
arriba redondeadas, borde de 1 px y sombra suave. Es un tema de KWin (Aurorae) llamado «apogeo».

  ventanas.py [destino]    por defecto /usr/share/aurorae/themes
"""
import os
import sys

DST = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/aurorae/themes'
THEME = 'apogeo'

SURFACE, TEXT = '#1e1621', '#f1e6ea'


def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(ca, cb))


BAR = mix(SURFACE, TEXT, 0.03)          # --chrome-solid de Ágape
BAR_OFF = SURFACE
EDGE = mix(SURFACE, TEXT, 0.10)         # --border
MUTED = mix(BAR, TEXT, 0.62)            # --muted
FAINT = mix(BAR, TEXT, 0.38)            # --faint
HOVER = mix(BAR, TEXT, 0.07)            # --hover
PRESS = mix(BAR, TEXT, 0.13)            # --press
CLOSE = '#e5484d'                       # la ✕ de Ágape al pasar el ratón

TITLE_H, R = 38, 12                     # alto de la barra y radio de las esquinas de arriba
PAD = 24                                # margen de la sombra
BTN_W, BTN_H, BTN_TOP = 32, 28, 5       # botones de Ágape (32 × 28, radio 9)
BTN_R = 9

# Iconos de Ágape (ui/js/icons.js), en su cuadro de 24 y trazo 1,8, dibujados a 15 px
ICONS = {
    'minimize': '<path d="M6 12h12"/>',
    'maximize': '<rect x="6" y="6" width="12" height="12" rx="2"/>',
    'restore': '<rect x="5" y="9" width="10" height="10" rx="2"/><path d="M9 9V7a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2h-2"/>',
    'close': '<path d="M17 7L7 17M7 7l10 10"/>',
}


def svg(w, h, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            f'{body}</svg>\n')


def decoration():
    """Marco de 9 trozos. Los lados miden lo mismo que las esquinas (W): KSvg encaja cada esquina en el ancho del lado.
    La sombra va en el margen P; maximizada no hay sombra ni esquinas."""
    P = PAD
    W = P + R
    H = P + TITLE_H
    grads = []

    def shadow(gid, alpha, kind):
        stops = (f'<stop offset="0" stop-color="#000" stop-opacity="{alpha}"/>'
                 f'<stop offset="0.4" stop-color="#000" stop-opacity="{alpha * 0.4:.3f}"/>'
                 f'<stop offset="1" stop-color="#000" stop-opacity="0"/>')
        if len(kind) == 1:
            x1, y1, x2, y2 = {'l': (1, 0, 0, 0), 'r': (0, 0, 1, 0), 't': (0, 1, 0, 0), 'b': (0, 0, 0, 1)}[kind]
            grads.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{stops}</linearGradient>')
        else:
            cx = 1 if kind[1] == 'l' else 0
            cy = 1 if kind[0] == 't' else 0
            grads.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="1">{stops}</radialGradient>')
        return f'url(#{gid})'

    # Como la sombra de Ágape (0 14px 44px): poca arriba, más a los lados y la más fuerte abajo
    SIDE = {'t': 0.35, 'tl': 0.4, 'tr': 0.4, 'l': 0.75, 'r': 0.75, 'bl': 0.9, 'br': 0.9, 'b': 1.0}

    clear = 'fill="#000" fill-opacity="0"'
    parts = []
    col = 0
    for prefix, color, alpha in (('decoration', BAR, 0.5), ('decoration-inactive', BAR_OFF, 0.3)):
        ox = col
        col += 3 * W + 30
        g = lambda k: shadow(f'{prefix}-s{k}', round(alpha * SIDE[k], 3), k)  # noqa: E731
        # Barra con el borde de 1 px por fuera (la esquina, redondeada)
        corner_l = f'M{P} {P + R} A{R} {R} 0 0 1 {P + R} {P} V{H} H{P} Z'
        corner_r = f'M0 {P} A{R} {R} 0 0 1 {R} {P + R} V{H} H0 Z'
        parts.append(
            f'<g id="{prefix}-topleft" transform="translate({ox} 0)">'
            f'<rect x="0" y="0" width="{W}" height="{W}" fill="{g("tl")}"/>'
            f'<rect x="0" y="{W}" width="{P}" height="{H - W}" fill="{g("l")}"/>'
            f'<path d="{corner_l}" fill="{EDGE}"/>'
            f'<path d="M{P + 1} {P + R} A{R - 1} {R - 1} 0 0 1 {P + R} {P + 1} V{H} H{P + 1} Z" fill="{color}"/></g>')
        parts.append(
            f'<g id="{prefix}-top" transform="translate({ox + W + 5} 0)">'
            f'<rect x="0" y="0" width="10" height="{P}" fill="{g("t")}"/>'
            f'<rect x="0" y="{P}" width="10" height="1" fill="{EDGE}"/>'
            f'<rect x="0" y="{P + 1}" width="10" height="{TITLE_H - 1}" fill="{color}"/></g>')
        parts.append(
            f'<g id="{prefix}-topright" transform="translate({ox + W + 20} 0)">'
            f'<rect x="0" y="0" width="{W}" height="{W}" fill="{g("tr")}"/>'
            f'<rect x="{R}" y="{W}" width="{P}" height="{H - W}" fill="{g("r")}"/>'
            f'<path d="{corner_r}" fill="{EDGE}"/>'
            f'<path d="M0 {P + 1} A{R - 1} {R - 1} 0 0 1 {R - 1} {P + R} V{H} H0 Z" fill="{color}"/></g>')
        y = H + 5
        parts.append(
            f'<g id="{prefix}-left" transform="translate({ox} {y})">'
            f'<rect x="0" y="0" width="{P}" height="4" fill="{g("l")}"/>'
            f'<rect x="{P}" y="0" width="1" height="4" fill="{EDGE}"/>'
            f'<rect x="{P + 1}" y="0" width="{R - 1}" height="4" {clear}/></g>')
        parts.append(f'<rect id="{prefix}-center" x="{ox + W + 5}" y="{y}" width="4" height="4" {clear}/>')
        parts.append(
            f'<g id="{prefix}-right" transform="translate({ox + W + 20} {y})">'
            f'<rect x="0" y="0" width="{R - 1}" height="4" {clear}/>'
            f'<rect x="{R - 1}" y="0" width="1" height="4" fill="{EDGE}"/>'
            f'<rect x="{R}" y="0" width="{P}" height="4" fill="{g("r")}"/></g>')
        y += 9
        parts.append(
            f'<g id="{prefix}-bottomleft" transform="translate({ox} {y})">'
            f'<rect x="0" y="0" width="{P + 1}" height="{P + 1}" fill="{g("bl")}"/>'
            f'<rect x="{P}" y="0" width="{R}" height="1" fill="{EDGE}"/>'
            f'<rect x="{P + 1}" y="1" width="{R - 1}" height="{P}" fill="{g("b")}"/></g>')
        parts.append(
            f'<g id="{prefix}-bottom" transform="translate({ox + W + 5} {y})">'
            f'<rect x="0" y="0" width="4" height="1" fill="{EDGE}"/>'
            f'<rect x="0" y="1" width="4" height="{P}" fill="{g("b")}"/></g>')
        parts.append(
            f'<g id="{prefix}-bottomright" transform="translate({ox + W + 20} {y})">'
            f'<rect x="{R - 1}" y="0" width="{P + 1}" height="{P + 1}" fill="{g("br")}"/>'
            f'<rect x="0" y="0" width="{R}" height="1" fill="{EDGE}"/>'
            f'<rect x="0" y="1" width="{R - 1}" height="{P}" fill="{g("b")}"/></g>')

    # Maximizada: el mismo margen, transparente, y la barra recta
    for prefix, color in (('decoration-maximized', BAR), ('decoration-maximized-inactive', BAR_OFF)):
        ox = col
        col += 3 * (P + 4) + 30
        box = lambda x, y, w, h: f'<rect x="{x}" y="{y}" width="{w}" height="{h}" {clear}/>'  # noqa: E731
        for el, x in (('topleft', 0), ('top', P + 6), ('topright', 2 * P + 12)):
            parts.append(f'<g id="{prefix}-{el}" transform="translate({ox + x} 0)">{box(0, 0, P + 2, P)}'
                         f'<rect x="0" y="{P}" width="{P + 2}" height="{TITLE_H}" fill="{color}"/></g>')
        y = H + 5
        for el, x, w, h in (('left', 0, P + 1, 4), ('center', P + 6, 4, 4), ('right', 2 * P + 12, P + 1, 4),
                            ('bottomleft', 0, P + 1, P + 1), ('bottom', P + 6, 4, P + 1),
                            ('bottomright', 2 * P + 12, P + 1, P + 1)):
            yy = y if el in ('left', 'center', 'right') else y + 9
            parts.append(f'<g id="{prefix}-{el}" transform="translate({ox + x} {yy})">{box(0, 0, w, h)}</g>')
    body = '<defs>' + ''.join(grads) + '</defs>\n' + '\n'.join(parts) + '\n'
    return svg(col, 2 * H + 2 * P + 40, body)


def button(kind):
    """Botón de Ágape: sin fondo; al pasar el ratón, fondo suave (o rojo, la ✕) y el icono más claro."""
    close = kind == 'close'
    states = {
        'active': (None, MUTED),
        'hover': (CLOSE if close else HOVER, '#ffffff' if close else TEXT),
        'pressed': (mix(CLOSE, '#000000', 0.15) if close else PRESS, '#ffffff' if close else TEXT),
        'inactive': (None, FAINT),
        'hover-inactive': (CLOSE if close else HOVER, '#ffffff' if close else TEXT),
        'deactivated': (None, mix(BAR, TEXT, 0.22)),
    }
    s = 15 / 24
    ox, oy = (BTN_W - 15) / 2, (BTN_H - 15) / 2
    body = []
    for k, (state, (bg, ink)) in enumerate(states.items()):
        y = k * (BTN_H + 4)
        back = (f'<rect width="{BTN_W}" height="{BTN_H}" rx="{BTN_R}" fill="{bg}"/>' if bg else
                f'<rect width="{BTN_W}" height="{BTN_H}" fill="#000" fill-opacity="0"/>')
        body.append(f'<g id="{state}-center" transform="translate(0 {y})">{back}'
                    f'<g transform="translate({ox} {oy}) scale({s})" fill="none" stroke="{ink}" stroke-width="1.8" '
                    f'stroke-linecap="round" stroke-linejoin="round">{ICONS[kind]}</g></g>')
    return svg(BTN_W, len(states) * (BTN_H + 4), '\n'.join(body) + '\n')


def rc():
    return f"""[General]
ActiveTextColor={mix(BAR, TEXT, 0.8)}
InactiveTextColor={FAINT}
TitleAlignment=Center
TitleVerticalAlignment=Center
Animation=150

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
TitleEdgeLeft=12
TitleEdgeRight=6
TitleEdgeTopMaximized=0
TitleEdgeBottomMaximized=0
TitleEdgeLeftMaximized=12
TitleEdgeRightMaximized=6
TitleBorderLeft=8
TitleBorderRight=8
TitleHeight={TITLE_H}
ButtonHeight={BTN_H}
ButtonWidth={BTN_W}
ButtonSpacing=2
ButtonMarginTop={BTN_TOP}
ButtonMarginTopMaximized={BTN_TOP}
ExplicitButtonSpacer=0
"""


def main():
    d = os.path.join(DST, THEME)
    os.makedirs(d, exist_ok=True)
    files = {
        f'{THEME}rc': rc(),
        'decoration.svg': decoration(),
        'metadata.desktop': f"""[Desktop Entry]
Name=Apogeo
Comment=La barra de ventana de Ágape
X-KDE-PluginInfo-Author=Ares
X-KDE-PluginInfo-Name={THEME}
X-KDE-PluginInfo-Version=2.0
X-KDE-PluginInfo-License=MIT
""",
    }
    for kind in ICONS:
        files[f'{kind}.svg'] = button(kind)
    for name, text in files.items():
        with open(os.path.join(d, name), 'w') as f:
            f.write(text)
    print('Ventanas: tema', THEME)


if __name__ == '__main__':
    main()
