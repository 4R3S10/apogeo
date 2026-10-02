import QtQuick
import QtQuick.Effects
import Apogeo

// Música de Apogeo («M1 · Como en Ágape»): abajo a la izquierda una portada por cada cosa que suena (la que empezó la
// última, delante); al pasar el ratón, la tarjeta. Si no suena nada, lo último que sonó con «Seguir» y «Abrir Spotify». La ventana es transparente y de tamaño fijo (la coloca el script de
// KWin apogeo-ventanas en la esquina); solo lo que se ve recibe el ratón. «musica» es apogeo-musica.
Window {
    id: win
    width: 380
    height: 470
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus
    title: "Música de Apogeo"

    property var started: ({})           // clave → cuándo empezó a sonar (la más reciente va delante)
    property string pinned: ""           // la que has puesto en grande
    property bool open: openAtStart
    readonly property var all: musica.sources
    // Se enseña si algo suena o si Spotify está abierto (como en Ágape); delante, lo último que empezó
    readonly property var list: {
        const now = Date.now();
        const s = win.started;
        for (const x of all) {
            if (x.paused) delete s[x.key];
            else if (!s[x.key]) s[x.key] = now;
        }
        const playing = all.filter(x => !x.paused).sort((a, b) => s[b.key] - s[a.key]);
        const rest = all.filter(x => x.paused && x.spotify);
        let out = playing.concat(rest);
        const i = out.findIndex(x => x.key === win.pinned);
        if (i > 0) out.unshift(...out.splice(i, 1));
        return out;
    }
    readonly property var main: list.length ? list[0] : null
    readonly property bool idle: list.length === 0
    readonly property var last: musica.last
    visible: true

    // Abrir al pasar el ratón; cerrar un poco después de salir (por si vuelve)
    Timer { id: closeTimer; interval: 350; onTriggered: win.open = false }
    function hover(inside) { if (inside) { closeTimer.stop(); win.open = true; } else closeTimer.restart(); }

    // Solo la parte que se ve recibe el ratón
    function updateMask() {
        const r = win.open ? card : bubbles;
        musica.setInputRegion(win, [{ x: r.x - 4, y: r.y - 4, width: r.width + 8, height: r.height + 8 }]);
    }
    onOpenChanged: Qt.callLater(updateMask)
    onListChanged: Qt.callLater(updateMask)
    Component.onCompleted: Qt.callLater(updateMask)

    // Volumen con la rueda: se enseña el % un momento
    property string volKey: ""
    property real volValue: 0
    Timer { id: volHide; interval: 900; onTriggered: win.volKey = "" }
    function wheel(src, ev) {
        const v = Math.max(0, Math.min(1, (src.vol ?? 1) + (ev.angleDelta.y > 0 ? 0.05 : -0.05)));
        musica.setVolume(src.key, v);
        win.volKey = src.key; win.volValue = v; volHide.restart();
    }

    function mmss(s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    component Art: Item {
        id: art
        property var src: null
        property real radius: 14
        Rectangle { // sin portada: la inicial de la app sobre el degradado del tema
            anchors.fill: parent
            radius: art.radius
            gradient: Gradient {
                GradientStop { position: 0; color: art.src && art.src.spotify ? "#1db954" : "#7a4458" }
                GradientStop { position: 1; color: art.src && art.src.spotify ? "#0b3d20" : "#2a1830" }
            }
            Icono { anchors.centerIn: parent; width: parent.width * 0.42; height: width; nombre: "musica"; color: "#ffffff" }
        }
        Image {
            id: img
            anchors.fill: parent
            source: art.src && art.src.art ? art.src.art : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }
        Rectangle { id: mask; anchors.fill: parent; radius: art.radius; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; visible: img.status === Image.Ready; source: img; maskEnabled: true; maskSource: mask }
        Rectangle { // el % del volumen
            anchors.fill: parent
            radius: art.radius
            color: Qt.rgba(0, 0, 0, 0.55)
            visible: art.src && win.volKey === art.src.key
            Texto { anchors.centerIn: parent; text: Math.round(win.volValue * 100) + " %"; font.weight: Font.Bold; color: "#ffffff" }
        }
    }

    // ---------- Las portadas (recogido) ----------

    Item {
        id: bubbles
        x: 14
        y: win.height - height - 14
        width: Math.max(1, Math.min(win.list.length, 4)) * 22 + 30
        height: 52
        opacity: win.open ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Item { // sin nada sonando: lo último que sonó (o la nota de música)
            visible: win.idle
            width: 52; height: 52
            RectangularShadow { anchors.fill: parent; radius: 14; blur: 18; offset.y: 6; color: Qt.rgba(0, 0, 0, 0.5) }
            Art { anchors.fill: parent; src: win.last && win.last.title ? win.last : null; opacity: 0.85 }
            Rectangle { anchors.fill: parent; radius: 14; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.12) }
        }
        Repeater {
            model: win.list.slice(0, 4)
            delegate: Item {
                required property var modelData
                required property int index
                x: index * 22
                z: 10 - index
                width: 52; height: 52
                RectangularShadow { anchors.fill: parent; radius: 14; blur: 18; offset.y: 6; color: Qt.rgba(0, 0, 0, 0.5) }
                Art { anchors.fill: parent; src: parent.modelData }
                Rectangle { anchors.fill: parent; radius: 14; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.12) }
                Rectangle { // suena
                    visible: !parent.modelData.paused
                    x: parent.width - 11; y: parent.height - 11
                    width: 14; height: 14; radius: 7
                    color: Tema.rosa
                    border.width: 2; border.color: Tema.cromo
                }
            }
        }
        HoverHandler { onHoveredChanged: win.hover(hovered) }
        WheelHandler { onWheel: ev => win.main && win.wheel(win.main, ev) }
    }

    // ---------- La tarjeta (al pasar el ratón) ----------

    Rectangle {
        id: card
        x: 14
        y: win.height - height - 14
        width: 340
        height: (win.idle ? idleCol.implicitHeight : col.implicitHeight) + 28
        radius: 20
        color: Qt.rgba(33 / 255, 25 / 255, 36 / 255, 0.96)
        border.color: Tema.borde
        visible: opacity > 0
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.96
        transformOrigin: Item.BottomLeft
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        HoverHandler { onHoveredChanged: win.hover(hovered) }

        // Sin nada sonando
        Column {
            id: idleCol
            visible: win.idle
            x: 14; y: 14
            width: parent.width - 28
            spacing: 12
            Row {
                spacing: 12
                width: parent.width
                Art { width: 64; height: 64; src: win.last && win.last.title ? win.last : null }
                Column {
                    width: parent.width - 76
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Texto { width: parent.width; text: win.last && win.last.title ? win.last.title : "No suena nada"; font.pixelSize: 15; font.weight: Font.Bold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                    Texto {
                        width: parent.width
                        text: win.last && win.last.title ? "Lo último que sonó · " + (win.last.kind === "agape" ? "Ágape" : win.last.app) : "Pon algo en Spotify o en Ágape"
                        color: Tema.apagado; font.pixelSize: 12; elide: Text.ElideRight; wrapMode: Text.NoWrap
                    }
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Boton { visible: !!(win.last && win.last.title); tipo: "principal"; text: "Seguir"; icono: "reproducir"; onClicked: musica.resume() }
                Boton { visible: musica.hasSpotify; text: "Abrir Spotify"; icono: "musica"; onClicked: musica.openSpotify() }
            }
        }

        Column {
            id: col
            visible: !win.idle
            x: 14; y: 14
            width: parent.width - 28
            spacing: 6
            // Lo principal
            Row {
                spacing: 12
                width: parent.width
                Art {
                    width: 64; height: 64
                    src: win.main
                    WheelHandler { onWheel: ev => win.main && win.wheel(win.main, ev) }
                }
                Column {
                    width: parent.width - 76
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Texto {
                        width: parent.width
                        text: win.main ? win.main.title : ""
                        font.pixelSize: 15; font.weight: Font.Bold
                        elide: Text.ElideRight; wrapMode: Text.NoWrap
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.main && musica.open(win.main.key) }
                    }
                    Texto {
                        width: parent.width
                        text: win.main ? [win.main.artist, win.main.kind === "agape" ? "Ágape · pestaña" : win.main.app].filter(Boolean).join(" · ") : ""
                        color: Tema.apagado; font.pixelSize: 12
                        elide: Text.ElideRight; wrapMode: Text.NoWrap
                    }
                }
            }
            // Progreso
            Item {
                width: parent.width
                height: 22
                visible: !!win.main && win.main.dur > 0
                Rectangle {
                    y: 6; width: parent.width; height: 4; radius: 2
                    color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.14)
                    Rectangle { height: parent.height; radius: 2; color: Tema.rosa; width: win.main && win.main.dur ? parent.width * Math.min(1, win.main.time / win.main.dur) : 0 }
                }
                Texto { y: 11; text: win.main ? win.mmss(win.main.time) : ""; color: Tema.tenue; font.pixelSize: 11 }
                Texto { y: 11; anchors.right: parent.right; text: win.main ? win.mmss(win.main.dur) : ""; color: Tema.tenue; font.pixelSize: 11 }
            }
            // Botones
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Boton { tipo: "plano"; icono: "anterior"; enabled: !!win.main && win.main.prev; onClicked: musica.run(win.main.key, "prev") }
                Boton {
                    tipo: "principal"
                    icono: win.main && !win.main.paused ? "pausa" : "reproducir"
                    implicitWidth: 46
                    onClicked: musica.run(win.main.key, "toggle")
                }
                Boton { tipo: "plano"; icono: "siguiente"; enabled: !!win.main && win.main.next; onClicked: musica.run(win.main.key, "next") }
            }
            // El resto
            Repeater {
                model: win.list.slice(1, 5)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: col.width
                    height: 50
                    radius: 12
                    color: rowArea.containsMouse ? Tema.pulsado : Tema.encima
                    Art { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; radius: 9; src: row.modelData }
                    Column {
                        x: 52
                        width: parent.width - 52 - 44
                        anchors.verticalCenter: parent.verticalCenter
                        Texto { width: parent.width; text: row.modelData.title; font.weight: Font.Bold; font.pixelSize: 13; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                        Texto { width: parent.width; text: row.modelData.kind === "agape" ? "Ágape · pestaña" : row.modelData.app; color: Tema.apagado; font.pixelSize: 11; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                    }
                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.pinned = row.modelData.key // a lo grande
                        onWheel: ev => win.wheel(row.modelData, ev)
                    }
                    Boton {
                        anchors.right: parent.right; anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        tipo: "plano"
                        icono: row.modelData.paused ? "reproducir" : "pausa"
                        onClicked: musica.run(row.modelData.key, "toggle")
                    }
                }
            }
        }
    }
}
