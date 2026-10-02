"""
Datos para los widgets del escritorio y de la isla, por D-Bus (org.apogeo.Datos, /Datos, interfaz org.apogeo.Datos).
Lo sirve apogeo-pisos, que ya está siempre en marcha. Todo se devuelve como texto JSON (fácil de leer en QML).

  Tiempo()            el tiempo de tu ciudad (la de Ágape), con las próximas horas; se pide cada 20 minutos
  Proximo()           lo próximo del calendario de Ágape (hasta 3 planes de los siguientes 30 días)
  Pc()                temperatura, uso del procesador y de la memoria
  Estudio()           el temporizador de estudio (25 min / 5 de descanso; cada 4, uno largo de 15), lo de hoy y la semana
  EstudioAccion(a, v) alternar · saltar · reiniciar · asignatura (v = el nombre)
  Tareas() / GuardarTareas(json)        las tareas de hoy [{id, texto, hecha, asignatura}]
  Examenes() / GuardarExamenes(json)    los exámenes [{id, asignatura, fecha AAAA-MM-DD}]
  Asignaturas()       ~/Estudios: cada asignatura con sus carpetas (Temas, Trabajos, Ejercicios, que se crean solas)
  CrearAsignatura(n)  una carpeta nueva en ~/Estudios con sus tres carpetas
"""
import datetime
import glob
import json
import os
import re
import subprocess
import threading
import time
import urllib.request

import dbus
import dbus.service
from gi.repository import GLib

HOME = os.path.expanduser('~')
CONFIG = os.environ.get('XDG_CONFIG_HOME', os.path.join(HOME, '.config'))
AGAPE = os.path.join(CONFIG, 'ARES')
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

    # ---------- El tiempo ----------

    @dbus.service.method(IFACE, out_signature='s')
    def Tiempo(self):
        if time.time() - self.weather_at > 20 * 60:
            self.weather_at = time.time()
            threading.Thread(target=self._load_weather, daemon=True).start()
        return json.dumps(self.weather or {})

    def _load_weather(self):
        city = (read_json(os.path.join(AGAPE, 'settings.json'), {}) or {}).get('weatherCity') or {}
        if not city.get('lat'):
            self.weather = {'sinCiudad': True}
            return
        url = (f"https://api.open-meteo.com/v1/forecast?latitude={float(city['lat'])}&longitude={float(city['lon'])}"
               '&current=temperature_2m,weather_code,is_day&hourly=temperature_2m&daily=temperature_2m_max,'
               'temperature_2m_min&forecast_days=2&timezone=auto')
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
        }

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
