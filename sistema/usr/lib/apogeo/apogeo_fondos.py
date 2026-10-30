"""
Los fondos de Apogeo: los animados de Apogeo y tu biblioteca de Aura (lo que bajas con ella de Wallhaven, MotionBGS,
Bing… y tus carpetas de fondos). Lo que eliges en Aura va al piso en el que estás (apogeo-fondo); desde Ajustes → Fondos
y el carrusel del escritorio se elige también de tu biblioteca.

Los vídeos llevan una miniatura (un fotograma, con ffmpeg) en ~/.cache/apogeo/miniaturas.
"""
import hashlib
import json
import os
import subprocess
import threading
import urllib.parse
import urllib.request

import apogeo_comun as comun

NAMES = {'tinta': 'Tinta', 'humo': 'Humo', 'seda': 'Seda', 'marmol': 'Mármol', 'relieve': 'Relieve',
         'remolino': 'Remolino', 'dunas': 'Dunas', 'luces': 'Luces',
         'orbitas': 'Órbitas', 'nebulosa': 'Nebulosa', 'aurora': 'Aurora'}
_busy = threading.Lock()  # (una tanda de miniaturas a la vez)
THUMBS = os.path.join(os.environ.get('XDG_CACHE_HOME', os.path.join(comun.HOME, '.cache')), 'apogeo', 'miniaturas')


# Los fondos de serie de Órbita, de Wallhaven (como lo que bajas con Aura): Navegar, la nebulosa azul; Estudiar, el
# atardecer mínimo; Jugar, las nubes violeta. No se pueden repartir con Apogeo: se bajan a tu biblioteca de Aura la
# primera vez que entras con internet (apogeo-pisos) y van a su modo si aún tenía el animado de serie (el de antes).
DE_SERIE = {'navegar': ('4ddk8g', 'orbitas'), 'estudiar': ('mdjrqy', 'aurora'), 'jugar': ('k88m2m', 'nebulosa')}
_AGENTE = 'Apogeo (https://github.com/4R3S10/apogeo)'


def _bajar(url, timeout):
    req = urllib.request.Request(url, headers={'User-Agent': _AGENTE})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def bajar_de_serie(st):
    """Baja los fondos de serie que falten a Imágenes/Wallpapers/Aura: {modo: ruta} de los que están (los que ya
    estaban también). Lo que no se pudo bajar (sin internet…) no sale."""
    pics = comun._user_dir('PICTURES') or os.path.join(comun.HOME, 'Pictures')
    folder = os.path.join(pics, 'Wallpapers', 'Aura')
    out = {}
    for floor, (wid, _old) in DE_SERIE.items():
        have = [os.path.join(folder, n) for n in (os.listdir(folder) if os.path.isdir(folder) else [])
                if n.startswith(f'wallhaven-{wid}.')]
        if have:
            out[floor] = have[0]
            continue
        try:
            path = json.loads(_bajar(f'https://wallhaven.cc/api/v1/w/{wid}', 30))['data']['path']
            if not path.startswith('https://w.wallhaven.cc/full/'):
                continue
            data = _bajar(path, 120)
        except (OSError, ValueError, KeyError, TypeError):
            continue
        os.makedirs(folder, exist_ok=True)
        dest = os.path.join(folder, os.path.basename(path))
        tmp = dest + '.part'
        with open(tmp, 'wb') as f:
            f.write(data)
        os.replace(tmp, dest)
        out[floor] = dest
    return out


def _url(path):
    return 'file://' + urllib.parse.quote(path)


def thumb_path(path):
    """Dónde va la miniatura de un vídeo (cambia si el vídeo cambia)."""
    try:
        stamp = f'{path}:{os.path.getmtime(path)}'
    except OSError:
        stamp = path
    return os.path.join(THUMBS, hashlib.sha1(stamp.encode()).hexdigest()[:20] + '.jpg')


def item(path):
    """Un fondo de tu biblioteca: {valor, nombre, tipo, video, url, mini} (mini: '' si el vídeo aún no tiene)."""
    video = comun.is_video(path)
    mini = thumb_path(path) if video else path
    return {'valor': path, 'nombre': os.path.splitext(os.path.basename(path))[0], 'tipo': 'aura', 'video': video,
            'url': _url(path), 'mini': _url(mini) if os.path.isfile(mini) else ''}


def library(st=None):
    """Todo lo que se puede poner de fondo: {animados, aura}."""
    st = st or comun.load()
    return {
        'animados': [{'valor': s, 'nombre': NAMES[s], 'tipo': 'animado', 'indice': i} for i, s in enumerate(comun.STYLES)],
        'aura': [item(p) for p in comun.aura_wallpapers(st)],
    }


def glass(value):
    """El fondo de un piso, pequeño y desenfocado (para el cristal de los paneles y la isla): su url, o '' si es un
    animado de Apogeo (esos se pintan con su sombreador). Se hace una vez (ffmpeg) y se guarda con las miniaturas."""
    if not comun.is_wallpaper_file(value):
        return ''
    try:
        stamp = f'{value}:{os.path.getmtime(value)}:cristal1'
    except OSError:
        return ''
    out = os.path.join(THUMBS, hashlib.sha1(stamp.encode()).hexdigest()[:20] + '-cristal.jpg')
    if os.path.isfile(out):
        return _url(out)
    os.makedirs(THUMBS, exist_ok=True)
    tmp = f'{out}.{os.getpid()}.jpg'
    seek = ['-ss', '2'] if comun.is_video(value) else []
    try:
        # 320 px de ancho y un desenfoque fuerte: estirado a la pantalla parece cristal esmerilado
        subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', *seek, '-i', value, '-frames:v', '1',
                        '-vf', 'scale=320:-2,gblur=sigma=9,eq=saturation=1.35', '-q:v', '4', '-y', tmp],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20)
    except (OSError, subprocess.SubprocessError):
        pass
    if os.path.isfile(tmp) and os.path.getsize(tmp) > 0:
        os.replace(tmp, out)
        return _url(out)
    if os.path.exists(tmp):
        os.remove(tmp)
    return ''


def make_thumbnails(st=None, limit=40):
    """Las miniaturas que faltan de los vídeos de tu biblioteca (y de los que tienen puestos los pisos). Cuántas hizo."""
    if not _busy.acquire(blocking=False):
        return 0
    try:
        return _make_thumbnails(st or comun.load(), limit)
    finally:
        _busy.release()


def _make_thumbnails(st, limit):
    videos = [p for p in comun.aura_wallpapers(st) if comun.is_video(p)]
    videos += [st['pisos'][k]['fondo'] for k in comun.FLOOR_KEYS if comun.is_video(st['pisos'][k]['fondo'])]
    made = 0
    for path in dict.fromkeys(videos):
        out = thumb_path(path)
        if os.path.isfile(out) or made >= limit:
            continue
        os.makedirs(THUMBS, exist_ok=True)
        tmp = f'{out}.{os.getpid()}.jpg'  # (Ajustes y el escritorio pueden estar a la vez)
        for at in ('2', '0'):  # (un vídeo de menos de 2 s: el primer fotograma)
            try:
                subprocess.run(['ffmpeg', '-nostdin', '-loglevel', 'error', '-ss', at, '-i', path, '-frames:v', '1',
                                '-vf', 'scale=480:-2', '-y', tmp], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                               timeout=20)
            except (OSError, subprocess.SubprocessError):
                break
            if os.path.isfile(tmp) and os.path.getsize(tmp) > 0:
                os.replace(tmp, out)
                made += 1
                break
        if os.path.exists(tmp):
            os.remove(tmp)
    return made
