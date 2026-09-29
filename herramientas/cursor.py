#!/usr/bin/python3
"""
Cursor de Apogeo («Berenjena»): el cursor de KDE (Breeze, GPL) con el cuerpo berenjena y el borde rosa. Se genera al
construir el paquete a partir del Breeze que trae el sistema: las versiones SVG (Plasma las usa a cualquier tamaño) y las
de siempre (Xcursor, en imágenes) para las apps que no entienden SVG.

  cursor.py [origen] [destino]   por defecto /usr/share/icons/breeze_cursors → /usr/share/icons/Apogeo-cursor
"""
import json
import os
import re
import shutil
import struct
import sys

import cairo
import gi

gi.require_version('Rsvg', '2.0')
from gi.repository import Rsvg  # noqa: E402

SRC = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/icons/breeze_cursors'
DST = sys.argv[2] if len(sys.argv) > 2 else '/usr/share/icons/Apogeo-cursor'
BODY = '#241a28'  # berenjena (el cuerpo, que en Breeze es negro)
EDGE = '#e0a9b4'  # rosa de Ágape (el borde, que en Breeze es blanco)
SIZES = list(range(12, 73, 6))  # los mismos que Breeze


def recolor(svg):
    svg = re.sub(r'#(?:fff|ffffff|fcfcfc)\b', EDGE, svg, flags=re.I)
    svg = re.sub(r'#(?:000|000000|232629|31363b)\b', BODY, svg, flags=re.I)

    # Los trazos sin color son negros: se les pone el berenjena (menos la sombra, que va con opacidad, y el punto de
    # anclaje, que está oculto)
    def fill(m):
        tag = m.group(0)
        if 'fill=' in tag or 'fill:' in tag or 'display="none"' in tag or 'opacity=' in tag:
            return tag
        return tag.replace('<path', f'<path fill="{BODY}"', 1)
    return re.sub(r'<path\b[^>]*>', fill, svg)


def render(svg_path, dim):
    """Pinta el SVG a dim×dim y devuelve los píxeles en ARGB premultiplicado (lo que pide Xcursor)."""
    handle = Rsvg.Handle.new_from_file(svg_path)
    surface = cairo.ImageSurface(cairo.FORMAT_ARGB32, dim, dim)
    rect = Rsvg.Rectangle()
    rect.x, rect.y, rect.width, rect.height = 0, 0, dim, dim
    handle.render_document(cairo.Context(surface), rect)
    surface.flush()
    stride = surface.get_stride()
    data = bytes(surface.get_data())
    return b''.join(data[y * stride:y * stride + dim * 4] for y in range(dim))


def svg_width(path):
    with open(path) as fh:
        m = re.search(r'<svg\b[^>]*\bwidth="([\d.]+)', fh.read())
    return float(m.group(1)) if m else 32.0


def write_xcursor(path, images):
    """Escribe un archivo Xcursor: images = [(tamaño, lado, x, y, retardo, píxeles)]."""
    CHUNK = 0xfffd0002
    toc_size = 16 + 12 * len(images)
    toc, body, pos = [], [], toc_size
    for size, dim, hx, hy, delay, pix in images:
        chunk = struct.pack('<9I', 36, CHUNK, size, 1, dim, dim, hx, hy, delay) + pix
        toc.append(struct.pack('<3I', CHUNK, size, pos))
        body.append(chunk)
        pos += len(chunk)
    with open(path, 'wb') as fh:
        fh.write(b'Xcur' + struct.pack('<3I', 16, 0x10000, len(images)) + b''.join(toc) + b''.join(body))


def main():
    if os.path.exists(DST):
        shutil.rmtree(DST)
    shutil.copytree(SRC, DST, symlinks=True)
    scal = os.path.join(DST, 'cursors_scalable')
    count = 0
    for root, _dirs, files in os.walk(scal):
        for f in files:
            if f.endswith('.svg'):
                p = os.path.join(root, f)
                if os.path.islink(p):
                    continue
                with open(p) as fh:
                    s = fh.read()
                with open(p, 'w') as fh:
                    fh.write(recolor(s))
                count += 1
    print(f'{count} SVG recoloreados')

    # Imágenes de siempre (xcursor), una por cada cursor real (los alias son enlaces y se quedan como estaban)
    curdir = os.path.join(DST, 'cursors')
    made = 0
    for name in sorted(os.listdir(curdir)):
        path = os.path.join(curdir, name)
        meta_path = os.path.join(scal, name, 'metadata.json')
        if os.path.islink(path) or not os.path.exists(meta_path):
            continue
        with open(meta_path) as fh:
            frames = json.load(fh)
        images = []
        for size in SIZES:  # Xcursor quiere los fotogramas de cada tamaño seguidos
            for fr in frames:
                svg = os.path.join(scal, name, fr['filename'])
                # Como Breeze: un cursor de tamaño «nominal» ocupa lo que mide el SVG (32 para 24) a esa escala
                k = size / fr.get('nominal_size', 24)
                dim = round(svg_width(svg) * k)
                pix = render(svg, dim)
                images.append((size, dim, int(fr['hotspot_x'] * k), int(fr['hotspot_y'] * k), fr.get('delay', 50), pix))
        write_xcursor(path, images)
        made += 1
    print(f'{made} cursores generados')

    with open(os.path.join(DST, 'index.theme'), 'w') as fh:
        fh.write('[Icon Theme]\nName=Apogeo\nComment=Cursor de Apogeo (berenjena con borde rosa), basado en Breeze de KDE\n')


if __name__ == '__main__':
    main()
