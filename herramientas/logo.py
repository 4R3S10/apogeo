#!/usr/bin/python3
"""
El símbolo de Apogeo —«Núcleo»—: un punto sólido rodeado por tres órbitas abiertas, cada una con su nodo. Geométrico,
legible a 16 px y a 512 px, y a gusto en el grafito de Órbita. La identidad clásica (el búho) se conserva en
logo-clasico.py.

  logo.py <carpeta> [acento]    escribe logo.svg, logo-silueta.svg y aleteo-00.svg … aleteo-23.svg (las órbitas girando
                                despacio para el arranque; el nombre de los fotogramas se queda para no romper Plymouth)
"""
import math
import os
import sys

ACCENT = sys.argv[2] if len(sys.argv) > 2 else '#45d6ff'
DISC = '#0b0e14'
RING = '#1c2430'
TEXT = '#e9edf5'
MUTED = '#8b94a7'
FRAMES = 24

# Los tres arcos: (rotación, color, opacidad). El primero es el del modo de serie (Navegar): cian.
ARCS = ((0, ACCENT, 1.0), (120, TEXT, 0.42), (240, TEXT, 0.28))
SPAN = 82           # grados que ocupa cada arco
RADIUS = 27.5


def pt(angle, radius=RADIUS, cx=50, cy=50):
    a = math.radians(angle - 90)
    return cx + radius * math.cos(a), cy + radius * math.sin(a)


def f2(x, y):
    return f'{x:.2f} {y:.2f}'


def arc(rot, color, opacity):
    """Un arco abierto, con un nodo en su punta."""
    a0, a1 = -SPAN / 2, SPAN / 2
    p0, p1 = pt(a0 + rot), pt(a1 + rot)
    n = pt(a1 + rot, RADIUS, 50, 50)
    # (una vuelta casi completa: el hueco queda entre el final de un arco y el principio del siguiente)
    return (f'<path d="M{f2(*p0)} A{RADIUS} {RADIUS} 0 0 1 {f2(*p1)}" fill="none" stroke="{color}" '
            f'stroke-width="2.6" stroke-linecap="round" opacity="{opacity}"/>'
            f'<circle cx="{n[0]:.2f}" cy="{n[1]:.2f}" r="2.9" fill="{color}" opacity="{opacity}"/>')


def nucleo(rot=0, pulse=0.0, disc=True):
    body = ''
    if disc:
        body += (f'<circle cx="50" cy="50" r="48" fill="{DISC}"/>'
                 f'<circle cx="50" cy="50" r="47.25" fill="none" stroke="{RING}" stroke-width="1.5"/>')
    arcs = ''.join(arc(r + rot, c, o) for r, c, o in ARCS)
    # El núcleo: un punto sólido con un halo muy leve del acento
    core_r = 7.4 + pulse
    body += (f'<circle cx="50" cy="50" r="{core_r + 5.6:.2f}" fill="{ACCENT}" opacity="0.10"/>'
             f'<circle cx="50" cy="50" r="{core_r:.2f}" fill="{TEXT}"/>'
             f'<circle cx="47.4" cy="47.2" r="{core_r * 0.28:.2f}" fill="{ACCENT}" opacity="0.85"/>')
    body += f'<g>{arcs}</g>'
    return body


def svg(rot=0, pulse=0.0, disc=True):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">\n'
            f'  <!-- Núcleo: un punto y tres órbitas abiertas -->\n  {nucleo(rot, pulse, disc)}\n</svg>\n')


if __name__ == '__main__':
    M = sys.argv[1]
    os.makedirs(M, exist_ok=True)
    open(f'{M}/logo.svg', 'w').write(svg())
    open(f'{M}/logo-silueta.svg', 'w').write(svg(disc=False))
    for i in range(FRAMES):
        angle = i * (180 / FRAMES)
        open(f'{M}/aleteo-{i:02d}.svg', 'w').write(svg(rot=angle, pulse=0.45 * math.sin(2 * math.pi * i / FRAMES)))
