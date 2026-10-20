import QtQuick
import Apogeo
import QtQuick.Window
import org.kde.kwin
import org.kde.plasma.core as PlasmaCore

// Modo partida («S3 · Juego y Discord a la vez»). Meta+Tab con un juego a pantalla completa:
//  - El juego NO se toca: sigue a pantalla completa, a su resolución y sin minimizarse (lo que da tirones y fallos con
//    Alt+Tab). Se ve en vivo a la izquierda, en pequeño, con una imagen de KWin; pulsarla (o Meta+Tab otra vez) vuelve
//    al juego al instante.
//  - Discord a la derecha, de verdad (se puede escribir y hablar). Si no está abierto, se abre.
//  - Debajo del juego, lo que suena (Spotify u otra app) con sus botones; si no suena nada, «Abrir Spotify».
// Sin juego delante, Meta+Tab solo trae Discord.
Item {
    id: root
    property var game: null
    property bool on: false
    property var saved: []          // [{w, geo, above, minimized}] para dejar Discord como estaba
    property rect area: Qt.rect(0, 0, 0, 0)
    readonly property int gap: 16
    readonly property real side: Math.min(area.width * 0.55, Math.max(area.width * 0.38, 960))   // Discord no baja de 940 px

    function cls(w) { return ((w.resourceClass || "") + " " + (w.desktopFileName || "")).toLowerCase() }
    function isDiscord(w) { return w && w.normalWindow && cls(w).indexOf("discord") >= 0 }
    function isGame(w) { return w && w.normalWindow && w.fullScreen && !isDiscord(w) && cls(w).indexOf("apogeo") < 0 }
    function discord() { return Workspace.windows.find(isDiscord) || null }

    ShortcutHandler {
        name: "Apogeo partida"
        text: "Apogeo: el juego con Discord y lo que suena al lado"
        sequence: "Meta+Tab"
        onActivated: root.on ? root.leave() : root.enter()
    }
    DBusCall {
        id: abrir
        service: "org.apogeo.Datos"; path: "/Datos"; dbusInterface: "org.apogeo.Datos"; method: "Abrir"
    }
    function open(app) { abrir.arguments = [app]; abrir.call() }

    function enter() {
        const active = Workspace.activeWindow;
        game = isGame(active) ? active : null;
        if (!game) { // sin juego: solo Discord
            const d = discord();
            if (d) { d.minimized = false; Workspace.activeWindow = d } else open("discord");
            return;
        }
        area = Workspace.clientArea(KWin.FullScreenArea, game);
        on = true;
        panel.show();
        Qt.callLater(fixPanel);
        const d = discord();
        if (d) place(d); else open("discord");
    }

    // KWin coloca las ventanas nuevas a su manera (centradas): el panel va pegado a la izquierda, sin borde y fuera de la
    // barra de tareas y del cambiador
    function fixPanel() {
        const p = Workspace.windows.find(w => w.caption === "apogeo-partida");
        if (!p) return;
        p.noBorder = true;
        p.skipTaskbar = true; p.skipSwitcher = true; p.skipPager = true;
        p.frameGeometry = Qt.rect(area.x, area.y, area.width - side, area.height);
    }

    function place(d) {
        // (una copia: frameGeometry en JS sigue a la ventana y se perdería el sitio de antes)
        const g = d.frameGeometry;
        if (!saved.some(s => s.w === d)) saved.push({ w: d, geo: Qt.rect(g.x, g.y, g.width, g.height), above: d.keepAbove, minimized: d.minimized });
        d.minimized = false;
        if (d.fullScreen) d.fullScreen = false;
        d.keepAbove = true;
        // Pegado a la derecha y de arriba abajo: el panel de la izquierda (de KWin) va siempre encima de todo, así que
        // no se montan el uno sobre el otro
        d.frameGeometry = Qt.rect(area.x + area.width - side, area.y, side, area.height);
        Workspace.activeWindow = d;
    }

    function leave() {
        on = false;
        panel.hide();
        for (const s of saved) {
            if (!s.w || s.w.deleted) continue;
            s.w.keepAbove = s.above;
            s.w.frameGeometry = s.geo;
        }
        saved = [];
        if (game && !game.deleted) {
            game.minimized = false;
            Workspace.activeWindow = game;
        }
        game = null;
    }

    Connections {
        target: Workspace
        function onWindowAdded(w) { if (root.on && root.isDiscord(w)) Qt.callLater(() => root.place(w)) }
        function onWindowRemoved(w) { if (root.on && w === root.game) root.leave() }
        // Volver al juego por otro camino (Alt+Tab, la isla…): se acaba el modo partida
        function onWindowActivated(w) { if (root.on && w === root.game) root.leave() }
    }
    // Por si el juego se minimiza solo al perder el foco (algunos no hacen caso a SDL): se vuelve a dejar en su sitio
    Connections {
        target: root.game
        ignoreUnknownSignals: true
        function onMinimizedChanged() { if (root.on && root.game.minimized) root.game.minimized = false }
    }

    // Lo que suena: se lo pide a apogeo-pisos (aquí, dentro de KWin, no se puede usar el modelo MPRIS de Plasma)
    property var musica: ({})
    DBusCall {
        id: pedirMusica
        service: "org.apogeo.Datos"; path: "/Datos"; dbusInterface: "org.apogeo.Datos"; method: "Musica"
        onFinished: r => { try { root.musica = JSON.parse(r[0]) } catch (e) { root.musica = {} } }
    }
    DBusCall {
        id: accionMusica
        service: "org.apogeo.Datos"; path: "/Datos"; dbusInterface: "org.apogeo.Datos"; method: "MusicaAccion"
    }
    function musicaAccion(a) { accionMusica.arguments = [a]; accionMusica.call(); Qt.callLater(pedirMusica.call) }
    Timer { interval: 1500; repeat: true; triggeredOnStart: true; running: root.on; onTriggered: pedirMusica.call() }

    PlasmaCore.Window {
        id: panel
        flags: Qt.FramelessWindowHint
        color: "transparent"
        x: root.area.x; y: root.area.y
        width: root.area.width - root.side; height: root.area.height
        title: "apogeo-partida"
        backgroundHints: PlasmaCore.Types.NoBackground
        visible: false

      mainItem: Item {
        width: panel.width; height: panel.height
        Rectangle { anchors.fill: parent; color: "#e6120d14" } // el fondo, berenjena muy oscuro

        Item {
            id: izquierda
            x: root.gap; y: root.gap
            width: parent.width - 2 * root.gap
            height: parent.height - 2 * root.gap

            // El juego, en vivo y en su proporción
            Item {
                id: marco
                width: parent.width
                height: Math.min(parent.height - musica.height - root.gap, width * root.area.height / Math.max(1, root.area.width))
                Rectangle {
                    anchors.fill: thumb
                    anchors.margins: -2
                    radius: 16
                    color: "transparent"
                    border.color: Tema.rosa
                    border.width: 2
                }
                WindowThumbnail {
                    id: thumb
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height * root.area.width / Math.max(1, root.area.height))
                    height: width * root.area.height / Math.max(1, root.area.width)
                    wId: root.game ? root.game.internalId : "{00000000-0000-0000-0000-000000000000}"
                }
                MouseArea { anchors.fill: thumb; cursorShape: Qt.PointingHandCursor; onClicked: root.leave() }
                Text {
                    anchors.top: thumb.bottom; anchors.topMargin: 8; anchors.left: thumb.left
                    text: "Pulsa el juego o Meta+Tab para volver"
                    color: "#9ef1e6ea"; font.family: Tema.letra; font.pixelSize: 13
                }
            }

            // Lo que suena
            Rectangle {
                id: musica
                anchors.bottom: parent.bottom
                width: Math.min(parent.width, 520)
                height: 96
                radius: 20
                color: "#cc1e1621"
                border.color: "#1af1e6ea"
                readonly property var p: root.musica && root.musica.app ? root.musica : null
                Row {
                    anchors.fill: parent; anchors.margins: 16
                    spacing: 14
                    visible: !!musica.p
                    Rectangle {
                        width: 64; height: 64; radius: 12; color: "#33e0a9b4"; clip: true
                        Image { anchors.fill: parent; source: musica.p ? musica.p.portada : ""; fillMode: Image.PreserveAspectCrop }
                    }
                    Column {
                        width: parent.width - 64 - 14 - botones.width - 14
                        anchors.verticalCenter: parent.verticalCenter
                        Text { width: parent.width; text: musica.p ? musica.p.titulo : ""; color: Tema.texto; font.family: Tema.letra; font.pixelSize: 17; font.bold: true; elide: Text.ElideRight }
                        Text { width: parent.width; text: musica.p ? (musica.p.artista || musica.p.app) : ""; color: "#9ef1e6ea"; font.family: Tema.letra; font.pixelSize: 13; elide: Text.ElideRight }
                    }
                    Row {
                        id: botones
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Repeater {
                            model: [{ t: "⏮", a: "Previous" }, { t: musica.p && musica.p.sonando ? "⏸" : "▶", a: "PlayPause", main: true }, { t: "⏭", a: "Next" }]
                            delegate: Rectangle {
                                required property var modelData
                                width: 40; height: 40; radius: 13
                                color: modelData.main ? Tema.rosa : (ma.containsMouse ? Tema.pulsado : "transparent")
                                Text { anchors.centerIn: parent; text: parent.modelData.t; color: parent.modelData.main ? Tema.sobreRosa : Tema.texto; font.pixelSize: 16 }
                                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: root.musicaAccion(parent.modelData.a) }
                            }
                        }
                    }
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: !musica.p
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "No suena nada"; color: "#9ef1e6ea"; font.family: Tema.letra; font.pixelSize: 15 }
                    Rectangle {
                        width: abrirT.width + 28; height: 38; radius: 13; color: Tema.rosa
                        Text { id: abrirT; anchors.centerIn: parent; text: "Abrir Spotify"; color: Tema.sobreRosa; font.family: Tema.letra; font.pixelSize: 14; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.open("spotify") }
                    }
                }
            }
        }
      }
    }
}
