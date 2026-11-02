import QtQuick
import QtQuick.Window
import org.kde.kwin
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import Apogeo

// La vista de escritorios («como en COSMIC»), con Meta+W:
//  - A la izquierda, una columna con tus modos (Jugar, Navegar, Estudiar) y los escritorios de cada uno («Navegar 2»…),
//    en pequeño y en vivo (cada ventana en su sitio), del color de su modo; el tuyo, encendido. Un clic te lleva.
//  - En el centro, las ventanas del escritorio en el que estás, como tarjetas en vivo con su icono, su nombre y una ✕
//    roja para cerrarla. Un clic la trae delante (y se cierra la vista). Arrastrar una tarjeta a un escritorio de la
//    columna la lleva allí.
//  - Esc, Meta+W otra vez o un clic en un hueco: se cierra.
Item {
    id: root
    property bool on: false
    property rect area: Qt.rect(0, 0, 0, 0)
    property var arrastre: null                  // la ventana que estás arrastrando
    property int cambios: 0                       // (sube cuando cambian las ventanas: las listas se rehacen)

    readonly property var modos: ["Jugar", "Navegar", "Estudiar"]
    function modoDe(d) { return String(d && d.name || "").split(" ")[0] }
    function cuenta(w) { return w && w.normalWindow && !w.skipTaskbar && !w.deleted && w.caption !== "apogeo-vista" }
    // (el mismo escritorio: por su id, que es lo que no cambia)
    function mismo(a, b) { return !!a && !!b && (a === b || (a.id !== undefined && a.id === b.id) || (a.id === undefined && a.name === b.name)) }
    function en(w, d) { return w.onAllDesktops || w.desktops.some(x => mismo(x, d)) }
    function ventanasDe(d) { root.cambios; return Workspace.windows.filter(w => cuenta(w) && !w.minimized && en(w, d)) }
    function todasDe(d) { root.cambios; return Workspace.windows.filter(w => cuenta(w) && en(w, d)) }
    // Los escritorios de cada modo, en orden: [{modo, escritorios: [d]}]
    readonly property var filas: {
        root.cambios;
        return modos.map(m => ({ modo: m, escritorios: Workspace.desktops.filter(d => modoDe(d) === m) }))
                    .filter(f => f.escritorios.length > 0);
    }

    ShortcutHandler {
        name: "Apogeo vista"
        text: "Apogeo: tus modos, sus escritorios y tus ventanas"
        sequence: "Meta+W"
        onActivated: root.on ? root.cerrar() : root.abrir()
    }
    Connections {
        target: Workspace
        function onWindowAdded() { root.cambios++ }
        function onWindowRemoved() { root.cambios++ }
        function onCurrentDesktopChanged() { root.cambios++ }
        function onDesktopsChanged() { root.cambios++ }
    }

    function abrir() {
        area = Workspace.clientArea(KWin.FullScreenArea, Workspace.activeScreen, Workspace.currentDesktop);
        cambios++;
        on = true;
        vista.show();
        Qt.callLater(colocar);
    }
    function cerrar() {
        on = false;
        arrastre = null;
        vista.hide();
    }
    // KWin la pone a su manera: encima de todo, de toda la pantalla, sin borde y fuera de la barra y del cambiador
    function colocar() {
        const v = Workspace.windows.find(w => w.caption === "apogeo-vista");
        if (!v) return;
        v.noBorder = true;
        v.skipTaskbar = true; v.skipSwitcher = true; v.skipPager = true;
        v.keepAbove = true;
        v.onAllDesktops = true;
        v.frameGeometry = Qt.rect(area.x, area.y, area.width, area.height);
        Workspace.activeWindow = v;
    }
    function ir(d) {
        // (el de verdad: el de Workspace.desktops con ese id)
        const real = Workspace.desktops.find(x => mismo(x, d));
        if (real && !mismo(Workspace.currentDesktop, real)) Workspace.currentDesktop = real;
    }
    function traer(w) {
        cerrar();
        if (w.minimized) w.minimized = false;
        Workspace.activeWindow = w;
    }
    function llevar(w, d) {
        const real = Workspace.desktops.find(x => mismo(x, d));
        if (!w || !real) return;
        w.onAllDesktops = false;
        w.desktops = [real];
        cambios++;
    }

    PlasmaCore.Window {
        id: vista
        flags: Qt.FramelessWindowHint
        color: "transparent"
        x: root.area.x; y: root.area.y
        width: root.area.width; height: root.area.height
        title: "apogeo-vista"
        backgroundHints: PlasmaCore.Types.NoBackground
        visible: false

      mainItem: Item {
        id: lienzo
        width: vista.width; height: vista.height
        focus: true
        Keys.onEscapePressed: root.cerrar()
        opacity: root.on ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // El fondo: el grafito del modo, transparente
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.86)
            MouseArea { anchors.fill: parent; onClicked: root.cerrar() }
        }

        // ---------- La columna: tus modos y sus escritorios ----------
        Rectangle {
            id: columna
            x: 16; y: 16
            width: 236; height: parent.height - 32
            radius: Tema.r(20)
            color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.72)
            border.color: Tema.borde
            Flickable {
                anchors.fill: parent; anchors.margins: 14
                contentHeight: colModos.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: colModos
                    width: parent.width
                    spacing: 14
                    Repeater {
                        model: root.filas
                        delegate: Column {
                            id: fila
                            required property var modelData
                            readonly property color c: Tema.acentoDe(modelData.modo.toLowerCase())
                            width: colModos.width
                            spacing: 8
                            Row {
                                spacing: 7
                                Rectangle { width: 6; height: 6; radius: 3; color: fila.c; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: fila.modelData.modo.toUpperCase()
                                    color: fila.c
                                    font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.8 }
                                }
                            }
                            Repeater {
                                model: fila.modelData.escritorios
                                delegate: Item {
                                    id: esc
                                    required property var modelData
                                    readonly property bool actual: root.mismo(Workspace.currentDesktop, modelData)
                                    readonly property var ventanas: root.ventanasDe(modelData)
                                    width: fila.width
                                    height: mini.height + 22
                                    // La miniatura: cada ventana en su sitio, en vivo
                                    Rectangle {
                                        id: mini
                                        width: parent.width
                                        height: Math.round(width * root.area.height / Math.max(1, root.area.width))
                                        radius: Tema.r(12)
                                        color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.6)
                                        border.width: esc.actual || suelo.containsDrag ? 2 : 1
                                        border.color: esc.actual || suelo.containsDrag ? fila.c : Tema.borde
                                        clip: true
                                        Repeater {
                                            model: esc.ventanas
                                            delegate: WindowThumbnail {
                                                required property var modelData
                                                readonly property real k: mini.width / Math.max(1, root.area.width)
                                                x: (modelData.frameGeometry.x - root.area.x) * k
                                                y: (modelData.frameGeometry.y - root.area.y) * k
                                                width: modelData.frameGeometry.width * k
                                                height: modelData.frameGeometry.height * k
                                                wId: modelData.internalId
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: esc.ventanas.length === 0
                                            text: "Vacío"
                                            color: Tema.tenue
                                            font { family: Tema.letra; pixelSize: 11 }
                                        }
                                        DropArea {
                                            id: suelo
                                            anchors.fill: parent
                                            onDropped: { root.llevar(root.arrastre, esc.modelData); root.arrastre = null; }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.ir(esc.modelData)
                                        }
                                    }
                                    Text {
                                        anchors.top: mini.bottom; anchors.topMargin: 4
                                        text: esc.modelData.name + (esc.ventanas.length ? "  ·  " + esc.ventanas.length : "")
                                        color: esc.actual ? Tema.texto : Tema.apagado
                                        font { family: Tema.letra; pixelSize: 12; weight: esc.actual ? Font.DemiBold : Font.Normal }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------- Las ventanas del escritorio en el que estás, como tarjetas ----------
        Item {
            id: centro
            x: columna.x + columna.width + 32
            y: 40
            width: parent.width - x - 40
            height: parent.height - 80
            readonly property var ventanas: root.todasDe(Workspace.currentDesktop)
            readonly property int n: ventanas.length
            readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(n * width / Math.max(1, height) * 0.62)))
            readonly property int rows: Math.max(1, Math.ceil(n / cols))
            readonly property real celdaW: (width - (cols - 1) * 28) / cols
            readonly property real celdaH: (height - (rows - 1) * 28) / rows

            Text {
                anchors.centerIn: parent
                visible: centro.n === 0
                text: "No hay ventanas en " + (Workspace.currentDesktop ? Workspace.currentDesktop.name : "este escritorio")
                color: Tema.apagado
                font { family: Tema.letra; pixelSize: 16 }
            }

            Repeater {
                model: centro.ventanas
                delegate: Item {
                    id: tarjeta
                    required property var modelData
                    required property int index
                    readonly property real prop: modelData.frameGeometry.width / Math.max(1, modelData.frameGeometry.height)
                    // El sitio en la rejilla (la tarjeta, en la proporción de la ventana, centrada en su celda)
                    readonly property real cx: (index % centro.cols) * (centro.celdaW + 28)
                    readonly property real cy: Math.floor(index / centro.cols) * (centro.celdaH + 28)
                    readonly property real tw: Math.min(centro.celdaW, (centro.celdaH - 44) * prop, 760)
                    readonly property real th: tw / prop
                    x: cx + (centro.celdaW - tw) / 2
                    y: cy + (centro.celdaH - th - 44) / 2
                    width: tw; height: th + 44
                    opacity: root.arrastre === modelData ? 0.35 : 1
                    scale: area.containsMouse && !root.arrastre ? 1.02 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    // La cabecera: su icono y su nombre en una pastilla, y la ✕ roja
                    Rectangle {
                        id: pastilla
                        height: 32
                        width: Math.min(tarjeta.width - 44, cab.implicitWidth + 24)
                        radius: 16
                        color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.85)
                        border.color: Tema.borde
                        Row {
                            id: cab
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            spacing: 8
                            Kirigami.Icon { width: 18; height: 18; source: tarjeta.modelData.icon; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                width: Math.min(implicitWidth, tarjeta.width - 110)
                                text: tarjeta.modelData.caption
                                color: Tema.texto
                                elide: Text.ElideRight
                                font { family: Tema.letra; pixelSize: 13 }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        width: 28; height: 28; radius: 14
                        color: cierra.containsMouse ? "#ff4d64" : "#e8475d"
                        Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 13; font.bold: true }
                        MouseArea {
                            id: cierra
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tarjeta.modelData.closeWindow()
                        }
                    }
                    // La ventana, en vivo
                    Rectangle {
                        id: marco
                        y: 44
                        width: tarjeta.width; height: tarjeta.th
                        radius: Tema.r(14)
                        color: "transparent"
                        border.width: Workspace.activeWindow === tarjeta.modelData || area.containsMouse ? 2 : 1
                        border.color: Workspace.activeWindow === tarjeta.modelData || area.containsMouse ? Tema.acento : Tema.borde
                        WindowThumbnail {
                            anchors.fill: parent; anchors.margins: 2
                            wId: tarjeta.modelData.internalId
                            opacity: tarjeta.modelData.minimized ? 0.5 : 1
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            drag.target: fantasma
                            drag.threshold: 12
                            onPressed: mouse => {
                                const p = marco.mapToItem(lienzo, mouse.x - fantasma.width / 2, mouse.y - fantasma.height / 2);
                                fantasma.x = p.x; fantasma.y = p.y;
                            }
                            drag.onActiveChanged: if (drag.active) root.arrastre = tarjeta.modelData
                            onReleased: {
                                if (!root.arrastre) return;
                                fantasma.Drag.drop();
                                root.arrastre = null;
                            }
                            onClicked: if (!root.arrastre) root.traer(tarjeta.modelData)
                        }
                    }
                }
            }
        }

        // Lo que arrastras (una ventana, hacia un escritorio de la columna)
        Rectangle {
            id: fantasma
            width: 160; height: 100
            radius: Tema.r(12)
            visible: !!root.arrastre
            color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.9)
            border.color: Tema.acento; border.width: 2
            Drag.active: !!root.arrastre
            Drag.hotSpot.x: width / 2; Drag.hotSpot.y: height / 2
            WindowThumbnail {
                anchors.fill: parent; anchors.margins: 4
                wId: root.arrastre ? root.arrastre.internalId : "{00000000-0000-0000-0000-000000000000}"
            }
        }

        Text {
            anchors.right: parent.right; anchors.rightMargin: 40
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
            text: "Clic: ir · arrastra una ventana a un escritorio · ✕ cerrarla · Esc o Meta+W: salir"
            color: Tema.tenue
            font { family: Tema.mono; pixelSize: 11 }
        }
      }
    }
}
