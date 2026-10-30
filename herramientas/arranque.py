#!/usr/bin/python3
"""
Las imágenes del arranque de Órbita: un fondo grafito con tres órbitas muy tenues (cian, violeta y ámbar), la barra
fina del color de Navegar y el punto de la contraseña. Las usa Plymouth al encender y el splash de Plasma al entrar.

  arranque.py <carpeta>    escribe fondo.png (960×540), barra.png, barra-fondo.png y punto.png
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageOps

W, H = 1920, 1080
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
ACCENT = (69, 214, 255)       # el cian de Navegar
VIOLET = (183, 156, 255)      # el violeta de Jugar
AMBER = (255, 179, 92)        # el ámbar de Estudiar
TEXT = (233, 237, 245)


def fondo():
    """Grafito, un resplandor central y tres arcos orbitales abiertos, cada uno con su nodo."""
    top, bottom = (6, 8, 12), (13, 17, 24)
    strip = Image.new('RGB', (1, H))
    for y in range(H):
        t = y / (H - 1)
        strip.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    img = strip.resize((W, H)).convert('RGBA')

    def glow(cx, cy, radius, color, strength):
        size = max(2, radius * 2)
        mask = ImageOps.invert(Image.radial_gradient('L').resize((size, size), Image.LANCZOS))
        mask = mask.point(lambda v: int(v * strength))
        layer = Image.new('RGBA', (size, size), color + (0,))
        layer.putalpha(mask)
        img.alpha_composite(layer, (int(cx - radius), int(cy - radius)))

    cx, cy = W * 0.5, H * 0.44
    glow(cx, cy, 620, ACCENT, 0.075)
    glow(W * 0.22, H * 0.30, 380, VIOLET, 0.045)
    glow(W * 0.80, H * 0.72, 420, AMBER, 0.030)

    # Los arcos: (radio x, radio y, giro, color, opacidad, empieza, acaba)
    arcos = ((560, 168, -9, ACCENT, 54, 148, 328),
             (472, 142, 7, VIOLET, 40, 210, 390),
             (392, 118, -3, AMBER, 24, 30, 205))
    capa = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    for rx, ry, giro, color, alpha, a0, a1 in arcos:
        one = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(one)
        d.arc([cx - rx, cy - ry, cx + rx, cy + ry], a0, a1, fill=color + (alpha,), width=3)
        import math
        for ang in (a0, a1):
            x = cx + rx * math.cos(math.radians(ang))
            y = cy + ry * math.sin(math.radians(ang))
            d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=color + (min(255, alpha + 45),))
        capa.alpha_composite(one.rotate(giro, center=(cx, cy), resample=Image.BICUBIC))
    capa = capa.filter(ImageFilter.GaussianBlur(0.6))
    img.alpha_composite(capa)

    # Unas estrellas muy quietas (deterministas)
    import random
    rnd = random.Random(7)
    estrella = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(estrella)
    for _ in range(150):
        x, y = rnd.randrange(W), rnd.randrange(H)
        a = rnd.randrange(6, 30)
        r = 1 if rnd.random() < 0.82 else 2
        d.ellipse([x, y, x + r, y + r], fill=TEXT + (a,))
    img.alpha_composite(estrella)

    # Viñeta: el centro respira, los bordes se apagan
    vig = Image.radial_gradient('L').resize((W, H), Image.LANCZOS).point(lambda v: int(v * 0.55))
    negro = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    negro.putalpha(vig)
    img.alpha_composite(negro)
    return img.convert('RGB').resize((960, 540), Image.LANCZOS)


def barra(ancho=240, alto=4, color=(255, 255, 255, 30)):
    im = Image.new('RGBA', (ancho, alto), (0, 0, 0, 0))
    ImageDraw.Draw(im).rounded_rectangle([0, 0, ancho - 1, alto - 1], radius=alto / 2, fill=color)
    return im


def punto():
    im = Image.new('RGBA', (12, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, 11, 11], fill=ACCENT + (255,))
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    fondo().save(os.path.join(OUT, 'fondo.png'), optimize=True)
    barra(color=(255, 255, 255, 30)).save(os.path.join(OUT, 'barra-fondo.png'), optimize=True)
    barra(color=ACCENT + (255,)).save(os.path.join(OUT, 'barra.png'), optimize=True)
    punto().save(os.path.join(OUT, 'punto.png'), optimize=True)
    print('Arranque: fondo, barra y punto')


if __name__ == '__main__':
    main()
