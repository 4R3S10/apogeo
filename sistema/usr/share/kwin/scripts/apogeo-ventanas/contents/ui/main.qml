import QtQuick
import org.kde.kwin

// Ventanas de Apogeo:
//  - La consola (se pone ella sola a pantalla completa) vive en el piso Jugar y no se mueve de ahí: al ir a otro piso,
//    KWin le daba el foco aunque no se viera y la traía a ese piso (por «la ventana que se pone delante se viene a tu
//    piso»); entonces Estudiar parecía Jugar y tus teclas iban a ella. Ahora se queda en Jugar y, fuera de Jugar, el
//    foco va al escritorio del piso.
//  - La música (apogeo-musica) va abajo a la izquierda, encima de todo, en todos los pisos y fuera de la barra de
//    tareas y del cambiador de ventanas. Se esconde con Ágape delante (Ágape enseña la suya en el mismo sitio), con
//    una ventana a pantalla completa (un juego, la consola) y en Navegar con el escritorio a la vista (allí ya está el
//    widget de música del escritorio).
//  - El resumen de avisos al volver (apogeo-resumen) va abajo en el centro, justo encima de la isla, encima de todo y
//    en todos los pisos (sale al cambiar de piso, mientras se deslizan).
Item {
    id: root
    property var music: null
    property var consoleWin: null

    function jugar() { return Workspace.desktops.find(d => d.name === "Jugar") || null }
    function pinConsole() {
        const w = consoleWin, j = jugar();
        if (!w || !j) return;
        if (w.onAllDesktops || w.desktops.length !== 1 || w.desktops[0] !== j) {
            w.onAllDesktops = false;
            w.desktops = [j];
        }
        // Fuera de Jugar, que no se quede con el foco (las teclas irían a ella sin verla): al escritorio del piso
        if (Workspace.activeWindow === w && Workspace.currentDesktop !== j) {
            const desk = Workspace.windows.find(x => x.desktopWindow && x.output === w.output) || Workspace.windows.find(x => x.desktopWindow);
            if (desk) Workspace.activeWindow = desk;
        }
    }

    function added(w) {
        const cls = (w.resourceClass || "") + " " + (w.desktopFileName || "");
        if (cls.indexOf("apogeo-resumen") >= 0) summary(w);
        if (cls.indexOf("apogeo-consola") >= 0 && w.normalWindow) {
            consoleWin = w;
            pinConsole();
            w.desktopsChanged.connect(pinConsole);
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
    function removed(w) { if (w === music) music = null; if (w === consoleWin) consoleWin = null; }

    function summary(w) {
        w.onAllDesktops = true;
        w.keepAbove = true;
        w.skipTaskbar = true;
        w.skipSwitcher = true;
        w.skipPager = true;
        const put = () => {
            const area = Workspace.clientArea(KWin.FullScreenArea, w);
            const g = w.frameGeometry;
            const x = Math.round(area.x + (area.width - g.width) / 2), y = area.y + area.height - g.height - 74;
            if (g.x !== x || g.y !== y) w.frameGeometry = Qt.rect(x, y, g.width, g.height);
        };
        put();
        w.frameGeometryChanged.connect(put);
    }

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
        const desk = Workspace.currentDesktop;
        const covered = Workspace.windows.some(w => w.normalWindow && !w.minimized && w !== music && !w.skipTaskbar
                                                    && (w.onAllDesktops || w.desktops.indexOf(desk) >= 0));
        const desktopShown = desk && desk.name === "Navegar" && !covered;
        const busy = (a && a !== music && (a.fullScreen || agape)) || desktopShown;
        if (music.minimized !== busy) music.minimized = busy;
    }

    Component.onCompleted: Workspace.windows.forEach(added)
    Connections {
        target: Workspace
        function onWindowAdded(w) { root.added(w) }
        function onWindowRemoved(w) { root.removed(w) }
        function onWindowActivated(w) { root.hideMusic(); if (w && w === root.consoleWin) root.pinConsole() }
        function onCurrentDesktopChanged() { root.hideMusic(); root.pinConsole() }
    }
    Timer { // por si una ventana se pone a pantalla completa sin cambiar de ventana activa
        interval: 1000
        repeat: true
        running: root.music !== null
        onTriggered: root.hideMusic()
    }
}
