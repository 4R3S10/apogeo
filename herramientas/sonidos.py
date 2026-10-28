#!/usr/bin/python3
"""
Sonidos de Apogeo: propios y suaves, todos de la misma familia (notas de marimba de madera, con un poco de sala), sin
nada estridente. Para entrar, el «uu-uu» de un búho, muy suave, sobre un acorde cálido. Se sintetizan al construir el
paquete (sin archivos de nadie).

  sonidos.py <carpeta>    escribe los .wav con los nombres del tema de sonidos de freedesktop
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 44100
random.seed(7)


def note(freq):
    """Nombre de nota (A4, C#5…) o hercios."""
    if isinstance(freq, (int, float)):
        return float(freq)
    names = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    n, o = freq[:-1], int(freq[-1])
    return 440.0 * 2 ** ((names[n] + 12 * (o - 4)) / 12)


def silence(sec):
    return [0.0] * int(sec * RATE)


def mallet(freq, dur=0.6, vol=1.0, bright=0.25):
    """Una nota de marimba de madera: el tono y dos parciales que se apagan antes; ataque de 4 ms."""
    f = note(freq)
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        att = min(1.0, t / 0.004)
        v = (math.sin(2 * math.pi * f * t) * math.exp(-t * 7)
             + bright * math.sin(2 * math.pi * f * 3.98 * t) * math.exp(-t * 26)
             + bright * 0.3 * math.sin(2 * math.pi * f * 9.6 * t) * math.exp(-t * 60))
        out.append(att * v * vol)
    return out


def pad(freqs, dur=1.6, vol=0.5):
    """Un acorde blando que entra y sale despacio."""
    fs = [note(x) for x in freqs]
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.35) * min(1.0, (dur - t) / 0.7)
        v = sum(math.sin(2 * math.pi * f * t + k) + 0.25 * math.sin(4 * math.pi * f * t) for k, f in enumerate(fs))
        out.append(env * v / len(fs) * vol)
    return out


def hoot(freq, dur, vol=0.8, fall=0.06):
    """Un «uu» de búho: tono redondo que baja un poco, con algo de aire y un vibrato lento."""
    f0 = note(freq)
    n = int(dur * RATE)
    out, phase, lp = [], 0.0, 0.0
    for i in range(n):
        t = i / RATE
        f = f0 * (1 - fall * t / dur) * (1 + 0.006 * math.sin(2 * math.pi * 5.5 * t))
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / 0.05) * min(1.0, (dur - t) / 0.12)
        lp += 0.08 * (random.uniform(-1, 1) - lp)          # aire (ruido suave)
        v = math.sin(phase) + 0.18 * math.sin(2 * phase) + 0.35 * lp
        out.append(env * v * vol)
    return out


def tick(vol=0.6):
    """Un toque cortito (el volumen)."""
    return mallet('E6', 0.12, vol, bright=0.1)


def at(base, part, start):
    """Mezcla «part» dentro de «base» a partir de «start» segundos."""
    s = int(start * RATE)
    need = s + len(part) - len(base)
    if need > 0:
        base = base + [0.0] * need
    for i, v in enumerate(part):
        base[s + i] += v
    return base


def room(x, amount=0.22):
    """Un poco de sala (dos ecos suaves que se van apagando)."""
    out = x + [0.0] * int(0.45 * RATE)
    for d, g in ((0.043, amount), (0.071, amount * 0.7), (0.113, amount * 0.45)):
        k = int(d * RATE)
        for i in range(len(out) - 1, k - 1, -1):
            out[i] += out[i - k] * g
    return out


def write(path, x, peak=0.45):
    """En 16 bits, con el pico a -7 dB (suave) y un final sin chasquidos."""
    m = max(1e-9, max(abs(v) for v in x))
    fade = int(0.03 * RATE)
    data = bytearray()
    for i, v in enumerate(x):
        g = min(1.0, (len(x) - i) / fade)
        data += struct.pack('<h', int(max(-1, min(1, v / m * peak * g)) * 32767))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))


def sounds():
    s = {}
    # Avisos: dos notas que suben (la de la isla y el panel)
    s['message-new-instant'] = room(at(mallet('E5', 0.7), mallet('B5', 0.8, 0.8), 0.09))
    s['dialog-information'] = room(at(mallet('C5', 0.7), mallet('G5', 0.8, 0.8), 0.1))
    s['dialog-warning'] = room(at(mallet('A5', 0.6), mallet('E5', 0.8, 0.9), 0.11))
    s['dialog-error'] = room(at(mallet('D4', 0.5, bright=0.15), mallet('D4', 0.6, 0.8, bright=0.15), 0.14))
    s['dialog-question'] = room(at(mallet('G5', 0.6), mallet('D6', 0.7, 0.7), 0.1))
    # USB: tres notas que suben al conectarlo y bajan al quitarlo
    up = silence(0)
    for k, n in enumerate(('C5', 'E5', 'G5')):
        up = at(up, mallet(n, 0.6, 0.9), k * 0.07)
    s['device-added'] = room(up)
    down = silence(0)
    for k, n in enumerate(('G5', 'E5', 'C5')):
        down = at(down, mallet(n, 0.6, 0.9), k * 0.07)
    s['device-removed'] = room(down)
    # El volumen y lo hecho
    s['audio-volume-change'] = tick()
    s['complete'] = room(at(at(mallet('C6', 0.6, 0.8), mallet('E6', 0.6, 0.8), 0.06), mallet('G6', 0.9, 0.7), 0.12))
    s['trash-empty'] = room(at(mallet('A4', 0.4, 0.7, 0.1), mallet('E4', 0.5, 0.6, 0.1), 0.06), 0.15)
    s['screen-capture'] = room(at(tick(0.8), tick(0.6), 0.05), 0.12)
    s['bell'] = room(mallet('A5', 0.9))
    # Recordatorios y temporizadores: un motivo de cuatro notas, tres veces (que se oiga, sin asustar)
    alarm = silence(0)
    for r in range(3):
        for k, n in enumerate(('E5', 'G#5', 'B5', 'E6')):
            alarm = at(alarm, mallet(n, 0.55, 0.85 - 0.1 * (k == 3)), r * 0.95 + k * 0.12)
    s['alarm-clock-elapsed'] = room(alarm, 0.2)
    # Entrar: el «uu-uu» del búho sobre un acorde cálido; salir: el acorde que baja
    login = pad(('A3', 'E4', 'C#5'), 2.0, 0.35)
    login = at(login, hoot('E5', 0.28, 0.55), 0.25)
    login = at(login, hoot('C#5', 0.6, 0.6, fall=0.08), 0.68)
    s['desktop-login'] = room(login, 0.25)
    s['desktop-logout'] = room(at(pad(('E4', 'A3', 'C#4'), 1.4, 0.4), mallet('A4', 0.9, 0.5), 0.05), 0.2)
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
