"""
Un cliente de Wayland muy pequeño, en Python, para lo poco que Apogeo le pide a KWin por su cuenta: el portapapeles en
segundo plano (ext-data-control-v1: ver lo que copias y dejar algo listo para pegar) y pulsar teclas
(org_kde_kwin_fake_input: el Ctrl+V de pegar). Habla el protocolo de Wayland tal cual por el socket de la sesión (sin
librerías: solo mensajes de 32 bits, textos y descriptores de archivo).

  w = Wayland()                               se conecta y mira qué ofrece KWin
  w.watch_clipboard(lo_copiado)               lo_copiado(tipos, leer) cada vez que copias algo; leer(tipo) → bytes
  w.set_clipboard({'text/plain': b'hola'})    lo deja en el portapapeles (Apogeo lo sirve mientras siga ahí)
  w.keys([29, 47])                            pulsa y suelta esas teclas (códigos de Linux: Ctrl, V)
  w.run()                                     atiende a KWin para siempre (en un hilo aparte)
Va en su propio hilo porque las apps (también la nuestra, Qt) leen lo que servimos esperando: si el mismo hilo tuviera
que contestarles, se quedaría parado. «lo_copiado» se llama desde ese hilo.
"""
import os
import select
import socket
import struct
import threading

KEY_LEFTCTRL, KEY_LEFTSHIFT, KEY_V = 29, 42, 47


class WaylandError(Exception):
    pass


class _Args:
    """Los argumentos de un evento, en orden."""

    def __init__(self, data, fds):
        self.data, self.pos, self.fds = data, 0, fds

    def u(self):
        v = struct.unpack_from('<I', self.data, self.pos)[0]
        self.pos += 4
        return v

    def s(self):
        n = self.u()
        v = self.data[self.pos:self.pos + max(0, n - 1)].decode('utf-8', 'replace')
        self.pos += (n + 3) & ~3
        return v

    def h(self):
        return self.fds.pop(0) if self.fds else -1


class Wayland:
    def __init__(self):
        name = os.environ.get('WAYLAND_DISPLAY', 'wayland-0')
        path = name if name.startswith('/') else os.path.join(os.environ['XDG_RUNTIME_DIR'], name)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM | socket.SOCK_CLOEXEC)
        self.sock.connect(path)
        self.next_id = 2  # (el 1 es wl_display)
        self.lock = threading.RLock()  # (se envía desde el hilo de la app y se recibe en el suyo)
        self.later = []                # lo que se avisa al acabar de leer un mensaje (fuera del candado)
        self.handlers = {1: self._display}
        self.inbuf, self.infds = b'', []
        self.globals = {}
        self.registry = self._new(self._registry)
        self._send(1, 1, 'n', self.registry)  # wl_display.get_registry
        self.roundtrip()
        self.device = self.manager = self.fake = None
        self.offers = {}           # oferta → sus tipos
        self.current = None        # la oferta de lo que hay copiado ahora
        self.own = 0               # cambios del portapapeles que son nuestros (no se guardan otra vez)
        self.sources = {}          # lo que servimos → {tipo: bytes}

    # ---------- El protocolo ----------

    def _new(self, handler):
        with self.lock:
            oid = self.next_id
            self.next_id += 1
            self.handlers[oid] = handler
            return oid

    def _send(self, obj, opcode, sig, *args):
        body, fds = b'', []
        for kind, a in zip(sig, args):
            if kind in 'unoi':
                body += struct.pack('<i' if kind == 'i' else '<I', a or 0)
            elif kind == 's':
                raw = a.encode('utf-8') + b'\0'
                body += struct.pack('<I', len(raw)) + raw + b'\0' * (-len(raw) % 4)
            elif kind == 'h':
                fds.append(a)
        msg = struct.pack('<II', obj, ((8 + len(body)) << 16) | opcode) + body
        anc = [(socket.SOL_SOCKET, socket.SCM_RIGHTS, struct.pack(f'<{len(fds)}i', *fds))] if fds else []
        with self.lock:
            self.sock.sendmsg([msg], anc)

    def dispatch(self):
        """Espera a que KWin diga algo y lo atiende."""
        data, anc, _flags, _addr = self.sock.recvmsg(65536, socket.CMSG_SPACE(28 * 4))
        if not data:
            raise WaylandError('KWin ha cerrado la conexión')
        with self.lock:
            for level, kind, payload in anc:
                if level == socket.SOL_SOCKET and kind == socket.SCM_RIGHTS:
                    self.infds += list(struct.unpack(f'<{len(payload) // 4}i', payload[:len(payload) // 4 * 4]))
            self.inbuf += data
            while len(self.inbuf) >= 8:
                obj, word = struct.unpack_from('<II', self.inbuf)
                size, opcode = word >> 16, word & 0xffff
                if len(self.inbuf) < size:
                    break
                body, self.inbuf = self.inbuf[8:size], self.inbuf[size:]
                handler = self.handlers.get(obj)
                if handler:
                    handler(opcode, _Args(body, self.infds))
            later, self.later = self.later, []
        for f in later:
            f()

    def run(self):
        while True:
            self.dispatch()

    def roundtrip(self):
        done = []
        cb = self._new(lambda op, a: done.append(True))
        self._send(1, 0, 'n', cb)  # wl_display.sync
        while not done:
            self.dispatch()

    def _display(self, opcode, a):
        if opcode == 0:  # error
            obj, code, msg = a.u(), a.u(), a.s()
            raise WaylandError(f'error {code} en el objeto {obj}: {msg}')
        if opcode == 1:  # delete_id
            self.handlers.pop(a.u(), None)

    def _registry(self, opcode, a):
        if opcode == 0:
            name, iface, version = a.u(), a.s(), a.u()
            self.globals[iface] = (name, version)

    def bind(self, iface, version, handler=None):
        if iface not in self.globals:
            raise WaylandError(f'KWin no ofrece {iface}')
        name, top = self.globals[iface]
        oid = self._new(handler or (lambda op, a: None))
        self._send(self.registry, 0, 'usun', name, iface, min(version, top), oid)
        return oid

    # ---------- El portapapeles ----------

    def watch_clipboard(self, callback):
        self.callback = callback
        seat = self.bind('wl_seat', 1)
        self.manager = self.bind('ext_data_control_manager_v1', 1)
        self.device = self._new(self._device)
        self._send(self.manager, 1, 'no', self.device, seat)  # get_data_device
        self.roundtrip()

    def _device(self, opcode, a):
        if opcode == 0:  # data_offer: una oferta nueva (con sus tipos detrás)
            oid = a.u()
            self.offers[oid] = []
            self.handlers[oid] = lambda op, b, oid=oid: self.offers[oid].append(b.s()) if op == 0 else None
        elif opcode == 1:  # selection: lo copiado ahora
            oid = a.u()
            if self.current:
                self._drop(self.current)
            self.current = oid or None
            if self.own:
                self.own -= 1
                return
            if oid:
                types = list(self.offers.get(oid, []))
                self.later.append(lambda: self.callback(types, lambda mime: self._receive(oid, mime)))
        elif opcode == 3:  # primary_selection (lo seleccionado con el ratón): no se usa
            oid = a.u()
            if oid and oid != self.current:
                self._drop(oid)

    def _drop(self, oid):
        self.offers.pop(oid, None)
        self.handlers.pop(oid, None)
        self._send(oid, 1, '')  # destroy

    def _receive(self, oid, mime, limit=32 << 20, timeout=3.0):
        """Lo copiado en ese tipo (b'' si la app no lo da a tiempo o es muy grande)."""
        with self.lock:
            if oid not in self.offers:
                return b''
        r, w = os.pipe2(os.O_CLOEXEC)
        try:
            self._send(oid, 0, 'sh', mime, w)  # receive
        finally:
            os.close(w)
        out = bytearray()
        try:
            while len(out) <= limit:
                if not select.select([r], [], [], timeout)[0]:
                    return b''
                chunk = os.read(r, 1 << 16)
                if not chunk:
                    return bytes(out)
                out += chunk
            return b''
        finally:
            os.close(r)

    def set_clipboard(self, items):
        """Deja esto en el portapapeles ({tipo: bytes}); se sirve desde aquí hasta que copies otra cosa."""
        with self.lock:
            src = self._new(None)
            self.handlers[src] = lambda op, a, src=src: self._source(src, op, a)
            self.sources[src] = dict(items)
            self._send(self.manager, 0, 'n', src)  # create_data_source
            for mime in items:
                self._send(src, 0, 's', mime)  # offer
            self.own += 1
            self._send(self.device, 0, 'o', src)  # set_selection

    def _source(self, src, opcode, a):
        if opcode == 0:  # send: una app lo quiere pegar
            mime, fd = a.s(), a.h()
            data = self.sources.get(src, {}).get(mime, b'')

            def write():
                try:
                    with os.fdopen(fd, 'wb') as f:
                        f.write(data)
                except OSError:
                    pass
            threading.Thread(target=write, daemon=True).start()
        elif opcode == 1:  # cancelled: ya hay otra cosa copiada
            self.sources.pop(src, None)
            self.handlers.pop(src, None)
            self._send(src, 1, '')  # destroy

    # ---------- Teclas ----------

    def keys(self, codes):
        """Pulsa las teclas en orden y las suelta al revés (un atajo: Ctrl+V = [29, 47])."""
        with self.lock:
            if self.fake is None:
                self.fake = self.bind('org_kde_kwin_fake_input', 4)
                self._send(self.fake, 0, 'ss', 'Apogeo', 'Pegar lo que eliges en el portapapeles o en los emojis')
            for c in codes:
                self._send(self.fake, 10, 'uu', c, 1)  # keyboard_key, pulsada
            for c in reversed(codes):
                self._send(self.fake, 10, 'uu', c, 0)
