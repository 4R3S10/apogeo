#!/usr/bin/python3
"""
Estilo de Plasma «Apogeo»: la isla, los paneles de los lados, los menús, los avisos y las ventanitas emergentes con el
cristal y las tarjetas de Ágape. Con efectos (lo normal) se usa la versión translúcida (cristal desenfocado); sin ellos,
la opaca.

  - Paneles (la isla y los de los lados): cristal de Ágape, rgba(superficie, .55) con desenfoque, radio 20, borde del 10 % y el brillo
    de 1 px arriba, del color del piso.
  - Menús, avisos y ventanitas: tarjeta de Ágape (el cromo casi opaco), radio 16, sombra grande y suave.
  - Bocadillos: cromo, radio 10.
  - La raya del foco en un panel: en la isla, la del acento en su borde de dentro; en los paneles de los lados, ninguna.

  plasma.py [destino]    por defecto /usr/share/plasma/desktoptheme
"""
import json
import os
import sys

DST = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/plasma/desktoptheme'
from fichas import SURFACE, TEXT, ACCENT, NOMBRE, CRISTAL, r

THEME = NOMBRE or 'apogeo'


def mix(a, b, t):
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(ca, cb))


CHROME = mix(SURFACE, TEXT, 0.03)


def frame_svg(R, M, fill, opacity, shadow_size, shadow_alpha, highlight=True, extra_hints=True, shine=None):
    """Un marco de 9 trozos con sus pistas (márgenes), su máscara (para el desenfoque) y su sombra, con los nombres que
    usa Plasma (los mismos que el tema Breeze)."""
    S = shadow_size + R        # esquina de la sombra: lo que sale por fuera + lo que queda debajo del marco
    E = 10                     # largo de los trozos de los lados
    border = f'fill="{TEXT}" fill-opacity="0.1"'
    body = f'fill="{fill}" fill-opacity="{opacity}"'
    shine = f'fill="{shine[0]}" fill-opacity="{shine[1]}"' if shine else 'fill="#ffffff" fill-opacity="0.06"'
    out, defs = [], []

    # ----- El marco (arriba a la izquierda en el lienzo) -----
    x0, y0 = 0, 0
    pos = {  # trozo: (x, y, ancho, alto)
        'topleft': (x0, y0, R, R), 'top': (x0 + R + 2, y0, E, R), 'topright': (x0 + R + E + 4, y0, R, R),
        'left': (x0, y0 + R + 2, R, E), 'center': (x0 + R + 2, y0 + R + 2, E, E),
        'right': (x0 + R + E + 4, y0 + R + 2, R, E),
        'bottomleft': (x0, y0 + R + E + 4, R, R), 'bottom': (x0 + R + 2, y0 + R + E + 4, E, R),
        'bottomright': (x0 + R + E + 4, y0 + R + E + 4, R, R),
    }

    def corner(cx, cy, dx, dy):
        """Cuarto de círculo de radio R con la esquina hacia (dx, dy) (±1)."""
        ax, ay = (cx + R if dx < 0 else cx), (cy + R if dy < 0 else cy)   # centro del arco
        sx, sy = ax + dx * R, ay                                        # punto en el lado
        ex, ey = ax, ay + dy * R                                        # punto arriba/abajo
        sweep = 1 if dx * dy > 0 else 0
        return f'M{ax} {ay} L{sx} {sy} A{R} {R} 0 0 {sweep} {ex} {ey} Z'

    def corner_ring(cx, cy, dx, dy, r_out, r_in):
        ax, ay = (cx + R if dx < 0 else cx), (cy + R if dy < 0 else cy)
        sweep = 1 if dx * dy > 0 else 0
        o1 = (ax + dx * r_out, ay)
        o2 = (ax, ay + dy * r_out)
        i2 = (ax, ay + dy * r_in)
        i1 = (ax + dx * r_in, ay)
        return (f'M{o1[0]} {o1[1]} A{r_out} {r_out} 0 0 {sweep} {o2[0]} {o2[1]} L{i2[0]} {i2[1]} '
                f'A{r_in} {r_in} 0 0 {1 - sweep} {i1[0]} {i1[1]} Z')

    dirs = {'topleft': (-1, -1), 'topright': (1, -1), 'bottomleft': (-1, 1), 'bottomright': (1, 1)}
    for name, (x, y, w, h) in pos.items():
        g = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>']
        if name in dirs:
            dx, dy = dirs[name]
            g.append(f'<path d="{corner(x, y, dx, dy)}" {body}/>')
            g.append(f'<path d="{corner_ring(x, y, dx, dy, R, R - 1)}" {border}/>')
            if highlight and dy < 0:
                g.append(f'<path d="{corner_ring(x, y, dx, dy, R - 1, R - 2)}" {shine}/>')
        else:
            g.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" {body}/>')
            if name == 'top':
                g.append(f'<rect x="{x}" y="{y}" width="{w}" height="1" {border}/>')
                if highlight:
                    g.append(f'<rect x="{x}" y="{y + 1}" width="{w}" height="1" {shine}/>')
            if name == 'bottom':
                g.append(f'<rect x="{x}" y="{y + h - 1}" width="{w}" height="1" {border}/>')
            if name == 'left':
                g.append(f'<rect x="{x}" y="{y}" width="1" height="{h}" {border}/>')
            if name == 'right':
                g.append(f'<rect x="{x + w - 1}" y="{y}" width="1" height="{h}" {border}/>')
        out.append(f'<g id="{name}">{"".join(g)}</g>')

    # Pistas: márgenes del contenido e insets (0)
    out += [
        f'<rect id="hint-top-margin" x="{R + 2}" y="0" width="4" height="{M}" fill="none"/>',
        f'<rect id="hint-bottom-margin" x="{R + 2}" y="{2 * R + E + 4 - M}" width="4" height="{M}" fill="none"/>',
        f'<rect id="hint-left-margin" x="0" y="{R + 2}" width="{M}" height="4" fill="none"/>',
        f'<rect id="hint-right-margin" x="{2 * R + E + 4 - M}" y="{R + 2}" width="{M}" height="4" fill="none"/>',
        '<rect id="hint-tile-center" x="0" y="0" width="5" height="5" fill="none"/>',
    ]
    if extra_hints:
        out += [f'<rect id="hint-{s}-inset" x="0" y="0" width="{0.00000001 if s in ("left", "right") else 4}" '
                f'height="{0.00000001 if s in ("top", "bottom") else 4}" fill="none"/>'
                for s in ('top', 'bottom', 'left', 'right')]

    # ----- Máscara (la forma, para el desenfoque de detrás) -----
    mx = 2 * R + E + 20
    for name, (x, y, w, h) in pos.items():
        x += mx
        if name in dirs:
            dx, dy = dirs[name]
            out.append(f'<g id="mask-{name}"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" '
                       f'fill-opacity="0"/><path d="{corner(x, y, dx, dy)}" fill="#000"/></g>')
        else:
            out.append(f'<rect id="mask-{name}" x="{x}" y="{y}" width="{w}" height="{h}" fill="#000"/>')

    # ----- Sombra -----
    sx0 = 2 * mx
    stops = (f'<stop offset="{R / S:.3f}" stop-color="#000" stop-opacity="{shadow_alpha}"/>'
             f'<stop offset="{(R + (S - R) * 0.35) / S:.3f}" stop-color="#000" stop-opacity="{shadow_alpha * 0.4:.3f}"/>'
             f'<stop offset="1" stop-color="#000" stop-opacity="0"/>')
    lin = (f'<stop offset="{R / S:.3f}" stop-color="#000" stop-opacity="{shadow_alpha}"/>'
           f'<stop offset="{(R + (S - R) * 0.35) / S:.3f}" stop-color="#000" stop-opacity="{shadow_alpha * 0.4:.3f}"/>'
           f'<stop offset="1" stop-color="#000" stop-opacity="0"/>')
    for name, (cx, cy) in {'topleft': (1, 1), 'topright': (0, 1), 'bottomleft': (1, 0), 'bottomright': (0, 0)}.items():
        defs.append(f'<radialGradient id="g-{name}" cx="{cx}" cy="{cy}" r="1">{stops}</radialGradient>')
    for name, (x1, y1, x2, y2) in {'top': (0, 1, 0, 0), 'bottom': (0, 0, 0, 1), 'left': (1, 0, 0, 0),
                                   'right': (0, 0, 1, 0)}.items():
        defs.append(f'<linearGradient id="g-{name}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{lin}</linearGradient>')
    spos = {
        'topleft': (0, 0, S, S), 'top': (S + 2, 0, E, S), 'topright': (S + E + 4, 0, S, S),
        'left': (0, S + 2, S, E), 'center': (S + 2, S + 2, E, E), 'right': (S + E + 4, S + 2, S, E),
        'bottomleft': (0, S + E + 4, S, S), 'bottom': (S + 2, S + E + 4, E, S), 'bottomright': (S + E + 4, S + E + 4, S, S),
    }
    for name, (x, y, w, h) in spos.items():
        x += sx0
        fill = 'fill="#000" fill-opacity="0"' if name == 'center' else f'fill="url(#g-{name})"'
        out.append(f'<rect id="shadow-{name}" x="{x}" y="{y}" width="{w}" height="{h}" {fill}/>')
    out += [
        f'<rect id="shadow-hint-top-margin" x="{sx0}" y="0" width="2" height="{shadow_size}" fill="none"/>',
        f'<rect id="shadow-hint-bottom-margin" x="{sx0}" y="0" width="2" height="{shadow_size}" fill="none"/>',
        f'<rect id="shadow-hint-left-margin" x="{sx0}" y="0" width="{shadow_size}" height="2" fill="none"/>',
        f'<rect id="shadow-hint-right-margin" x="{sx0}" y="0" width="{shadow_size}" height="2" fill="none"/>',
        f'<rect id="shadow-hint-top-inset" x="{sx0}" y="0" width="2" height="{R}" fill="none"/>',
        f'<rect id="shadow-hint-bottom-inset" x="{sx0}" y="0" width="2" height="{R}" fill="none"/>',
        f'<rect id="shadow-hint-left-inset" x="{sx0}" y="0" width="{R}" height="2" fill="none"/>',
        f'<rect id="shadow-hint-right-inset" x="{sx0}" y="0" width="{R}" height="2" fill="none"/>',
    ]
    w = sx0 + 2 * S + E + 8
    h = max(2 * S + E + 8, 2 * R + E + 8)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            f'<defs>{"".join(defs)}</defs>\n' + '\n'.join(out) + '\n</svg>\n')


def plain_frames(items, R, M):
    """Varios marcos de 9 trozos sin sombra, uno por prefijo (normal, hover, selected…), con sus pistas de margen.
    items: [(prefijo, relleno, opacidad, borde o None, opacidad del borde)]."""
    E = 6
    out = ['<rect id="hint-tile-center" x="0" y="0" width="5" height="5" fill="none"/>']
    size = 2 * R + E + 4

    def corner(ax, ay, dx, dy, rr):
        sweep = 1 if dx * dy > 0 else 0
        return f'M{ax} {ay} L{ax + dx * rr} {ay} A{rr} {rr} 0 0 {sweep} {ax} {ay + dy * rr} Z'

    for row, (prefix, fill, op, border, bop) in enumerate(items):
        y0 = row * (size + 6)
        pos = {'topleft': (0, 0, R, R), 'top': (R + 2, 0, E, R), 'topright': (R + E + 4, 0, R, R),
               'left': (0, R + 2, R, E), 'center': (R + 2, R + 2, E, E), 'right': (R + E + 4, R + 2, R, E),
               'bottomleft': (0, R + E + 4, R, R), 'bottom': (R + 2, R + E + 4, E, R),
               'bottomright': (R + E + 4, R + E + 4, R, R)}
        dirs = {'topleft': (-1, -1), 'topright': (1, -1), 'bottomleft': (-1, 1), 'bottomright': (1, 1)}
        body = f'fill="{fill}" fill-opacity="{op}"'
        for name, (x, y, w, h) in pos.items():
            y += y0
            g = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000" fill-opacity="0"/>']
            if name in dirs:
                dx, dy = dirs[name]
                ax, ay = (x + R if dx < 0 else x), (y + R if dy < 0 else y)
                g.append(f'<path d="{corner(ax, ay, dx, dy, R)}" {body}/>')
                if border:
                    sweep = 1 if dx * dy > 0 else 0
                    g.append(f'<path d="M{ax + dx * R} {ay} A{R} {R} 0 0 {sweep} {ax} {ay + dy * R} L{ax} {ay + dy * (R - 1)} '
                             f'A{R - 1} {R - 1} 0 0 {1 - sweep} {ax + dx * (R - 1)} {ay} Z" fill="{border}" fill-opacity="{bop}"/>')
            else:
                g.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" {body}/>')
                if border and name != 'center':
                    bx, by, bw, bh = {'top': (x, y, w, 1), 'bottom': (x, y + h - 1, w, 1), 'left': (x, y, 1, h),
                                      'right': (x + w - 1, y, 1, h)}[name]
                    g.append(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="{border}" fill-opacity="{bop}"/>')
            out.append(f'<g id="{prefix}-{name}">{"".join(g)}</g>')
        for s in ('top', 'bottom', 'left', 'right'):
            out.append(f'<rect id="{prefix}-hint-{s}-margin" x="0" y="{y0}" width="{M if s in ("left", "right") else 2}" '
                       f'height="{M if s in ("top", "bottom") else 2}" fill="none"/>')
    w, h = 2 * R + E + 8, len(items) * (size + 6)
    return out, w, h


def svg_doc(parts, w, h):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">\n'
            + '\n'.join(parts) + '\n</svg>\n')


def tabbar():
    """La raya que pinta Plasma en un panel junto a lo que tiene el foco (widgets/tabbar, «<borde>-active-tab»). Sin las
    de «west» y «east» no pinta nada en los paneles de los lados (allí la raya cruzaba el panel de arriba abajo al lado de
    lo que escribías). La de la isla (abajo: «south»; arriba: «north»), 3 px del acento en su borde de dentro."""
    p = []
    for k, (prefix, line) in enumerate((('south-active-tab', 'top'), ('north-active-tab', 'bottom'))):
        x0 = k * 40
        cells = {'topleft': (0, 0, 6, 3), 'top': (6, 0, 20, 3), 'topright': (26, 0, 6, 3),
                 'left': (0, 3, 6, 20), 'center': (6, 3, 20, 20), 'right': (26, 3, 6, 20),
                 'bottomleft': (0, 23, 6, 3), 'bottom': (6, 23, 20, 3), 'bottomright': (26, 23, 6, 3)}
        for name, (x, y, w, h) in cells.items():
            on = name.startswith(line)
            p.append(f'<rect id="{prefix}-{name}" x="{x0 + x}" y="{y}" width="{w}" height="{h}" fill="{ACCENT}" '
                     f'fill-opacity="{1 if on else 0}"/>')
        for side, (x, y, w, h) in {'left': (0, 30, 6, 2), 'right': (26, 30, 6, 2), 'top': (12, 34, 2, 3),
                                   'bottom': (16, 34, 2, 3)}.items():
            p.append(f'<rect id="{prefix}-hint-{side}-margin" x="{x0 + x}" y="{y}" width="{w}" height="{h}" fill="none"/>')
    return svg_doc(p, 80, 40)


def widgets():
    """Las piezas de los menús y ventanitas de Plasma con las formas de Ágape: la fila de una lista (al pasar, la
    elegida), los botones, los campos de texto, los deslizadores (como el del volumen) y las barras de progreso."""
    files = {}
    # Listas: al pasar, el fondo suave; la elegida, el rosa suave
    p, w, h = plain_frames([('normal', TEXT, 0, None, 0), ('hover', TEXT, 0.07, None, 0),
                            ('selected', ACCENT, 0.22, None, 0), ('selected+hover', ACCENT, 0.3, None, 0)], r(10), 6)
    files['widgets/viewitem.svg'] = svg_doc(p, w, h)
    # Botones y botones de barra (los de Ágape: fondo suave, radio 12)
    p, w, h = plain_frames([('normal', TEXT, 0.07, TEXT, 0.08), ('hover', TEXT, 0.11, TEXT, 0.1),
                            ('pressed', TEXT, 0.15, TEXT, 0.1), ('focus', TEXT, 0.07, ACCENT, 0.9),
                            ('toolbutton-hover', TEXT, 0.08, None, 0), ('toolbutton-pressed', TEXT, 0.14, None, 0),
                            ('toolbutton-focus', TEXT, 0.06, ACCENT, 0.9)], r(12), 6)
    files['widgets/button.svg'] = svg_doc(p, w, h)
    # Campos de texto (como la barra de direcciones de Ágape)
    p, w, h = plain_frames([('base', TEXT, 0.07, None, 0), ('hover', TEXT, 0.09, TEXT, 0.12),
                            ('focus', TEXT, 0.07, ACCENT, 0.95)], r(12), 6)
    files['widgets/lineedit.svg'] = svg_doc(p, w, h)
    # Barras de progreso: una pastilla fina, rosa lo hecho
    p, w, h = plain_frames([('bar-inactive', TEXT, 0.12, None, 0), ('bar-active', ACCENT, 1, None, 0)], 3, 0)
    p.append(f'<rect id="hint-bar-size" x="0" y="0" width="6" height="6" fill="none"/>')
    files['widgets/bar_meter_horizontal.svg'] = svg_doc(p, w, h)
    # Deslizadores: la ranura fina y el tirador redondo blanco (con el anillo rosa al tener el foco)
    p, w, h = plain_frames([('groove', TEXT, 0.14, None, 0), ('groove-highlight', ACCENT, 1, None, 0)], 3, 0)
    y = h + 10
    for kind in ('horizontal', 'vertical'):
        p += [f'<circle id="{kind}-slider-handle" cx="{12}" cy="{y + 12}" r="9" fill="#ffffff"/>',
              f'<g id="{kind}-slider-hover"><circle cx="{40}" cy="{y + 12}" r="11" fill="{ACCENT}" fill-opacity="0.25"/>'
              f'<circle cx="40" cy="{y + 12}" r="9" fill="#ffffff"/></g>',
              f'<g id="{kind}-slider-focus"><circle cx="{68}" cy="{y + 12}" r="11" fill="{ACCENT}"/>'
              f'<circle cx="68" cy="{y + 12}" r="9" fill="#ffffff"/></g>',
              f'<circle id="{kind}-slider-shadow" cx="{96}" cy="{y + 13}" r="10" fill="#000" fill-opacity="0.25"/>']
        y += 30
    p.append(f'<rect id="hint-handle-size" x="0" y="{h + 10}" width="24" height="24" fill="none"/>')
    files['widgets/slider.svg'] = svg_doc(p, max(w, 110), y)
    return files


def main():
    root = os.path.join(DST, THEME)
    files = {
        # Isla y columna de pisos: cristal de Ágape
        # (el brillo de arriba, del color del piso: como el cristal de los paneles de los lados, «Cristal con tu fondo»)
        'translucent/widgets/panel-background.svg': frame_svg(r(20), 6, SURFACE, CRISTAL, 22, 0.32, shine=(ACCENT, 0.45)),
        'widgets/panel-background.svg': frame_svg(r(20), 6, CHROME, 0.97, 22, 0.32),
        # Menús, avisos y ventanitas: tarjeta de Ágape
        'translucent/dialogs/background.svg': frame_svg(r(16), 12, CHROME, min(0.98, CRISTAL + 0.35), 32, 0.45),
        'dialogs/background.svg': frame_svg(r(16), 12, CHROME, 0.98, 32, 0.45),
        # Bocadillos
        'translucent/widgets/tooltip.svg': frame_svg(r(10), 8, CHROME, 0.94, 16, 0.35, highlight=False),
        'widgets/tooltip.svg': frame_svg(r(10), 8, CHROME, 0.98, 16, 0.35, highlight=False),
    }
    files['widgets/tabbar.svg'] = tabbar()
    files.update(widgets())
    for rel, text in files.items():
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(text)
    with open(os.path.join(root, 'metadata.json'), 'w') as f:
        json.dump({
            'KPlugin': {
                'Id': THEME, 'Name': 'Apogeo' if THEME == 'apogeo' else 'Apogeo (tu aspecto)', 'Description': 'El cristal y las tarjetas de Ágape',
                'Authors': [{'Name': 'Ares'}], 'License': 'MIT', 'Version': '1.0', 'Category': '',
            },
            'X-Plasma-API-Minimum-Version': '6.0',
        }, f, ensure_ascii=False, indent=4)
    # El desenfoque de detrás, con la saturación de Ágape (blur 26px saturate 1.5)
    with open(os.path.join(root, 'plasmarc'), 'w') as f:
        f.write('[ContrastEffect]\nenabled=true\ncontrast=1\nintensity=1\nsaturation=1.5\n\n'
                '[AdaptiveTransparency]\nenabled=false\n')
    print('Plasma: estilo', THEME)


if __name__ == '__main__':
    main()
