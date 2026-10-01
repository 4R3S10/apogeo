"""
La parte de Qt que comparten la bienvenida y los ajustes de Apogeo: Base (la red, tu cuenta, instalar Ágape y traer su
copia, para QML) y run() para abrir una ventana QML con las piezas de Ágape (import Apogeo).
"""
import os
import sys
import threading
import urllib.error

import dbus
from PyQt6.QtCore import QObject, QUrl, pyqtProperty, pyqtSignal, pyqtSlot
from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

from apogeo_comun import CONFIG, HOME, Accounts, front, human, kwin, real_gpu, spawn
import apogeo_comun

AVATAR = os.path.join(os.environ.get('XDG_CACHE_HOME', os.path.join(HOME, '.cache')), 'apogeo', 'foto.png')
agape = apogeo_comun.agape()


class Base(QObject):
    """Lo común de la bienvenida y los ajustes: la red, tu cuenta, instalar Ágape y traer su copia."""
    APP_ID = ''  # la ventana que vuelve delante al traer la copia
    changed = pyqtSignal()
    progress = pyqtSignal(float, arguments=['value'])  # descarga de Ágape, 0…1 (-1 si no se sabe el total)
    installed = pyqtSignal(bool, str, arguments=['ok', 'message'])  # (bien, mensaje si no)
    restored = pyqtSignal()               # Ágape ha traído la copia

    def __init__(self):
        super().__init__()
        self._online = False
        self._restoring = False
        try:
            self.accounts = Accounts()
        except dbus.DBusException:
            self.accounts = None
        self.check_online()

    # ---------- Estado ----------

    @pyqtProperty(bool, notify=changed)
    def online(self):
        return self._online

    @pyqtProperty(str, constant=True)
    def realName(self):
        name = self.accounts.get('RealName') if self.accounts else ''
        return name or os.environ.get('USER', '').capitalize()

    @pyqtProperty(str, constant=True)
    def avatarPath(self):
        return AVATAR

    @pyqtProperty(bool, constant=True)
    def animate(self):
        return real_gpu()

    @pyqtProperty(bool, notify=changed)
    def agapeInstalled(self):
        return os.access(agape.APP, os.X_OK)

    @pyqtProperty(str, constant=True)
    def mediaFolder(self):
        """Donde están los USB y los discos (para abrir ahí el selector de la copia)."""
        media = f"/run/media/{os.environ.get('USER', '')}"
        return QUrl.fromLocalFile(media if os.path.isdir(media) else HOME).toString()

    @pyqtSlot()
    def check_online(self):
        try:
            nm = dbus.SystemBus().get_object('org.freedesktop.NetworkManager', '/org/freedesktop/NetworkManager')
            # 4 = conectado a internet del todo (NM_CONNECTIVITY_FULL); si NM no comprueba, basta con estar conectado
            conn = int(nm.Get('org.freedesktop.NetworkManager', 'Connectivity',
                              dbus_interface='org.freedesktop.DBus.Properties'))
            state = int(nm.Get('org.freedesktop.NetworkManager', 'State',
                               dbus_interface='org.freedesktop.DBus.Properties'))
            online = conn == 4 or (conn == 0 and state >= 70)
        except dbus.DBusException:
            online = True  # sin NetworkManager no se sabe: que lo intente
        if online != self._online:
            self._online = online
            self.changed.emit()

    @pyqtSlot()
    def openNetwork(self):
        spawn('kcmshell6', 'kcm_networkmanagement')

    # ---------- Tu nombre y tu foto ----------

    @pyqtSlot(str, result=str)
    def saveProfile(self, name):
        """El nombre y la foto (la dibuja la ventana en AVATAR). Devuelve el problema, o «» si todo bien."""
        return self._save_profile(name, True)

    @pyqtSlot(str, result=str)
    def saveName(self, name):
        """Solo el nombre (la foto se queda como está)."""
        return self._save_profile(name, False)

    def _save_profile(self, name, photo):
        if not self.accounts:
            return 'No se ha podido guardar (el servicio de cuentas no responde).'
        try:
            if name.strip() and name.strip() != self.accounts.get('RealName'):
                self.accounts.set_name(name.strip())
            if photo and os.path.exists(AVATAR):
                self.accounts.set_icon(AVATAR)
        except dbus.DBusException as e:
            return f'No se ha podido guardar ({e.get_dbus_message()}).'
        return ''

    # ---------- Ágape ----------

    @pyqtSlot(str)
    def installAgape(self, token):
        token = token.strip()

        def work():
            try:
                rel = agape.check_token(token)
                agape.save_token(token)
                agape.download(rel, token, lambda done, total: self.progress.emit(done / total if total else -1))
            except agape.Fallo as f:
                self.installed.emit(False, str(f))
                return
            except (urllib.error.URLError, OSError) as e:
                self.installed.emit(False, f'No se ha podido descargar Ágape ({getattr(e, "reason", e)}). '
                                           '¿Hay conexión a internet?')
                return
            self.changed.emit()
            self.installed.emit(True, '')
            # Se abre una vez (crea su acceso) y queda como navegador del sistema
            spawn(agape.APP)
            agape.make_default()

        threading.Thread(target=work, daemon=True).start()

    @pyqtSlot(str, result='QVariantMap')
    def copyInfo(self, url):
        path = QUrl(url).toLocalFile()
        try:
            size = os.path.getsize(path)
        except OSError:
            return {}
        media = f"/run/media/{os.environ.get('USER', '')}/"
        if path.startswith(media):
            where = f"En «{path[len(media):].split('/')[0]}»"
        else:
            where = 'En ' + os.path.dirname(path).replace(HOME, 'tu carpeta', 1)
        return {'path': path, 'name': os.path.basename(path), 'where': f'{where} · {human(size)}'}

    @pyqtSlot(str)
    def restoreCopy(self, path):
        """Ágape abre la copia y pide su contraseña (con Ágape ya abierto, se la pasa a esa ventana)."""
        if not os.access(agape.APP, os.X_OK) or not os.path.isfile(path):
            return
        spawn(agape.APP, f'--importar={path}')
        front('ares', (1, 1, 2, 3))  # Ágape pide la contraseña en su ventana: delante
        if not self._restoring:
            self._restoring = True
            threading.Thread(target=self._wait_restore, daemon=True).start()

    def _wait_restore(self):
        """Ágape deja lo traído en «copia-pendiente» hasta reiniciarse: en cuanto aparece, la copia está bien."""
        pending = os.path.join(CONFIG, 'ARES', 'copia-pendiente')
        for _ in range(3600):
            if os.path.isdir(pending):
                self.restored.emit()
                front(self.APP_ID, (1.5,))  # y esta ventana vuelve delante
                break
            threading.Event().wait(1)
        self._restoring = False



def run(name, app_id, qml, backend_class, context=None, all_desktops=False, images=None):
    """Abre la ventana QML con «apogeo» (el backend) y las piezas de Ágape. Devuelve el código de salida."""
    os.makedirs(os.path.dirname(AVATAR), exist_ok=True)
    os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'  # los controles los dibuja el QML, con las formas de Ágape
    app = QGuiApplication(sys.argv)
    app.setApplicationName(name)
    app.setDesktopFileName(app_id)
    app.setWindowIcon(QIcon.fromTheme('apogeo'))
    backend = backend_class()
    engine = QQmlApplicationEngine()
    if os.environ.get('APOGEO_QML_DIR'):  # (para probar otra copia; el módulo Apogeo está en /usr/lib/qt6/qml)
        engine.addImportPath(os.environ['APOGEO_QML_DIR'])
    engine.rootContext().setContextProperty('apogeo', backend)
    providers = [(k, v()) for k, v in (images or {}).items()]  # (se guardan: si no, Python los borraría)
    for k, v in providers:
        engine.addImageProvider(k, v)
    for k, v in (context or {}).items():
        engine.rootContext().setContextProperty(k, v)
    engine.load(QUrl.fromLocalFile(qml))
    if not engine.rootObjects():
        return 1
    if all_desktops:
        # En todos los pisos: si cambias de piso a medias, la ventana va contigo
        threading.Thread(target=lambda: (threading.Event().wait(1), kwin(
            'for (const w of workspace.windowList()) { if (w.desktopFileName === "%s") w.onAllDesktops = true; }' % app_id
        )), daemon=True).start()
    return app.exec()
