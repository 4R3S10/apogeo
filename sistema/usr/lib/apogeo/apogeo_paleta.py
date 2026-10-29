"""
Los colores que salen del fondo (Ajustes → Aspecto → «Del fondo»): de la imagen o el vídeo de cada piso se saca su
color (el tono que más se ve, con su viveza) y con él, todo: el acento, el fondo y la superficie oscuros de ese tono, el
texto y los colores de los fondos animados. Como en Material You, pero con la forma de Ágape (oscuro, un solo acento).

Los fondos animados de Apogeo no son una foto: su color lo eliges tú (pisos.X.color, de COLORS); sin elegir, el rosa de
Apogeo (None: lo de siempre).

Lo sacado se guarda en ~/.cache/apogeo/paletas.json (por archivo y fecha): no se vuelve a mirar la imagen.
"""
import colorsys
import json
import math
import os
import subprocess
import threading

HOME = os.path.expanduser('~')
CACHE = os.path.join(os.environ.get('XDG_CACHE_HOME', os.path.join(HOME, '.cache')), 'apogeo', 'paletas.json')
VIDEOS = ('.mp4', '.webm', '.mkv', '.mov', '.m4v', '.avi')
# Los colores que puedes dar a un fondo animado ('' = el rosa de Apogeo)
COLORS = {'': 'Rosa de Apogeo', '#f2939b': 'Rojo', '#f5ae86': 'Naranja', '#f2c48d': 'Ámbar', '#9ed9b0': 'Verde',
          '#86d6c6': 'Menta', '#8fb4f2': 'Azul', '#bfa6ee': 'Lila', '#f59cc9': 'Chicle'}
_lock = threading.Lock()


def _hex(h, l, s):
    return '#' + ''.join(f'{round(max(0, min(1, c)) * 255):02x}' for c in colorsys.hls_to_rgb(h % 1, l, s))


def _hls(hexa):
    return colorsys.rgb_to_hls(*(int(hexa[i:i + 2], 16) / 255 for i in (1, 3, 5)))


def palette(hue, sat, accent=None):
    """Todos los colores de un tono (0–1) y su viveza (0–1), en oscuro, con la forma de los de Apogeo."""
    s = max(0.04, min(0.85, sat))
    acc = accent or _hex(hue, 0.74, s)
    return {
        'acento': acc,
        'vivo': _hex(hue, 0.8, min(1, s + 0.15)),
        'sobreAcento': _hex(hue, 0.12, s * 0.5),
        'fondo': _hex(hue, 0.065, min(0.35, s * 0.4)),
        'superficie': _hex(hue, 0.11, min(0.3, s * 0.35)),
        'texto': _hex(hue, 0.93, min(0.4, s * 0.45)),
        'wp': [_hex(hue, 0.23, s * 0.45), _hex(hue, 0.37, s * 0.5), acc],
    }


def of_color(hexa):
    """Los colores de un fondo animado con el color que le diste (None: el rosa de Apogeo)."""
    if hexa not in COLORS or not hexa:
        return None
    h, _l, s = _hls(hexa)
    return palette(h, s, accent=hexa)


def _pixels(path):
    """La imagen (o un fotograma del vídeo) en pequeño: 48×48 puntos RGB."""
    seek = ['-ss', '2'] if path.lower().endswith(VIDEOS) else []
    for extra in (seek, []) if seek else ([],):  # (un vídeo de menos de 2 s: el primer fotograma)
        try:
            out = subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', *extra, '-i', path, '-frames:v', '1',
                                  '-vf', 'scale=48:48', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                                 capture_output=True, timeout=20).stdout
        except (OSError, subprocess.SubprocessError):
            return b''
        if len(out) >= 48 * 48 * 3:
            return out
    return b''


def extract(path):
    """El tono que más se ve en la imagen y su viveza: (tono, viveza), o None si no se puede leer."""
    px = _pixels(path)
    if not px:
        return None
    bins = [0.0] * 24
    hues = [[0.0, 0.0] for _ in range(24)]   # (para el tono medio de cada parte: seno y coseno)
    sats = [0.0] * 24
    gray = [0.0, 0.0, 0.0]
    for i in range(0, len(px) - 2, 3):
        r, g, b = px[i] / 255, px[i + 1] / 255, px[i + 2] / 255
        hi, lo = max(r, g, b), min(r, g, b)
        c = hi - lo
        gray = [gray[0] + r, gray[1] + g, gray[2] + b]
        if c < 0.08:
            continue
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        w = c * c
        k = int(h * 24) % 24
        bins[k] += w
        hues[k][0] += w * math.sin(h * 2 * math.pi)
        hues[k][1] += w * math.cos(h * 2 * math.pi)
        sats[k] += w * s
    total = sum(bins)
    if total < 2:  # (casi en blanco y negro: un gris con un punto del tono que haya)
        n = len(px) // 3
        h, _l, _s = colorsys.rgb_to_hls(gray[0] / n, gray[1] / n, gray[2] / n)
        return (h, 0.06)
    # La parte que más pesa (con las de al lado, que un tono cae entre dos)
    best = max(range(24), key=lambda k: bins[k - 1] + 2 * bins[k] + bins[(k + 1) % 24])
    near = [best - 1, best, (best + 1) % 24]
    sx, cx = sum(hues[k][0] for k in near), sum(hues[k][1] for k in near)
    hue = (math.atan2(sx, cx) / (2 * math.pi)) % 1
    weight = sum(bins[k] for k in near)
    vivid = sum(sats[k] for k in near) / weight if weight else 0.5
    return (hue, 0.35 + vivid * 0.55)


def _load_cache():
    try:
        with open(CACHE) as f:
            c = json.load(f)
        return c if isinstance(c, dict) else {}
    except (OSError, ValueError):
        return {}


def of_file(path):
    """Los colores de una imagen o un vídeo tuyo (None si no se puede leer)."""
    try:
        key = f'{path}|{os.path.getmtime(path)}'
    except OSError:
        return None
    with _lock:
        cache = _load_cache()
        got = cache.get(key)
        if not (isinstance(got, list) and len(got) == 2):
            got = extract(path)
            if got is None:
                return None
            cache = {k: v for k, v in cache.items() if not k.startswith(path + '|')}
            cache[key] = [round(got[0], 4), round(got[1], 4)]
            if len(cache) > 400:  # (los más viejos fuera)
                cache = dict(list(cache.items())[-300:])
            os.makedirs(os.path.dirname(CACHE), exist_ok=True)
            tmp = CACHE + f'.{os.getpid()}'
            with open(tmp, 'w') as f:
                json.dump(cache, f)
            os.replace(tmp, CACHE)
    return palette(*got)


def of_floor(st, floor, wallpaper=None):
    """Los colores de un piso: los de su foto o vídeo, o el color que diste a su animado (None: el rosa de Apogeo).
    «wallpaper»: el fondo que se ve ahora (con «que cambie solo» puede no ser el elegido)."""
    f = st['pisos'][floor]
    wall = wallpaper or f.get('fondo')
    if isinstance(wall, str) and wall.startswith('/') and os.path.isfile(wall):
        return of_file(wall)
    return of_color(f.get('color', ''))
