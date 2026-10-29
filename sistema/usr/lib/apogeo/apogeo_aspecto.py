"""
Ajustes → Aspecto («K2 con vista previa»): estilos completos de un clic y cada detalle a mano. Lo de siempre (Apogeo:
Ágape, Berenjena oscuro, el rosa) es lo predeterminado y usa los temas de serie; con cualquier otra cosa se generan tus
temas (colores de KDE, Kvantum, Plasma y barra de ventana, con los generadores de /usr/lib/apogeo/temas) y se ponen.

Lo que lee todo lo de Apogeo hecho en QML (Tema): ~/.config/apogeo/aspecto.json (las fichas ya calculadas).

«Del fondo» (lo de serie): los colores salen del fondo de cada piso (apogeo_paleta): cada piso con los suyos, y al
cambiar de piso o de fondo cambian. Los temas de KDE de cada piso se hacen una vez (con un nombre por colores) y al
cambiar de piso solo se ponen. En aspecto.json van los del piso en el que estás y, en «pisos», los de los tres (el fondo
de Plasma pinta cada piso con los suyos sin esperar).

«Como Ágape»: Apogeo sigue lo que elijas en Ágape → Personalizar (sus colores, claro u oscuro, los
colores del fondo, la letra, las esquinas, el cristal y la velocidad de las animaciones). Se lee de los ajustes de
Ágape (~/.config/ARES/settings.json, solo leer) y apogeo-pisos lo vuelve a mirar cada vez que Ágape los guarda. Con
Ágape como viene, es exactamente lo de Apogeo.

  ajustes['aspecto'] = {estilo, acento, modo, letra, esquinas, cristal, tamano, animaciones, posicion}
"""
import datetime
import glob
import json
import os
import shutil
import subprocess
import tempfile

import apogeo_paleta as paleta

HOME = os.path.expanduser('~')
CONFIG = os.environ.get('XDG_CONFIG_HOME', os.path.join(HOME, '.config'))
DATA = os.environ.get('XDG_DATA_HOME', os.path.join(HOME, '.local', 'share'))
TOKENS = os.path.join(CONFIG, 'apogeo', 'aspecto.json')
AGAPE = os.path.join(CONFIG, 'ARES', 'settings.json')
GENERATORS = os.environ.get('APOGEO_TEMAS', '/usr/lib/apogeo/temas')   # (otra carpeta, para probar)
MINE = 'ApogeoTuAspecto'          # el nombre de tus temas generados (+ «-» y sus colores)
FLOORS = ('jugar', 'navegar', 'estudiar')

# Los estilos: fondo, superficie, texto, acento, texto sobre el acento, rosa vivo, y los 3 colores de los fondos animados
STYLES = {
    'apogeo': {'nombre': 'Apogeo', 'fondo': '#120d14', 'superficie': '#1e1621', 'texto': '#f1e6ea', 'acento': '#e0a9b4',
               'sobreAcento': '#2a1c26', 'vivo': '#ff8fc6', 'wp': ['#4a2c4f', '#7a4458', '#e0a9b4']},
    'medianoche': {'nombre': 'Medianoche', 'fondo': '#0b0f17', 'superficie': '#151b27', 'texto': '#e6ecf5',
                   'acento': '#8fb4f2', 'sobreAcento': '#0f1b2e', 'vivo': '#9fc2ff', 'wp': ['#1d2c4a', '#2f4a78', '#8fb4f2']},
    'bosque': {'nombre': 'Bosque', 'fondo': '#0c130f', 'superficie': '#16201a', 'texto': '#e4efe7', 'acento': '#9ed9b0',
               'sobreAcento': '#12261a', 'vivo': '#a8f0c0', 'wp': ['#1f3a2a', '#2f5a3f', '#9ed9b0']},
    'arena': {'nombre': 'Arena', 'fondo': '#15110c', 'superficie': '#211b14', 'texto': '#f3ebe0', 'acento': '#f2c48d',
              'sobreAcento': '#2e1f0c', 'vivo': '#ffcf94', 'wp': ['#4a3524', '#7a5636', '#f2c48d']},
    'papel': {'nombre': 'Papel', 'claro': True, 'fondo': '#f6f0ee', 'superficie': '#fffdfc', 'texto': '#2a1c26',
              'acento': '#b0476a', 'sobreAcento': '#ffffff', 'vivo': '#c4507a', 'wp': ['#ecdde1', '#dcbcc8', '#b0476a']},
}
DEFAULT = {'estilo': 'fondo', 'acento': '', 'modo': 'oscuro', 'letra': 'Bricolage Grotesque', 'esquinas': 'redondas',
           'cristal': 55, 'tamano': 'normal', 'animaciones': 'suaves', 'posicion': 'abajo-dcha'}
CORNERS = {'rectas': 0.35, 'suaves': 0.7, 'redondas': 1.0}
SIZES = {'compacto': (9, 50), 'normal': (10, 56), 'grande': (11.5, 64)}     # (letra en pt, alto de la isla)
ANIMS = {'sin': 0.0, 'rapidas': 0.5, 'suaves': 1.0}


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def mix(a, b, t):
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(rgb(a), rgb(b)))


def luminance(h):
    r, g, b = (c / 255 for c in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def agape_style():
    """El aspecto que tienes en Ágape, como un estilo más (None si Ágape no está)."""
    try:
        with open(AGAPE) as f:
            g = json.load(f)
    except (OSError, ValueError):
        return None
    def col(k, d):
        v = str(g.get(k) or d)
        return v.lower() if len(v) == 7 and v.startswith('#') else d
    st = STYLES['apogeo']
    acc = col('accent', st['acento'])
    stock = acc == st['acento']
    font = str(g.get('font') or '').split(',')[0].strip().strip('"\'') or 'Bricolage Grotesque'
    speed = float(g.get('animSpeed', 1) or 0)
    return {
        'nombre': 'Ágape', 'claro': g.get('mode') == 'light',
        'fondo': col('bg', st['fondo']), 'superficie': col('surface', st['superficie']), 'texto': col('text', st['texto']),
        'acento': acc,
        # el texto encima del acento, como en Ágape (el de serie, el de Apogeo)
        'sobreAcento': st['sobreAcento'] if stock else ('#121218' if wcag(acc) > 0.36 else '#f6f7fc'),
        'vivo': st['vivo'] if stock else mix(acc, '#ffffff', 0.25),
        'wp': [col('wpColor1', st['wp'][0]), col('wpColor2', st['wp'][1]), col('wpColor3', st['wp'][2])],
        'radio': max(0.3, min(1.6, float(g.get('radius', 12) or 12) / 12)),
        'cristal': max(0.3, min(0.98, float(g.get('chromeOpacity', 0.5) or 0.5) + 0.05)),
        'letra': font,
        'animaciones': 0.0 if speed <= 0.05 else round(min(2.0, 1 / speed), 2),
    }


def wcag(h):
    f = lambda v: v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (f(c / 255) for c in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def light_now():
    """«Según la hora»: claro de 8:00 a 20:00."""
    return 8 <= datetime.datetime.now().hour < 20


def settings_of(st):
    a = dict(DEFAULT)
    a.update({k: v for k, v in (st.get('aspecto') or {}).items() if k in DEFAULT})
    if a['estilo'] not in STYLES and a['estilo'] not in ('agape', 'fondo'):
        a['estilo'] = 'apogeo'
    return a


def is_default(a):
    return all(a.get(k) == v for k, v in DEFAULT.items())


def tokens(a, st=None, floor='navegar', wallpaper=None):
    """Las fichas de tu aspecto (lo que leen Tema y los generadores). Con «Del fondo», las del piso «floor» (con
    «wallpaper», el fondo que se ve ahora en él); sin ajustes (st), las de Apogeo."""
    g = agape_style() if a['estilo'] == 'agape' else None
    if g:
        font_pt, island = SIZES.get(a['tamano'], SIZES['normal'])
        t = {'estilo': 'agape', 'claro': g['claro'], 'fondo': g['fondo'], 'superficie': g['superficie'],
             'texto': g['texto'], 'acento': g['acento'], 'sobreAcento': g['sobreAcento'], 'vivo': g['vivo'],
             'wp': g['wp'], 'radio': g['radio'], 'cristal': round(g['cristal'], 3), 'letra': g['letra'],
             'letraPt': font_pt, 'isla': island, 'animaciones': g['animaciones'], 'posicion': a['posicion']}
        t['nombre'] = None if stock(t) else theme_name(t)
        return t
    if a['estilo'] == 'agape':
        a = dict(a, estilo='apogeo')
    if a['estilo'] == 'fondo':
        # Los colores del fondo del piso (sin foto ni color elegido, los de Apogeo); tu acento no cuenta
        pal = paleta.of_floor(st, floor, wallpaper) if st else None
        s = dict(STYLES['apogeo'], **(pal or {}), nombre='Del fondo')
        a = dict(a, acento='')
    else:
        s = dict(STYLES[a['estilo']])
    dark_style = not s.get('claro')
    want_light = a['modo'] == 'claro' or (a['modo'] == 'hora' and light_now())
    if a['modo'] == 'oscuro' and not dark_style:
        want_light = False
    if want_light and dark_style:
        # La versión clara de un estilo oscuro: papel tintado con su color y el texto de su fondo
        acc = s['acento']
        s.update(fondo=mix('#ffffff', acc, 0.07), superficie=mix('#ffffff', acc, 0.025), texto=s['fondo'],
                 acento=mix(s['vivo'], '#000000', 0.25), sobreAcento='#ffffff', vivo=mix(s['vivo'], '#000000', 0.12),
                 wp=[mix('#ffffff', acc, 0.15), mix('#ffffff', acc, 0.35), mix(acc, '#000000', 0.3)], claro=True)
    elif not want_light and not dark_style:
        # Papel en oscuro: el de Apogeo con su acento
        s.update({k: STYLES['apogeo'][k] for k in ('fondo', 'superficie', 'texto', 'wp')}, claro=False)
    if a['acento']:
        acc = a['acento']
        s.update(acento=acc, vivo=mix(acc, '#ffffff', 0.25),
                 sobreAcento='#1a1216' if luminance(acc) > 0.45 else '#ffffff')
        s['wp'] = [s['wp'][0], mix(s['wp'][1], acc, 0.35), acc]
    font_pt, island = SIZES.get(a['tamano'], SIZES['normal'])
    cristal = max(0.3, min(0.98, 1 - float(a['cristal']) / 100 * 0.75))   # 0 = opaco, 100 = muy transparente
    t = {
        'estilo': a['estilo'], 'claro': bool(s.get('claro')),
        'fondo': s['fondo'], 'superficie': s['superficie'], 'texto': s['texto'], 'acento': s['acento'],
        'sobreAcento': s['sobreAcento'], 'vivo': s['vivo'], 'wp': s['wp'],
        'radio': CORNERS.get(a['esquinas'], 1.0), 'cristal': round(cristal, 3),
        'letra': a['letra'] or DEFAULT['letra'], 'letraPt': font_pt, 'isla': island,
        'animaciones': ANIMS.get(a['animaciones'], 1.0), 'posicion': a['posicion'],
    }
    t['nombre'] = None if stock(t) else theme_name(t)
    return t


# Lo que cambia los temas generados (colores, esquinas, cristal y claro u oscuro): si es lo de Apogeo, los del paquete
_STOCK = {'fondo': '#120d14', 'superficie': '#1e1621', 'texto': '#f1e6ea', 'acento': '#e0a9b4', 'sobreAcento': '#2a1c26',
          'radio': 1.0, 'claro': False}


def stock(t):
    return all(t.get(k) == v for k, v in _STOCK.items()) and abs(t.get('cristal', 0) - 0.587) < 0.04


def theme_name(t):
    """El nombre de tus temas generados con estos colores y formas: si cambian, otro nombre (así Plasma los vuelve a
    leer) y los mismos colores en otro piso usan los mismos temas."""
    import hashlib
    key = json.dumps([t.get(k) for k in (*_STOCK, 'cristal')])
    return MINE + '-' + hashlib.sha1(key.encode()).hexdigest()[:8]


# Lo de cada piso que va en aspecto.json («pisos»)
FLOOR_TOKENS = ('fondo', 'superficie', 'texto', 'acento', 'sobreAcento', 'vivo', 'wp', 'claro')


def all_tokens(st, floor, shown=None):
    """Las fichas del piso en el que estás, con las de los tres pisos en «pisos» (y «piso»: cuál es este)."""
    a = settings_of(st)
    per = {k: tokens(a, st, k, (shown or {}).get(k)) for k in FLOORS}
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
            os.path.join(DATA, 'icons', icons)]
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
        # a leer). Hacerlo tarda: con los colores del fondo, el más parecido de unos pocos (así se hacen una vez)
        if not os.path.isdir(want[4]):
            gen('iconos', want[4], tokens=dict(t, acento=icon_accent(t)))
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


def icon_accent(t):
    """El color de las carpetas: el tuyo o, con «Del fondo», el más parecido (por su tono) de los de los animados."""
    acc = t['acento']
    if t.get('estilo') != 'fondo' or acc in paleta.COLORS or acc == STYLES['apogeo']['acento']:
        return acc
    import colorsys
    hue = lambda h: colorsys.rgb_to_hls(*(c / 255 for c in rgb(h)))
    h0, _l0, s0 = hue(acc)
    choices = [c for c in paleta.COLORS if c] + [STYLES['apogeo']['acento']]
    if s0 < 0.15:   # (casi gris: el rosa de Apogeo)
        return STYLES['apogeo']['acento']
    return min(choices, key=lambda c: min(abs(hue(c)[0] - h0), 1 - abs(hue(c)[0] - h0)))


def icon_theme(t):
    return ICONS_PREFIX + icon_accent(t).lstrip('#') + ('-claro' if t['claro'] else '')


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


def switch(st, floor, shown=None, log=print):
    """Has cambiado de piso (o de fondo en él): con «Del fondo», sus colores en todo. Lo llama apogeo-pisos un momento
    después del cambio (no en medio de la animación) y en segundo plano: si su tema aún no está hecho, se hace."""
    t, _per = all_tokens(st, floor, shown)
    write_tokens(t)
    if t['nombre']:
        _generate(t)
    _kde(t)
    log('colores del piso:', floor, t['acento'])
    return t


def apply(st, floor='navegar', shown=None, log=print):
    """Pone tu aspecto en todo el sistema (lo llama apogeo-pisos al cambiar los ajustes)."""
    t, per = all_tokens(st, floor, shown)
    write_tokens(t)
    # (y una copia de los colores para la pantalla de inicio de sesión, que no puede leer tus ajustes)
    try:
        login = {k: v for k, v in t.items() if k != 'pisos'}
        subprocess.run(['pkexec', '/usr/lib/apogeo/apogeo-aspecto-login'], input=json.dumps(login), text=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
    except (OSError, subprocess.SubprocessError):
        pass
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
    log('aspecto aplicado: ' + (settings_of(st)['estilo'] if t['nombre'] else 'el de serie'))
    return t


if __name__ == '__main__':
    import sys
    sys.path.insert(0, '/usr/lib/apogeo')
    import apogeo_comun
    apply(apogeo_comun.load())
