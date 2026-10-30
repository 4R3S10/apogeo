#!/usr/bin/python3
"""
El símbolo de Apogeo —«Núcleo», «N1 · Una órbita por modo»—: un punto sólido rodeado por tres órbitas abiertas, cada
una con su nodo y del color de su modo (Navegar cian arriba, Estudiar ámbar abajo a la derecha, Jugar violeta abajo a la
izquierda). Geométrico,
legible a 16 px y a 512 px, y a gusto en el grafito de Órbita. La identidad clásica (el búho) se conserva en
logo-clasico.py.

  logo.py <carpeta> [acento]    escribe logo.svg, logo-silueta.svg, las piezas del arranque —disco.svg (el disco y el
                                punto), orbitas.svg (solo las tres órbitas, que Plymouth y el splash giran enteras, sin
                                saltos) y halo.svg (el brillo del punto, que respira)— y forma-00.svg … forma-89.svg (el
                                orbe formándose al encender, uno por refresco: el punto se enciende y las tres órbitas
                                entran girando hasta su sitio; el último es igual que disco + orbitas)
"""
import math
import os
import sys

ACCENT = sys.argv[2] if len(sys.argv) > 2 else '#45d6ff'   # (Navegar)
AMBER, VIOLET = '#ffb35c', '#b79cff'                        # (Estudiar y Jugar)
DISC = '#0b0e14'
RING = '#1c2430'
TEXT = '#e9edf5'
MUTED = '#8b94a7'
FORM = 90           # fotogramas del orbe formándose (1,8 s a los 50 por segundo de Plymouth)

# Los tres arcos: (rotación, color, opacidad), uno por modo
ARCS = ((0, ACCENT, 1.0), (120, AMBER, 1.0), (240, VIOLET, 1.0))
SPAN = 82           # grados que ocupa cada arco
RADIUS = 27.5


def pt(angle, radius=RADIUS, cx=50, cy=50):
    a = math.radians(angle - 90)
    return cx + radius * math.cos(a), cy + radius * math.sin(a)


def f2(x, y):
    return f'{x:.2f} {y:.2f}'


def arc(rot, color, opacity, span=SPAN):
    """Un arco abierto, con un nodo en su punta."""
    if span < 1 or opacity <= 0:
        return ''
    a0, a1 = -SPAN / 2, -SPAN / 2 + span
    p0, p1 = pt(a0 + rot), pt(a1 + rot)
    n = pt(a1 + rot, RADIUS, 50, 50)
    # (una vuelta casi completa: el hueco queda entre el final de un arco y el principio del siguiente)
    return (f'<path d="M{f2(*p0)} A{RADIUS} {RADIUS} 0 0 1 {f2(*p1)}" fill="none" stroke="{color}" '
            f'stroke-width="3" stroke-linecap="round" opacity="{opacity}"/>'
            f'<circle cx="{n[0]:.2f}" cy="{n[1]:.2f}" r="3.2" fill="{color}" opacity="{opacity}"/>')


def nucleo(rot=0, pulse=0.0, disc=True):
    body = ''
    if disc:
        body += (f'<circle cx="50" cy="50" r="48" fill="{DISC}"/>'
                 f'<circle cx="50" cy="50" r="47.25" fill="none" stroke="{RING}" stroke-width="1.5"/>')
    arcs = ''.join(arc(r + rot, c, o) for r, c, o in ARCS)
    # El núcleo: un punto sólido con un halo muy leve
    core_r = 7.4 + pulse
    body += (f'<circle cx="50" cy="50" r="{core_r + 5.6:.2f}" fill="{TEXT}" opacity="0.07"/>'
             f'<circle cx="50" cy="50" r="{core_r:.2f}" fill="{TEXT}"/>')
    body += f'<g>{arcs}</g>'
    return body


def ease(t):
    t = min(1.0, max(0.0, t))
    return 1 - (1 - t) ** 3


def forma(t):
    """El orbe formándose (t de 0 a 1): primero el disco y el punto, que se enciende con un pequeño rebote, y luego cada
    órbita, una tras otra, entra girando desde atrás mientras se alarga hasta su sitio."""
    d = ease(t / 0.25)
    body = (f'<circle cx="50" cy="50" r="48" fill="{DISC}" opacity="{d:.3f}"/>'
            f'<circle cx="50" cy="50" r="47.25" fill="none" stroke="{RING}" stroke-width="1.5" opacity="{d:.3f}"/>')
    c = min(1.0, max(0.0, (t - 0.05) / 0.3))
    core_r = 7.4 * (1 + 0.35 * math.sin(math.pi * c)) * ease(c * 1.6) if c > 0 else 0
    if core_r > 0.1:
        body += (f'<circle cx="50" cy="50" r="{core_r + 5.6 * c:.2f}" fill="{TEXT}" opacity="{0.07 + 0.18 * (1 - c):.3f}"/>'
                 f'<circle cx="50" cy="50" r="{core_r:.2f}" fill="{TEXT}"/>')
    arcs = ''
    for i, (r, col, o) in enumerate(ARCS):
        a = ease((t - 0.25 - 0.12 * i) / 0.45)
        arcs += arc(r - 70 * (1 - a), col, o * min(1.0, a * 2.5), SPAN * a)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">\n'
            f'  <!-- Núcleo formándose -->\n  {body}<g>{arcs}</g>\n</svg>\n')


def pieza(body, nota):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">\n'
            f'  <!-- {nota} -->\n  {body}\n</svg>\n')


def halo():
    """El brillo del punto, que respira encima del disco (solo su opacidad cambia: sin saltos)."""
    return pieza(f'<defs><radialGradient id="h"><stop offset="0.3" stop-color="{TEXT}" stop-opacity="0.22"/>'
                 f'<stop offset="1" stop-color="{TEXT}" stop-opacity="0"/></radialGradient></defs>'
                 f'<circle cx="50" cy="50" r="19" fill="url(#h)"/>', 'El brillo del Núcleo')


def svg(rot=0, pulse=0.0, disc=True):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">\n'
            f'  <!-- Núcleo: un punto y tres órbitas abiertas -->\n  {nucleo(rot, pulse, disc)}\n</svg>\n')


if __name__ == '__main__':
    M = sys.argv[1]
    os.makedirs(M, exist_ok=True)
    open(f'{M}/logo.svg', 'w').write(svg())
    open(f'{M}/logo-silueta.svg', 'w').write(svg(disc=False))
    # Las piezas del arranque (el último fotograma de «forma» es disco + orbitas, sin el halo)
    nucleo_solo = nucleo().split('<g>')[0]
    open(f'{M}/disco.svg', 'w').write(pieza(nucleo_solo, 'El disco y el punto del Núcleo'))
    open(f'{M}/orbitas.svg', 'w').write(pieza(''.join(arc(r, c, o) for r, c, o in ARCS), 'Las tres órbitas'))
    open(f'{M}/halo.svg', 'w').write(halo())
    for i in range(FORM):
        open(f'{M}/forma-{i:02d}.svg', 'w').write(forma(i / (FORM - 1)))
