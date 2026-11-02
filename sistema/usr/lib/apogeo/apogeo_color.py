"""
El color de un fondo de pantalla («Del fondo», Ajustes → Identidad): como en COSMIC, cada modo coge el color de su fondo
y todo (el acento, el grafito de las ventanas, las barras, el orbe, los menús) se tiñe de él.

Se mira el fondo en pequeño (48 × 48, con ffmpeg: vale para imágenes y para el primer fotograma de un vídeo) y se busca
el tono que más pesa entre los colores vivos (los grises y los negros casi no cuentan). Un fondo sin color (blanco y
negro) da un acento gris claro. El tono se redondea a pasos de 10° para que fondos parecidos compartan temas generados.
Lo calculado se guarda (~/.cache/apogeo/colores-fondo.json) por ruta, tamaño y fecha del archivo.

  color_de(ruta) → {'tono': grados o None (sin color), 'claridad': 0…1} o None (no se pudo leer)
  acento(info, claro) → el acento en hex para el tema oscuro o el claro
"""
import colorsys
import json
import math
import os
import subprocess

CACHE = os.path.join(os.environ.get('XDG_CACHE_HOME', os.path.expanduser('~/.cache')), 'apogeo', 'colores-fondo.json')
SIZE = 48
STEP = 10           # grados: fondos de tono parecido, el mismo acento (y los mismos temas)
GRIS = 0.16         # con menos color medio que esto, el fondo cuenta como blanco y negro


def _read_cache():
    try:
        with open(CACHE) as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _write_cache(data):
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        tmp = CACHE + '.nuevo'
        with open(tmp, 'w') as f:
            json.dump(data, f)
        os.replace(tmp, CACHE)
    except OSError:
        pass


def _pixels(path):
    """Los píxeles del fondo en pequeño, como bytes RGB (o None)."""
    try:
        out = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-frames:v', '1', '-vf', f'scale={SIZE}:{SIZE}',
                              '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                             capture_output=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    return out if len(out) >= SIZE * SIZE * 3 else None


def analizar(raw):
    """El tono que manda en esos píxeles (o None si casi no hay color) y lo claro que es el fondo."""
    bins = [0.0] * 36
    acc = [[0.0, 0.0, 0.0] for _ in range(36)]   # (para el tono medio de cada cajón)
    vivid = light = 0.0
    n = len(raw) // 3
    for i in range(n):
        r, g, b = raw[3 * i] / 255, raw[3 * i + 1] / 255, raw[3 * i + 2] / 255
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        light += v
        w = s * s * v          # lo vivo pesa mucho más que lo apagado
        vivid += s * v
        k = int(h * 36) % 36
        bins[k] += w
        acc[k][0] += w * math.cos(h * 2 * math.pi)
        acc[k][1] += w * math.sin(h * 2 * math.pi)
    claridad = light / max(1, n)
    if vivid / max(1, n) < GRIS:
        return {'tono': None, 'claridad': round(claridad, 3)}
    # El cajón que más pesa, junto con sus vecinos (un rojo puede caer a los dos lados del 0°)
    k = max(range(36), key=lambda i: bins[i - 1] + bins[i] + bins[(i + 1) % 36])
    x = sum(acc[j % 36][0] for j in (k - 1, k, k + 1))
    y = sum(acc[j % 36][1] for j in (k - 1, k, k + 1))
    tono = (math.degrees(math.atan2(y, x)) + 360) % 360
    tono = round(tono / STEP) * STEP % 360
    return {'tono': tono, 'claridad': round(claridad, 3)}


def color_de(path):
    if not path or not os.path.isfile(path):
        return None
    try:
        st = os.stat(path)
    except OSError:
        return None
    key = f'{path}|{st.st_size}|{int(st.st_mtime)}'
    cache = _read_cache()
    if key in cache:
        return cache[key]
    raw = _pixels(path)
    if raw is None:
        return None
    info = analizar(raw)
    # (solo lo de los últimos fondos: que no crezca sin fin)
    cache = {k: v for k, v in list(cache.items())[-63:] if not k.startswith(path + '|')}
    cache[key] = info
    _write_cache(cache)
    return info


def _hex(h, s, l):
    r, g, b = colorsys.hls_to_rgb(h / 360, l, s)
    return '#' + ''.join(f'{round(c * 255):02x}' for c in (r, g, b))


def acento(info, claro=False):
    """El acento de ese fondo: vivo y que se lea sobre el grafito (o sobre el papel, en claro). Sin color: gris."""
    if not info:
        return None
    if info.get('tono') is None:
        return '#3d424c' if claro else '#d4d8df'
    return _hex(info['tono'], 0.66, 0.40) if claro else _hex(info['tono'], 0.82, 0.60)
