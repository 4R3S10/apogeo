"""
Los juegos de Apogeo, todos juntos, para la consola del piso Jugar (apogeo-consola):
  - Steam: los descargados y el resto de tu biblioteca (para descargarlos); descargar y quitar los hace Steam.
  - Epic: tu biblioteca de Heroic; descargar y quitar con legendary (el mismo que usa Heroic por dentro).
  - Emuladores: lo que haya en ~/Juegos/<Sistema>/ (tus copias de tus juegos), con su portada de libretro-thumbnails.
  - PS5: los juegos volcados de tu PS5 en ~/Juegos/PS5/<Juego>/, convertidos con AnyPS5 (experimental).
  - Windows: los que solo van en el Windows escondido (anticheat del núcleo).
Solo lee las listas que cada tienda guarda en tu carpeta; no entra en tus cuentas. Apogeo no trae ni busca juegos:
cada uno pone los suyos.
"""
import glob
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

HOME = os.environ.get('APOGEO_JUEGOS_HOME', os.path.expanduser('~'))  # para probarlo con una carpeta de mentira
DATA = os.path.join(HOME, '.local/share/apogeo')
CACHE = os.path.join(HOME, '.cache/apogeo')
STEAM = os.path.join(HOME, '.local/share/Steam')
HEROIC = next((d for d in (os.path.join(HOME, '.config/heroic'),
                           os.path.join(HOME, '.var/app/com.heroicgameslauncher.hgl/config/heroic')) if os.path.isdir(d)),
              os.path.join(HOME, '.config/heroic'))
LEGENDARY = '/usr/lib/heroic-games-launcher/app.asar.unpacked/build/bin/x64/linux/legendary'
WINDOWS_LIST = os.path.join(HOME, '.config/apogeo/juegos-windows.json')
PLAYED = os.path.join(DATA, 'jugado.json')        # cuándo jugaste por última vez (lo que no apunta su tienda)
JUEGOS = os.path.join(HOME, 'Juegos')               # tus juegos de los emuladores y de PS5
ANYPS5 = os.path.join(DATA, 'anyps5')               # AnyPS5 (lo pone al día apogeo-al-dia)
PS5_OUT = os.path.join(DATA, 'ps5')                 # tus juegos de PS5 ya convertidos
RUN = os.path.join(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}'), 'apogeo-descargas')
STEAM_CDN = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/{}/{}'
NOT_GAMES = re.compile(r'Proton|Steam Linux Runtime|Steamworks|SteamVR|Redistributable', re.I)

# Los sistemas de los emuladores: carpeta en ~/Juegos, extensiones, emulador (Flatpak) y nombre en libretro-thumbnails
RA = 'org.libretro.RetroArch'
SYSTEMS = [
    # clave, nombre, carpeta, extensiones, (flatpak, núcleo de RetroArch o argumentos), portadas
    ('nes', 'NES', 'NES', ('.nes', '.zip'), (RA, 'nestopia_libretro'), 'Nintendo - Nintendo Entertainment System'),
    ('snes', 'Super Nintendo', 'SNES', ('.sfc', '.smc', '.zip'), (RA, 'snes9x_libretro'),
     'Nintendo - Super Nintendo Entertainment System'),
    ('n64', 'Nintendo 64', 'N64', ('.z64', '.n64', '.v64', '.zip'), (RA, 'mupen64plus_next_libretro'), 'Nintendo - Nintendo 64'),
    ('gb', 'Game Boy', 'GB', ('.gb', '.zip'), (RA, 'gambatte_libretro'), 'Nintendo - Game Boy'),
    ('gbc', 'Game Boy Color', 'GBC', ('.gbc', '.zip'), (RA, 'gambatte_libretro'), 'Nintendo - Game Boy Color'),
    ('gba', 'Game Boy Advance', 'GBA', ('.gba', '.zip'), (RA, 'mgba_libretro'), 'Nintendo - Game Boy Advance'),
    ('megadrive', 'Mega Drive', 'MegaDrive', ('.md', '.gen', '.bin', '.zip'), (RA, 'genesis_plus_gx_libretro'),
     'Sega - Mega Drive - Genesis'),
    ('ps1', 'PlayStation', 'PS1', ('.chd', '.cue', '.pbp', '.m3u'), (RA, 'swanstation_libretro'), 'Sony - PlayStation'),
    ('psp', 'PSP', 'PSP', ('.iso', '.cso', '.chd'), (RA, 'ppsspp_libretro'), 'Sony - PlayStation Portable'),
    ('ps2', 'PlayStation 2', 'PS2', ('.iso', '.chd', '.cso'), ('net.pcsx2.PCSX2', ['-fullscreen', '-nogui', '--']),
     'Sony - PlayStation 2'),
    ('ps3', 'PlayStation 3', 'PS3', ('EBOOT.BIN',), ('net.rpcs3.RPCS3', ['--no-gui']), 'Sony - PlayStation 3'),
    ('gc', 'GameCube', 'GameCube', ('.iso', '.rvz', '.gcz', '.ciso'), ('org.DolphinEmu.dolphin-emu', ['-b', '-e']),
     'Nintendo - GameCube'),
    ('wii', 'Wii', 'Wii', ('.iso', '.rvz', '.wbfs', '.wad'), ('org.DolphinEmu.dolphin-emu', ['-b', '-e']), 'Nintendo - Wii'),
    ('wiiu', 'Wii U', 'WiiU', ('.wua', '.wud', '.wux', '.rpx'), ('info.cemu.Cemu', ['-f', '-g']), 'Nintendo - Wii U'),
    ('nds', 'Nintendo DS', 'DS', ('.nds',), ('net.kuribo64.melonDS', ['-f']), 'Nintendo - Nintendo DS'),
    ('3ds', 'Nintendo 3DS', '3DS', ('.3ds', '.cci', '.cxi', '.3dsx'), ('org.azahar_emu.Azahar', []), 'Nintendo - Nintendo 3DS'),
    ('switch', 'Switch', 'Switch', ('.nsp', '.xci'), ('io.github.ryubing.Ryujinx', ['--fullscreen']), ''),
]
CORES = sorted({s[4][1] for s in SYSTEMS if s[4][0] == RA})
RA_CORES = os.path.join(HOME, '.var/app', RA, 'config/retroarch/cores')
EMULATORS = sorted({s[4][0] for s in SYSTEMS})


def read_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + '.nuevo'
    with open(tmp, 'w') as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(tmp, path)


def file_url(path):
    return 'file://' + urllib.parse.quote(path) if path else ''


def game(store, gid, name, installed, cover='', hero='', last=0, **extra):
    """Un juego para la consola. «cover», la portada (vertical); «hero», el arte de fondo."""
    return {'store': store, 'id': str(gid), 'name': name, 'installed': bool(installed), 'cover': cover, 'hero': hero,
            'last': int(last or 0), **extra}


# ---------- Steam ----------

def vdf_values(text, key):
    return re.findall(r'"%s"\s+"([^"]*)"' % re.escape(key), text, re.I)


def steam_libraries():
    libs = [os.path.join(STEAM, 'steamapps')]
    try:
        with open(os.path.join(STEAM, 'steamapps/libraryfolders.vdf')) as f:
            libs += [os.path.join(p, 'steamapps') for p in vdf_values(f.read(), 'path')]
    except OSError:
        pass
    return list(dict.fromkeys(libs))


def steam_art(appid):
    """(portada, fondo) de la caché de Steam, o de su web."""
    cache = os.path.join(STEAM, 'appcache/librarycache')
    found = glob.glob(f'{cache}/{appid}/**/*.jpg', recursive=True) + glob.glob(f'{cache}/{appid}_*.jpg')
    cover = next((f for f in sorted(found) if 'library_600x900' in f), '')
    hero = next((f for f in sorted(found) if 'library_hero' in f and 'blur' not in f), '')
    return (file_url(cover) or STEAM_CDN.format(appid, 'library_600x900.jpg'),
            file_url(hero) or STEAM_CDN.format(appid, 'library_hero.jpg'))


def appinfo_names():
    """{appid: (nombre, tipo)} de appcache/appinfo.vdf (binario, versiones 28 y 29), o {} si no se puede leer."""
    path = os.path.join(STEAM, 'appcache/appinfo.vdf')
    try:
        with open(path, 'rb') as f:
            data = f.read()
    except OSError:
        return {}
    try:
        magic, _universe = struct.unpack_from('<II', data, 0)
        version = magic & 0xff
        if magic >> 8 != 0x075644 or version not in (0x28, 0x29):
            return {}
        pos = 8
        strings = None
        if version == 0x29:
            (table,) = struct.unpack_from('<q', data, pos)
            pos += 8
            (count,) = struct.unpack_from('<I', data, table)
            strings, p = [], table + 4
            for _ in range(count):
                end = data.index(b'\0', p)
                strings.append(data[p:end].decode('utf-8', 'replace'))
                p = end + 1
        out = {}
        while pos + 8 <= len(data):
            appid, size = struct.unpack_from('<II', data, pos)
            if appid == 0:
                break
            start = pos + 8
            kv = start + 4 + 4 + 8 + 20 + 4 + 20  # estado, actualizado, token, sha1, cambio, sha1 binario
            info = _kv_common(data, kv, start + size, strings)
            if info:
                out[appid] = info
            pos = start + size
        return out
    except (struct.error, ValueError, IndexError):
        return {}


def _kv_common(data, pos, end, strings):
    """(nombre, tipo) de la sección «common» de un bloque KeyValues binario."""
    depth, path, name, kind = 0, [], '', ''

    def key():
        nonlocal pos
        if strings is not None:
            (i,) = struct.unpack_from('<I', data, pos)
            pos += 4
            return strings[i] if i < len(strings) else ''
        e = data.index(b'\0', pos)
        k = data[pos:e].decode('utf-8', 'replace')
        pos = e + 1
        return k

    while pos < end:
        t = data[pos]
        pos += 1
        if t == 0x08:
            if depth == 0:
                break
            depth -= 1
            path.pop()
            continue
        k = key()
        if t == 0x00:
            depth += 1
            path.append(k.lower())
        elif t == 0x01:
            e = data.index(b'\0', pos)
            v = data[pos:e].decode('utf-8', 'replace')
            pos = e + 1
            if path[-1:] == ['common']:
                if k.lower() == 'name':
                    name = v
                elif k.lower() == 'type':
                    kind = v.lower()
            if name and kind:
                return name, kind
        elif t in (0x02, 0x03, 0x06):
            pos += 4
        elif t in (0x07, 0x0a):
            pos += 8
        else:
            return None
    return (name, kind) if name else None


def steam_games():
    """Los de Steam: los descargados y los demás de tu biblioteca (los que Steam tiene en su caché de la biblioteca)."""
    games, seen = [], set()
    for lib in steam_libraries():
        for acf in glob.glob(os.path.join(lib, 'appmanifest_*.acf')):
            try:
                with open(acf, encoding='utf-8', errors='replace') as f:
                    text = f.read()
            except OSError:
                continue
            appid = (vdf_values(text, 'appid') or [''])[0]
            name = (vdf_values(text, 'name') or [''])[0]
            if not appid or appid in seen or NOT_GAMES.search(name):
                continue
            seen.add(appid)
            size = int((vdf_values(text, 'SizeOnDisk') or ['0'])[0] or 0)
            cover, hero = steam_art(appid)
            games.append(game('steam', appid, name, True, cover, hero, (vdf_values(text, 'LastPlayed') or ['0'])[0],
                              size=size))
    # El resto de tu biblioteca: Steam guarda el arte de cada juego que tienes
    cache = os.path.join(STEAM, 'appcache/librarycache')
    owned = set()
    if os.path.isdir(cache):
        for n in os.listdir(cache):
            m = re.match(r'^(\d+)', n)
            if m:
                owned.add(m.group(1))
    owned -= seen
    if owned:
        names = appinfo_names()
        for appid in owned:
            info = names.get(int(appid))
            if not info or info[1] != 'game' or NOT_GAMES.search(info[0]):
                continue
            cover, hero = steam_art(appid)
            games.append(game('steam', appid, info[0], False, cover, hero))
    return games


# ---------- Epic (Heroic) ----------

def legendary_env():
    return {**os.environ, 'LEGENDARY_CONFIG_PATH': os.path.join(HEROIC, 'legendaryConfig/legendary')}


def epic_games():
    lib = read_json(os.path.join(HEROIC, 'store_cache/legendary_library.json'), {}).get('library', [])
    installed = read_json(os.path.join(HEROIC, 'legendaryConfig/legendary/installed.json'), {})
    # Cuándo jugaste: lo apunta Heroic (store/timestamp.json, «lastPlayed») y la consola
    stamps = read_json(os.path.join(HEROIC, 'store/timestamp.json'), {})
    mine = read_json(PLAYED, {})
    played = {}
    for app, v in (stamps.items() if isinstance(stamps, dict) else []):
        try:
            played[app] = int(time.mktime(time.strptime((v or {}).get('lastPlayed', '')[:19], '%Y-%m-%dT%H:%M:%S')))
        except (ValueError, TypeError, AttributeError):
            pass
    for k, v in mine.items():
        if k.startswith('epic:'):
            played[k[5:]] = max(played.get(k[5:], 0), v)
    out = []
    for g in lib if isinstance(lib, list) else []:
        if not isinstance(g, dict) or not g.get('app_name') or g.get('is_dlc'):
            continue
        app = g['app_name']
        inst = app in installed or bool(g.get('is_installed'))
        size = (installed.get(app) or {}).get('install_size', 0) if isinstance(installed, dict) else 0
        out.append(game('epic', app, g.get('title') or app, inst,
                        g.get('art_cover') or g.get('art_square') or '', g.get('art_background') or g.get('art_cover') or '',
                        played.get(app, 0), size=size))
    return out


# ---------- Emuladores ----------

def system(key):
    return next((s for s in SYSTEMS if s[0] == key), None)


def boxart(sysname, title):
    """La portada de libretro-thumbnails (en caché; se baja la primera vez que se pide)."""
    if not sysname:
        return ''
    safe = re.sub(r'[&*/:`<>?\\|"]', '_', title)
    local = os.path.join(CACHE, 'portadas', sysname, safe + '.png')
    if os.path.exists(local):
        return file_url(local) if os.path.getsize(local) else ''
    return 'https://thumbnails.libretro.com/' + urllib.parse.quote(f'{sysname}/Named_Boxarts/{safe}.png')


def cache_boxarts(games):
    """Baja a la caché las portadas de los emuladores que aún no están (las que no existen se apuntan vacías)."""
    for g in games:
        url = g.get('cover', '')
        if g.get('store') != 'emu' or not url.startswith('https://thumbnails.libretro.com/'):
            continue
        rel = urllib.parse.unquote(url.split('thumbnails.libretro.com/', 1)[1])
        sysname, _named, fname = rel.split('/', 2)
        local = os.path.join(CACHE, 'portadas', sysname, fname)
        if os.path.exists(local):
            continue
        os.makedirs(os.path.dirname(local), exist_ok=True)
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Apogeo/1.0'})
            with urllib.request.urlopen(req, timeout=20) as r:
                data = r.read(8 << 20)
        except urllib.error.HTTPError:
            data = b''  # no hay portada con ese nombre: no se vuelve a pedir
        except OSError:
            continue  # sin internet: otra vez será
        with open(local + '.nuevo', 'wb') as f:
            f.write(data)
        os.replace(local + '.nuevo', local)


def emu_games():
    out = []
    played = read_json(PLAYED, {})
    for key, name, folder, exts, emu, thumbs in SYSTEMS:
        base = os.path.join(JUEGOS, folder)
        if not os.path.isdir(base):
            continue
        found = []
        if key == 'ps3':  # cada juego es una carpeta con PS3_GAME/USRDIR/EBOOT.BIN
            for eboot in glob.glob(os.path.join(base, '*', 'PS3_GAME', 'USRDIR', 'EBOOT.BIN')):
                found.append((eboot, os.path.basename(eboot.split('/PS3_GAME/')[0])))
        else:
            for root, _dirs, files in os.walk(base):
                for f in files:
                    if f.lower().endswith(exts) and not f.startswith('.'):
                        found.append((os.path.join(root, f), os.path.splitext(f)[0]))
            # Un juego en varios discos con su lista (.m3u): solo la lista
            lists = {os.path.dirname(p) for p, _t in found if p.lower().endswith('.m3u')}
            found = [(p, t) for p, t in found if p.lower().endswith('.m3u') or os.path.dirname(p) not in lists]
        for path, title in sorted(found, key=lambda x: x[1].lower()):
            gid = f'{key}:{os.path.relpath(path, JUEGOS)}'
            clean = re.sub(r'\s*[\(\[][^)\]]*[\)\]]', '', title).strip() or title
            out.append(game('emu', gid, clean, True, boxart(thumbs, title), '', played.get(gid, 0),
                            system=key, systemName=name, path=path, size=_size(path)))
    return out


def _size(path):
    try:
        return os.path.getsize(path)
    except OSError:
        return 0


def emulators_installed():
    """Los emuladores que hay (Flatpak)."""
    r = subprocess.run(['flatpak', 'list', '--app', '--columns=application'], capture_output=True, text=True)
    have = set(r.stdout.split())
    return {e: e in have for e in EMULATORS}


# ---------- PS5 (AnyPS5) ----------

def ps5_title(folder):
    """(id, nombre) de sce_sys/param.json."""
    p = read_json(os.path.join(folder, 'sce_sys', 'param.json'), {})
    loc = p.get('localizedParameters') or {}
    lang = loc.get('defaultLanguage') or p.get('defaultLanguage') or 'en-US'
    entry = loc.get(lang) or next((v for v in loc.values() if isinstance(v, dict)), {}) or {}
    return p.get('titleId', ''), entry.get('titleName') or os.path.basename(folder)


def ps5_games():
    out = []
    base = os.path.join(JUEGOS, 'PS5')
    if not os.path.isdir(base):
        return out
    played = read_json(PLAYED, {})
    for folder in sorted(glob.glob(os.path.join(base, '*', ''))):
        folder = folder.rstrip('/')
        if not os.path.exists(os.path.join(folder, 'eboot.bin')):
            continue
        tid, name = ps5_title(folder)
        gid = 'ps5:' + os.path.basename(folder)
        ready = os.path.exists(os.path.join(PS5_OUT, os.path.basename(folder), 'app.elf'))
        icon = os.path.join(folder, 'sce_sys', 'icon0.png')
        pic = next((p for p in (os.path.join(folder, 'sce_sys', n) for n in ('pic0.png', 'pic1.png')) if os.path.exists(p)), '')
        out.append(game('ps5', gid, name, ready, file_url(icon) if os.path.exists(icon) else '', file_url(pic),
                        played.get(gid, 0), titleId=tid, path=folder, converted=ready))
    return out


# ---------- Windows ----------

OLD_EXAMPLE = [{'id': 'valorant', 'name': 'VALORANT'}, {'id': 'eafc', 'name': 'EA SPORTS FC 26'}]


def windows_games():
    """Los que solo van en el Windows escondido (anticheat del núcleo), los que añadas a
    ~/.config/apogeo/juegos-windows.json. De serie, ninguno (la pestaña Windows no sale hasta que haya uno)."""
    items = read_json(WINDOWS_LIST, [])
    if items == OLD_EXAMPLE:  # (los dos de ejemplo de antes, si no los habías tocado: fuera)
        write_json(WINDOWS_LIST, [])
        items = []
    return [game('windows', g['id'], g.get('name', g['id']), True, g.get('cover', ''), g.get('hero', ''), g.get('last', 0))
            for g in items if isinstance(g, dict) and g.get('id')]


# ---------- Todo junto ----------

def tabs():
    """Lo de cada pestaña de la consola: inicio (lo descargado, lo último jugado primero) y cada tienda o plataforma
    (todo, lo descargado primero)."""
    steam, epic, emu, ps5, win = steam_games(), epic_games(), emu_games(), ps5_games(), windows_games()
    inicio = [g for g in steam + epic + emu + ps5 if g['installed']]
    inicio.sort(key=lambda g: (-g['last'], g['name'].lower()))

    def lib(items):
        return sorted(items, key=lambda g: (not g['installed'], -g['last'], g['name'].lower()))
    out = {'inicio': inicio, 'steam': lib(steam), 'epic': lib(epic), 'emuladores': lib(emu), 'ps5': lib(ps5),
           'windows': lib(win), 'descargas': downloads()}
    out['emuladoresHay'] = emulators_installed() if shutil.which('flatpak') else {}
    out['anyps5'] = os.path.exists(os.path.join(ANYPS5, 'actual', 'relinker'))
    return out


def mark_played(gid):
    played = read_json(PLAYED, {})
    played[gid] = int(time.time())
    write_json(PLAYED, played)


# ---------- Jugar ----------

def detach(cmd, cwd=None, env=None):
    subprocess.Popen(['systemd-run', '--user', '--scope', '--collect', '--slice=app.slice', *cmd],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True, cwd=cwd, env=env)


def play(g):
    """Abre el juego. Devuelve '' o lo que falta para poder jugar."""
    store, gid = g['store'], g['id']
    if store == 'steam':
        detach(['steam', '-silent', f'steam://rungameid/{gid}'])
    elif store == 'epic':
        detach(['xdg-open', f'heroic://launch?appName={gid}&runner=legendary'])
        mark_played('epic:' + gid)
    elif store == 'windows':
        detach(['/usr/lib/apogeo/apogeo-windows', gid])
        items = read_json(WINDOWS_LIST, [])
        for it in items:
            if it.get('id') == gid:
                it['last'] = int(time.time())
        write_json(WINDOWS_LIST, items)
    elif store == 'emu':
        s = system(g.get('system'))
        if not s:
            return 'No se sabe con qué abrirlo'
        flatpak, how = s[4]
        if not emulators_installed().get(flatpak):
            return f'Falta el emulador de {s[1]}: se instala solo con internet'
        if flatpak == RA:
            core = os.path.join(RA_CORES, how + '.so')
            if not os.path.exists(core):
                return 'Falta el núcleo de RetroArch: se baja solo con internet'
            detach(['flatpak', 'run', RA, '-f', '-L', core, g['path']])
        else:
            detach(['flatpak', 'run', flatpak, *how, g['path']])
        mark_played(gid)
    elif store == 'ps5':
        name = os.path.basename(g['path'])
        out = os.path.join(PS5_OUT, name)
        if not os.path.exists(os.path.join(out, 'app.elf')):
            return 'Todavía no está convertido'
        env = {**os.environ, 'ANYPS5_LANGUAGE': os.environ.get('ANYPS5_LANGUAGE', 'es-ES')}
        detach(['sh', '-c', 'exec ./app.elf > anyps5.log 2>&1'], cwd=out, env=env)
        mark_played(gid)
    else:
        return 'No se sabe abrir'
    return ''


# ---------- Descargar y quitar ----------

def downloads():
    """{id: {estado, progreso, mensaje}} de lo que se está bajando o quitando (lo de Epic y PS5: Steam lo enseña él)."""
    out = {}
    for f in glob.glob(os.path.join(RUN, '*.json')):
        d = read_json(f, None)
        if d and d.get('id'):
            out[d['id']] = d
    return out


def _status(gid, **kw):
    os.makedirs(RUN, exist_ok=True)
    safe = hashlib.sha1(gid.encode()).hexdigest()[:16]
    path = os.path.join(RUN, safe + '.json')
    if kw.get('estado') == 'hecho':
        try:
            os.remove(path)
        except OSError:
            pass
        return
    write_json(path, {'id': gid, **kw})


def install(g):
    """Descargar: Steam con su ventana de instalar; Epic con legendary (aquí se ve el progreso); PS5, convertirlo."""
    store, gid = g['store'], g['id']
    if store == 'steam':
        detach(['steam', '-silent', f'steam://install/{gid}'])
        return ''
    if store == 'epic':
        if not os.access(LEGENDARY, os.X_OK):
            return 'Falta Heroic'
        base = os.path.join(HOME, 'Games', 'Heroic')
        _status(gid, estado='hecho')
        threading.Thread(target=_legendary, args=(gid, ['install', gid, '--yes', '--base-path', base, '--skip-sdl']),
                         daemon=True).start()
        return ''
    if store == 'ps5':
        _status(gid, estado='hecho')  # (si antes falló, se prueba otra vez)
        threading.Thread(target=convert_ps5, args=(g['path'],), daemon=True).start()
        return ''
    return 'Esto no se descarga'


def uninstall(g):
    store, gid = g['store'], g['id']
    if store == 'steam':
        detach(['steam', '-silent', f'steam://uninstall/{gid}'])
        return ''
    if store == 'epic':
        if not os.access(LEGENDARY, os.X_OK):
            return 'Falta Heroic'
        threading.Thread(target=_legendary, args=(gid, ['uninstall', gid, '--yes']), daemon=True).start()
        return ''
    if store == 'emu':  # tu copia, a la papelera (se puede recuperar)
        subprocess.run(['gio', 'trash', g['path']], capture_output=True)
        return ''
    if store == 'ps5':  # solo lo convertido; tu volcado se queda
        shutil.rmtree(os.path.join(PS5_OUT, os.path.basename(g['path'])), ignore_errors=True)
        return ''
    return 'Esto no se quita desde aquí'


def _legendary(gid, args):
    kind = 'descargando' if args[0] == 'install' else 'quitando'
    _status(gid, estado=kind, progreso=0, mensaje='Empezando…')
    try:
        p = subprocess.Popen([LEGENDARY, *args], env=legendary_env(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, bufsize=1)
        last = 0
        for line in p.stdout:
            m = re.search(r'Progress:\s*([\d.]+)%.*?ETA:\s*([\d:]+)', line)
            if m and time.time() - last > 1:
                last = time.time()
                _status(gid, estado=kind, progreso=float(m.group(1)) / 100, mensaje='Quedan ' + m.group(2))
        p.wait()
        if p.returncode:
            _status(gid, estado='error', progreso=0, mensaje='No se ha podido (¿has entrado en Epic en Heroic?)')
            return
        _status(gid, estado='hecho')
    except OSError as e:
        _status(gid, estado='error', progreso=0, mensaje=str(e))


def convert_ps5(folder):
    """Convierte un juego volcado de tu PS5 con AnyPS5: ~/.local/share/apogeo/ps5/<juego>/ con app.elf, libs/ (las de
    AnyPS5) y app0/ (tu volcado, enlazado: no se copia ni se toca)."""
    name = os.path.basename(folder.rstrip('/'))
    gid = 'ps5:' + name
    relinker = os.path.join(ANYPS5, 'actual', 'relinker')
    libs = os.path.join(ANYPS5, 'actual', 'libs')
    if not os.access(relinker, os.X_OK):
        _status(gid, estado='error', progreso=0, mensaje='AnyPS5 aún no está: se baja solo con internet')
        return False
    _status(gid, estado='descargando', progreso=0.3, mensaje='Convirtiendo con AnyPS5…')
    out = os.path.join(PS5_OUT, name)
    tmp = out + '.nuevo'
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    # app0: un árbol de enlaces a tu volcado (así el convertido escribe sus módulos sin tocar tus archivos)
    subprocess.run(['cp', '-as', folder.rstrip('/') + '/.', os.path.join(tmp, 'app0')], check=False)
    os.symlink(libs, os.path.join(tmp, 'libs'))
    log = open(os.path.join(tmp, 'conversion.log'), 'w')
    eboot = os.path.join(folder, 'eboot.bin')
    # Los volcados suelen venir como SELF (descifrado): AnyPS5 trae con qué sacar el ELF de dentro
    with open(eboot, 'rb') as f:
        magic = f.read(4)
    if magic == b'\x4f\x15\x3d\x1d':
        unwrap = os.path.join(os.environ.get('APOGEO_LIB', '/usr/lib/apogeo'), 'anyps5', 'unwrap_self.py')
        elf = os.path.join(tmp, 'eboot.elf')
        if subprocess.run(['python3', '-I', unwrap, eboot, elf], stdout=log, stderr=subprocess.STDOUT).returncode == 0:
            eboot = elf
    r = subprocess.run([relinker, '--sce-module-path', folder, eboot, os.path.join(tmp, 'app.elf')],
                       stdout=log, stderr=subprocess.STDOUT, cwd=tmp)
    log.close()
    if r.returncode or not os.path.exists(os.path.join(tmp, 'app.elf')):
        _status(gid, estado='error', progreso=0, mensaje='AnyPS5 todavía no puede con este juego (mira conversion.log)')
        shutil.rmtree(out + '.fallo', ignore_errors=True)
        os.replace(tmp, out + '.fallo')
        return False
    os.chmod(os.path.join(tmp, 'app.elf'), 0o755)
    shutil.rmtree(out, ignore_errors=True)
    os.replace(tmp, out)
    _status(gid, estado='hecho')
    return True


def prepare_folders():
    """~/Juegos con una carpeta por sistema (y BIOS) y un LEEME, la primera vez."""
    os.makedirs(JUEGOS, exist_ok=True)
    for _k, name, folder, exts, emu, _t in SYSTEMS:
        os.makedirs(os.path.join(JUEGOS, folder), exist_ok=True)
    os.makedirs(os.path.join(JUEGOS, 'PS5'), exist_ok=True)
    os.makedirs(os.path.join(JUEGOS, 'BIOS'), exist_ok=True)
    # RetroArch (PS1) y PCSX2 (PS2) buscan la BIOS en ~/Juegos/BIOS
    ra_cfg = os.path.join(HOME, '.var/app', RA, 'config/retroarch/retroarch.cfg')
    if not os.path.exists(ra_cfg):
        os.makedirs(os.path.dirname(ra_cfg), exist_ok=True)
        with open(ra_cfg, 'w') as f:
            f.write(f'system_directory = "{os.path.join(JUEGOS, "BIOS")}"\nvideo_fullscreen = "true"\n'
                    'menu_driver = "ozone"\nconfig_save_on_exit = "true"\n')
    pcsx2 = os.path.join(HOME, '.var/app/net.pcsx2.PCSX2/config/PCSX2/inis/PCSX2.ini')
    if not os.path.exists(pcsx2):
        os.makedirs(os.path.dirname(pcsx2), exist_ok=True)
        with open(pcsx2, 'w') as f:
            f.write(f'[Folders]\nBios = {os.path.join(JUEGOS, "BIOS")}\n\n[UI]\nSetupWizardIncomplete = false\n')
    readme = os.path.join(JUEGOS, 'LEEME.txt')
    if not os.path.exists(readme):
        with open(readme, 'w') as f:
            f.write(LEEME)


LEEME = """Tus juegos para los emuladores de Apogeo
=========================================

Pon cada juego en la carpeta de su sistema y saldrá solo en Jugar → Emuladores, con su portada:

  NES, SNES, N64, GB, GBC, GBA, MegaDrive   un archivo por juego (.nes, .sfc, .z64, .gb, .gbc, .gba, .md o .zip)
  PS1                                       .chd, .cue (con su .bin) o .pbp
  PSP, PS2                                  .iso, .chd o .cso
  PS3                                       una carpeta por juego con PS3_GAME/USRDIR/EBOOT.BIN dentro
  GameCube, Wii                             .iso o .rvz (Wii también .wbfs)
  WiiU                                      .wua o .wux
  DS, 3DS                                   .nds · .3ds o .cci
  Switch                                    .nsp o .xci
  PS5                                       una carpeta por juego volcado (con eboot.bin, sce_module y sce_sys):
                                            Apogeo la convierte con AnyPS5 (experimental: aún van muy pocos)

Para que la portada salga sola, llama al archivo como el juego, por ejemplo «God of War (USA).iso».

Lo que algunos emuladores necesitan de tu consola (Apogeo no lo trae: sácalo de la tuya):
  PS1 y PS2   la BIOS, en la carpeta BIOS
  PS3         el sistema de la PS3: en RPCS3, Archivo → Instalar firmware (se baja gratis de la web de Sony)
  Switch      tus claves (prod.keys) y el firmware, en Ryujinx
  Wii U       tus claves, en Cemu

Solo tus copias de tus juegos: Apogeo no trae ni busca juegos.
"""
