#!/usr/bin/python3
"""
El logo de Apogeo («R4 · Batiendo»): un búho de frente, a mitad del aleteo, realista pero sencillo. Las plumas van por
capas (primarias largas, secundarias y coberteras) en el rosa de Ágape, separadas por líneas finas del color del disco;
la cara en corazón, el pecho con sus uves y la cola en abanico. Diseño propio.

  logo.py <carpeta>    escribe logo.svg (en el disco berenjena), logo-silueta.svg (el búho solo) y
                       aleteo-00.svg … aleteo-NN.svg (un aleteo completo, para la animación de arranque)
"""
import math
import sys

ROSA = '#ff8fc6'
DISCO = '#1e1621'
LINEA = 0.85
POSE = -20          # el giro de las alas del logo (0 = arriba del todo, -40 = en cruz)


def f2(x, y):
    return f'{x:.2f} {y:.2f}'


def espejo(s):
    return f'<g transform="translate(100 0) scale(-1 1)">{s}</g>'


def pluma(x, y, ang, largo, ancho):
    """Una pluma: base estrecha, lados casi rectos y punta redonda."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux

    def p(t, s):
        return x + ux * largo * t + nx * ancho * s, y + uy * largo * t + ny * ancho * s
    return (f'<path d="M{f2(*p(0, .35))} Q{f2(*p(.25, 1))} {f2(*p(.55, 1))} L{f2(*p(.88, 1))} Q{f2(*p(1, .9))} '
            f'{f2(*p(1, 0))} Q{f2(*p(1, -.9))} {f2(*p(.88, -1))} L{f2(*p(.55, -1))} Q{f2(*p(.25, -1))} {f2(*p(0, -.35))} Z"/>')


def fila(p0, p1, a0, a1, largos, ancho):
    """Una fila de plumas repartidas entre dos puntos, girando de un ángulo a otro."""
    s = ''
    n = len(largos)
    for i, largo in enumerate(largos):
        t = i / (n - 1)
        s += pluma(p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t, a0 + (a1 - a0) * t, largo, ancho)
    return s


def ala(giro):
    """El ala izquierda (la derecha es su espejo), girada alrededor del hombro."""
    hombro, muneca = (45, 47), (29, 30)
    s = fila((26.5, 33.5), (30.2, 28.6), -172, -106, [17, 20, 22, 23, 22.5, 21, 19.5], 3.4)   # primarias
    s += fila((29, 34), (44, 49), 176, 112, [18, 18, 17.5, 16.5, 15.5, 14, 12.5], 3.3)        # secundarias
    s += fila((30, 32.5), (43.5, 46.5), 160, 122, [11, 11, 10.5, 10, 9.5, 9], 3.0)            # coberteras
    s += (f'<path d="M{hombro[0]} {hombro[1] - 3.2} Q37 35 {muneca[0] - 1} {muneca[1] - 1} '
          f'Q33 36 {hombro[0]} {hombro[1] + 3} Z"/>')                                         # el brazo
    return (f'<g transform="rotate({giro} {hombro[0]} {hombro[1]})" fill="{ROSA}" stroke="{DISCO}" '
            f'stroke-width="{LINEA}" stroke-linejoin="round">{s}</g>')


def cola():
    return (f'<path d="M45.5 72 L43.5 81 Q50 84 56.5 81 L54.5 72 Z" fill="{ROSA}"/>'
            f'<path d="M47.5 74 L46.5 82 M50 74 L50 82.6 M52.5 74 L53.5 82" fill="none" stroke="{DISCO}" '
            f'stroke-width="{LINEA}" stroke-linecap="round"/>')


def cuerpo():
    uves = ''
    for y, xs in ((55, (46, 50, 54)), (61, (44, 48, 52, 56)), (67, (47, 50, 53))):
        for x in xs:
            uves += f'M{x - 1.5} {y} L{x} {y + 1.6} L{x + 1.5} {y} '
    return (f'<path d="M40 46 C38 54 39.5 64 44 70 C46 73 48 75 50 76 C52 75 54 73 56 70 C60.5 64 62 54 60 46 Z" '
            f'fill="{ROSA}"/><path d="{uves}" fill="none" stroke="{DISCO}" stroke-width="{LINEA}" '
            f'stroke-linecap="round" stroke-linejoin="round"/>')


def cabeza():
    # la cabeza ancha con sus penachos, la cara en corazón, los ojos y el pico
    return (f'<path d="M38 44 C36 38 36.5 33 39 30 L37.2 21.5 L44.5 27.6 C47.5 26.8 52.5 26.8 55.5 27.6 L62.8 21.5 '
            f'L61 30 C63.5 33 64 38 62 44 C60 49 55 51.5 50 52 C45 51.5 40 49 38 44 Z" fill="{ROSA}"/>'
            f'<path d="M50 31.5 C48.5 29 40.5 28.6 40.3 35.5 C40.2 41 44.5 45 50 48.6 C55.5 45 59.8 41 59.7 35.5 '
            f'C59.5 28.6 51.5 29 50 31.5 Z" fill="none" stroke="{DISCO}" stroke-width="{LINEA * 1.15:.2f}"/>'
            f'<circle cx="45.6" cy="37.6" r="3.1" fill="{DISCO}"/><circle cx="54.4" cy="37.6" r="3.1" fill="{DISCO}"/>'
            f'<circle cx="45.9" cy="37.4" r="1.25" fill="{ROSA}"/><circle cx="54.1" cy="37.4" r="1.25" fill="{ROSA}"/>'
            f'<path d="M48.7 41 L51.3 41 L50 44.6 Z" fill="{DISCO}"/>')


def buho(giro=POSE):
    a = ala(giro)
    return a + espejo(a) + cola() + cuerpo() + cabeza()


def en_disco(giro=POSE):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">\n'
            f'  <!-- Logo de Apogeo: un búho batiendo las alas -->\n'
            f'  <circle cx="50" cy="50" r="48" fill="{DISCO}"/>\n'
            f'  <g transform="translate(50 51) scale(.86) translate(-50 -50)">{buho(giro)}</g>\n</svg>\n')


def silueta(giro=POSE):
    # sin disco: las líneas de las plumas se quedan del color del disco (para fondos oscuros)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1 6 102 86">\n'
            f'  <!-- El búho de Apogeo, sin el disco -->\n  {buho(giro)}\n</svg>\n')


# Un aleteo: las alas suben (0) y bajan hasta casi en cruz (-42), con más tiempo arriba y abajo (como un ave de verdad)
FOTOGRAMAS = 24


def aleteo(i):
    t = i / FOTOGRAMAS
    return -21 - 21 * math.cos(2 * math.pi * t)


if __name__ == '__main__':
    M = sys.argv[1]
    open(f'{M}/logo.svg', 'w').write(en_disco())
    open(f'{M}/logo-silueta.svg', 'w').write(silueta())
    for i in range(FOTOGRAMAS):
        open(f'{M}/aleteo-{i:02d}.svg', 'w').write(en_disco(aleteo(i)))
