"""
Los fondos de Apogeo: tu biblioteca (los animados de Apogeo, los que has añadido y los de la carpeta vigilada) y la
galería de internet.

La galería busca en las «imágenes destacadas» de Wikimedia Commons: fotos de alta calidad elegidas por la comunidad, con
licencia libre y sin clave ni cuenta. Solo se enseñan las apaisadas de 2560 px de ancho o más. Al bajar una, se guarda en
la carpeta vigilada (así entra sola en «que cambie solo») y su autor y licencia se apuntan en
~/.local/share/apogeo/fondos-creditos.json.
"""
import json
import os
import re
import urllib.parse
import urllib.request

import apogeo_comun as comun

API = 'https://commons.wikimedia.org/w/api.php'
UA = {'User-Agent': 'Apogeo/1.0 (https://github.com/4R3S10/apogeo)'}  # Wikimedia pide identificarse
CREDITS = os.path.join(os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share')), 'apogeo',
                       'fondos-creditos.json')
NAMES = {'tinta': 'Tinta', 'humo': 'Humo', 'seda': 'Seda', 'marmol': 'Mármol', 'relieve': 'Relieve',
         'remolino': 'Remolino', 'dunas': 'Dunas', 'luces': 'Luces'}
# Ideas para buscar (en la galería se busca en inglés, que es como están descritas casi todas)
SUGGESTIONS = [
    {'texto': 'Montañas', 'buscar': 'mountains'}, {'texto': 'Espacio', 'buscar': 'nebula galaxy'},
    {'texto': 'Auroras', 'buscar': 'aurora'}, {'texto': 'Mar', 'buscar': 'sea coast'},
    {'texto': 'Bosque', 'buscar': 'forest'}, {'texto': 'Ciudad de noche', 'buscar': 'city night'},
    {'texto': 'Desierto', 'buscar': 'desert dunes'}, {'texto': 'Flores', 'buscar': 'flowers macro'},
]


def _item(path, kind):
    return {'valor': path, 'nombre': os.path.splitext(os.path.basename(path))[0], 'tipo': kind,
            'video': comun.is_video(path), 'url': 'file://' + urllib.parse.quote(path)}


def library(st=None):
    """Todo lo que se puede poner de fondo: {animados, tuyos, carpeta, rutaCarpeta}."""
    st = st or comun.load()
    tuyos = [x for x in st['fondos']['tuyos'] if os.path.isfile(x)]
    carpeta = [x for x in comun.folder_wallpapers(st) if x not in tuyos]
    return {
        'animados': [{'valor': s, 'nombre': NAMES[s], 'tipo': 'animado', 'indice': i} for i, s in enumerate(comun.STYLES)],
        'tuyos': [_item(x, 'tuyo') for x in tuyos],
        'carpeta': [_item(x, 'carpeta') for x in carpeta],
        'rutaCarpeta': comun.wallpaper_folder(st),
    }


def search(query):
    """Busca en las imágenes destacadas de Wikimedia Commons. Devuelve [{titulo, mini, url, ancho, alto, autor, licencia,
    pagina}]."""
    q = (query or '').strip() or 'landscape'
    params = {
        'action': 'query', 'format': 'json', 'generator': 'search', 'gsrnamespace': '6', 'gsrlimit': '40',
        'gsrsearch': f'{q} incategory:"Featured_pictures_on_Wikimedia_Commons" filetype:bitmap',
        'prop': 'imageinfo', 'iiprop': 'url|size|extmetadata', 'iiurlwidth': '480',
        'iiextmetadatafilter': 'Artist|LicenseShortName',
    }
    req = urllib.request.Request(API + '?' + urllib.parse.urlencode(params), headers=UA)
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.load(r)
    out = []
    pages = sorted(data.get('query', {}).get('pages', {}).values(), key=lambda p: p.get('index', 0))
    for p in pages:
        ii = (p.get('imageinfo') or [{}])[0]
        w, h = ii.get('width', 0), ii.get('height', 0)
        if w < 2560 or w < h * 1.2:  # alta calidad y apaisada (para la pantalla)
            continue
        meta = ii.get('extmetadata', {})
        artist = re.sub(r'<[^>]+>', '', meta.get('Artist', {}).get('value', '')).strip()
        out.append({
            'titulo': re.sub(r'^File:|\.\w+$', '', p.get('title', '')),
            'mini': ii.get('thumburl', ''), 'url': ii.get('url', ''), 'ancho': w, 'alto': h,
            'autor': artist[:80], 'licencia': meta.get('LicenseShortName', {}).get('value', ''),
            'pagina': ii.get('descriptionurl', ''),
        })
    return out


def download(item, st=None):
    """Baja una imagen de la galería a la carpeta vigilada y apunta su autor y licencia. Devuelve la ruta."""
    url = item.get('url', '')
    if not url.startswith('https://upload.wikimedia.org/'):
        raise ValueError('Solo se baja de Wikimedia Commons')
    st = st or comun.load()
    folder = comun.wallpaper_folder(st)
    os.makedirs(folder, exist_ok=True)
    name = re.sub(r'[^\w .()-]+', '', item.get('titulo') or 'fondo').strip()[:90] or 'fondo'
    ext = os.path.splitext(urllib.parse.urlparse(url).path)[1].lower() or '.jpg'
    path = os.path.join(folder, name + ext)
    if not os.path.exists(path):
        tmp = path + '.parcial'
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r, open(tmp, 'wb') as f:
            while True:
                chunk = r.read(1 << 16)
                if not chunk:
                    break
                f.write(chunk)
        os.replace(tmp, path)
    try:
        with open(CREDITS) as f:
            credits = json.load(f)
    except (OSError, ValueError):
        credits = {}
    credits[path] = {'autor': item.get('autor', ''), 'licencia': item.get('licencia', ''), 'origen': item.get('pagina', '')}
    os.makedirs(os.path.dirname(CREDITS), exist_ok=True)
    with open(CREDITS, 'w') as f:
        json.dump(credits, f, ensure_ascii=False, indent=1)
    return path
