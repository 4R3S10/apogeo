"""
Datos para los widgets del escritorio y de la isla, por D-Bus (org.apogeo.Datos, /Datos, interfaz org.apogeo.Datos).
Lo sirve apogeo-pisos, que ya está siempre en marcha. Todo se devuelve como texto JSON (fácil de leer en QML).

  Tiempo()            el tiempo de tu ciudad (la de Apogeo o, si no, la de Ágape), con las próximas horas y los próximos
                      3 días; se pide cada 20 minutos
  BuscarCiudad(t)     ciudades que se llaman así (para elegir la tuya) · PonerCiudad(json) la guarda
  Proximo()           lo próximo del calendario de Ágape (hasta 3 planes de los siguientes 30 días)
  Agenda(fecha)       lo de ese día (AAAA-MM-DD): tus planes de Ágape y tus recordatorios, y los temporizadores en marcha
  Marcas(mes)         los días de ese mes (AAAA-MM) que tienen algo
  Recordar(json)      un recordatorio {texto, fecha, hora} · Temporizador(json) {minutos, texto} · Quitar(id)
                      (cuando llega la hora: un aviso que suena, con «Posponer 10 min»; sale aunque estés en Jugar)
  Pc()                temperatura, uso del procesador y de la memoria
  Estudio()           el temporizador de estudio (25 min / 5 de descanso; cada 4, uno largo de 15), lo de hoy y la semana
  EstudioAccion(a, v) alternar · saltar · reiniciar · asignatura (v = el nombre)
  Tareas() / GuardarTareas(json)        las tareas de hoy [{id, texto, hecha, asignatura}]
  Examenes() / GuardarExamenes(json)    los exámenes [{id, asignatura, fecha AAAA-MM-DD}]
  Asignaturas()       ~/Estudios: cada asignatura con sus carpetas (Temas, Trabajos, Ejercicios, que se crean solas)
  CrearAsignatura(n)  una carpeta nueva en ~/Estudios con sus tres carpetas
  Abrir(app)          abre una app de la lista (discord, spotify): la pide el modo partida de KWin (Meta+Tab)
  Musica()            lo que suena (MPRIS): {app, titulo, artista, portada, sonando}; {} si no suena nada
  MusicaAccion(a)     Previous · PlayPause · Next en ese reproductor
  Fondos()            tu biblioteca de fondos (animados, tuyos, carpeta), el de cada piso y «que cambie solo»
  PonerFondo(p, v)    el fondo del piso p (un animado o la ruta de una imagen o un vídeo); se ve al momento
  CambiarSolo(p, on)  «que cambie solo» en el piso p
  Ventanas()          tus ventanas: [{titulo, clase, app, pisos, x, y, w, h (de 0 a 1 en la pantalla), min, activa}]
  PonerVentanas(j)    (lo llama el script de KWin apogeo-ventanas cada vez que cambian)
"""
import datetime
import glob
import json
import os
import re
import subprocess
import threading
import time
import urllib.parse
import urllib.request
import uuid

import dbus
import dbus.service
from gi.repository import GLib

HOME = os.path.expanduser('~')
CONFIG = os.environ.get('XDG_CONFIG_HOME', os.path.join(HOME, '.config'))
AGAPE = os.path.join(CONFIG, 'ARES')
CITY_FILE = os.path.join(CONFIG, 'apogeo', 'ciudad.json')
REMINDERS_FILE = os.path.join(CONFIG, 'apogeo', 'recordatorios.json')
STUDY_FILE = os.path.join(CONFIG, 'apogeo', 'estudio.json')
STUDY_DIR = os.path.join(HOME, 'Estudios')
SUBFOLDERS = ('Temas', 'Trabajos', 'Ejercicios')
WORK, SHORT, LONG = 25 * 60, 5 * 60, 15 * 60
IFACE = 'org.apogeo.Datos'


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


def today():
    return datetime.date.today().isoformat()


class Datos(dbus.service.Object):
    def __init__(self, bus):
        self.name = dbus.service.BusName(IFACE, bus)
        super().__init__(self.name, '/Datos')
        self.weather = None
        self.weather_at = 0
        self.cpu_prev = None
        st = read_json(STUDY_FILE, {})
        self.study = {'tareas': st.get('tareas', []), 'examenes': st.get('examenes', []), 'dias': st.get('dias', {})}
        self.phase, self.cycle, self.subject = 'estudio', 1, st.get('asignatura', '')
        self.left, self.running, self.ends = WORK, False, 0
        self.tick_id = None
        self.windows = '[]'
        # Recordatorios y temporizadores: se mira cada 10 s si toca alguno (los que pasaron con el PC apagado, al entrar)
        self.reminders = read_json(REMINDERS_FILE, [])
        self.ringing = {}  # id del aviso → recordatorio
        self.bus = bus
        bus.add_signal_receiver(self._reminder_action, 'ActionInvoked', 'org.freedesktop.Notifications',
                                path='/org/freedesktop/Notifications')
        GLib.timeout_add_seconds(10, self._check_reminders)

    # ---------- El tiempo ----------

    # Solo estas: el modo partida (apogeo-partida, en KWin) abre Discord o Spotify si aún no están
    APPS = {'discord': 'discord.desktop', 'spotify': 'spotify-launcher.desktop'}

    @dbus.service.method(IFACE, in_signature='s')
    def Abrir(self, app):
        if app == 'hud':  # MangoHud en el juego: enseñarlo o esconderlo (el botón «HUD» del modo partida y de la isla)
            subprocess.Popen(['mangohudctl', 'toggle', 'no_display'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            return
        if app == 'fondos':  # «Más…» del carrusel de fondos: Ajustes → Fondos
            subprocess.Popen(['/usr/lib/apogeo/apogeo-ajustes', 'fondos'], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            return
        desktop = self.APPS.get(app)
        if not desktop:
            return
        subprocess.Popen(['gtk-launch', desktop], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    def _player(self):
        """El reproductor que suena (si no, Spotify; si no, el primero), como en la isla."""
        bus = dbus.SessionBus()
        names = [n for n in bus.list_names() if str(n).startswith('org.mpris.MediaPlayer2.')]
        best = None
        for n in names:
            try:
                props = dbus.Interface(bus.get_object(n, '/org/mpris/MediaPlayer2'), 'org.freedesktop.DBus.Properties')
                status = str(props.Get('org.mpris.MediaPlayer2.Player', 'PlaybackStatus'))
            except dbus.DBusException:
                continue
            rank = 2 if status == 'Playing' else 1 if 'spotify' in n.lower() else 0
            if best is None or rank > best[0]:
                best = (rank, n, props, status)
        return best

    # ---------- Tus ventanas (las cuenta KWin) ----------

    @dbus.service.method(IFACE, in_signature='s')
    def PonerVentanas(self, j):
        if len(j) < 200000:
            self.windows = j

    @dbus.service.method(IFACE, out_signature='s')
    def Ventanas(self):
        return self.windows

    @dbus.service.method(IFACE, out_signature='s')
    def Musica(self):
        best = self._player()
        if not best:
            return '{}'
        _, name, props, status = best
        try:
            meta = props.Get('org.mpris.MediaPlayer2.Player', 'Metadata')
        except dbus.DBusException:
            meta = {}
        artist = meta.get('xesam:artist', [])
        return json.dumps({
            'app': name.split('.')[3] if name.count('.') >= 3 else name,
            'titulo': str(meta.get('xesam:title', '')),
            'artista': ', '.join(str(a) for a in artist) if isinstance(artist, (list, dbus.Array)) else str(artist),
            'portada': str(meta.get('mpris:artUrl', '')),
            'sonando': status == 'Playing',
        }, ensure_ascii=False)

    @dbus.service.method(IFACE, in_signature='s')
    def MusicaAccion(self, action):
        if action not in ('Previous', 'PlayPause', 'Next'):
            return
        best = self._player()
        if best:
            try:
                dbus.SessionBus().get_object(best[1], '/org/mpris/MediaPlayer2').get_dbus_method(
                    action, 'org.mpris.MediaPlayer2.Player')()
            except dbus.DBusException:
                pass

    @dbus.service.method(IFACE, out_signature='s')
    def Fondos(self):
        import apogeo_comun as comun
        import apogeo_fondos as fondos
        st = comun.load()
        out = fondos.library(st)
        out['pisos'] = {k: st['pisos'][k]['fondo'] for k in comun.FLOOR_KEYS}
        out['cambiar'] = st['fondos']['cambiar']
        return json.dumps(out, ensure_ascii=False)

    @dbus.service.method(IFACE, in_signature='ss')
    def PonerFondo(self, floor, value):
        import apogeo_comun as comun
        if floor not in comun.FLOOR_KEYS or (value not in comun.STYLES and not comun.is_wallpaper_file(value)):
            return
        st = comun.load()
        st['pisos'][floor]['fondo'] = value
        comun.save(st)  # apogeo-pisos lo ve y lo pone

    @dbus.service.method(IFACE, in_signature='ss')  # (on: «true» o «false»: los widgets solo mandan texto)
    def CambiarSolo(self, floor, on):
        import apogeo_comun as comun
        if floor not in comun.FLOOR_KEYS:
            return
        st = comun.load()
        st['fondos']['cambiar'][floor]['activo'] = str(on).lower() == 'true'
        comun.save(st)

    @dbus.service.method(IFACE, out_signature='s')
    def Tiempo(self):
        if time.time() - self.weather_at > 20 * 60:
            self.weather_at = time.time()
            threading.Thread(target=self._load_weather, daemon=True).start()
        return json.dumps(self.weather or {})

    def _load_weather(self):
        city = read_json(CITY_FILE, {}) or (read_json(os.path.join(AGAPE, 'settings.json'), {}) or {}).get('weatherCity') or {}
        if not city.get('lat'):
            self.weather = {'sinCiudad': True}
            return
        url = (f"https://api.open-meteo.com/v1/forecast?latitude={float(city['lat'])}&longitude={float(city['lon'])}"
               '&current=temperature_2m,weather_code,is_day&hourly=temperature_2m&daily=weather_code,temperature_2m_max,'
               'temperature_2m_min&forecast_days=4&timezone=auto')
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Apogeo'}), timeout=12) as r:
                d = json.load(r)
        except (OSError, ValueError):
            self.weather_at = time.time() - 18 * 60  # sin conexión: se reintenta en 2 minutos
            return
        now = datetime.datetime.now().strftime('%Y-%m-%dT%H:00')
        times = d.get('hourly', {}).get('time', [])
        temps = d.get('hourly', {}).get('temperature_2m', [])
        start = times.index(now) + 1 if now in times else 0
        self.weather = {
            'ciudad': str(city.get('name', '')),
            'temp': round(d['current']['temperature_2m']), 'codigo': int(d['current']['weather_code']),
            'dia': bool(d['current']['is_day']),
            'max': round(d['daily']['temperature_2m_max'][0]), 'min': round(d['daily']['temperature_2m_min'][0]),
            'horas': [{'h': times[i][11:13], 't': round(temps[i])} for i in range(start, min(start + 6, len(times)))],
            'dias': [{'dia': 'LMXJVSD'[datetime.date.fromisoformat(day).weekday()],
                      'codigo': int(d['daily']['weather_code'][i]), 'max': round(d['daily']['temperature_2m_max'][i]),
                      'min': round(d['daily']['temperature_2m_min'][i])}
                     for i, day in enumerate(d['daily'].get('time', [])[1:4], start=1)],
        }

    @dbus.service.method(IFACE, in_signature='s', out_signature='s')
    def BuscarCiudad(self, text):
        """Las ciudades que se llaman así (Open-Meteo, en español), para elegir la tuya."""
        url = ('https://geocoding-api.open-meteo.com/v1/search?count=6&language=es&format=json&name='
               + urllib.parse.quote(text.strip()[:60]))
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Apogeo'}), timeout=10) as r:
                found = json.load(r).get('results') or []
        except (OSError, ValueError):
            return json.dumps(None)
        return json.dumps([{'name': c.get('name', ''), 'zona': ', '.join(x for x in (c.get('admin1'), c.get('country')) if x),
                            'lat': c['latitude'], 'lon': c['longitude']} for c in found if 'latitude' in c],
                          ensure_ascii=False)

    @dbus.service.method(IFACE, in_signature='s')
    def PonerCiudad(self, data):
        c = json.loads(data)
        write_json(CITY_FILE, {'name': str(c['name']), 'lat': float(c['lat']), 'lon': float(c['lon'])})
        self.weather, self.weather_at = {}, 0
        self.Tiempo()

    # ---------- Calendario de Ágape ----------

    @dbus.service.method(IFACE, out_signature='s')
    def Proximo(self):
        events = read_json(os.path.join(AGAPE, 'calendar.json'), [])
        now = datetime.datetime.now()
        hhmm = now.strftime('%H:%M')
        out = []
        for e in sorted((e for e in events if isinstance(e, dict) and re.match(r'^\d{4}-\d{2}-\d{2}$', str(e.get('date', '')))),
                        key=lambda e: (e['date'], e.get('time') or '99')):
            day = datetime.date.fromisoformat(e['date'])
            days = (day - now.date()).days
            if days < 0 or days > 30 or (days == 0 and e.get('time') and e['time'] < hhmm):
                continue
            out.append({'texto': str(e.get('text', '')), 'dias': days, 'hora': str(e.get('time') or ''), 'fecha': e['date']})
            if len(out) == 3:
                break
        return json.dumps(out, ensure_ascii=False)

    # ---------- La agenda: tus planes de Ágape y tus recordatorios ----------

    def _agape_events(self):
        return [e for e in read_json(os.path.join(AGAPE, 'calendar.json'), [])
                if isinstance(e, dict) and re.match(r'^\d{4}-\d{2}-\d{2}$', str(e.get('date', '')))]

    @dbus.service.method(IFACE, in_signature='s', out_signature='s')
    def Agenda(self, day):
        things = [{'tipo': 'agape', 'texto': str(e.get('text', '')), 'hora': str(e.get('time') or ''), 'id': ''}
                  for e in self._agape_events() if e['date'] == day]
        for r in self.reminders:
            when = datetime.datetime.fromtimestamp(r['cuando'])
            if r['tipo'] == 'recordatorio' and when.date().isoformat() == day:
                things.append({'tipo': 'recordatorio', 'texto': r['texto'], 'hora': when.strftime('%H:%M'), 'id': r['id']})
        things.sort(key=lambda t: t['hora'] or '99')
        timers = [{'id': r['id'], 'texto': r['texto'], 'termina': r['cuando']} for r in self.reminders
                  if r['tipo'] == 'temporizador']
        return json.dumps({'cosas': things, 'temporizadores': timers}, ensure_ascii=False)

    @dbus.service.method(IFACE, in_signature='s', out_signature='s')
    def Marcas(self, month):
        days = {int(e['date'][8:10]) for e in self._agape_events() if e['date'].startswith(month)}
        for r in self.reminders:
            when = datetime.date.fromtimestamp(r['cuando'])
            if r['tipo'] == 'recordatorio' and when.isoformat().startswith(month):
                days.add(when.day)
        return json.dumps(sorted(days))

    def _save_reminders(self):
        write_json(REMINDERS_FILE, self.reminders)

    @dbus.service.method(IFACE, in_signature='s', out_signature='s')
    def Recordar(self, data):
        d = json.loads(data)
        when = datetime.datetime.fromisoformat(f"{d['fecha']}T{d['hora']}")
        r = {'id': uuid.uuid4().hex[:10], 'tipo': 'recordatorio', 'texto': str(d.get('texto') or 'Recordatorio')[:120],
             'cuando': when.timestamp()}
        self.reminders.append(r)
        self._save_reminders()
        return r['id']

    @dbus.service.method(IFACE, in_signature='s', out_signature='s')
    def Temporizador(self, data):
        d = json.loads(data)
        minutes = max(1, min(24 * 60, int(d['minutos'])))
        r = {'id': uuid.uuid4().hex[:10], 'tipo': 'temporizador', 'minutos': minutes,
             'texto': str(d.get('texto') or f'Temporizador de {minutes} min')[:120], 'cuando': time.time() + minutes * 60}
        self.reminders.append(r)
        self._save_reminders()
        return r['id']

    @dbus.service.method(IFACE, in_signature='s')
    def Quitar(self, rid):
        self.reminders = [r for r in self.reminders if r['id'] != rid]
        self._save_reminders()

    def _check_reminders(self):
        now = time.time()
        due = [r for r in self.reminders if r['cuando'] <= now]
        if due:
            self.reminders = [r for r in self.reminders if r['cuando'] > now]
            self._save_reminders()
            for r in due:
                self._ring(r, late=now - r['cuando'] > 120)
        return True

    def _ring(self, r, late=False):
        """El aviso que suena: urgente (sale aunque estés en Jugar o en Estudiar, y se queda hasta que lo cierras)."""
        when = datetime.datetime.fromtimestamp(r['cuando']).strftime('%H:%M')
        title = '¡Se acabó el tiempo!' if r['tipo'] == 'temporizador' else r['texto']
        body = (r['texto'] if r['tipo'] == 'temporizador' else
                (f'Era a las {when} (el equipo estaba apagado)' if late else f'Son las {when}'))
        try:  # (se busca cada vez: si Plasma se reinicia, el de antes ya no está)
            notify = dbus.Interface(self.bus.get_object('org.freedesktop.Notifications', '/org/freedesktop/Notifications'),
                                    'org.freedesktop.Notifications')
            nid = notify.Notify('Apogeo', dbus.UInt32(0), 'alarm-symbolic', title, body,
                                ['posponer', 'Posponer 10 min', 'hecho', 'Hecho'],
                                dbus.Dictionary({'urgency': dbus.Byte(2), 'sound-name': 'alarm-clock-elapsed',
                                                 'x-kde-display-appname': 'Recordatorio'}, signature='sv'),
                                dbus.Int32(0))
            self.ringing[int(nid)] = r
        except dbus.DBusException:
            pass

    def _reminder_action(self, nid, action):
        r = self.ringing.pop(int(nid), None)
        if r and action == 'posponer':
            self.reminders.append({**r, 'cuando': time.time() + 600})
            self._save_reminders()

    # ---------- Tu PC ----------

    @dbus.service.method(IFACE, out_signature='s')
    def Pc(self):
        temp = 0
        for d in glob.glob('/sys/class/hwmon/hwmon*'):
            try:
                name = open(f'{d}/name').read().strip()
            except OSError:
                continue
            if name in ('k10temp', 'zenpower', 'coretemp', 'cpu_thermal', 'amdgpu'):
                for p in glob.glob(f'{d}/temp*_input'):
                    try:
                        temp = max(temp, int(open(p).read()) / 1000)
                    except (OSError, ValueError):
                        pass
        try:
            v = [int(x) for x in open('/proc/stat').readline().split()[1:]]
            idle, total = v[3] + v[4], sum(v)
            prev, self.cpu_prev = self.cpu_prev, (idle, total)
            cpu = 0 if not prev or total == prev[1] else round(100 * (1 - (idle - prev[0]) / (total - prev[1])))
        except (OSError, ValueError):
            cpu = 0
        mem = {}
        try:
            for line in open('/proc/meminfo'):
                k, v = line.split(':', 1)
                mem[k] = int(v.split()[0])
            used = round(100 * (1 - mem['MemAvailable'] / mem['MemTotal']))
        except (OSError, KeyError, ValueError):
            used = 0
        return json.dumps({'temp': round(temp), 'cpu': cpu, 'mem': used})

    # ---------- Estudio ----------

    def _save(self):
        write_json(STUDY_FILE, {**self.study, 'asignatura': self.subject})

    def _remaining(self):
        return max(0, round(self.ends - time.time())) if self.running else self.left

    @dbus.service.method(IFACE, out_signature='s')
    def Estudio(self):
        days = self.study['dias']
        week = []
        monday = datetime.date.today() - datetime.timedelta(days=datetime.date.today().weekday())
        for i in range(7):
            week.append(days.get((monday + datetime.timedelta(days=i)).isoformat(), 0))
        total = {'estudio': WORK, 'descanso': SHORT, 'largo': LONG}[self.phase]
        return json.dumps({'fase': self.phase, 'quedan': self._remaining(), 'total': total, 'corriendo': self.running,
                           'ciclo': self.cycle, 'asignatura': self.subject, 'hoy': days.get(today(), 0),
                           'semana': week}, ensure_ascii=False)

    @dbus.service.method(IFACE, in_signature='ss')
    def EstudioAccion(self, action, value):
        if action == 'alternar':
            if self.running:
                self.left, self.running = self._remaining(), False
            else:
                self.ends, self.running = time.time() + self.left, True
                if not self.tick_id:
                    self.tick_id = GLib.timeout_add_seconds(1, self._tick)
        elif action == 'saltar':
            self._next_phase(alert=False)
        elif action == 'reiniciar':
            self.phase, self.cycle, self.left, self.running = 'estudio', 1, WORK, False
        elif action == 'asignatura':
            self.subject = str(value)[:40]
            self._save()

    def _tick(self):
        if not self.running:
            self.tick_id = None
            return False
        if self.phase == 'estudio':
            d = self.study['dias']
            d[today()] = d.get(today(), 0) + 1
            if d[today()] % 30 == 0:
                self.study['dias'] = {k: v for k, v in d.items() if k >= (datetime.date.today() - datetime.timedelta(days=60)).isoformat()}
                self._save()
        if time.time() >= self.ends:
            self._next_phase(alert=True)
        return True

    def _next_phase(self, alert):
        if self.phase == 'estudio':
            self.phase = 'largo' if self.cycle % 4 == 0 else 'descanso'
            msg = '¡A descansar! ' + ('15 minutos' if self.phase == 'largo' else '5 minutos')
        else:
            self.phase = 'estudio'
            self.cycle += 1
            msg = 'Vuelta al estudio: 25 minutos'
        self.left = {'estudio': WORK, 'descanso': SHORT, 'largo': LONG}[self.phase]
        if self.running:
            self.ends = time.time() + self.left
        self._save()
        if alert:  # (urgente: sale aunque el piso Estudiar no deje pasar los avisos)
            subprocess.Popen(['notify-send', '-a', 'Estudiar', '-i', 'apogeo', '-u', 'critical', '-t', '8000', 'Estudiar', msg],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @dbus.service.method(IFACE, out_signature='s')
    def Tareas(self):
        return json.dumps(self.study['tareas'], ensure_ascii=False)

    @dbus.service.method(IFACE, in_signature='s')
    def GuardarTareas(self, data):
        items = json.loads(data)
        self.study['tareas'] = [{'id': str(t.get('id', '')), 'texto': str(t.get('texto', ''))[:120], 'hecha': bool(t.get('hecha')),
                                 'asignatura': str(t.get('asignatura', ''))[:40]} for t in items if isinstance(t, dict)][:50]
        self._save()

    @dbus.service.method(IFACE, out_signature='s')
    def Examenes(self):
        return json.dumps(sorted(self.study['examenes'], key=lambda e: e.get('fecha', '')), ensure_ascii=False)

    @dbus.service.method(IFACE, in_signature='s')
    def GuardarExamenes(self, data):
        items = json.loads(data)
        self.study['examenes'] = [{'id': str(e.get('id', '')), 'asignatura': str(e.get('asignatura', ''))[:40],
                                   'fecha': str(e.get('fecha', ''))[:10]} for e in items
                                  if isinstance(e, dict) and re.match(r'^\d{4}-\d{2}-\d{2}$', str(e.get('fecha', '')))][:30]
        self._save()

    @dbus.service.method(IFACE, out_signature='s')
    def Asignaturas(self):
        os.makedirs(STUDY_DIR, exist_ok=True)
        out = []
        for name in sorted(os.listdir(STUDY_DIR), key=str.lower):
            path = os.path.join(STUDY_DIR, name)
            if name.startswith('.') or not os.path.isdir(path):
                continue
            folders = []
            for sub in SUBFOLDERS:
                p = os.path.join(path, sub)
                os.makedirs(p, exist_ok=True)
                files = sorted((f for f in os.listdir(p) if not f.startswith('.')), key=lambda f: -os.path.getmtime(os.path.join(p, f)))
                folders.append({'nombre': sub, 'ruta': p, 'archivos': [{'nombre': f, 'ruta': os.path.join(p, f)} for f in files[:12]],
                                'cuantos': len(files)})
            out.append({'nombre': name, 'ruta': path, 'carpetas': folders})
        return json.dumps(out, ensure_ascii=False)

    @dbus.service.method(IFACE, in_signature='s')
    def CrearAsignatura(self, name):
        name = re.sub(r'[/\x00]', '', str(name)).strip()[:40]
        if name and not name.startswith('.'):
            for sub in SUBFOLDERS:
                os.makedirs(os.path.join(STUDY_DIR, name, sub), exist_ok=True)
