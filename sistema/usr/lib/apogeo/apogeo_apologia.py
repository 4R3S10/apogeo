"""
apologIA, la IA de Apogeo que corre en tu PC. Aquí está todo lo que no es la ventana (esa es apogeo-apologia con
Apologia.qml):
  Motor     llama-server (llama.cpp), solo en 127.0.0.1, con el modelo que elijas. El modelo se reparte solo: lo que cabe
            en la GPU (Vulkan), el resto en la RAM y, si tampoco cabe, se lee del disco (mmap). La memoria de cada chat
            (su caché KV) se guarda en el disco al acabar cada respuesta y se recupera al volver a ese chat.
  Modelos   los .gguf de ~/Modelos, todos juntos (o de la carpeta que elijas; los de otras carpetas se añaden con un
            enlace). Se buscan en
            Hugging Face y en GitHub, o se bajan de cualquier enlace. Solo GGUF: son datos, no ejecutan nada al abrirse
            (los .bin/.pt de PyTorch sí podrían, y no se aceptan).
  Chats     uno por archivo en chats/, con qué modelo se escribió cada respuesta. Al cambiar de modelo se le pasa la
            conversación entera: el hilo no se pierde.
  Ajustes   el «Modificador»: tus instrucciones (o ninguna), sin límite de largo, la creatividad, la memoria…
  Colab     un cuaderno para usar la GPU gratis de Google Colab con modelos grandes, chateando dentro del cuaderno (lo
            que Colab gratis permite).
"""
import hashlib
import json
import os
import re
import secrets
import shutil
import signal
import socket
import struct
import subprocess
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

HOME = os.path.expanduser('~')
DATA = os.path.join(os.environ.get('XDG_DATA_HOME', os.path.join(HOME, '.local/share')), 'apologia')
CONFIG = os.path.join(os.environ.get('XDG_CONFIG_HOME', os.path.join(HOME, '.config')), 'apologia')
CACHE = os.path.join(os.environ.get('XDG_CACHE_HOME', os.path.join(HOME, '.cache')), 'apologia')
DEFAULT_MODELS = os.path.join(HOME, 'Modelos')
OLD_MODELS = os.path.join(DATA, 'modelos')     # (donde iban al principio, escondidos)
MODELS = DEFAULT_MODELS                        # la de ahora: la pone use_models_dir() con tus ajustes
CHATS = os.path.join(DATA, 'chats')
KV = os.path.join(CACHE, 'memoria')            # la caché KV de cada chat (una carpeta por modelo)
KV_MAX = 3 << 30                               # (de cada modelo se guardan los chats más recientes, hasta 3 GB)
SETTINGS = os.path.join(CONFIG, 'ajustes.json')
TOKEN = os.path.join(CONFIG, 'token-hf')       # tu token de Hugging Face, para los modelos con licencia (600)
META = os.path.join(CACHE, 'modelos.json')     # lo leído de cada .gguf, para no volver a leerlo
LOG = os.path.join(CACHE, 'motor.log')
LLAMA = os.environ.get('APOLOGIA_LLAMA') or shutil.which('llama-server') or '/usr/bin/llama-server'
AGENT = 'Apologia (Apogeo)'

DEFAULTS = {
    'sistema': '',          # tus instrucciones para el modelo ('' = ninguna)
    'largo': 0,             # máximo de tokens por respuesta (0 = sin límite)
    'temperatura': 0.8,
    'top_p': 0.95,
    'top_k': 40,
    'min_p': 0.05,
    'repeticion': 1.0,
    'contexto': 8192,       # la memoria de la conversación, en tokens (0 = la máxima del modelo)
    'pensar': True,         # los modelos que razonan antes de contestar (Qwen3, DeepSeek…)
    'gpu': 'auto',          # auto · cpu
    'hilos': 0,             # 0 = los que elija llama.cpp
    'modelo': '',           # el último elegido
    'carpeta': '',          # la carpeta de los modelos ('' = ~/Modelos)
}
PRESETS = {
    'preciso': {'temperatura': 0.3, 'top_p': 0.9, 'top_k': 20, 'min_p': 0.05, 'repeticion': 1.05},
    'equilibrado': {'temperatura': 0.8, 'top_p': 0.95, 'top_k': 40, 'min_p': 0.05, 'repeticion': 1.0},
    'creativo': {'temperatura': 1.15, 'top_p': 0.98, 'top_k': 80, 'min_p': 0.02, 'repeticion': 1.0},
}


def load_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + '.tmp'
    with open(tmp, 'w') as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(tmp, path)


def settings():
    st = dict(DEFAULTS)
    st.update({k: v for k, v in load_json(SETTINGS, {}).items() if k in DEFAULTS})
    return st


def save_settings(changes):
    st = settings()
    st.update({k: v for k, v in changes.items() if k in DEFAULTS})
    save_json(SETTINGS, st)
    return st


def use_models_dir(path=''):
    global MODELS
    MODELS = os.path.abspath(os.path.expanduser(path)) if path else DEFAULT_MODELS
    return MODELS


def move_models(src, dest, on_progress=lambda done, total, name: None):
    """Lleva los modelos (con sus partes y los enlaces) de una carpeta a otra. Si es a otro disco, mira antes que
    quepan. Lanza RuntimeError con el porqué si no puede."""
    os.makedirs(dest, exist_ok=True)
    if not os.path.isdir(src):
        return
    files = sorted(f for f in os.listdir(src) if f.endswith('.gguf'))
    if os.stat(src).st_dev != os.stat(dest).st_dev:
        need = sum(os.path.getsize(os.path.join(src, f)) for f in files if not os.path.islink(os.path.join(src, f)))
        free = shutil.disk_usage(dest).free
        if free < need + (512 << 20):
            raise RuntimeError(f'No caben: hacen falta {human(need)} y en ese disco quedan {human(free)}')
    moved = []
    for i, f in enumerate(files):
        on_progress(i, len(files), f)
        target = os.path.join(dest, f)
        if os.path.lexists(target):
            continue
        try:
            shutil.move(os.path.join(src, f), target)
            moved.append(f)
        except OSError as e:
            if os.path.lexists(os.path.join(src, f)) and os.path.lexists(target):
                os.remove(target)  # (la copia a medias en el otro disco)
            for m in moved:  # (a medias no: lo movido vuelve a su sitio)
                try:
                    shutil.move(os.path.join(dest, m), os.path.join(src, m))
                except OSError:
                    pass
            raise RuntimeError(f'No se ha podido mover {f}: {e.strerror or e}')


def migrate_old():
    """Los modelos de la carpeta escondida del principio (~/.local/share/apologia/modelos) pasan a la de ahora."""
    if os.path.isdir(OLD_MODELS) and os.path.realpath(OLD_MODELS) != os.path.realpath(MODELS):
        try:
            move_models(OLD_MODELS, MODELS)
            for f in os.listdir(OLD_MODELS):
                if f.endswith('.part'):
                    os.remove(os.path.join(OLD_MODELS, f))
            os.rmdir(OLD_MODELS)
        except (OSError, RuntimeError):
            pass


def ram_total():
    try:
        with open('/proc/meminfo') as f:
            for line in f:
                if line.startswith('MemTotal:'):
                    return int(line.split()[1]) * 1024
    except OSError:
        pass
    return 8 << 30


def free_space():
    os.makedirs(MODELS, exist_ok=True)
    return shutil.disk_usage(MODELS).free


def fit(size):
    """Cómo irá un modelo de ese tamaño en este PC: «rapido» (cabe holgado), «lento» (justo) o «disco» (no cabe en la
    RAM: se leerá del disco, muy despacio)."""
    ram = ram_total()
    return 'rapido' if size < ram * 0.45 else 'lento' if size < ram * 0.8 else 'disco'


# ---------- Los .gguf ----------

_SCALAR = {0: '<B', 1: '<b', 2: '<H', 3: '<h', 4: '<I', 5: '<i', 6: '<f', 7: '<?', 10: '<Q', 11: '<q', 12: '<d'}
# general.file_type de llama.cpp → el nombre de la cuantización
FTYPES = {0: 'F32', 1: 'F16', 2: 'Q4_0', 3: 'Q4_1', 7: 'Q8_0', 8: 'Q5_0', 9: 'Q5_1', 10: 'Q2_K', 11: 'Q3_K_S',
          12: 'Q3_K_M', 13: 'Q3_K_L', 14: 'Q4_K_S', 15: 'Q4_K_M', 16: 'Q5_K_S', 17: 'Q5_K_M', 18: 'Q6_K',
          19: 'IQ2_XXS', 20: 'IQ2_XS', 21: 'Q2_K_S', 22: 'IQ3_XS', 23: 'IQ3_XXS', 24: 'IQ1_S', 25: 'IQ4_NL',
          26: 'IQ3_S', 27: 'IQ3_M', 28: 'IQ2_S', 29: 'IQ2_M', 30: 'IQ4_XS', 31: 'IQ1_M', 32: 'BF16', 36: 'TQ1_0',
          37: 'TQ2_0', 38: 'MXFP4'}
QUANT = re.compile(r'(?<![A-Za-z0-9])(UD-)?(I?Q\d(?:_[A-Z0-9]+)*|BF16|F16|F32|MXFP4(?:_MOE)?)(?![A-Za-z0-9])', re.I)
SPLIT = re.compile(r'-(\d{5})-of-(\d{5})\.gguf$')
# Lo que viene en los repositorios junto a los modelos y no es uno: proyectores de visión, datos de calibración,
# cabezas de predicción (MTP), borradores y adaptadores
NOT_MODEL = re.compile(r'mmproj|imatrix|(^|[-_.])(mtp|draft|lora)([-_.]|$)', re.I)
# Los que traen quitadas las protecciones del modelo no salen en «Lo más bajado» (sí si los buscas por su nombre)
UNSAFE = re.compile(r'abliterat|uncensor|heretic|decensor', re.I)
# Los tipos de Hugging Face que no son para conversar (voz, imágenes, búsquedas…)
NOT_CHAT = {'text-to-speech', 'automatic-speech-recognition', 'text-to-audio', 'audio-to-audio', 'text-to-image',
            'image-to-image', 'feature-extraction', 'sentence-similarity', 'text-classification', 'token-classification',
            'text-ranking', 'image-classification', 'object-detection', 'image-segmentation', 'depth-estimation',
            'text-to-video', 'image-to-video', 'zero-shot-classification', 'fill-mask', 'translation'}


def gguf_header(path):
    """Las claves general.* y el contexto máximo de la cabecera de un .gguf (sin leer el modelo)."""
    out = {}
    with open(path, 'rb') as f:
        if f.read(4) != b'GGUF':
            raise ValueError('no es un GGUF')
        version, _tensors, count = struct.unpack('<IQQ', f.read(20))
        if version < 2:
            raise ValueError('GGUF demasiado antiguo')

        def text():
            n, = struct.unpack('<Q', f.read(8))
            if n > 1 << 26:
                raise ValueError('cabecera rota')
            return f.read(n).decode('utf-8', 'replace')

        def value(kind):
            if kind == 8:
                return text()
            if kind == 9:  # una lista (el vocabulario: se salta)
                inner, n = struct.unpack('<IQ', f.read(12))
                if inner == 8:
                    for _ in range(n):
                        m, = struct.unpack('<Q', f.read(8))
                        f.seek(m, 1)
                elif inner in _SCALAR:
                    f.seek(struct.calcsize(_SCALAR[inner]) * n, 1)
                else:
                    raise ValueError('lista rara')
                return None
            fmt = _SCALAR[kind]
            return struct.unpack(fmt, f.read(struct.calcsize(fmt)))[0]

        for _ in range(min(count, 1 << 20)):
            key = text()
            kind, = struct.unpack('<I', f.read(4))
            if kind not in _SCALAR and kind not in (8, 9):
                break
            v = value(kind)
            if v is not None and (key.startswith('general.') or key.endswith('.context_length')):
                out[key] = v
            if key.startswith('tokenizer.') and len(out) > 3:
                break  # (lo que interesa va antes del vocabulario)
    return out


def quant_of(name):
    m = QUANT.search(os.path.basename(name).replace('.gguf', ''))
    return (m.group(1) or '').upper() + m.group(2).upper() if m else ''


def nice_name(name):
    """«Qwen3-4B-Instruct-2507-Q4_K_M.gguf» → «Qwen3 4B Instruct 2507»."""
    base = SPLIT.sub('', os.path.basename(name)).removesuffix('.gguf')
    q = QUANT.search(base)
    if q:
        base = base[:q.start()] + base[q.end():]
    return re.sub(r'[-_ ]+|(?<!\d)\.|\.(?!\d)', ' ', base).strip() or os.path.basename(name)


def summary(head, name):
    arch = head.get('general.architecture', '')
    ft = head.get('general.file_type')
    return {
        'nombre': nice_name(name),
        'arquitectura': arch,
        'parametros': head.get('general.size_label', ''),
        'contextoMax': int(head.get(f'{arch}.context_length', 0) or 0),
        'cuant': (FTYPES.get(ft, '') if isinstance(ft, int) else '') or quant_of(name),
        'tipo': head.get('general.type', 'model'),
    }


def model_parts(name):
    """Los archivos de un modelo (los de uno partido en trozos: …-00001-of-00003.gguf…)."""
    m = SPLIT.search(name)
    if not m:
        return [name]
    base, total = name[:m.start()], int(m.group(2))
    return [f'{base}-{i:05d}-of-{total:05d}.gguf' for i in range(1, total + 1)]


def models():
    """Los modelos que tienes: [{archivo, nombre, parametros, cuant, tamano, contextoMax, enlace, va}]."""
    os.makedirs(MODELS, exist_ok=True)
    cache, dirty, out = load_json(META, {}), False, []
    for name in sorted(os.listdir(MODELS), key=str.lower):
        if not name.endswith('.gguf') or NOT_MODEL.search(name):
            continue
        m = SPLIT.search(name)
        if m and m.group(1) != '00001':
            continue
        parts = model_parts(name)
        path = os.path.join(MODELS, name)
        try:
            st = os.stat(path)
            size = sum(os.path.getsize(os.path.join(MODELS, p)) for p in parts)
        except OSError:
            continue  # (un enlace roto o una parte que falta)
        key = f'{name}:{st.st_mtime_ns}:{size}'
        info = cache.get(key)
        if info is None:
            try:
                info = summary(gguf_header(path), name)
            except (OSError, ValueError, struct.error):
                continue
            cache[key], dirty = info, True
        if info.get('tipo') not in ('model', None):
            continue  # (adaptadores LoRA, proyectores de visión…)
        out.append(dict(info, nombre=nice_name(name), archivo=name, tamano=size, enlace=os.path.islink(path),
                        va=fit(size)))
    if dirty:
        save_json(META, cache)
    return out


def delete_model(name):
    for p in model_parts(os.path.basename(name)):
        try:
            os.remove(os.path.join(MODELS, p))
        except OSError:
            pass
    shutil.rmtree(os.path.join(KV, kv_dir(name)), ignore_errors=True)


def import_model(path):
    """Añade un .gguf de otra carpeta (un disco externo…) con un enlace: no se copia ni ocupa más."""
    path = os.path.abspath(path)
    with open(path, 'rb') as f:
        if f.read(4) != b'GGUF':
            raise ValueError('Ese archivo no es un modelo GGUF')
    os.makedirs(MODELS, exist_ok=True)
    folder, name = os.path.split(path)
    for p in model_parts(name):
        dest = os.path.join(MODELS, p)
        if os.path.lexists(dest):
            continue
        if not os.path.exists(os.path.join(folder, p)):
            raise ValueError(f'Falta la parte {p}')
        os.symlink(os.path.join(folder, p), dest)
    return name


# ---------- Los chats ----------

def chat_list():
    os.makedirs(CHATS, exist_ok=True)
    out = []
    for f in os.listdir(CHATS):
        if f.endswith('.json'):
            c = load_json(os.path.join(CHATS, f), None)
            if c and c.get('id'):
                out.append({'id': c['id'], 'titulo': c.get('titulo') or 'Chat nuevo',
                            'actualizado': c.get('actualizado', 0)})
    return sorted(out, key=lambda c: -c['actualizado'])


def new_chat():
    now = time.time()
    return {'id': f'{int(now * 1000):x}', 'titulo': '', 'creado': now, 'actualizado': now, 'mensajes': []}


def load_chat(cid):
    c = load_json(os.path.join(CHATS, os.path.basename(cid) + '.json'), None)
    return c if c and c.get('id') else None


def save_chat(chat):
    chat['actualizado'] = time.time()
    if not chat.get('titulo'):
        first = next((m['texto'] for m in chat['mensajes'] if m['rol'] == 'user'), '')
        first = ' '.join(first.split())
        chat['titulo'] = first[:42] + ('…' if len(first) > 42 else '')
    save_json(os.path.join(CHATS, chat['id'] + '.json'), chat)


def delete_chat(cid):
    cid = os.path.basename(cid)
    try:
        os.remove(os.path.join(CHATS, cid + '.json'))
    except OSError:
        pass
    if os.path.isdir(KV):
        for d in os.listdir(KV):
            try:
                os.remove(os.path.join(KV, d, cid + '.bin'))
            except OSError:
                pass


def build_messages(chat, st, ctx):
    """Lo que se le manda al modelo: tus instrucciones y la conversación; si ya no cabe en su memoria, se quitan los
    mensajes más antiguos (devuelve también si se ha recortado)."""
    msgs = [{'role': m['rol'], 'content': m['texto']} for m in chat['mensajes'] if m.get('texto') or m['rol'] == 'user']
    system = [{'role': 'system', 'content': st['sistema'].strip()}] if st['sistema'].strip() else []
    budget = max(512, int(ctx * 0.85) - (st['largo'] or 1024))

    def cost(ms):
        return sum(len(m['content']) for m in ms) / 3.2 + 8 * len(ms)
    cut = False
    while len(msgs) > 1 and cost(system + msgs) > budget:
        msgs.pop(0)
        cut = True
        while msgs and msgs[0]['role'] != 'user':
            msgs.pop(0)
    return system + msgs, cut


# ---------- El motor ----------

def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def kv_dir(model):
    return re.sub(r'[^\w.-]', '_', os.path.basename(model))[:120]


def _die_with_parent():
    try:
        import ctypes
        ctypes.CDLL('libc.so.6').prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG: si se cierra apologIA, se apaga
    except OSError:
        pass


class Engine:
    """llama-server con un modelo. on_state(estado, detalle): apagado · cargando · listo · error."""

    def __init__(self, on_state):
        self.on_state = on_state
        self.proc = None
        self.port = 0
        self.model = ''
        self.state = 'apagado'
        self.detail = ''
        self.ctx = 0
        self.gpu = ''           # «20/37» capas en la GPU ('' si ninguna)
        self.kv_chat = ''       # el chat cuya memoria tiene ahora el motor
        self.lock = threading.Lock()
        self.gen = 0
        self.key = ''           # la llave de cada arranque: sin ella, ninguna web puede usar el motor desde el navegador

    def _set(self, state, detail=''):
        self.state, self.detail = state, detail
        self.on_state(state, detail)

    def url(self, path):
        return f'http://127.0.0.1:{self.port}{path}'

    def start(self, model, st):
        """Arranca con ese modelo (en segundo plano; avisa con on_state)."""
        self.stop()
        with self.lock:
            self.gen += 1
            gen = self.gen
            path = os.path.join(MODELS, os.path.basename(model))
            if not os.path.exists(path):
                self._set('error', 'No está ese modelo')
                return
            if not os.access(LLAMA, os.X_OK):
                self._set('error', 'Falta llama.cpp (el paquete llama-cpp)')
                return
            kv = os.path.join(KV, kv_dir(model))
            os.makedirs(kv, exist_ok=True)
            os.makedirs(CACHE, exist_ok=True)
            self.port = free_port()
            args = [LLAMA, '-m', path, '--host', '127.0.0.1', '--port', str(self.port), '-np', '1', '--jinja',
                    '--reasoning-format', 'deepseek', '--slot-save-path', kv, '--no-webui',
                    '-ngl', '0' if st['gpu'] == 'cpu' else 'auto']
            if st['contexto']:
                args += ['-c', str(int(st['contexto']))]
            if st['hilos']:
                args += ['-t', str(int(st['hilos']))]
            self.key = secrets.token_hex(24)
            log = open(LOG, 'w')
            try:
                self.proc = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                             env=dict(os.environ, LLAMA_API_KEY=self.key),
                                             preexec_fn=_die_with_parent)
            except OSError as e:
                self._set('error', str(e))
                return
            finally:
                log.close()
            self.model, self.kv_chat, self.ctx, self.gpu = os.path.basename(model), '', 0, ''
            self._set('cargando')
        threading.Thread(target=self._wait, args=(gen, st), daemon=True).start()

    def _wait(self, gen, st):
        proc, t0 = self.proc, time.time()
        while gen == self.gen and proc and time.time() - t0 < 900:
            if proc.poll() is not None:
                self._set('error', self.why())
                return
            try:
                with urllib.request.urlopen(self.url('/health'), timeout=2) as r:
                    if r.status == 200:
                        break
            except (OSError, urllib.error.URLError):
                pass
            time.sleep(0.4)
        else:
            if gen == self.gen:
                self.stop()
                self._set('error', 'El modelo tarda demasiado en cargar')
            return
        try:
            with urllib.request.urlopen(self._req('/props'), timeout=5) as r:
                props = json.load(r)
            self.ctx = int(props.get('default_generation_settings', {}).get('n_ctx') or 0)
        except (OSError, ValueError, urllib.error.URLError):
            pass
        self.ctx = self.ctx or int(st['contexto'] or 4096)
        try:
            with open(LOG, errors='replace') as f:
                m = re.findall(r'offloaded (\d+)/(\d+) layers to GPU', f.read())
            self.gpu = f'{m[-1][0]}/{m[-1][1]}' if m and m[-1][0] != '0' else ''
        except OSError:
            pass
        if gen == self.gen:
            self._set('listo')

    def why(self):
        """La razón (más o menos legible) de que el motor no haya arrancado."""
        try:
            with open(LOG, errors='replace') as f:
                lines = [ln.strip() for ln in f if ln.strip()]
        except OSError:
            lines = []
        text = '\n'.join(lines[-40:]).lower()
        if 'unknown model architecture' in text:
            return 'Este llama.cpp aún no sabe usar este tipo de modelo'
        if 'failed to allocate' in text or 'out of memory' in text or 'cannot allocate' in text:
            return 'No hay memoria para este modelo con esta memoria de conversación: prueba con menos'
        if 'failed to load model' in text or 'error loading model' in text:
            return 'No se ha podido abrir el modelo (¿está entero?)'
        err = [ln for ln in lines if 'error' in ln.lower()]
        return (err or lines or ['El motor se ha cerrado'])[-1][-200:]

    def stop(self):
        with self.lock:
            self.gen += 1
            p, self.proc = self.proc, None
            if p and p.poll() is None:
                p.terminate()
                try:
                    p.wait(5)
                except subprocess.TimeoutExpired:
                    p.kill()
            if self.state != 'apagado':
                self.model, self.kv_chat = '', ''
                self._set('apagado')

    def ram(self):
        """Lo que ocupa el motor en la RAM, en bytes."""
        try:
            with open(f'/proc/{self.proc.pid}/status') as f:
                for line in f:
                    if line.startswith('VmRSS:'):
                        return int(line.split()[1]) * 1024
        except (OSError, AttributeError):
            pass
        return 0

    def _req(self, path, body=None):
        return urllib.request.Request(self.url(path), data=None if body is None else json.dumps(body).encode(),
                                      headers={'Content-Type': 'application/json', 'Authorization': 'Bearer ' + self.key})

    def _post(self, path, body, timeout):
        return urllib.request.urlopen(self._req(path, body), timeout=timeout)

    def memory(self, action, chat):
        """Guarda («save») o recupera («restore») la memoria (caché KV) de ese chat en el disco."""
        try:
            with self._post(f'/slots/0?action={action}', {'filename': os.path.basename(chat) + '.bin'}, 300):
                pass
        except (OSError, ValueError, urllib.error.URLError):
            return False
        if action == 'save':
            self.kv_chat = chat
            self._prune()
        return True

    def has_memory(self, chat):
        return os.path.exists(os.path.join(KV, kv_dir(self.model), os.path.basename(chat) + '.bin'))

    def _prune(self):
        d = os.path.join(KV, kv_dir(self.model))
        try:
            files = sorted((os.path.join(d, f) for f in os.listdir(d)), key=os.path.getmtime, reverse=True)
        except OSError:
            return
        total = 0
        for f in files:
            total += os.path.getsize(f)
            if total > KV_MAX:
                os.remove(f)

    def chat(self, messages, st, on_piece, stop):
        """Pide la respuesta y la va dando a trozos: on_piece('texto'|'razon', trozo). Devuelve sus datos
        {tps, tokens, fin} o lanza RuntimeError con el porqué."""
        body = {'messages': messages, 'stream': True, 'cache_prompt': True,
                'temperature': float(st['temperatura']), 'top_p': float(st['top_p']), 'top_k': int(st['top_k']),
                'min_p': float(st['min_p']), 'repeat_penalty': float(st['repeticion']),
                'stream_options': {'include_usage': True},
                'chat_template_kwargs': {'enable_thinking': bool(st['pensar'])}}
        if st['largo']:
            body['max_tokens'] = int(st['largo'])
        timings, usage, finish = {}, {}, ''
        try:
            r = self._post('/v1/chat/completions', body, 900)
        except urllib.error.HTTPError as e:
            try:
                msg = json.load(e).get('error', {}).get('message', '')
            except (ValueError, AttributeError):
                msg = ''
            if 'context' in msg.lower() or 'exceed' in msg.lower():
                msg = 'La conversación ya no cabe en la memoria del modelo: sube «Memoria» en el Modificador'
            raise RuntimeError(msg or f'El motor ha dicho que no ({e.code})')
        except (OSError, urllib.error.URLError) as e:
            raise RuntimeError('No se puede hablar con el motor: ' + str(getattr(e, 'reason', e)))
        with r:
            for raw in r:
                if stop.is_set():
                    finish = 'parado'
                    break
                line = raw.decode('utf-8', 'replace').strip()
                if not line.startswith('data:'):
                    continue
                data = line[5:].strip()
                if data == '[DONE]':
                    break
                try:
                    ev = json.loads(data)
                except ValueError:
                    continue
                if 'error' in ev:
                    raise RuntimeError(str(ev['error'].get('message', ev['error'])))
                for ch in ev.get('choices') or []:
                    d = ch.get('delta') or {}
                    if d.get('reasoning_content'):
                        on_piece('razon', d['reasoning_content'])
                    if d.get('content'):
                        on_piece('texto', d['content'])
                    finish = ch.get('finish_reason') or finish
                timings = ev.get('timings') or timings
                usage = ev.get('usage') or usage
        return {'tps': round(float(timings.get('predicted_per_second') or 0), 1),
                'tokens': int(usage.get('total_tokens') or 0), 'fin': finish or ''}


# ---------- Buscar y bajar modelos ----------

class Redirect(urllib.request.HTTPRedirectHandler):
    """Al saltar a otro servidor (la CDN de Hugging Face…) no se le pasa tu token."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new and urllib.parse.urlsplit(newurl).hostname != urllib.parse.urlsplit(req.full_url).hostname:
            new.remove_header('Authorization')
        return new


_opener = urllib.request.build_opener(Redirect)


def hf_token():
    try:
        with open(TOKEN) as f:
            return f.read().strip()
    except OSError:
        return ''


def set_hf_token(token):
    os.makedirs(CONFIG, exist_ok=True)
    if not token.strip():
        try:
            os.remove(TOKEN)
        except OSError:
            pass
        return
    fd = os.open(TOKEN, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as f:
        f.write(token.strip())


def _headers(url):
    h = {'User-Agent': AGENT}
    host = urllib.parse.urlsplit(url).hostname or ''
    if host == 'huggingface.co' and hf_token():
        h['Authorization'] = 'Bearer ' + hf_token()
    if host == 'api.github.com':
        h['Accept'] = 'application/vnd.github+json'
    return h


def get_json(url, timeout=20):
    try:
        with _opener.open(urllib.request.Request(url, headers=_headers(url)), timeout=timeout) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code in (403, 429) and 'github' in url:
            raise RuntimeError('GitHub no deja buscar más ahora mismo (tiene un límite por hora): prueba en un rato')
        if e.code == 404:
            raise RuntimeError('No existe (o es privado)')
        if e.code == 401:
            raise RuntimeError('Hace falta tu token de Hugging Face (y aceptar la licencia en su web)')
        raise RuntimeError(f'Ha fallado ({e.code})')
    except (OSError, ValueError, urllib.error.URLError):
        raise RuntimeError('Sin conexión con el servidor')


def _files(entries):
    """[{ruta, url, tamano, sha}] → un modelo por archivo, con los trozos juntos y sin proyectores ni adaptadores."""
    groups = {}
    for e in entries:
        name = os.path.basename(e['ruta'])
        if not name.lower().endswith('.gguf') or NOT_MODEL.search(name):
            continue
        m = SPLIT.search(name)
        key = name[:m.start()] if m else name
        g = groups.setdefault(key, {'archivo': '', 'partes': [], 'tamano': 0})
        g['partes'].append(e)
        g['tamano'] += int(e.get('tamano') or 0)
        if not m or m.group(1) == '00001':
            g['archivo'] = name
    out = []
    for g in groups.values():
        if not g['archivo']:
            continue
        g['partes'].sort(key=lambda e: e['ruta'])
        out.append({'archivo': g['archivo'], 'cuant': quant_of(g['archivo']), 'tamano': g['tamano'],
                    'partes': [{'archivo': os.path.basename(e['ruta']), 'url': e['url'], 'tamano': e.get('tamano', 0),
                                'sha': e.get('sha', '')} for e in g['partes']],
                    'va': fit(g['tamano']), 'tienes': os.path.exists(os.path.join(MODELS, g['archivo']))})
    return sorted(out, key=lambda f: f['tamano'])


def hf_search(query):
    q = urllib.parse.urlencode({'filter': 'gguf', 'sort': 'downloads', 'direction': -1, 'limit': 40,
                                'search': query.strip()})
    return [{'repo': m['id'], 'autor': m['id'].split('/')[0], 'nombre': m['id'].split('/')[-1],
             'descargas': m.get('downloads', 0), 'likes': m.get('likes', 0), 'origen': 'hf'}
            for m in get_json('https://huggingface.co/api/models?' + q)
            if '/' in m.get('id', '') and m.get('pipeline_tag') not in NOT_CHAT
            and (query.strip() or not UNSAFE.search(m['id']))]


def hf_files(repo):
    d = get_json(f'https://huggingface.co/api/models/{urllib.parse.quote(repo, safe="/")}?blobs=true')
    entries = [{'ruta': s['rfilename'], 'tamano': s.get('size') or s.get('lfs', {}).get('size', 0),
                'sha': s.get('lfs', {}).get('sha256', ''),
                'url': f'https://huggingface.co/{repo}/resolve/main/{urllib.parse.quote(s["rfilename"])}'}
               for s in d.get('siblings', [])]
    g = d.get('gguf') or {}
    card = d.get('cardData') or {}
    return {'repo': repo, 'origen': 'hf', 'web': f'https://huggingface.co/{repo}', 'licencia': card.get('license', ''),
            'conLicencia': bool(d.get('gated')), 'arquitectura': g.get('architecture', ''),
            'contextoMax': g.get('context_length', 0), 'archivos': _files(entries)}


def gh_search(query):
    q = urllib.parse.quote(f'{query.strip()} gguf'.strip())
    d = get_json(f'https://api.github.com/search/repositories?q={q}&sort=stars&order=desc&per_page=30')
    return [{'repo': r['full_name'], 'autor': r['owner']['login'], 'nombre': r['name'],
             'descargas': 0, 'likes': r.get('stargazers_count', 0), 'detalle': (r.get('description') or '')[:140],
             'origen': 'github'} for r in d.get('items', [])]


def gh_files(repo):
    entries = []
    for rel in get_json(f'https://api.github.com/repos/{repo}/releases?per_page=30'):
        for a in rel.get('assets', []):
            digest = a.get('digest') or ''
            entries.append({'ruta': a['name'], 'url': a['browser_download_url'], 'tamano': a.get('size', 0),
                            'sha': digest[7:] if digest.startswith('sha256:') else ''})
    try:
        tree = get_json(f'https://api.github.com/repos/{repo}/git/trees/HEAD?recursive=1')
        for t in tree.get('tree', []):
            if t.get('type') == 'blob' and t['path'].lower().endswith('.gguf'):
                entries.append({'ruta': t['path'], 'tamano': t.get('size', 0), 'sha': '',
                                'url': f'https://github.com/{repo}/raw/HEAD/{urllib.parse.quote(t["path"])}'})
    except RuntimeError:
        pass
    return {'repo': repo, 'origen': 'github', 'web': f'https://github.com/{repo}', 'licencia': '',
            'conLicencia': False, 'arquitectura': '', 'contextoMax': 0, 'archivos': _files(entries)}


def from_link(url):
    """Un enlace pegado: un repositorio de Hugging Face o GitHub (se ven sus modelos) o un .gguf de donde sea."""
    url = url.strip()
    u = urllib.parse.urlsplit(url)
    if u.scheme != 'https' or not u.hostname:
        raise RuntimeError('Pega un enlace que empiece por https://')
    path = [p for p in u.path.split('/') if p]
    if u.hostname in ('huggingface.co', 'www.huggingface.co') and len(path) >= 2:
        if 'resolve' not in path and 'blob' not in path:
            return hf_files('/'.join(path[:2]))
        url = url.replace('/blob/', '/resolve/')
    elif u.hostname in ('github.com', 'www.github.com') and len(path) >= 2:
        if not url.lower().split('?')[0].endswith('.gguf'):
            return gh_files('/'.join(path[:2]))
        url = url.replace('/blob/', '/raw/')
    name = urllib.parse.unquote(os.path.basename(urllib.parse.urlsplit(url).path))
    size = 0
    try:
        req = urllib.request.Request(url, method='HEAD', headers=_headers(url))
        with _opener.open(req, timeout=20) as r:
            size = int(r.headers.get('Content-Length') or 0)
            cd = r.headers.get('Content-Disposition') or ''
            m = re.search(r'filename\*?=(?:UTF-8\'\')?"?([^";]+)', cd)
            if m:
                name = urllib.parse.unquote(m.group(1))
    except (OSError, urllib.error.URLError):
        pass
    if not name.lower().endswith('.gguf'):
        name = (name or 'modelo') + '.gguf'
    entries = [{'ruta': name, 'url': url, 'tamano': size, 'sha': ''}]
    return {'repo': u.hostname, 'origen': 'enlace', 'web': url, 'licencia': '', 'conLicencia': False,
            'arquitectura': '', 'contextoMax': 0, 'archivos': _files(entries)}


def download(part, on_progress, cancel):
    """Baja un archivo de modelo a modelos/ (sigue donde se quedó si se cortó). on_progress(hecho, total, velocidad).
    Comprueba que es un GGUF y, si se sabe, su sha256. Lanza RuntimeError con el porqué si no sale."""
    name = os.path.basename(part['archivo'])
    if not name.endswith('.gguf') or name.startswith('.'):
        raise RuntimeError('Solo se bajan modelos .gguf')
    os.makedirs(MODELS, exist_ok=True)
    dest = os.path.join(MODELS, name)
    if os.path.exists(dest):
        return
    tmp = dest + '.part'
    have = os.path.getsize(tmp) if os.path.exists(tmp) else 0
    total = int(part.get('tamano') or 0)
    if total and free_space() < total - have + (512 << 20):
        raise RuntimeError(f'No cabe: hacen falta {human(total - have)} y quedan {human(free_space())}')
    headers = _headers(part['url'])
    if have:
        headers['Range'] = f'bytes={have}-'
    try:
        r = _opener.open(urllib.request.Request(part['url'], headers=headers), timeout=30)
    except urllib.error.HTTPError as e:
        if e.code == 416 and have and have == total:
            r = None
        elif e.code in (401, 403) and 'huggingface' in part['url']:
            raise RuntimeError('Este modelo pide aceptar su licencia en Hugging Face y tu token')
        else:
            raise RuntimeError(f'El servidor ha dicho que no ({e.code})')
    except (OSError, urllib.error.URLError) as e:
        raise RuntimeError('Sin conexión: ' + str(getattr(e, 'reason', e)))
    if r is not None:
        with r:
            if r.status == 200 and have:
                have = 0  # (no deja seguir: desde el principio)
            size = r.headers.get('Content-Length')
            if size and not total:
                total = int(size) + have
            if total and free_space() < total - have + (512 << 20):
                raise RuntimeError(f'No cabe: hacen falta {human(total - have)} y quedan {human(free_space())}')
            with open(tmp, 'ab' if have else 'wb') as f:
                done, t0, last, speed = have, time.time(), 0, 0
                first = not have
                while True:
                    if cancel.is_set():
                        raise RuntimeError('Cancelado')
                    chunk = r.read(1 << 20)
                    if not chunk:
                        break
                    if first:
                        if not chunk.startswith(b'GGUF'):
                            f.close()
                            os.remove(tmp)
                            raise RuntimeError('Eso no es un modelo GGUF')
                        first = False
                    f.write(chunk)
                    done += len(chunk)
                    now = time.time()
                    if now - last > 0.3:
                        speed = (done - have) / max(0.001, now - t0)
                        on_progress(done, total, speed)
                        last = now
    if total and os.path.getsize(tmp) < total:
        raise RuntimeError('Se ha cortado: dale otra vez para seguir')
    if part.get('sha'):
        on_progress(-1, total, 0)  # (comprobando)
        h = hashlib.sha256()
        with open(tmp, 'rb') as f:
            for block in iter(lambda: f.read(8 << 20), b''):
                if cancel.is_set():
                    raise RuntimeError('Cancelado')
                h.update(block)
        if h.hexdigest() != part['sha'].lower():
            os.remove(tmp)
            raise RuntimeError('Ha llegado mal (no coincide su huella): bájalo otra vez')
    os.replace(tmp, dest)


def human(n):
    n = float(n or 0)
    for unit in ('B', 'KB', 'MB', 'GB', 'TB'):
        if n < 1024 or unit == 'TB':
            return (f'{n:.1f}' if unit in ('GB', 'TB') else f'{n:.0f}').replace('.', ',') + ' ' + unit
        n /= 1024


# ---------- Colab ----------

def colab_notebook(info, file, st, folder):
    """Escribe un cuaderno de Colab que compila llama.cpp con CUDA, baja ese modelo de Hugging Face y abre un chat
    dentro del propio cuaderno (Colab gratis no deja usarlo desde fuera). Devuelve su ruta."""
    repo = info['repo']
    names = [p['archivo'] for p in file['partes']]
    paths = [urllib.parse.unquote(p['url'].split('/resolve/main/', 1)[-1]) for p in file['partes']]

    def md(text):
        return {'cell_type': 'markdown', 'metadata': {}, 'source': text}

    def code(text):
        return {'cell_type': 'code', 'metadata': {}, 'execution_count': None, 'outputs': [], 'source': text}
    gen = {'temperature': float(st['temperatura']), 'top_p': float(st['top_p']), 'top_k': int(st['top_k']),
           'min_p': float(st['min_p']), 'repeat_penalty': float(st['repeticion'])}
    if st['largo']:
        gen['max_tokens'] = int(st['largo'])
    cells = [
        md(f'# apologIA en Colab\n**{repo}** · `{names[0]}` ({human(file["tamano"])})\n\n'
           '1. **Entorno de ejecución → Cambiar tipo de entorno → GPU T4**.\n'
           '2. **Entorno de ejecución → Ejecutar todo**. La primera vez tarda unos minutos (compila llama.cpp y baja '
           'el modelo).\n3. Escribe abajo, en el chat del final. Todo pasa dentro de este cuaderno.'),
        code('!nvidia-smi -L || echo "Sin GPU: elige la T4 en Entorno de ejecución → Cambiar tipo de entorno"'),
        code('%%bash\nset -e\nif [ ! -x /content/llama.cpp/build/bin/llama-server ]; then\n'
             '  git clone -q --depth 1 https://github.com/ggml-org/llama.cpp /content/llama.cpp\n'
             '  cd /content/llama.cpp\n'
             '  cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=75 -DLLAMA_CURL=OFF > /dev/null\n'
             '  cmake --build build -j 4 --target llama-server > /dev/null\nfi\necho "llama.cpp listo"'),
        code('from huggingface_hub import hf_hub_download\n'
             f'REPO = {repo!r}\nARCHIVOS = {paths!r}\n'
             "rutas = [hf_hub_download(REPO, a, local_dir='/content/modelos') for a in ARCHIVOS]\n"
             'MODELO = rutas[0]\nprint("Modelo listo:", MODELO)'),
        code('import subprocess, time, urllib.request\n'
             f"CONTEXTO = {int(st['contexto'] or 8192)}\n"
             "motor = subprocess.Popen(['/content/llama.cpp/build/bin/llama-server', '-m', MODELO, '-ngl', 'auto',\n"
             "    '-c', str(CONTEXTO), '--host', '127.0.0.1', '--port', '8080', '--jinja', '--reasoning-format',\n"
             "    'deepseek', '--no-webui'], stdout=open('/content/motor.log', 'w'), stderr=subprocess.STDOUT)\n"
             'for _ in range(600):\n    try:\n'
             "        urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2); break\n"
             '    except Exception:\n        time.sleep(1)\n'
             "print('Motor listo' if motor.poll() is None else open('/content/motor.log').read()[-2000:])"),
        code('import html, json, urllib.request\nimport ipywidgets as w\nfrom IPython.display import display\n'
             f"SISTEMA = {st['sistema'].strip()!r}\nAJUSTES = {gen!r}\n"
             "historial = [{'role': 'system', 'content': SISTEMA}] if SISTEMA else []\n"
             "chat = w.VBox()\nentrada = w.Textarea(placeholder='Escribe aquí…', layout=w.Layout(width='100%', height='80px'))\n"
             "boton = w.Button(description='Enviar', button_style='primary')\n\n"
             'def burbuja(texto, tuyo):\n'
             "    fondo = '#1f2633' if tuyo else '#11151c'\n"
             "    return w.HTML(f'<div style=\"background:{fondo};color:#e9edf5;padding:10px 14px;border-radius:12px;"
             "margin:4px 0;white-space:pre-wrap\">{html.escape(texto)}</div>')\n\n"
             'def enviar(_=None):\n    texto = entrada.value.strip()\n    if not texto:\n        return\n'
             "    entrada.value = ''\n    historial.append({'role': 'user', 'content': texto})\n"
             '    respuesta = burbuja("…", False)\n    chat.children += (burbuja(texto, True), respuesta)\n'
             "    cuerpo = dict(AJUSTES, messages=historial, stream=True)\n"
             "    pedido = urllib.request.Request('http://127.0.0.1:8080/v1/chat/completions', data=json.dumps(cuerpo).encode(),\n"
             "                                    headers={'Content-Type': 'application/json'})\n"
             "    hecho = ''\n    with urllib.request.urlopen(pedido) as r:\n        for linea in r:\n"
             "            linea = linea.decode().strip()\n"
             "            if not linea.startswith('data:') or linea.endswith('[DONE]'):\n                continue\n"
             "            for c in json.loads(linea[5:]).get('choices', []):\n"
             "                hecho += (c.get('delta') or {}).get('content') or ''\n"
             '            respuesta.value = burbuja(hecho or "…", False).value\n'
             "    historial.append({'role': 'assistant', 'content': hecho})\n\n"
             'boton.on_click(enviar)\ndisplay(chat, entrada, boton)'),
    ]
    nb = {'nbformat': 4, 'nbformat_minor': 5, 'cells': cells,
          'metadata': {'accelerator': 'GPU', 'colab': {'gpuType': 'T4', 'name': f'apologIA · {repo}'},
                       'kernelspec': {'name': 'python3', 'display_name': 'Python 3'}}}
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, 'apologIA · ' + re.sub(r'[^\w.-]+', ' ', repo.split('/')[-1]).strip() + '.ipynb')
    with open(path, 'w') as f:
        json.dump(nb, f, ensure_ascii=False, indent=1)
    return path
