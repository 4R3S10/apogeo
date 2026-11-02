"""
Ajustes → Identidad: Órbita (grafito, Geist y un acento por modo) y, a tu gusto, el acento, claro u oscuro, las
esquinas, el cristal, el tamaño y las animaciones. Lo de serie usa los temas del paquete; con cualquier otra cosa se
generan tus temas (colores de KDE, Kvantum, Plasma y barra de ventana, con los generadores de /usr/lib/apogeo/temas) y
se ponen.

Lo que lee todo lo de Apogeo hecho en QML (Tema): ~/.config/apogeo/aspecto.json (las fichas ya calculadas). Cada modo
tiene su acento: en aspecto.json van los del modo en el que estás y, en «pisos», los de los tres (el fondo de Plasma
pinta cada modo con los suyos sin esperar).

  ajustes['aspecto'] = {estilo, acento, color, modo, letra, esquinas, cristal, tamano, animaciones, posicion}
  (estilo, letra y posicion ya no se eligen: siempre Órbita, Geist y abajo a la derecha)

«color»: «fondo» (lo de serie, como en COSMIC: cada modo coge el color de su fondo de pantalla y todo se tiñe de él; un
fondo animado de Apogeo, que no es una imagen, se queda con el color de su modo) o «modo» (el violeta, el cian y el ámbar
de siempre). Un acento elegido a mano manda sobre los dos.
"""
import datetime
import glob
import json
import os
import shutil
import subprocess
import tempfile

import apogeo_color

HOME = os.path.expanduser('~')
CONFIG = os.environ.get('XDG_CONFIG_HOME', os.path.join(HOME, '.config'))
DATA = os.environ.get('XDG_DATA_HOME', os.path.join(HOME, '.local', 'share'))
TOKENS = os.path.join(CONFIG, 'apogeo', 'aspecto.json')
GENERATORS = os.environ.get('APOGEO_TEMAS', '/usr/lib/apogeo/temas')   # (otra carpeta, para probar)
MINE = 'ApogeoTuAspecto'          # el nombre de tus temas generados (+ «-» y sus colores)
FLOORS = ('jugar', 'navegar', 'estudiar')

# Órbita: fondo, superficie, texto, acento, texto sobre el acento, acento vivo, los 3 colores de los fondos animados y el
# acento de cada modo (en oscuro y en claro)
ORBITA = {'nombre': 'Órbita', 'fondo': '#080a0f', 'superficie': '#0f131a', 'texto': '#e9edf5',
          'acento': '#45d6ff', 'sobreAcento': '#041318', 'vivo': '#45d6ff',
          'wp': ['#0b1118', '#12303d', '#45d6ff'], 'letra': 'Geist', 'mono': 'Geist Mono',
          'acentos': {'jugar': '#b79cff', 'navegar': '#45d6ff', 'estudiar': '#ffb35c'},
          'acentosClaro': {'jugar': '#6d4bc4', 'navegar': '#007a99', 'estudiar': '#a85a00'}}
# Los modos con su color fijo (lo que manda sobre «Del fondo»): Navegar en azul navy y Estudiar en ámbar cálido oscuro,
# con su barra de arriba de ese color, sólida (la que sale con Ágape delante). Jugar sigue con el de su fondo (o el violeta).
PALETAS = {
    'navegar': {'fondo': '#08112a', 'superficie': '#0d1a3a', 'acento': '#5b8cff', 'sobreAcento': '#ffffff',
                'barra': '#172a5c', 'barraOpacidad': 1.0, 'sobreBarra': '#e8edf7'},
    'estudiar': {'fondo': '#140c05', 'superficie': '#1e140a', 'acento': '#ffb35c', 'sobreAcento': '#2a1a08',
                 'barra': '#ffb35c', 'barraOpacidad': 1.0, 'sobreBarra': '#2a1a08'},
}
DEFAULT = {'estilo': 'orbita', 'acento': '', 'color': 'fondo', 'modo': 'piso', 'letra': 'Geist', 'esquinas': 'suaves',
           'cristal': 55, 'tamano': 'normal', 'animaciones': 'suaves', 'posicion': 'abajo-dcha'}
CORNERS = {'rectas': 0.35, 'suaves': 0.7, 'redondas': 1.0}
SIZES = {'compacto': (9, 50), 'normal': (10, 56), 'grande': (11.5, 64)}     # (letra en pt, alto del orbe)
ANIMS = {'sin': 0.0, 'rapidas': 0.5, 'suaves': 1.0}


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def mix(a, b, t):
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(rgb(a), rgb(b)))


def luminance(h):
    r, g, b = (c / 255 for c in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def light_now():
    """«Según la hora»: claro de 8:00 a 20:00."""
    return 8 <= datetime.datetime.now().hour < 20


def settings_of(st):
    a = dict(DEFAULT)
    a.update({k: v for k, v in (st.get('aspecto') or {}).items() if k in DEFAULT})
    a.update(estilo='orbita', letra='Geist', posicion='abajo-dcha')
    if a['modo'] not in ('oscuro', 'claro', 'hora', 'piso'):
        a['modo'] = 'piso'
    if a['color'] not in ('fondo', 'modo'):
        a['color'] = 'fondo'
    return a


def wallpaper_of(st, floor):
    """El fondo que se ve en ese piso (con «que cambie solo», el que toca ahora: lo pone apogeo-pisos en «_vistos»):
    la ruta de una imagen o un vídeo, o '' si es un fondo animado de Apogeo."""
    f = (st.get('_vistos') or {}).get(floor) or ((st.get('pisos') or {}).get(floor) or {}).get('fondo') or ''
    return f if isinstance(f, str) and os.path.isfile(f) else ''


def wallpaper_colors(st, a):
    """{piso: lo que dice apogeo_color de su fondo} con «Del fondo»; vacío con «Del modo» o un acento a mano."""
    if a['color'] != 'fondo' or a['acento']:
        return {}
    out = {}
    for k in FLOORS:
        path = wallpaper_of(st, k)
        info = apogeo_color.color_de(path) if path else None
        if info:
            out[k] = info
    return out


def tokens(a, floor='navegar', fondo=None):
    """Las fichas de tu aspecto en el modo «floor» (lo que leen Tema y los generadores): el acento del modo (o el de su
    fondo de pantalla, con «Del fondo»: «fondo» es lo que dice apogeo_color), salvo que hayas elegido uno a mano."""
    s = dict(ORBITA)
    mode = floor if floor in FLOORS else 'navegar'
    light = a['modo'] == 'claro' or (a['modo'] == 'hora' and light_now())   # («por modo»: grafito en los tres)
    del_fondo = not a['acento'] and a.get('color') == 'fondo' and fondo
    if not a['acento']:
        acc = apogeo_color.acento(fondo, light) if del_fondo else (s['acentosClaro'] if light else s['acentos'])[mode]
        s['acento'] = acc
        s['vivo'] = mix(acc, '#000000' if light else '#ffffff', 0.12 if light else 0.18)
        s['sobreAcento'] = '#ffffff' if light or luminance(acc) < 0.45 else '#041318'
        s['wp'] = [s['wp'][0], mix(s['wp'][1], acc, 0.35), acc]
        if del_fondo:
            # Todo se tiñe del fondo (como en COSMIC): el grafito, un poco de su color
            s['fondo'] = mix(s['fondo'], acc, 0.07)
            s['superficie'] = mix(s['superficie'], acc, 0.11)
            s['wp'] = [s['fondo'], mix(s['wp'][1], acc, 0.45), acc]
    if light:
        # Papel cálido, no un blanco clínico: se lee como un cuaderno
        s.update(fondo='#f3efe6', superficie='#fbf8f2', texto='#1a1c22', claro=True,
                 vivo=mix(s['acento'], '#000000', 0.10), sobreAcento='#ffffff')
        s['wp'] = ['#f3efe6', '#e9e2d3', s['acento']]
        if del_fondo:
            s['fondo'] = mix(s['fondo'], s['acento'], 0.06)
            s['superficie'] = mix(s['superficie'], s['acento'], 0.05)
    pal = PALETAS.get(mode)
    if pal and not a['acento']:
        if light:
            s.update(acento=mix(pal['acento'], '#000000', 0.35), vivo=mix(pal['acento'], '#000000', 0.25), sobreAcento='#ffffff')
            s['fondo'] = mix(s['fondo'], pal['acento'], 0.06)
            s['superficie'] = mix(s['superficie'], pal['acento'], 0.05)
        else:
            s.update(fondo=pal['fondo'], superficie=pal['superficie'], acento=pal['acento'], sobreAcento=pal['sobreAcento'],
                     vivo=mix(pal['acento'], '#ffffff', 0.18))
            s['wp'] = [pal['fondo'], mix(pal['superficie'], pal['acento'], 0.3), pal['acento']]
        s.update(barra=pal['barra'], barraOpacidad=pal['barraOpacidad'], sobreBarra=pal['sobreBarra'])
    if a['acento']:
        acc = a['acento']
        s.update(acento=acc, vivo=mix(acc, '#ffffff', 0.25),
                 sobreAcento='#1a1216' if luminance(acc) > 0.45 else '#ffffff')
        s['wp'] = [s['wp'][0], mix(s['wp'][1], acc, 0.35), acc]
    font_pt, island = SIZES.get(a['tamano'], SIZES['normal'])
    cristal = max(0.3, min(0.98, 1 - float(a['cristal']) / 100 * 0.75))   # 0 = opaco, 100 = muy transparente
    t = {
        'estilo': 'orbita', 'claro': bool(s.get('claro')),
        'fondo': s['fondo'], 'superficie': s['superficie'], 'texto': s['texto'], 'acento': s['acento'],
        'sobreAcento': s['sobreAcento'], 'vivo': s['vivo'], 'wp': s['wp'],
        'radio': CORNERS.get(a['esquinas'], 0.7), 'cristal': round(cristal, 3),
        'letra': s['letra'], 'mono': s['mono'],
        'modo': a['modo'], 'letraPt': font_pt, 'isla': island,
        'animaciones': ANIMS.get(a['animaciones'], 1.0), 'posicion': 'abajo-dcha',
        # la barra de arriba (con Ágape delante): su color, lo opaca que es y el de lo que va encima ('' = sin franja)
        'barra': s.get('barra', ''), 'barraOpacidad': s.get('barraOpacidad', 0), 'sobreBarra': s.get('sobreBarra', s['texto']),
    }
    t['nombre'] = None if stock(t) else theme_name(t)
    return t


# Lo que cambia los temas generados (colores, esquinas, cristal y claro u oscuro): si es lo de Apogeo, los del paquete
_STOCK = {'fondo': '#080a0f', 'superficie': '#0f131a', 'texto': '#e9edf5', 'acento': '#45d6ff', 'sobreAcento': '#041318',
          'radio': 0.7, 'claro': False}


# Sube cuando cambian los generadores (así tus temas se vuelven a hacer con lo nuevo). 2: el brillo de la isla del color
# del piso.
GENERATED = 5  # 5: la barra de arriba de color en Navegar y Estudiar; 4: 4: ventanas, menús y bocadillos transparentes (como COSMIC)


def stock(t):
    return all(t.get(k) == v for k, v in _STOCK.items()) and abs(t.get('cristal', 0) - 0.587) < 0.04


def theme_name(t):
    """El nombre de tus temas generados con estos colores y formas: si cambian, otro nombre (así Plasma los vuelve a
    leer) y los mismos colores en otro piso usan los mismos temas."""
    import hashlib
    key = json.dumps([t.get(k) for k in (*_STOCK, 'cristal')] + ([GENERATED] if GENERATED > 1 else [])
                     + ([t.get('barra'), t.get('barraOpacidad')] if t.get('barra') else []))
    return MINE + '-' + hashlib.sha1(key.encode()).hexdigest()[:8]


# Lo de cada piso que va en aspecto.json («pisos»)
FLOOR_TOKENS = ('fondo', 'superficie', 'texto', 'acento', 'sobreAcento', 'vivo', 'wp', 'claro', 'barra', 'barraOpacidad',
                'sobreBarra')


def all_tokens(st, floor):
    """Las fichas del piso en el que estás, con las de los tres pisos en «pisos» (y «piso»: cuál es este)."""
    a = settings_of(st)
    colors = wallpaper_colors(st, a)
    per = {k: tokens(a, k, colors.get(k)) for k in FLOORS}
    t = dict(per[floor] if floor in per else per['navegar'])
    t['piso'] = floor
    t['pisos'] = {k: {x: v[x] for x in FLOOR_TOKENS} for k, v in per.items()}
    return t, per


def _run(*c, env=None):
    subprocess.run(list(c), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env, timeout=120)


def _kw(f, g, k, v):
    _run('kwriteconfig6', '--notify', '--file', f, '--group', g, '--key', k, str(v))


def _font(family, pt, weight=400):
    return f'{family},{pt:g},-1,5,{weight},0,0,0,0,0,0,0,0,0,0,1'


def write_tokens(t):
    os.makedirs(os.path.dirname(TOKENS), exist_ok=True)
    tmp = TOKENS + '.nuevo'
    with open(tmp, 'w') as f:
        json.dump(t, f)
    os.replace(tmp, TOKENS)


def _generate(t):
    """Tus temas con estos colores, esquinas y cristal (t['nombre']) en tu carpeta, si aún no están."""
    name, icons = t['nombre'], icon_theme(t)
    want = [os.path.join(DATA, 'color-schemes', name + '.colors'), os.path.join(CONFIG, 'Kvantum', name),
            os.path.join(DATA, 'plasma', 'desktoptheme', name), os.path.join(DATA, 'aurorae', 'themes', name),
            os.path.join(DATA, 'icons', icons),
            # (los temas hechos antes de la versión opaca del panel se rehacen: sin ella, fondo oscuro en las barras)
            os.path.join(DATA, 'plasma', 'desktoptheme', name, 'solid', 'widgets', 'panel-background.svg')]
    if all(os.path.exists(x) for x in want):
        return
    paths = []

    def gen(kind, *args, tokens=t):
        with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as f:
            json.dump(tokens, f)
            paths.append(f.name)
        _run('python3', os.path.join(GENERATORS, kind + '.py'), *args,
             env=dict(os.environ, APOGEO_TOKENS=paths[-1], PYTHONDONTWRITEBYTECODE='1'))
    try:
        os.makedirs(os.path.join(DATA, 'color-schemes'), exist_ok=True)
        gen('colores', want[0])
        gen('kvantum', os.path.join(CONFIG, 'Kvantum'))
        gen('plasma', os.path.join(DATA, 'plasma', 'desktoptheme'))
        gen('ventanas', os.path.join(DATA, 'aurorae', 'themes'))
        # Las carpetas de tu color: un tema de iconos por color (si se llamara siempre igual, las apps no lo vuelven
        # a leer)
        if not os.path.isdir(want[4]):
            gen('iconos', want[4])
    finally:
        for p in paths:
            os.remove(p)


def _clean(keep):
    """Fuera tus temas generados que ya no usa ningún piso («keep»: las fichas que sí)."""
    names = {t['nombre'] for t in keep if t.get('nombre')}
    icons = {icon_theme(t) for t in keep if t.get('nombre')}
    for pattern, kind in ((os.path.join(DATA, 'color-schemes', MINE + '*.colors'), 'tema'),
                          (os.path.join(CONFIG, 'Kvantum', MINE + '*'), 'tema'),
                          (os.path.join(DATA, 'plasma', 'desktoptheme', MINE + '*'), 'tema'),
                          (os.path.join(DATA, 'aurorae', 'themes', MINE + '*'), 'tema'),
                          (os.path.join(DATA, 'icons', ICONS_PREFIX + '*'), 'iconos')):
        for old in glob.glob(pattern):
            base = os.path.basename(old)
            if (base.removesuffix('.colors') in names) if kind == 'tema' else (base in icons):
                continue
            shutil.rmtree(old, ignore_errors=True) if os.path.isdir(old) else os.remove(old)


ICONS_PREFIX = 'ApogeoCarpetas-'


def icon_theme(t):
    return ICONS_PREFIX + t['acento'].lstrip('#') + ('-claro' if t['claro'] else '')


_applied = {'tema': None, 'borde': None}   # el tema de KDE y el borde puestos ahora (para no volver a ponerlos)


def _kde(t):
    """Los colores y las formas de KDE (los de serie o los tuyos) y el borde de color de la ventana activa."""
    name = t['nombre']
    if _applied['tema'] != (name, t['acento']):
        _applied['tema'] = (name, t['acento'])
        if name:
            _run('plasma-apply-colorscheme', name)
            _kw('Kvantum/kvantum.kvconfig', 'General', 'theme', name)
            _run('plasma-apply-desktoptheme', name)
            _kw('kwinrc', 'org.kde.kdecoration2', 'theme', '__aurorae__svg__' + name)
            _run('/usr/lib/plasma-changeicons', icon_theme(t))
        else:
            _run('plasma-apply-colorscheme', 'Apogeo')
            _kw('Kvantum/kvantum.kvconfig', 'General', 'theme', 'Apogeo')
            _run('plasma-apply-desktoptheme', 'apogeo')
            _kw('kwinrc', 'org.kde.kdecoration2', 'theme', '__aurorae__svg__apogeo')
            _run('/usr/lib/plasma-changeicons', 'Apogeo')
    # El borde: del acento en la activa; en las demás, una raya muy suave del color del texto
    if _applied.get('borde') == (t['acento'], t['texto']):
        return
    _applied['borde'] = (t['acento'], t['texto'])
    for key, value in (('OutlineThickness', 2), ('OutlineColor', t['acento']), ('ActiveOutlineAlpha', 255),
                       ('ActiveOutlineUseCustom', 'true'), ('ActiveOutlineUsePalette', 'false'),
                       ('InactiveOutlineThickness', 1), ('InactiveOutlineColor', t['texto']),
                       ('InactiveOutlineAlpha', 28), ('InactiveOutlineUseCustom', 'true'),
                       ('InactiveOutlineUsePalette', 'false'),
                       ('SecondOutlineThickness', 0), ('InactiveSecondOutlineThickness', 0)):
        _kw('kwinrc', 'Round-Corners', key, value)
    _run('qdbus6', 'org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.reconfigureEffect', 'kwin4_effect_shapecorners')


_login_last = {'copia': None}


def _login_copy(st, t, per):
    """Una copia de los colores para la pantalla de inicio de sesión, que no puede leer tus ajustes: los generales y, por
    piso, sus colores y su fondo animado («8 · Inicio de sesión»: detrás, el fondo del piso que eliges). Solo si cambian."""
    import apogeo_comun as comun
    login = {k: v for k, v in t.items() if k != 'pisos'}
    login['pisos'] = {}
    for k in comun.FLOOR_KEYS:
        x = per.get(k) or {}
        value = ((st.get('pisos') or {}).get(k) or {}).get('fondo', '')
        login['pisos'][k] = {**{c: x[c] for c in ('fondo', 'acento', 'sobreAcento', 'vivo', 'wp') if c in x},
                             'estilo': comun.STYLES.index(value) if value in comun.STYLES else -1}
    text = json.dumps(login, sort_keys=True)
    if text == _login_last['copia']:
        return
    try:
        subprocess.run(['pkexec', '/usr/lib/apogeo/apogeo-aspecto-login'], input=text, text=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
        _login_last['copia'] = text
    except (OSError, subprocess.SubprocessError):
        pass


def switch(st, floor, log=print):
    """Has cambiado de piso: su acento en todo. Lo llama apogeo-pisos un momento después del cambio (no en medio de la
    animación) y en segundo plano: si su tema aún no está hecho, se hace."""
    t, per = all_tokens(st, floor)
    write_tokens(t)
    # (la copia para el inicio de sesión no: lleva los tres pisos y no cambia al cambiar de piso; la pone apply. Antes se
    # escribía en cada cambio, con pkexec, y lo hacía lento)
    if t['nombre']:
        _generate(t)
    _kde(t)
    log('colores del piso:', floor, t['acento'])
    return t


def apply(st, floor='navegar', log=print):
    """Pone tu aspecto en todo el sistema (lo llama apogeo-pisos al cambiar los ajustes)."""
    t, per = all_tokens(st, floor)
    write_tokens(t)
    _login_copy(st, t, per)
    # Los temas de cada piso (los que falten) y fuera los que ya no se usan; luego, los del piso en el que estás
    for x in [t] + [v for k, v in per.items() if k != floor]:
        if x['nombre']:
            _generate(x)
    _clean(per.values())
    _applied.update(tema=None, borde=None)
    _kde(t)
    # La letra y su tamaño
    f = _font(t['letra'], t['letraPt'])
    for key in ('font', 'menuFont', 'toolBarFont'):
        _kw('kdeglobals', 'General', key, f)
    _kw('kdeglobals', 'General', 'smallestReadableFont', _font(t['letra'], max(7, t['letraPt'] - 2)))
    _kw('kdeglobals', 'WM', 'activeFont', _font(t['letra'], t['letraPt'], 600))
    for gtk in ('gtk-3.0', 'gtk-4.0'):
        _run('kwriteconfig6', '--file', os.path.join(CONFIG, gtk, 'settings.ini'), '--group', 'Settings', '--key',
             'gtk-font-name', f"{t['letra']},  {t['letraPt']:g}")
    # Las esquinas de las ventanas, como las de su barra (el efecto de esquinas redondeadas: «Size» es la activa)
    corner = max(2, round(12 * float(t.get('radio', 1.0))))
    for key in ('Size', 'InactiveCornerRadius'):
        _kw('kwinrc', 'Round-Corners', key, corner)
    _run('qdbus6', 'org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.reconfigureEffect', 'kwin4_effect_shapecorners')
    # Las animaciones (KWin, Plasma y las apps)
    _kw('kdeglobals', 'KDE', 'AnimationDurationFactor', t['animaciones'])
    _run('qdbus6', 'org.kde.KWin', '/KWin', 'reconfigure')
    log('aspecto aplicado: ' + (t['nombre'] or 'el de serie'))
    return t


if __name__ == '__main__':
    import sys
    sys.path.insert(0, '/usr/lib/apogeo')
    import apogeo_comun
    apply(apogeo_comun.load())
