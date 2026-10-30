"""
Las fichas del aspecto de Apogeo —la identidad «Órbita»— para los generadores de temas (colores, kvantum, plasma,
ventanas, iconos). De serie: grafito, Geist y un acento por modo (cian en Navegar, ámbar en Estudiar, violeta en
Jugar). Con APOGEO_TOKENS=<json> (lo hace apogeo-aspecto con lo que eliges en Ajustes → Aspecto), las tuyas, y el
tema sale con otro nombre. Con APOGEO_MODO=jugar|navegar|estudiar se elige el acento de ese modo.

La identidad clásica (Berenjena, rosa de Ágape, Bricolage) sigue disponible como estilo «Clásico».
"""
import json
import os

_T = {}
if os.environ.get('APOGEO_TOKENS'):
    with open(os.environ['APOGEO_TOKENS']) as _f:
        _T = json.load(_f)

# ---------- Órbita: la identidad de serie ----------
BG = _T.get('fondo', '#080a0f')
SURFACE = _T.get('superficie', '#0f131a')
ELEVADA = _T.get('elevada', '#171c25')
TEXT = _T.get('texto', '#e9edf5')
MUTED = _T.get('apagado', '#8b94a7')
FAINT = _T.get('tenue', '#5b6475')

ACENTOS = {'jugar': '#b79cff', 'navegar': '#45d6ff', 'estudiar': '#ffb35c'}
MODO = os.environ.get('APOGEO_MODO', 'navegar')
if MODO not in ACENTOS:
    MODO = 'navegar'
ACCENT = _T.get('acento', ACENTOS[MODO])
ACCENT_TEXT = _T.get('sobreAcento', '#041318')
VIVO = _T.get('vivo', ACCENT)
RADIO = float(_T.get('radio', 0.7))          # las esquinas: 1 = redondas; 0.7 = suaves (la de Órbita)
CRISTAL = float(_T.get('cristal', 0.55))     # lo opaco del cristal de la isla y los paneles
NOMBRE = _T.get('nombre')                    # el nombre del tema generado (None = el de serie)
ESTILO = _T.get('estilo', 'orbita')          # orbita (de serie), apogeo (Clásico), agape, fondo…
CLARO = bool(_T.get('claro', False))
LETRA = _T.get('letra', 'Geist')
MONO = _T.get('mono', 'Geist Mono')
WP = _T.get('wp', ['#0b1118', '#12303d', ACCENT])
ANIM = float(_T.get('animaciones', 1.0))


def r(n):
    """Un radio con tus esquinas."""
    return max(1, round(n * RADIO))


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (1, 3, 5)]


def mix(a, b, t):
    ca, cb = rgb(a), rgb(b)
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(ca, cb))
