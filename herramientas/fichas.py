"""
Las fichas del aspecto de Apogeo (colores, esquinas y cristal) para los generadores de temas (colores, kvantum, plasma,
ventanas). Sin nada, las de siempre (Ágape, Berenjena oscuro): así se construye el paquete. Con APOGEO_TOKENS=<json>
(lo hace apogeo-aspecto con lo que eliges en Ajustes → Aspecto), las tuyas, y el tema sale con otro nombre.
"""
import json
import os

_T = {}
if os.environ.get('APOGEO_TOKENS'):
    with open(os.environ['APOGEO_TOKENS']) as _f:
        _T = json.load(_f)

BG = _T.get('fondo', '#120d14')
SURFACE = _T.get('superficie', '#1e1621')
TEXT = _T.get('texto', '#f1e6ea')
ACCENT = _T.get('acento', '#e0a9b4')
ACCENT_TEXT = _T.get('sobreAcento', '#2a1c26')
RADIO = float(_T.get('radio', 1.0))          # las esquinas: 1 = las de Ágape
CRISTAL = float(_T.get('cristal', 0.55))     # lo opaco del cristal de la isla y la columna
NOMBRE = _T.get('nombre')                    # el nombre del tema generado (None = el de serie)
CLARO = bool(_T.get('claro', False))


def r(n):
    """Un radio con tus esquinas."""
    return max(1, round(n * RADIO))
