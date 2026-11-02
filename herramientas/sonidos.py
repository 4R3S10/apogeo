#!/usr/bin/python3
"""
Sonidos de Apogeo (Órbita): propios, limpios y espaciales, todos de la misma familia: tonos puros con un brillo suave
que se apaga antes, un poco abiertos a los lados (dos voces casi iguales, una a cada lado) y con espacio (ecos que van
de un lado a otro y una sala grande y oscura). Nada estridente. Para entrar, un acorde que se abre y unas notas que
suben dando la vuelta de un lado al otro, como algo que entra en órbita; para salir, lo mismo hacia abajo. Se
sintetizan al construir el paquete (sin archivos de nadie).

  sonidos.py <carpeta>    escribe los .wav (estéreo) con los nombres del tema de sonidos de freedesktop
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 44100
random.seed(7)
TAU = 2 * math.pi
GAIN = 0.12   # (lo que suena la sala, con wet=1)


def note(freq):
    """Nombre de nota (A4, C#5…) o hercios."""
    if isinstance(freq, (int, float)):
        return float(freq)
    names = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    n, o = freq[:-1], int(freq[-1])
    return 440.0 * 2 ** ((names[n] + 12 * (o - 4)) / 12)


def empty(sec=0.0):
    n = int(sec * RATE)
    return [[0.0] * n, [0.0] * n]


def tone(freq, dur=0.9, vol=1.0, glow=0.2, attack=0.008, decay=4.5, width=0.0003):
    """Una nota limpia, en estéreo: el tono puro, su octava y su quinta de arriba muy suaves (se apagan antes) y un
    ataque blando. Cada lado va un pelo desafinado hacia un lado: se abre y respira, sin sonar a metal."""
    f0 = note(freq)
    n = int(dur * RATE)
    sides = []
    for f in (f0 * (1 + width), f0 * (1 - width)):
        out = []
        for i in range(n):
            t = i / RATE
            env = min(1.0, t / attack) * math.exp(-t * decay)
            v = (math.sin(TAU * f * t)
                 + glow * math.sin(TAU * 2 * f * t + 0.6) * math.exp(-t * decay * 1.6)
                 + glow * 0.3 * math.sin(TAU * 3 * f * t + 1.1) * math.exp(-t * decay * 3.2))
            out.append(env * v * vol)
        sides.append(out)
    return sides


def pad(freqs, dur=2.0, vol=0.5, rise=0.6, fall=0.9):
    """Un acorde de tonos puros que se abre despacio; cada voz se mueve un poco de lado a lado."""
    fs = [note(x) for x in freqs]
    n = int(dur * RATE)
    left, right = [], []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / rise) * min(1.0, max(0.0, dur - t) / fall)
        l = r = 0.0
        for k, f in enumerate(fs):
            v = math.sin(TAU * f * t + k) + 0.12 * math.sin(TAU * 2 * f * t + k)
            p = 0.5 + 0.35 * math.sin(TAU * (0.21 + 0.07 * k) * t + k * 1.7)   # (dónde está esa voz, de 0 a 1)
            l += v * math.cos(p * math.pi / 2)
            r += v * math.sin(p * math.pi / 2)
        g = env * vol / len(fs)
        left.append(l * g)
        right.append(r * g)
    return [left, right]


def air(dur=0.5, vol=0.3, start=5000, end=600):
    """Un soplo (ruido filtrado que se va oscureciendo): para vaciar la papelera."""
    n = int(dur * RATE)
    sides = []
    for _ in range(2):
        out, lp = [], 0.0
        for i in range(n):
            t = i / RATE
            cut = start * (end / start) ** (t / dur)
            a = 1 - math.exp(-TAU * cut / RATE)
            lp += a * (random.uniform(-1, 1) - lp)
            env = min(1.0, t / 0.03) * (1 - t / dur) ** 1.5
            out.append(lp * env * vol)
        sides.append(out)
    return sides


def at(base, part, start, pan=0.0):
    """Mezcla «part» dentro de «base» a partir de «start» segundos; «pan» de -1 (izquierda) a 1 (derecha)."""
    s = int(start * RATE)
    need = s + len(part[0]) - len(base[0])
    if need > 0:
        for c in base:
            c.extend([0.0] * need)
    p = (pan + 1) / 2
    gl, gr = math.cos(p * math.pi / 2) * math.sqrt(2), math.sin(p * math.pi / 2) * math.sqrt(2)
    for i in range(len(part[0])):
        base[0][s + i] += part[0][i] * gl
        base[1][s + i] += part[1][i] * gr
    return base


def space(x, echo=0.18, wet=0.32, tail=1.4):
    """El espacio: ecos que van de un lado al otro (cada vez más oscuros) y una sala grande, con algo distinto en cada
    lado para que se abra."""
    n = len(x[0]) + int(tail * RATE)
    left, right = x[0] + [0.0] * (n - len(x[0])), x[1] + [0.0] * (n - len(x[1]))
    # Ecos de un lado al otro
    d = int(0.19 * RATE)
    el, er, lp_l, lp_r = [0.0] * n, [0.0] * n, 0.0, 0.0
    for i in range(n):
        fl = er[i - d] if i >= d else 0.0
        fr = el[i - d] if i >= d else 0.0
        lp_l += 0.35 * (fl - lp_l)
        lp_r += 0.35 * (fr - lp_r)
        el[i] = left[i] + lp_l * 0.42
        er[i] = right[i] + lp_r * 0.42
    out = []
    for side, src, combs in ((0, el, (1557, 1617, 1491, 1422)), (1, er, (1580, 1640, 1514, 1445))):
        # La sala (Schroeder: cuatro peines con algo de pérdida en los agudos y dos pasatodo)
        rev = [0.0] * n
        for m in combs:
            buf, k, lp = [0.0] * m, 0, 0.0
            for i in range(n):
                y = buf[k]
                lp += 0.45 * (y - lp)
                buf[k] = src[i] + lp * 0.8
                rev[i] += y
                k = (k + 1) % m
        for m in (225 + 23 * side, 556 + 31 * side):
            buf, k = [0.0] * m, 0
            for i in range(n):
                y = buf[k]
                buf[k] = rev[i] + y * 0.5
                rev[i] = y - rev[i] * 0.5
                k = (k + 1) % m
        dry = x[side] + [0.0] * (n - len(x[side]))
        out.append([dry[i] + (src[i] - dry[i]) * echo * 3 + rev[i] * wet * GAIN for i in range(n)])
    return out


def write(path, x, peak=0.42):
    """En 16 bits y estéreo, con el pico a unos -7.5 dB (suave) y un final sin chasquidos."""
    m = max(1e-9, max(max(abs(v) for v in c) for c in x))
    n = len(x[0])
    fade = int(0.08 * RATE)
    data = bytearray()
    for i in range(n):
        g = min(1.0, (n - i) / fade) * peak / m
        for c in x:
            data += struct.pack('<h', int(max(-1, min(1, c[i] * g)) * 32767))
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))


def click(vol=0.6, tono=2400, cuerpo=0.35, dur=0.045):
    """Un clic mecánico: un chasquido de ruido muy corto (el contacto) y un golpecito grave que se apaga enseguida (la
    tecla al tocar fondo). Seco: sin sala."""
    import random
    rnd = random.Random(int(tono))   # (siempre el mismo clic)
    n = int(dur * RATE)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / RATE
        noise = rnd.uniform(-1, 1)
        hp = noise - prev   # (ruido agudo: solo los cambios)
        prev = noise
        chasquido = hp * math.exp(-t * 900) * 0.6
        golpe = math.sin(TAU * tono * t) * math.exp(-t * 260) * 0.35 + math.sin(TAU * 180 * t) * math.exp(-t * 120) * cuerpo
        out.append((chasquido + golpe) * vol)
    return [out, list(out)]


def notes(seq, step, dur=0.8, vol=1.0, pans=None, **kw):
    """Unas notas seguidas («step» segundos entre ellas), cada una en su sitio de lado a lado."""
    x = empty()
    for k, n in enumerate(seq):
        x = at(x, tone(n, dur, vol * (0.92 ** k), **kw), k * step, pans[k] if pans else 0.0)
    return x


def sounds():
    s = {}
    # Avisos: dos notas que suben (de un lado al otro, poco)
    s['message-new-instant'] = space(notes(('E5', 'B5'), 0.085, pans=(-0.25, 0.25)))
    s['dialog-information'] = space(notes(('C#5', 'G#5'), 0.1, pans=(-0.2, 0.2)))
    s['dialog-warning'] = space(notes(('B5', 'F#5'), 0.12, pans=(0.2, -0.2)))
    s['dialog-question'] = space(notes(('F#5', 'C#6'), 0.11, 0.7, pans=(-0.2, 0.25)))
    # Error: dos notas graves y apagadas (que se note, sin asustar)
    s['dialog-error'] = space(notes(('E4', 'B3'), 0.15, 0.7, glow=0.08, decay=6), wet=0.25)
    # USB: tres notas que suben de izquierda a derecha al conectarlo y bajan de vuelta al quitarlo
    s['device-added'] = space(notes(('E5', 'G#5', 'B5'), 0.075, 0.7, pans=(-0.5, 0, 0.5)))
    s['device-removed'] = space(notes(('B5', 'G#5', 'E5'), 0.075, 0.7, pans=(0.5, 0, -0.5)))
    # El volumen: un punto de luz cortito (sin eco: se repite mucho)
    s['audio-volume-change'] = tone('B6', 0.09, 0.8, glow=0.1, attack=0.003, decay=38)
    # Lo hecho: tres notas que suben deprisa y brillan
    s['complete'] = space(notes(('E6', 'G#6', 'B6'), 0.06, 0.8, 0.8, pans=(-0.3, 0, 0.3)))
    s['trash-empty'] = space(at(air(0.45, 0.6), tone('E4', 0.5, 0.35, glow=0.05, decay=7), 0.04), wet=0.2)
    s['screen-capture'] = space(at(tone('E7', 0.07, 0.6, 0.05, 0.002, 45), tone('B6', 0.1, 0.5, 0.05, 0.002, 35),
                                   0.06), wet=0.15, tail=0.6)
    s['bell'] = space(tone('A5', 1.4, decay=2.6), wet=0.4)
    # Recordatorios y temporizadores: un motivo de cuatro notas, tres veces, de un lado a otro (que se oiga)
    alarm = empty()
    for r in range(3):
        alarm = at(alarm, notes(('E5', 'B5', 'G#5', 'E6'), 0.13, 0.6, 0.85, pans=(-0.4, -0.1, 0.1, 0.4)), r * 0.95)
    s['alarm-clock-elapsed'] = space(alarm, wet=0.25)
    # Entrar: un acorde abierto que crece y cuatro notas que suben dando la vuelta, de un lado al otro, como algo que
    # entra en órbita; arriba, un brillo que se queda
    login = pad(('E3', 'B3', 'F#4', 'G#4'), 3.0, 0.5, rise=1.0, fall=1.4)
    for k, (n, p) in enumerate((('B4', -0.6), ('E5', 0.6), ('B5', -0.35), ('F#6', 0.35))):
        login = at(login, tone(n, 1.6, 0.55 - 0.05 * k, glow=0.15, attack=0.02, decay=2.2), 0.45 + k * 0.24, p)
    login = at(login, tone('G#6', 1.8, 0.18, glow=0.0, attack=0.4, decay=1.4), 1.3)
    s['desktop-login'] = space(login, wet=0.45, tail=1.8)
    # Salir: lo mismo, hacia abajo y más corto
    logout = pad(('E3', 'B3', 'E4'), 1.9, 0.45, rise=0.2, fall=1.3)
    for k, (n, p) in enumerate((('B5', 0.4), ('E5', -0.4), ('B4', 0.0))):
        logout = at(logout, tone(n, 1.2, 0.5 - 0.06 * k, glow=0.12, attack=0.015, decay=2.8), 0.05 + k * 0.2, p)
    s['desktop-logout'] = space(logout, wet=0.4, tail=1.5)
    # La consola de Jugar: clics mecánicos, secos y suaves (como un teclado mecánico silencioso)
    s['apogeo-consola-mover'] = click(0.55, 2600)
    s['apogeo-consola-pestana'] = click(0.6, 1900, cuerpo=0.5)
    # Elegir: un clic doble (como pulsar y soltar una tecla)
    s['apogeo-consola-elegir'] = at(click(0.7, 2200, cuerpo=0.6), click(0.45, 3000), 0.045)
    s['apogeo-consola-abrir'] = at(click(0.65, 1700, cuerpo=0.7), click(0.35, 2600), 0.03)
    # Atrás: un clic más grave y apagado
    s['apogeo-consola-atras'] = click(0.5, 1300, cuerpo=0.6)
    return s


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, x in sounds().items():
        write(os.path.join(out, name + '.wav'), x)
    # mismos sonidos con otros nombres
    links = {'dialog-error-critical': 'dialog-error', 'dialog-error-serious': 'dialog-error',
             'dialog-warning-auth': 'dialog-warning', 'message-new-email': 'message-new-instant',
             'message': 'message-new-instant', 'service-login': 'desktop-login', 'service-logout': 'desktop-logout',
             'power-plug': 'device-added', 'power-unplug': 'device-removed', 'completion-success': 'complete',
             'outcome-success': 'complete', 'timer-elapsed': 'alarm-clock-elapsed'}
    for a, b in links.items():
        p = os.path.join(out, a + '.wav')
        if os.path.lexists(p):
            os.remove(p)
        os.symlink(b + '.wav', p)
    print('Sonidos:', len(os.listdir(out)))
