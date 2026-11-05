"""
Lo que comparten los programas de Apogeo: tus ajustes (~/.config/apogeo/ajustes.json), tu cuenta (nombre y foto),
Ágape (apogeo-agape como módulo), abrir apps y poner ventanas delante con KWin.

Los ajustes se guardan enteros (con lo que no has cambiado, por defecto) y apogeo-pisos los vigila: al guardarlos se
aplican solos (fondo, avisos, energía, apps de cada piso, la isla).
"""
import contextlib
import copy
import fcntl
import glob
import importlib.machinery
import importlib.util
import json
import os
import re
import shutil
import subprocess
import tempfile
import threading
import time

HOME = os.path.expanduser('~')
CONFIG = os.environ.get('XDG_CONFIG_HOME', os.path.join(HOME, '.config'))
SETTINGS = os.path.join(CONFIG, 'apogeo', 'ajustes.json')
SETTINGS_BAK = SETTINGS + '.bak'
SETTINGS_LOCK = os.path.join(os.path.dirname(SETTINGS), '.ajustes.lock')
HEALTH = '/etc/apogeo/salud.json'
FPS_FILE = os.path.join(CONFIG, 'environment.d', '60-apogeo-juegos.conf')
LIB = os.environ.get('APOGEO_LIB', '/usr/lib/apogeo')

VERSION = 9  # 2: Jugar pasa de Remolino a Luces; 3: Navegar ya no abre Ágape solo; 4-5: el aspecto pasó por
# «Como Ágape» y «Del fondo»; 6: Órbita es la identidad de serie (grafito, Geist, un acento por modo); 7: los fondos
# animados de Órbita (Órbitas, Nebulosa y Aurora); 8: Órbita también para quien se quedó en el aspecto de antes;
# 9: solo queda Órbita (fuera los demás estilos y los fondos animados de antes).
FLOOR_KEYS = ('jugar', 'navegar', 'estudiar')
STYLES = ('orbitas', 'nebulosa', 'aurora')   # los fondos animados (su número es el «kind» del sombreador)
# Fondos tuyos (los de Aura): imágenes y vídeos en alta calidad
IMAGES = ('.jpg', '.jpeg', '.png', '.webp', '.avif', '.jxl', '.bmp', '.tif', '.tiff')
VIDEOS = ('.mp4', '.webm', '.mkv', '.mov', '.m4v', '.avi')
AURA_CONFIG = os.path.join(CONFIG, 'aura', 'config.json')
ROTATION_FROM = ('aura', 'animados', 'ambos')
GAPS = (0, 4, 8, 16)
WIDTHS = {'mitad': '50%', 'dostercios': '66.667%', 'entera': '100%'}  # (en este orden)
EVERY = {'15min': 15 * 60, 'hora': 3600, 'dia': 86400, 'piso': 0}  # «que cambie solo»; «piso»: al entrar en el piso
FOLDER_DEFAULT = '~/Imágenes/Fondos'
import apogeo_aspecto as _aspecto  # noqa: E402

DEFAULTS = {
    'pisos': {
        # Órbita: cada modo con su acento y su carácter. En Jugar solo se abre la consola (las tiendas y herramientas
        # están dentro, y todas las apps siguen en el menú y en el buscador). Energía: nunca «rendimiento».
        # «carrusel»: las ventanas en columnas que se deslizan, como en niri (Karousel)
        'jugar': {'fondo': 'nebulosa', 'avisos': False, 'energia': 'balanced', 'apps': ['apogeo-consola.desktop'],
                  'carrusel': False},
        'navegar': {'fondo': 'orbitas', 'avisos': True, 'energia': 'balanced', 'apps': [], 'carrusel': False},
        'estudiar': {'fondo': 'aurora', 'avisos': False, 'energia': 'power-saver', 'apps': [], 'carrusel': False},
    },
    # El carrusel, igual en todos los pisos que lo tienen: los huecos entre ventanas (px) y los anchos que recorre
    # Meta+Alt+R
    'carrusel': {'huecos': 8, 'anchos': ['mitad', 'dostercios', 'entera']},
    # El fondo de cada piso (pisos.X.fondo) es un fondo animado de Apogeo o la ruta de una imagen o un vídeo tuyo (los
    # eliges con Aura). «cambiar»: que cambie solo, de tu biblioteca de Aura, de los animados o de los dos. «tuyos» y
    # «carpeta» son de antes de Aura (los que añadiste y la carpeta vigilada): siguen en tu biblioteca
    'fondos': {
        'tuyos': [],
        'carpeta': FOLDER_DEFAULT,
        'cambiar': {k: {'activo': False, 'cada': 'hora', 'de': 'aura'} for k in ('jugar', 'navegar', 'estudiar')},
    },
    # Luz cálida en Estudiar por la noche (la luz nocturna de KWin): entra poco a poco al anochecer en tu zona
    'luz': {'activa': True, 'calor': 4500},
    # La copia de Apogeo (apogeo-copia): sola cada semana al conectar el USB o disco elegido, y con el botón
    'copia': {
        'sola': True, 'guardar': 4,
        'que': ['ajustes', 'fondos', 'estudios', 'tareas'],
        'destino': {'uuid': '', 'carpeta': '', 'nombre': ''},  # el disco (por su UUID) y la carpeta dentro de él
    },
    'animar': True,      # fondos animados (solo con gráfica de verdad)
    'silencio': False,   # «No molestar» en todos los pisos
    # El orbe: escondido hasta tocar el borde de abajo
    'isla': {'esconder': True},
    'fps': 60,
    'pantallaFluida': True,  # FreeSync/VRR: la pantalla va al ritmo del juego (si el monitor lo tiene)
    'juegos_fps': {},    # el límite de FPS de cada juego («steam:123»: 45), si no es el de todos (la consola)
    'fpsVisibles': True,  # los FPS de MangoHud en los juegos (la consola: Herramientas → FPS en pantalla)
    # Ajustes → Identidad (apogeo_aspecto): Órbita, con tu acento, claro u oscuro, esquinas, cristal y tamaño
    'aspecto': dict(_aspecto.DEFAULT),
    'version': VERSION,
}
WARMTH = (4500, 3700, 3000)  # luz cálida: suave, media, fuerte (kelvin)
COPY_PARTS = ('ajustes', 'fondos', 'estudios', 'tareas', 'documentos')
COPY_KEEP = (1, 4, 8)
HEALTH_DEFAULT = {'limite': 80}
FPS_CHOICES = (30, 45, 60)


# ---------- Ajustes ----------

def _merge(base, over):
    """Lo que trae el archivo sobre lo de serie, sin dejar que un tipo raro lo rompa: si el valor no es del mismo tipo
    que el de serie, se queda el de serie (un `null` o un número donde iba un objeto dejaban el programa en bucle)."""
    out = copy.deepcopy(base)
    if not isinstance(over, dict):
        return out
    for k, v in over.items():
        if k not in out:
            continue
        if isinstance(out[k], dict):
            if isinstance(v, dict):
                out[k] = _merge(out[k], v)
        elif isinstance(out[k], list):
            if isinstance(v, list):
                out[k] = v
        elif isinstance(out[k], bool):
            if isinstance(v, bool):
                out[k] = v
        elif isinstance(out[k], (int, float)):
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                out[k] = v
        elif isinstance(out[k], str):
            if isinstance(v, str):
                out[k] = v
        else:
            out[k] = v
    return out


def _read_json(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, ValueError):
        return None
    return data if isinstance(data, dict) else None


def load():
    raw = _read_json(SETTINGS)
    if raw is None:
        raw = _read_json(SETTINGS_BAK)   # (la última copia buena, si el archivo se quedó a medias)
    if raw is None:
        return copy.deepcopy(DEFAULTS)
    try:
        ver = int(raw.get('version', 1))
    except (TypeError, ValueError):
        ver = 1
    st = _merge(DEFAULTS, raw)
    if ver < 2 and st['pisos']['jugar']['fondo'] == 'remolino':
        st['pisos']['jugar']['fondo'] = 'luces'
    if ver < 3 and st['pisos']['navegar']['apps'] == ['ares.desktop']:
        st['pisos']['navegar']['apps'] = []  # (si no lo habías cambiado)
    # (lo que venía de serie antes de Órbita; _aspecto.DEFAULT ya es Órbita y no vale para reconocerlo)
    old = {'estilo': 'apogeo', 'acento': '', 'modo': 'oscuro', 'letra': 'Bricolage Grotesque', 'esquinas': 'redondas',
           'cristal': 55, 'tamano': 'normal', 'animaciones': 'suaves', 'posicion': 'abajo-dcha'}
    if ver < 4 and all(st['aspecto'].get(k) == v for k, v in old.items()):
        st['aspecto']['estilo'] = 'agape'  # (si no lo habías cambiado)
    if ver < 5 and all(st['aspecto'].get(k) == v for k, v in dict(old, estilo='agape').items()):
        st['aspecto']['estilo'] = 'fondo'
    # 6: quien tenía el asunto tal como venía (Berenjena, rosa, Bricolage) pasa a Órbita; lo personalizado se respeta
    # 8: también si se quedó en «Clásico» o «Como Ágape» tal como venían (la comparación de antes no lo reconocía)
    old6 = dict(old, estilo='fondo')
    if ver < 8 and st['aspecto'].get('estilo') in ('apogeo', 'agape', 'fondo') and \
            all(st['aspecto'].get(k) == v for k, v in old6.items() if k != 'estilo'):
        st['aspecto'].update({'estilo': 'orbita', 'modo': 'piso', 'letra': 'Geist', 'esquinas': 'suaves'})
    # 7: los fondos animados de Órbita, uno por modo, para quien tenía los de antes tal como venían
    if ver < 8 and st['aspecto'].get('estilo') == 'orbita':
        for k, old, new in (('jugar', 'luces', 'nebulosa'), ('navegar', 'tinta', 'orbitas'), ('estudiar', 'seda', 'aurora')):
            if st['pisos'][k].get('fondo') == old:
                st['pisos'][k]['fondo'] = new
    # 9: solo Órbita (con tu acento y lo demás que hubieras cambiado) y, quien tuviera un fondo animado de antes, el de
    # su modo
    if ver < 9:
        if st['aspecto'].get('estilo') != 'orbita':
            st['aspecto']['acento'] = ''   # (el de otro estilo: mejor el de cada modo)
        st['aspecto'].update({'estilo': 'orbita', 'letra': 'Geist', 'posicion': 'abajo-dcha'})
        for k in FLOOR_KEYS:
            f = st['pisos'][k]
            if f.get('fondo') not in STYLES and not is_wallpaper_file(f.get('fondo')):
                f['fondo'] = DEFAULTS['pisos'][k]['fondo']
    return valid(st)


def valid(st):
    """Lo que no tenga sentido vuelve a su valor por defecto (nunca «rendimiento», FPS de la lista…)."""
    for k in FLOOR_KEYS:
        f = st['pisos'][k]
        # (no se exige que el archivo exista: un fondo en un disco que ahora no está conectado no se debe perder)
        if f.get('fondo') not in STYLES and not _looks_wallpaper(f.get('fondo')):
            f['fondo'] = DEFAULTS['pisos'][k]['fondo']
        if f.get('energia') not in ('power-saver', 'balanced'):
            f['energia'] = 'balanced'
        f['avisos'] = bool(f.get('avisos'))
        f['carrusel'] = bool(f.get('carrusel'))
        f.pop('color', None)
        f['apps'] = [a for a in f.get('apps', []) if isinstance(a, str) and a.endswith('.desktop')]
    if st.get('fps') not in FPS_CHOICES:
        st['fps'] = 60
    st['juegos_fps'] = {k: v for k, v in (st.get('juegos_fps') or {}).items() if v in FPS_CHOICES}
    st['fpsVisibles'] = st.get('fpsVisibles') is not False
    fondos = st['fondos']
    fondos['tuyos'] = list(dict.fromkeys(x for x in fondos.get('tuyos', []) if _looks_wallpaper(x)))
    if not isinstance(fondos.get('carpeta'), str):
        fondos['carpeta'] = FOLDER_DEFAULT
    for k in FLOOR_KEYS:
        c = fondos['cambiar'][k]
        c['activo'] = bool(c.get('activo'))
        if c.get('cada') not in EVERY:
            c['cada'] = 'hora'
        if c.get('de') not in ROTATION_FROM:
            c['de'] = 'aura'  # (también los de antes de Aura: tuyos, carpeta, todos)
    car = st['carrusel']
    if car.get('huecos') not in GAPS:
        car['huecos'] = 8
    car['anchos'] = [w for w in WIDTHS if w in (car.get('anchos') or [])] or ['entera']
    luz = st['luz']
    luz['activa'] = bool(luz.get('activa'))
    if luz.get('calor') not in WARMTH:
        luz['calor'] = WARMTH[0]
    copia = st['copia']
    copia['sola'] = bool(copia.get('sola'))
    if copia.get('guardar') not in COPY_KEEP:
        copia['guardar'] = 4
    copia['que'] = [x for x in COPY_PARTS if x in (copia.get('que') or [])]
    d = copia['destino']
    for k in ('uuid', 'carpeta', 'nombre'):
        if not isinstance(d.get(k), str):
            d[k] = ''
    return st


# ---------- Fondos ----------

def _looks_wallpaper(path):
    """Tiene pinta de fondo (por la extensión), exista ahora o no (puede estar en un disco sin conectar)."""
    return isinstance(path, str) and path.lower().endswith(IMAGES + VIDEOS)


def is_wallpaper_file(path):
    return _looks_wallpaper(path) and os.path.isfile(path)


def is_video(path):
    return isinstance(path, str) and path.lower().endswith(VIDEOS)


def _user_dir(kind):
    """Una carpeta tuya (PICTURES, VIDEOS…) con su nombre de verdad; '' si no hay."""
    try:
        d = subprocess.run(['xdg-user-dir', kind], capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        d = ''
    return d if d and d != HOME else ''


def wallpaper_folder(st):
    """La carpeta de fondos de antes de Aura; por defecto, «Fondos» dentro de tu carpeta de imágenes (sea cual sea su
    nombre)."""
    folder = st['fondos'].get('carpeta') or FOLDER_DEFAULT
    pics = _user_dir('PICTURES')
    if folder == FOLDER_DEFAULT and pics:
        return os.path.join(pics, 'Fondos')
    return os.path.expanduser(folder)


def _aura_config():
    try:
        with open(AURA_CONFIG) as f:
            cfg = json.load(f)
        return cfg if isinstance(cfg, dict) else {}
    except (OSError, ValueError):
        return {}


def aura_dirs(st):
    """Las carpetas de tu biblioteca de Aura, como las mira ella: la de lo que bajas (Imágenes/Wallpapers/Aura), las
    que tengas en Aura (o, sin abrirla todavía, las suyas de serie: Wallpapers, Wallpaper y Fondos en Imágenes y en
    Vídeos) y, de antes de Aura, tu carpeta de fondos de Apogeo."""
    pics = _user_dir('PICTURES') or os.path.join(HOME, 'Pictures')
    dirs = [os.path.join(pics, 'Wallpapers', 'Aura')]
    cfg = _aura_config()
    if isinstance(cfg.get('dirs'), list):
        dirs += [os.path.expanduser(d) for d in cfg['dirs'] if isinstance(d, str)]
    else:
        vids = _user_dir('VIDEOS') or os.path.join(HOME, 'Videos')
        dirs += [os.path.join(b, sub) for b in (pics, vids) for sub in ('Wallpapers', 'Wallpaper', 'Fondos')]
    dirs.append(wallpaper_folder(st))
    return [d for d in dict.fromkeys(os.path.realpath(d) for d in dirs) if os.path.isdir(d)]


def aura_wallpapers(st):
    """Tu biblioteca de Aura (lo de sus carpetas y un nivel de subcarpetas, como ella, y los vídeos que le
    añadiste uno a uno) y los fondos que añadiste en Apogeo antes de Aura. Los más nuevos primero."""
    out = []
    for d in aura_dirs(st):
        for root, dirs, files in os.walk(d):
            depth = root[len(d):].count(os.sep)
            if depth >= 1:
                dirs[:] = []
            dirs[:] = [x for x in dirs if not x.startswith('.')]
            out += [os.path.join(root, n) for n in files if n.lower().endswith(IMAGES + VIDEOS) and not n.startswith('.')]
    extra = _aura_config().get('custom_videos')
    out += [os.path.expanduser(x) for x in (extra if isinstance(extra, list) else []) if isinstance(x, str)]
    out += st['fondos']['tuyos']
    out = [p for p in dict.fromkeys(os.path.realpath(p) for p in out) if is_wallpaper_file(p)]
    return sorted(out, key=os.path.getmtime, reverse=True)[:500]


def rotation_pool(st, floor):
    """Los fondos por los que pasa «que cambie solo» en ese piso."""
    de = st['fondos']['cambiar'][floor]['de']
    pool = aura_wallpapers(st) if de in ('aura', 'ambos') else []
    if de in ('animados', 'ambos') or not pool:  # (sin fondos en Aura todavía: los animados de Apogeo)
        pool += list(STYLES)
    return list(dict.fromkeys(pool))


@contextlib.contextmanager
def settings_locked():
    """Cerrojo entre procesos para leer-modificar-guardar los ajustes (Ajustes, la isla, los pisos…). El sistema lo
    suelta solo si el proceso muere, así que no puede quedarse trabado."""
    os.makedirs(os.path.dirname(SETTINGS_LOCK), exist_ok=True)
    with open(SETTINGS_LOCK, 'a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def _fsync_dir(path):
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(fd)
    except OSError:
        pass
    finally:
        os.close(fd)


def _write_json(path, data):
    """Escribe en un temporal único de la misma carpeta y lo cambia de golpe: si dos procesos guardan a la vez, cada uno
    usa su archivo y nunca se mezclan (antes compartían «ajustes.json.nuevo»)."""
    d = os.path.dirname(path)
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.' + os.path.basename(path) + '.', dir=d)
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
        _fsync_dir(d)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _looks_ok(raw):
    """¿El archivo que hay ahora parece de verdad unos ajustes? (si está a medias o con tipos rotos, no se usa como
    copia de seguridad: se conserva la última buena)."""
    if not isinstance(raw, dict):
        return False
    try:
        int(raw.get('version', 1))
    except (TypeError, ValueError):
        return False
    pisos = raw.get('pisos')
    if pisos is not None:
        if not isinstance(pisos, dict):
            return False
        for k in FLOOR_KEYS:
            if k in pisos and not isinstance(pisos[k], dict):
                return False
    return True


def _save_locked(st):
    st = valid(st)
    st['version'] = VERSION
    try:
        if _looks_ok(_read_json(SETTINGS)):   # (no pisar la copia buena con una rota)
            shutil.copyfile(SETTINGS, SETTINGS_BAK)
    except OSError:
        pass
    _write_json(SETTINGS, st)
    if not os.path.exists(SETTINGS_BAK):   # (la primera vez, para que siempre haya una copia de la que tirar)
        try:
            shutil.copyfile(SETTINGS, SETTINGS_BAK)
        except OSError:
            pass
    write_fps(st['fps'], st.get('juegos_fps'), st['fpsVisibles'])
    return st


def save(st):
    with settings_locked():
        return _save_locked(st)


def update(fn):
    """Leer, cambiar y guardar los ajustes sin que otro proceso se meta en medio: `fn(st)` los cambia y devuelve el
    estado (o False para no guardar). Para lo que se hace desde varios sitios: la isla, los pisos, una copia…"""
    with settings_locked():
        st = load()
        out = fn(st)
        if out is False:
            return st
        # (solo se guarda un estado de verdad: si `fn` devolviera otra cosa sin querer, se guarda lo que cambió en `st`)
        return _save_locked(out if isinstance(out, dict) else st)


def set_path(st, path, value):
    """«pisos.jugar.avisos» = valor"""
    node = st
    keys = path.split('.')
    for k in keys[:-1]:
        node = node[k]
    if keys[-1] not in node:
        raise KeyError(path)
    node[keys[-1]] = value
    return st


def write_fps(fps, per_game=None, visible=True):
    """Los juegos a esos FPS como mucho (y los que tienen el suyo, al suyo), con MangoHud (escondido) en todos los juegos
    Vulkan, también los de Windows con Proton. MANGOHUD=1 es del entorno de la sesión: vale al volver a entrar; los
    límites, al momento."""
    os.makedirs(os.path.dirname(FPS_FILE), exist_ok=True)
    with open(FPS_FILE, 'w') as f:
        f.write('# Apogeo (Ajustes → Salud del PC): MangoHud en los juegos (escondido), con su límite de FPS\n'
                'MANGOHUD=1\n')
    try:
        import apogeo_juegos
        apogeo_juegos.write_mangohud(fps, per_game or {}, visible)
    except Exception as e:  # (que un juego raro no impida guardar los ajustes)
        print('MangoHud:', e)


def health():
    try:
        with open(HEALTH) as f:
            return {**HEALTH_DEFAULT, **json.load(f)}
    except (OSError, ValueError):
        return dict(HEALTH_DEFAULT)


# ---------- Sistema ----------

def real_gpu():
    """¿Hay una gráfica que dibuje los fondos animados? En una máquina virtual sin 3D lo haría el procesador."""
    for card in glob.glob('/sys/class/drm/card[0-9]/device/driver'):
        if os.path.basename(os.path.realpath(card)) in ('amdgpu', 'radeon', 'i915', 'xe', 'nouveau', 'nvidia'):
            return True
    return False


def temperatures():
    """{'cpu': °C, 'gpu': °C} de los sensores que haya (los mismos que vigila apogeo-termico)."""
    out = {}
    for d in glob.glob('/sys/class/hwmon/hwmon*'):
        try:
            name = open(f'{d}/name').read().strip()
        except OSError:
            continue
        kind = 'cpu' if name in ('k10temp', 'zenpower', 'coretemp', 'cpu_thermal') else \
            'gpu' if name in ('amdgpu', 'nouveau', 'i915', 'xe') else None
        if not kind:
            continue
        for p in glob.glob(f'{d}/temp*_input'):
            try:
                t = int(open(p).read()) / 1000
            except (OSError, ValueError):
                continue
            out[kind] = max(out.get(kind, 0), t)
    return out


def human(n):
    for unit in ('B', 'KB', 'MB', 'GB'):
        if n < 1024 or unit == 'GB':
            return f'{n:.0f} {unit}' if unit in ('B', 'KB') else f'{n:.1f} {unit}'.replace('.', ',')
        n /= 1024


def spawn(*cmd):
    """Como si lo abrieras tú: en su propio grupo de systemd (sigue abierto aunque se cierre quien lo abre)."""
    subprocess.Popen(['systemd-run', '--user', '--scope', '--collect', '--slice=app.slice', *cmd],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def agape():
    """apogeo-agape (sin .py) como módulo: la misma descarga y el mismo sitio para la llave."""
    path = os.environ.get('APOGEO_AGAPE', os.path.join(LIB, 'apogeo-agape'))
    loader = importlib.machinery.SourceFileLoader('apogeo_agape', path)
    spec = importlib.util.spec_from_loader('apogeo_agape', loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


# ---------- Apps ----------

def desktop_info(desktop_id):
    """La app de ese .desktop (GioUnix en GLib nuevas; Gio en las de antes), o None."""
    import gi
    try:
        gi.require_version('GioUnix', '2.0')
        from gi.repository import GioUnix as G
    except (ValueError, ImportError):
        gi.require_version('Gio', '2.0')
        from gi.repository import Gio as G
    try:
        return G.DesktopAppInfo.new(desktop_id)
    except TypeError:
        return None


def app_info(desktop_id):
    """(nombre, icono, ejecutable) de una app por su .desktop, o None si no está."""
    info = desktop_info(desktop_id)
    if not info:
        return None
    icon = info.get_icon()
    return info.get_name(), icon.to_string() if icon else 'application-x-executable', info.get_executable() or ''


def apps():
    """Las apps que se pueden elegir (las del menú), por nombre."""
    import gi
    gi.require_version('Gio', '2.0')
    from gi.repository import Gio
    out = []
    for info in Gio.AppInfo.get_all():
        if not info.should_show() or not info.get_id():
            continue
        icon = info.get_icon()
        out.append({'id': info.get_id(), 'name': info.get_name(),
                    'icon': icon.to_string() if icon else 'application-x-executable'})
    return sorted(out, key=lambda a: a['name'].lower())


# ---------- Tu cuenta ----------

class Accounts:
    """Tu nombre y tu foto (AccountsService: los usan el inicio de sesión, el bloqueo y Plasma)."""

    def __init__(self):
        import dbus
        bus = dbus.SystemBus()
        path = bus.get_object('org.freedesktop.Accounts', '/org/freedesktop/Accounts').FindUserById(
            dbus.Int64(os.getuid()), dbus_interface='org.freedesktop.Accounts')
        self.user = bus.get_object('org.freedesktop.Accounts', path)

    def get(self, name):
        return str(self.user.Get('org.freedesktop.Accounts.User', name, dbus_interface='org.freedesktop.DBus.Properties'))

    def set_name(self, name):
        self.user.SetRealName(name, dbus_interface='org.freedesktop.Accounts.User')

    def set_icon(self, path):
        self.user.SetIconFile(path, dbus_interface='org.freedesktop.Accounts.User')


# ---------- KWin ----------

def kwin(js):
    """Ejecuta un momento un script de KWin (para poner delante una ventana aunque KWin no quiera quitarle el sitio a
    otra a pantalla completa)."""
    import dbus
    with tempfile.NamedTemporaryFile('w', suffix='.js', dir=os.environ.get('XDG_RUNTIME_DIR'), delete=False) as f:
        f.write(js)
    try:
        scripting = dbus.Interface(dbus.SessionBus().get_object('org.kde.KWin', '/Scripting'), 'org.kde.kwin.Scripting')
        name = f'apogeo-{os.getpid()}-{threading.get_ident()}'
        sid = scripting.loadScript(f.name, name, signature='ss')
        dbus.SessionBus().get_object('org.kde.KWin', f'/Scripting/Script{sid}').run(dbus_interface='org.kde.kwin.Script')
        time.sleep(0.3)
        scripting.unloadScript(name)
    except Exception:  # sin KWin (pruebas): no pasa nada
        pass
    finally:
        os.remove(f.name)


def front(app_id, delays=(0,)):
    """La ventana de esa app, delante (se reintenta: una app recién abierta tarda en tener ventana)."""
    def work():
        for d in delays:
            time.sleep(d)
            kwin('for (const w of workspace.windowList()) { if (w.normalWindow && w.desktopFileName === "%s") '
                 '{ w.minimized = false; workspace.activeWindow = w; } }' % app_id)
    threading.Thread(target=work, daemon=True).start()


def vrr_outputs():
    """Las pantallas que pueden ir al ritmo del juego (FreeSync/VRR) y lo que tienen puesto: {nombre: 'never' | 'always' |
    'automatic'} (automático: solo con un juego a pantalla completa). Lo dice kscreen-doctor (su JSON no lo trae)."""
    try:
        text = subprocess.run(['kscreen-doctor', '-o'], capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    out, name = {}, None
    for line in re.sub(r'\x1b\[[0-9;]*m', '', text).splitlines():
        m = re.match(r'Output: \d+ (\S+)', line)
        if m:
            name = m.group(1)
            continue
        m = re.match(r'\s+Vrr: (\w+)', line)
        if m and name and m.group(1).lower() in ('never', 'always', 'automatic'):
            out[name] = m.group(1).lower()
    return out
