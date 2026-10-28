"""
La calculadora del buscador de Apogeo: cuentas («(12+3)*4», «2^10», «raíz de 81»), porcentajes («15% de 80»,
«80 + 21%»), unidades («5 km en millas», «70 kg en libras», «30 c en f», «2 gb en mb») y monedas («10 € en dólares»,
«50 usd a eur», con el cambio del día del Banco Central Europeo). Todo en español, con la coma de los decimales.

  answer(texto) -> {'valor': '12', 'detalle': '…'} o None (si no es una cuenta)
"""
import ast
import json
import math
import operator
import os
import re
import threading
import time
import urllib.request

# ----- Números -----


def nice(x):
    """Lo de una conversión: dos decimales (cuatro cifras si es pequeño)."""
    return round(x, 2) if abs(x) >= 1 else float(f'{x:.4g}')


def show(x):
    """Un número como se escribe aquí: 1.234,5 (sin decimales de sobra)."""
    if isinstance(x, float) and (math.isinf(x) or math.isnan(x)):
        raise ValueError
    if abs(x) >= 1e15 or (x != 0 and abs(x) < 1e-6):
        return f'{x:.6g}'.replace('.', ',')
    digits = 0 if float(x).is_integer() else max(0, min(8, 6 - int(math.floor(math.log10(abs(x))))))
    s = f'{x:,.{digits}f}'
    if '.' in s:
        s = s.rstrip('0').rstrip('.')
    return s.replace(',', ' ').replace('.', ',').replace(' ', '.')


def num(s):
    """«1.234,5», «1234.5», «0,5» → número."""
    s = s.strip()
    if ',' in s:
        s = s.replace('.', '').replace(',', '.')
    elif s.count('.') > 1 or re.fullmatch(r'\d{1,3}(\.\d{3})+', s):
        s = s.replace('.', '')
    return float(s)


# ----- Cuentas -----

_OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
        ast.Pow: operator.pow, ast.Mod: operator.mod, ast.FloorDiv: operator.floordiv}
_FUNCS = {'raiz': math.sqrt, 'sqrt': math.sqrt, 'sen': lambda d: math.sin(math.radians(d)),
          'sin': lambda d: math.sin(math.radians(d)), 'cos': lambda d: math.cos(math.radians(d)),
          'tan': lambda d: math.tan(math.radians(d)), 'log': math.log10, 'ln': math.log, 'abs': abs, 'redondear': round}
_CONSTS = {'pi': math.pi, 'e': math.e}


def _eval(node):
    if isinstance(node, ast.Expression):
        return _eval(node.body)
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return node.value
    if isinstance(node, ast.BinOp) and type(node.op) in _OPS:
        a, b = _eval(node.left), _eval(node.right)
        if isinstance(node.op, ast.Pow) and abs(b) > 1000:
            raise ValueError
        return _OPS[type(node.op)](a, b)
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
        v = _eval(node.operand)
        return -v if isinstance(node.op, ast.USub) else v
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in _FUNCS and len(node.args) == 1:
        return _FUNCS[node.func.id](_eval(node.args[0]))
    if isinstance(node, ast.Name) and node.id in _CONSTS:
        return _CONSTS[node.id]
    raise ValueError


def expression(text):
    t = text.lower().replace('×', '*').replace('÷', '/').replace('^', '**').replace('−', '-')
    t = re.sub(r'ra[ií]z(?: cuadrada)?(?: de)?\s*', 'raiz', t)
    t = re.sub(r'(?<=\d)\s*x\s*(?=[\d(])', '*', t)
    # los números con coma decimal o puntos de miles
    t = re.sub(r'\d[\d.,]*', lambda m: repr(num(m.group(0))) if re.search(r'\d', m.group(0)) else m.group(0), t)
    t = re.sub(r'raiz\s*([\d.]+)', r'raiz(\1)', t)
    if not re.search(r'[-+*/%]|raiz|sqrt|\w\(', t) or not re.search(r'\d', t):
        return None  # un número solo (o una palabra) no es una cuenta
    if not re.fullmatch(r'[\d\s.+\-*/%()a-z_]+', t):
        return None
    return _eval(ast.parse(t, mode='eval'))


# ----- Unidades -----

# (tipo, a la unidad base) · nombres en español, en singular y plural, y sus símbolos
UNITS = {}


def _u(kind, factor, *names):
    for n in names:
        UNITS[n] = (kind, factor, LABELS.get(names[0], names[0]))


LABELS = {'b': 'B', 'kb': 'KB', 'mb': 'MB', 'gb': 'GB', 'tb': 'TB', 'kib': 'KiB', 'mib': 'MiB', 'gib': 'GiB', 'tib': 'TiB'}


_u('largo', 1, 'm', 'metro', 'metros')
_u('largo', 1000, 'km', 'kilometro', 'kilometros', 'kilómetro', 'kilómetros')
_u('largo', 0.01, 'cm', 'centimetro', 'centimetros', 'centímetro', 'centímetros')
_u('largo', 0.001, 'mm', 'milimetro', 'milimetros', 'milímetro', 'milímetros')
_u('largo', 1609.344, 'millas', 'milla', 'mi')
_u('largo', 0.9144, 'yardas', 'yarda', 'yd')
_u('largo', 0.3048, 'pies', 'pie', 'ft')
_u('largo', 0.0254, 'pulgadas', 'pulgada', 'in', '"')
_u('peso', 1, 'kg', 'kilo', 'kilos', 'kilogramo', 'kilogramos')
_u('peso', 0.001, 'g', 'gramo', 'gramos', 'gr')
_u('peso', 1e-6, 'mg', 'miligramo', 'miligramos')
_u('peso', 1000, 't', 'tonelada', 'toneladas')
_u('peso', 0.45359237, 'libras', 'libra', 'lb', 'lbs')
_u('peso', 0.028349523125, 'onzas', 'onza', 'oz')
_u('volumen', 1, 'l', 'litro', 'litros')
_u('volumen', 0.001, 'ml', 'mililitro', 'mililitros')
_u('volumen', 3.785411784, 'galones', 'galon', 'galón', 'gal')
_u('velocidad', 1 / 3.6, 'km/h', 'kmh', 'kph')
_u('velocidad', 0.44704, 'mph')
_u('velocidad', 1, 'm/s')
_u('velocidad', 0.514444, 'nudos', 'nudo')
_u('datos', 1, 'b', 'byte', 'bytes')
_u('datos', 1e3, 'kb', 'kilobyte', 'kilobytes')
_u('datos', 1e6, 'mb', 'megabyte', 'megabytes', 'megas')
_u('datos', 1e9, 'gb', 'gigabyte', 'gigabytes', 'gigas')
_u('datos', 1e12, 'tb', 'terabyte', 'terabytes', 'teras')
_u('datos', 1024, 'kib')
_u('datos', 1024 ** 2, 'mib')
_u('datos', 1024 ** 3, 'gib')
_u('datos', 1024 ** 4, 'tib')
_u('tiempo', 1, 'segundos', 'segundo', 's', 'seg')
_u('tiempo', 60, 'minutos', 'minuto', 'min')
_u('tiempo', 3600, 'horas', 'hora', 'h')
_u('tiempo', 86400, 'días', 'dia', 'dias', 'día', 'd')
_u('tiempo', 604800, 'semanas', 'semana')
_u('tiempo', 31557600, 'años', 'año', 'anos', 'ano')
# (la temperatura, aparte: no es multiplicar)
TEMPS = {'c': 'c', '°c': 'c', 'ºc': 'c', 'celsius': 'c', 'grados': 'c', 'centigrados': 'c', 'centígrados': 'c',
         'f': 'f', '°f': 'f', 'ºf': 'f', 'fahrenheit': 'f', 'k': 'k', 'kelvin': 'k'}
TEMP_NAMES = {'c': '°C', 'f': '°F', 'k': 'K'}

# ----- Monedas (el cambio del BCE, en euros) -----

MONEY = {}


def _m(code, *names):
    for n in (code.lower(),) + names:
        MONEY[n] = code


_m('EUR', '€', 'euro', 'euros', 'eur')
_m('USD', '$', 'dolar', 'dolares', 'dólar', 'dólares', 'us$')
_m('GBP', '£', 'libra esterlina', 'libras esterlinas', 'esterlinas')
_m('JPY', '¥', 'yen', 'yenes')
_m('CHF', 'franco suizo', 'francos suizos', 'francos')
_m('MXN', 'peso mexicano', 'pesos mexicanos', 'pesos')
_m('BRL', 'real', 'reales')
_m('CNY', 'yuan', 'yuanes')
_m('CAD', 'dolar canadiense', 'dolares canadienses', 'dólar canadiense', 'dólares canadienses')
_m('AUD', 'dolar australiano', 'dolares australianos', 'dólar australiano', 'dólares australianos')
_m('SEK', 'corona sueca', 'coronas suecas')
_m('NOK', 'corona noruega', 'coronas noruegas')
_m('DKK', 'corona danesa', 'coronas danesas')
_m('PLN', 'zloty', 'zlotys')
_m('TRY', 'lira', 'liras', 'lira turca', 'liras turcas')
for _code in ('BGN', 'CZK', 'HUF', 'RON', 'ISK', 'HKD', 'IDR', 'ILS', 'INR', 'KRW', 'MYR', 'NZD', 'PHP', 'SGD', 'THB',
              'ZAR'):
    _m(_code)
MONEY_NAMES = {'EUR': '€', 'USD': '$', 'GBP': '£', 'JPY': '¥'}

RATES_FILE = os.path.join(os.environ.get('XDG_CACHE_HOME', os.path.expanduser('~/.cache')), 'apogeo', 'divisas.json')
ECB = 'https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml'
_rates = {'datos': None, 'pidiendo': False}


def rates():
    """El cambio de hoy (en euros). Se pide al BCE como mucho cada 12 horas, en segundo plano: la primera vez puede no
    estar todavía (y entonces no se contesta)."""
    if _rates['datos'] is None:
        try:
            with open(RATES_FILE) as f:
                _rates['datos'] = json.load(f)
        except (OSError, ValueError):
            _rates['datos'] = {}
    d = _rates['datos']
    if time.time() - d.get('pedido', 0) > 12 * 3600 and not _rates['pidiendo']:
        _rates['pidiendo'] = True
        threading.Thread(target=_fetch, daemon=True).start()
    return d.get('cambio') or {}


def _fetch():
    try:
        with urllib.request.urlopen(ECB, timeout=10) as r:
            xml = r.read().decode()
        found = dict(re.findall(r"currency='([A-Z]{3})' rate='([\d.]+)'", xml))
        day = re.search(r"time='([\d-]+)'", xml)
        if found:
            d = {'cambio': {'EUR': 1.0, **{k: float(v) for k, v in found.items()}},
                 'dia': day.group(1) if day else '', 'pedido': time.time()}
            os.makedirs(os.path.dirname(RATES_FILE), exist_ok=True)
            with open(RATES_FILE + '.nuevo', 'w') as f:
                json.dump(d, f)
            os.replace(RATES_FILE + '.nuevo', RATES_FILE)
            _rates['datos'] = d
    except (OSError, ValueError):
        pass
    finally:
        _rates['pidiendo'] = False


# ----- Lo que escribes -----

_NUM = r'(-?\d[\d.,]*)'
_TO = r'\s+(?:en|a|to|in|=)\s+'


def convert(text):
    t = text.lower().strip()
    # moneda: «10 € en dólares», «€10 a usd», «10eur»
    m = re.fullmatch(r'([€$£¥])?\s*' + _NUM + r'\s*(.*?)' + _TO + r'(.+)', t)
    if m:
        sym, n, frm, to = m.group(1), m.group(2), (m.group(3) or '').strip(), m.group(4).strip()
        a, b = MONEY.get(sym or frm), MONEY.get(to)
        if a and b:
            r = rates()
            if a in r and b in r:
                v = num(n) / r[a] * r[b]
                day = _rates['datos'].get('dia', '')
                return {'valor': f'{show(round(v, 2))} {MONEY_NAMES.get(b, b)}',
                        'detalle': f'{show(num(n))} {MONEY_NAMES.get(a, a)} · cambio del Banco Central Europeo'
                                   + (f' ({day})' if day else '')}
            return None
    m = re.fullmatch(_NUM + r'\s*(.+?)' + _TO + r'(.+)', t)
    if not m:
        return None
    n, frm, to = num(m.group(1)), m.group(2).strip(), m.group(3).strip()
    if frm in TEMPS and to in TEMPS:
        c = {'c': n, 'f': (n - 32) * 5 / 9, 'k': n - 273.15}[TEMPS[frm]]
        v = {'c': c, 'f': c * 9 / 5 + 32, 'k': c + 273.15}[TEMPS[to]]
        return {'valor': f'{show(round(v, 2))} {TEMP_NAMES[TEMPS[to]]}',
                'detalle': f'{show(n)} {TEMP_NAMES[TEMPS[frm]]}'}
    if frm in UNITS and to in UNITS and UNITS[frm][0] == UNITS[to][0]:
        v = n * UNITS[frm][1] / UNITS[to][1]
        return {'valor': f'{show(nice(v))} {UNITS[to][2]}', 'detalle': f'{show(n)} {LABELS.get(frm, frm)}'}
    return None


def percent(text):
    t = text.lower().strip()
    m = re.fullmatch(_NUM + r'\s*%\s*(?:de|of)\s*' + _NUM, t)
    if m:
        p, n = num(m.group(1)), num(m.group(2))
        return {'valor': show(n * p / 100), 'detalle': f'{show(p)} % de {show(n)}'}
    m = re.fullmatch(_NUM + r'\s*([+-])\s*' + _NUM + r'\s*%', t)
    if m:
        n, sign, p = num(m.group(1)), m.group(2), num(m.group(3))
        v = n * (1 + p / 100) if sign == '+' else n * (1 - p / 100)
        return {'valor': show(v), 'detalle': f'{show(n)} {"más" if sign == "+" else "menos"} el {show(p)} %'}
    return None


def answer(text):
    text = (text or '').strip()
    if not text or not re.search(r'\d', text) or len(text) > 120:
        return None
    try:
        r = percent(text) or convert(text)
        if r:
            return r
        v = expression(text)
        if v is None:
            return None
        return {'valor': show(v), 'detalle': text.replace('*', '×')}
    except (ValueError, ZeroDivisionError, OverflowError, SyntaxError, TypeError, RecursionError):
        return None
