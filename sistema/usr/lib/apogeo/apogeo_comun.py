"""
Lo que comparten los programas de Apogeo: tus ajustes (~/.config/apogeo/ajustes.json), tu cuenta (nombre y foto),
Ágape (apogeo-agape como módulo), abrir apps y poner ventanas delante con KWin.

Los ajustes se guardan enteros (con lo que no has cambiado, por defecto) y apogeo-pisos los vigila: al guardarlos se
aplican solos (fondo, avisos, energía, apps de cada piso, la isla).
"""
import copy
import glob
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import tempfile
import threading
import time

HOME = os.path.expanduser('~')
CONFIG = os.environ.get('XDG_CONFIG_HOME', os.path.join(HOME, '.config'))
SETTINGS = os.path.join(CONFIG, 'apogeo', 'ajustes.json')
HEALTH = '/etc/apogeo/salud.json'
FPS_FILE = os.path.join(CONFIG, 'environment.d', '60-apogeo-juegos.conf')
LIB = os.environ.get('APOGEO_LIB', '/usr/lib/apogeo')

VERSION = 2  # 2: Jugar pasa de Remolino a Luces (si no lo habías cambiado)
FLOOR_KEYS = ('jugar', 'navegar', 'estudiar')
STYLES = ('tinta', 'humo', 'seda', 'marmol', 'relieve', 'remolino', 'dunas', 'luces')
DEFAULTS = {
    'pisos': {
        # Un solo rosa (el de Ágape) en todo; cada piso con su fondo animado. Energía: nunca «rendimiento».
        'jugar': {'fondo': 'luces', 'avisos': False, 'energia': 'balanced', 'apps': ['apogeo-consola.desktop']},
        'navegar': {'fondo': 'tinta', 'avisos': True, 'energia': 'balanced', 'apps': ['ares.desktop']},
        'estudiar': {'fondo': 'seda', 'avisos': False, 'energia': 'power-saver', 'apps': []},
    },
    'animar': True,      # fondos animados (solo con gráfica de verdad)
    'silencio': False,   # «No molestar» en todos los pisos
    'isla': {'esconder': True, 'esconderPisos': True, 'jugar': True, 'navegar': True, 'estudiar': True},  # lo de cada piso: temperatura/FPS,
    'fps': 60,                                                                    # música, temporizador
    'version': VERSION,
}
HEALTH_DEFAULT = {'limite': 80}
FPS_CHOICES = (30, 45, 60)


# ---------- Ajustes ----------

def _merge(base, over):
    out = copy.deepcopy(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = _merge(out[k], v)
        elif k in out:
            out[k] = v
    return out


def load():
    try:
        with open(SETTINGS) as f:
            raw = json.load(f)
    except (OSError, ValueError):
        return copy.deepcopy(DEFAULTS)
    st = _merge(DEFAULTS, raw)
    if raw.get('version', 1) < 2 and st['pisos']['jugar']['fondo'] == 'remolino':
        st['pisos']['jugar']['fondo'] = 'luces'
    return st


def valid(st):
    """Lo que no tenga sentido vuelve a su valor por defecto (nunca «rendimiento», FPS de la lista…)."""
    for k in FLOOR_KEYS:
        f = st['pisos'][k]
        if f.get('fondo') not in STYLES:
            f['fondo'] = DEFAULTS['pisos'][k]['fondo']
        if f.get('energia') not in ('power-saver', 'balanced'):
            f['energia'] = 'balanced'
        f['avisos'] = bool(f.get('avisos'))
        f['apps'] = [a for a in f.get('apps', []) if isinstance(a, str) and a.endswith('.desktop')]
    if st.get('fps') not in FPS_CHOICES:
        st['fps'] = 60
    return st


def save(st):
    st = valid(st)
    st['version'] = VERSION
    os.makedirs(os.path.dirname(SETTINGS), exist_ok=True)
    tmp = SETTINGS + '.nuevo'
    with open(tmp, 'w') as f:
        json.dump(st, f, ensure_ascii=False, indent=1)
    os.replace(tmp, SETTINGS)  # de golpe: quien lo vigila nunca lee un archivo a medias
    write_fps(st['fps'])
    return st


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


def write_fps(fps):
    """Los juegos de Windows (Proton) a esos FPS como mucho. Es del entorno de la sesión: vale al volver a entrar."""
    os.makedirs(os.path.dirname(FPS_FILE), exist_ok=True)
    with open(FPS_FILE, 'w') as f:
        f.write('# Apogeo (Ajustes → Salud del PC): FPS máximos de los juegos de Windows (Proton)\n'
                f'DXVK_FRAME_RATE={fps}\nVKD3D_FRAME_RATE={fps}\n')


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
