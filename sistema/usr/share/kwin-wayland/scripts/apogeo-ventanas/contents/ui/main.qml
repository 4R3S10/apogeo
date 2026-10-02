import QtQuick
import org.kde.kwin

// Ventanas de Apogeo:
//  - La consola del piso Jugar se abre a pantalla completa. KWin no lo aplica hasta que la ventana tiene su título y se
//    ve, así que se reintenta un momento después de aparecer.
//  - La música (apogeo-musica) va abajo a la izquierda, encima de todo, en todos los pisos y fuera de la barra de
//    tareas y del cambiador de ventanas. Se esconde con Ágape delante (Ágape enseña la suya en el mismo sitio) y con
//    una ventana a pantalla completa (un juego, la consola).
Item {
    id: root
    property var pending: []
    property var music: null

    function added(w) {
        const cls = (w.resourceClass || "") + " " + (w.desktopFileName || "");
        if (w.normalWindow && cls.indexOf("plasmawindowed") >= 0) {
            pending.push(w);
            retry.start();
        }
        if (cls.indexOf("apogeo-musica") >= 0) {
            music = w;
            w.onAllDesktops = true;
            w.keepAbove = true;
            w.skipTaskbar = true;
            w.skipSwitcher = true;
            w.skipPager = true;
            place();
            w.frameGeometryChanged.connect(place);
            hideMusic();
        }
    }
    function removed(w) { if (w === music) music = null; }

    function place() {
        if (!music) return;
        const area = Workspace.clientArea(KWin.FullScreenArea, music);
        const g = music.frameGeometry;
        const x = area.x, y = area.y + area.height - g.height;
        if (g.x !== x || g.y !== y) music.frameGeometry = Qt.rect(x, y, g.width, g.height);
    }

    function hideMusic() {
        if (!music) return;
        const a = Workspace.activeWindow;
        const agape = a && ((a.resourceClass || "") + " " + (a.desktopFileName || "")).toLowerCase().indexOf("ares") >= 0;
        const busy = a && a !== music && (a.fullScreen || agape);
        if (music.minimized !== busy) music.minimized = busy;
    }

    function console_(w) {
        if (w.caption !== "Jugar") return false;
        w.fullScreen = true;
        return w.fullScreen;
    }
    Component.onCompleted: Workspace.windows.forEach(added)
    Connections {
        target: Workspace
        function onWindowAdded(w) { root.added(w) }
        function onWindowRemoved(w) { root.removed(w) }
        function onWindowActivated(w) { root.hideMusic() }
    }
    Timer {
        id: retry
        interval: 150
        repeat: true
        onTriggered: {
            root.pending = root.pending.filter(x => x && !root.console_(x));
            if (!root.pending.length) stop();
        }
    }
    Timer { // por si una ventana se pone a pantalla completa sin cambiar de ventana activa
        interval: 1000
        repeat: true
        running: root.music !== null
        onTriggered: root.hideMusic()
    }
}
