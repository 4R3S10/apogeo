#!/usr/bin/python3
"""
El logo de Apogeo: la silueta de un angelito volando (como los putti de los museos, del arte y de las esculturas), en el
rosa de Ágape sobre un disco berenjena. Se dibuja juntando formas sencillas del mismo color (cabeza, rizos, mofletes,
tronco, brazos, piernas y unas alas de plumas en abanico), así que todo queda como una sola silueta.

  logo.py <carpeta>    escribe logo.svg y logo-silueta.svg
"""
import math, sys
M = sys.argv[1]

def cap(x1, y1, x2, y2, r1, r2=None):
    """Miembro redondeado (de grosor r1 a r2), como un trozo de brazo o pierna."""
    r2 = r1 if r2 is None else r2
    a = math.atan2(y2 - y1, x2 - x1); n = (-math.sin(a), math.cos(a))
    p = lambda x, y, r, s: f'{x + s*r*n[0]:.2f} {y + s*r*n[1]:.2f}'
    return (f'<path d="M{p(x1,y1,r1,1)} L{p(x2,y2,r2,1)} A{r2} {r2} 0 0 0 {p(x2,y2,r2,-1)} '
            f'L{p(x1,y1,r1,-1)} A{r1} {r1} 0 0 0 {p(x1,y1,r1,1)} Z"/>')

def ell(cx, cy, rx, ry, rot=0): return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({rot} {cx} {cy})"/>'
def circ(cx, cy, r): return f'<circle cx="{cx}" cy="{cy}" r="{r}"/>'

def wing(bx, by, tipx, tipy, n=6, spread=1.0):
    """Ala de plumas: una forma que sube desde la espalda hasta la punta, con el borde de abajo festoneado."""
    # borde de arriba: curva de la espalda a la punta
    out = [f'M{bx} {by} C{bx-2} {by-12} {tipx+10} {tipy-2} {tipx} {tipy}']
    # borde de abajo: plumas redondeadas de la punta hacia la espalda
    for i in range(1, n + 1):
        t = i / n
        x = tipx + (bx - tipx) * t + 3*spread * math.sin(math.pi * t)
        y = tipy + (by - tipy) * t + 8*spread * math.sin(math.pi * t) * 0.9
        px = tipx + (bx - tipx) * (t - 1/n) + 3*spread * math.sin(math.pi * (t - 1/n))
        py = tipy + (by - tipy) * (t - 1/n) + 8*spread * math.sin(math.pi * (t - 1/n)) * 0.9
        mx, my = (x + px) / 2, (y + py) / 2
        # cada pluma sobresale hacia abajo-izquierda
        out.append(f'Q{mx - 3.2*spread:.1f} {my + 4.2*spread:.1f} {x:.1f} {y:.1f}')
    out.append('Z')
    return f'<path d="{" ".join(out)}"/>'

def body():
    s = []
    # cabeza y rizos
    s += [circ(64.6, 32.6, 8.4)]
    s += [circ(x, y, r) for x, y, r in [(57.8, 27, 3.7), (61.8, 23.6, 3.8), (66.6, 23.2, 3.4), (55.6, 32, 3.4), (56.6, 37.4, 3.1)]]
    # de perfil, mirando a la derecha: frente, nariz chata, moflete y barbilla
    s += [circ(73.4, 33.6, 1.9), circ(70.4, 37.2, 3.9), circ(67.4, 40.2, 3.4)]
    # cuello y tronco rechoncho, inclinado al volar
    s += [ell(52, 46, 12.5, 9.2, -24), ell(45, 52, 8.6, 7.4, -10)]
    # brazo de delante, extendido hacia arriba y adelante
    s += [cap(60, 42, 70, 41, 3.6, 3.0), cap(70, 41, 78.5, 35, 3.0, 2.5), circ(79.6, 34.2, 2.9)]
    # brazo de detrás
    s += [cap(55, 41, 49.6, 36.6, 3.2, 2.6), circ(48.6, 35.6, 2.6)]
    # pierna de delante doblada, pie hacia atrás
    s += [cap(44, 54, 41, 63, 5.8, 4.4), cap(41, 63, 33, 64.6, 4.0, 3.0), ell(30.6, 64.2, 3.4, 2.4, 10)]
    # pierna de detrás, más estirada
    s += [cap(39, 51, 29, 54, 5.6, 4.0), cap(29, 54, 21.6, 59.6, 3.8, 2.8), ell(19.8, 60.6, 3.2, 2.2, 30)]
    return ''.join(s)

def fan(bx, by, a0, a1, lens, w):
    """Ala como en los cuadros: plumas largas que salen en abanico del hombro (las de atrás más largas) y una masa
    redondeada junto a la espalda."""
    out = []
    n = len(lens)
    for i, L in enumerate(lens):
        a = math.radians(a0 + (a1 - a0) * i / (n - 1))
        cx, cy = bx + L / 2 * math.cos(a), by + L / 2 * math.sin(a)
        out.append(ell(round(cx, 2), round(cy, 2), round(L / 2, 2), w, round(math.degrees(a), 1)))
    a = math.radians((a0 + a1) / 2)
    out.append(ell(round(bx + 6 * math.cos(a), 2), round(by + 6 * math.sin(a), 2), 8, 5.6, round(math.degrees(a), 1)))
    return ''.join(out)

def wing_back():
    return fan(49, 41, -132, -96, [22, 26, 28, 27, 23], 3.3)

def wing_front():
    return fan(46, 43, -178, -132, [18, 24, 29, 31, 30, 26, 20], 3.6)

def wings():
    return wing_back() + wing_front()

def svg(inner, note):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">\n  <!-- {note} -->\n{inner}\n</svg>\n'

# El logo de Apogeo («V1 · Silueta rosa»), centrado en el disco, y la silueta sola
T = 'transform="translate(0.8 9.2)"'
logo = svg(f'''  <circle cx="50" cy="50" r="48" fill="#1e1621"/>
  <g fill="#ff8fc6" {T}>{wings()}{body()}</g>''', 'Logo de Apogeo: la silueta de un angelito volando, como los putti de los museos y las esculturas')
sola = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="15 22 70 56">
  <!-- La silueta del angelito de Apogeo, sin el disco -->
  <g fill="#ff8fc6" {T}>{wings()}{body()}</g>
</svg>
'''
open(f'{M}/logo.svg', 'w').write(logo)
open(f'{M}/logo-silueta.svg', 'w').write(sola)
