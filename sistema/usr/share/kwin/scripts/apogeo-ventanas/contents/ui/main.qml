import QtQuick
import org.kde.kwin
import Apogeo

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
//  - Le cuenta a apogeo-pisos (org.apogeo.Datos → PonerVentanas) tus ventanas de cada piso, con su sitio en la pantalla:
//    la columna de pisos enseña cuántas hay y la vista de cada piso, y la pantalla de apagar cuántas apps se cierran.
//  - Si sueltas una ventana encima de un piso de la columna, se va a ese piso (y vuelve a donde estaba en la pantalla).
//  - La rejilla: al llevar una ventana arriba, sus huecos (Rejilla.qml).
Item {
    id: root
    property var music: null
    property var consoleWin: null

    Rejilla { id: rejilla }

    // ---------- Tus ventanas, para la columna de pisos y la pantalla de apagar ----------
    function isTask(w) { return w.normalWindow && !w.skipTaskbar && !w.deleted }
    function report() { reportTimer.restart() }
    Timer {
        id: reportTimer
        interval: 400
        onTriggered: {
            const list = Workspace.windows.filter(root.isTask).map(w => {
                const area = Workspace.clientArea(KWin.FullScreenArea, w);
                const g = w.frameGeometry;
                return {
                    titulo: w.caption || "",
                    clase: w.resourceClass || "",
                    app: w.desktopFileName || "",
                    pisos: w.onAllDesktops ? ["*"] : w.desktops.map(d => d.name),
                    x: (g.x - area.x) / area.width, y: (g.y - area.y) / area.height,
                    w: g.width / area.width, h: g.height / area.height,
                    min: w.minimized, activa: w === Workspace.activeWindow
                };
            });
            reportCall.arguments = [JSON.stringify(list)];
            reportCall.call();
        }
    }
    DBusCall {
        id: reportCall
        service: "org.apogeo.Datos"
        path: "/Datos"
        dbusInterface: "org.apogeo.Datos"
        method: "PonerVentanas"
    }
    function watch(w) {
        if (!isTask(w)) return;
        w.desktopsChanged.connect(report);
        w.minimizedChanged.connect(report);
        w.captionChanged.connect(report);
        w.interactiveMoveResizeStarted.connect(() => { dragStart(w); rejilla.start(w); });
        w.interactiveMoveResizeStepped.connect(() => rejilla.step());
        w.interactiveMoveResizeFinished.connect(() => { dragEnd(w); rejilla.finish(w); report(); });
        report();
    }

    // ---------- Soltar una ventana encima de un piso de la columna ----------
    property var dragFrom: null
    function dragStart(w) { dragFrom = { win: w, geo: w.frameGeometry } }
    function dragEnd(w) {
        const from = dragFrom;
        dragFrom = null;
        if (!from || from.win !== w) return;
        const p = Workspace.cursorPos;
        // la columna: el panel de Plasma alto y estrecho pegado a la derecha
        const rail = Workspace.windows.find(x => x.dock && x.frameGeometry.height > x.frameGeometry.width
                                                && p.x >= x.frameGeometry.x && p.x <= x.frameGeometry.x + x.frameGeometry.width
                                                && p.y >= x.frameGeometry.y && p.y <= x.frameGeometry.y + x.frameGeometry.height);
        if (!rail) return;
        // (como en la columna: 6 px de margen arriba y un botón de 40 px cada 48 px)
        const i = Math.floor((p.y - rail.frameGeometry.y - 6) / 48);
        const target = Workspace.desktops[Math.max(0, Math.min(Workspace.desktops.length - 1, i))];
        if (!target || (w.desktops.length === 1 && w.desktops[0] === target)) return;
        w.frameGeometry = from.geo;
        w.onAllDesktops = false;
        w.desktops = [target];
        report();
    }

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
        watch(w);
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
    function removed(w) { if (w === music) music = null; if (w === consoleWin) consoleWin = null; report(); }

    function summary(w) {
        w.onAllDesktops = true;
        w.keepAbove = true;
        w.skipTaskbar = true;
        w.skipSwitcher = true;
        w.skipPager = true;
        const put = () => {
            const area = Workspace.clientArea(KWin.FullScreenArea, w);
            const g = w.frameGeometry;
            // justo encima de la isla (o debajo, si la isla va arriba: Ajustes → Aspecto)
            const x = Math.round(area.x + (area.width - g.width) / 2);
            const y = Tema.posicion === "arriba-dcha" ? area.y + 74 : area.y + area.height - g.height - 74;
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
        function onWindowActivated(w) { root.hideMusic(); if (w && w === root.consoleWin) root.pinConsole(); root.report() }
        function onCurrentDesktopChanged() { root.hideMusic(); root.pinConsole() }
    }
    Timer { // por si una ventana se pone a pantalla completa sin cambiar de ventana activa
        interval: 1000
        repeat: true
        running: root.music !== null
        onTriggered: root.hideMusic()
    }
}
