import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import Apogeo

// Panel rápido de Apogeo (el botón del final de la isla): lo de todos los días en mosaicos con la forma de Ágape (red,
// bluetooth, fondo animado, no molestar, ahorro de energía del piso, luz nocturna), el volumen y el brillo, y abajo tú,
// «Todos los ajustes» y apagar. Lo lee y lo cambia «apogeo-ajustes rapido», solo mientras está abierto.
PlasmoidItem {
    id: root
    toolTipMainText: "Panel rápido"
    toolTipSubText: "Red, sonido, energía, no molestar y todos los ajustes"

    TaskManager.VirtualDesktopInfo { id: desktops }
    readonly property int floorIndex: Math.max(0, desktops.desktopIds.indexOf(desktops.currentDesktop))
    readonly property string floorKey: ["jugar", "navegar", "estudiar"][floorIndex] || "navegar"
    readonly property string floorName: desktops.desktopNames[floorIndex] || "Navegar"

    property var st: ({ red: {}, bt: {}, energia: {} })
    readonly property string tool: "/usr/lib/apogeo/apogeo-ajustes rapido"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.tool) {
                try { root.st = JSON.parse(data.stdout); } catch (e) {}
            }
            disconnectSource(source);
        }
    }
    function refresh() { runner.connectSource(tool) }
    function act(what, value) {
        runner.connectSource(tool + " " + what + (value !== undefined ? " " + value : ""));
        after.restart();
    }
    Timer { id: after; interval: 450; onTriggered: root.refresh() }
    // Solo mientras se ve: cerrado no gasta nada
    Timer { interval: 2500; repeat: true; running: root.expanded; triggeredOnStart: true; onTriggered: root.refresh() }

    compactRepresentation: Item {
        id: compact
        Layout.minimumWidth: 34
        Layout.minimumHeight: 34
        implicitWidth: 34
        implicitHeight: 34
        Rectangle {
            anchors.centerIn: parent
            width: 34; height: 34
            radius: 12
            color: root.expanded ? Tema.pulsado : area.containsMouse ? Tema.encima : "transparent"
            Behavior on color { ColorAnimation { duration: 180 } }
            Icono { anchors.centerIn: parent; nombre: "ajustes"; color: root.expanded || area.containsMouse ? Tema.texto : Tema.apagado }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    component Tile: AbstractButton {
        id: t
        property string icono
        property string sub
        property bool on: false
        width: 186
        height: 58
        hoverEnabled: true
        opacity: enabled ? 1 : 0.5
        background: Rectangle {
            radius: 16
            color: t.hovered ? Tema.pulsado : Tema.encima
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Item {
            Item {
                id: badge
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 34
                RectangularShadow { anchors.fill: parent; visible: t.on; radius: 11; blur: 14; spread: -4; offset.y: 4; color: Tema.rosa }
                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: t.on ? Tema.rosa : Tema.pulsado
                    Behavior on color { ColorAnimation { duration: 180 } }
                    Icono { anchors.centerIn: parent; nombre: t.icono; color: t.on ? Tema.sobreRosa : Tema.texto }
                }
            }
            Column {
                x: badge.x + badge.width + 10
                width: parent.width - x - 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Texto { text: t.text; width: parent.width; elide: Text.ElideRight; wrapMode: Text.NoWrap; font.weight: Font.Bold }
                Texto { text: t.sub; width: parent.width; elide: Text.ElideRight; wrapMode: Text.NoWrap; color: Tema.apagado; font.pixelSize: 11 }
            }
        }
    }

    component Level: Rectangle {
        id: lv
        property string icono
        property int value: 0
        signal elegido(int value)
        width: 380
        height: 44
        radius: 16
        color: Tema.encima
        Icono { x: 14; anchors.verticalCenter: parent.verticalCenter; nombre: lv.icono; color: Tema.apagado }
        Deslizador {
            id: slider
            x: 40
            width: parent.width - 54
            anchors.verticalCenter: parent.verticalCenter
            from: 0; to: 100; stepSize: 1
            onMoved: throttle.restart()
            onPressedChanged: if (!pressed) lv.elegido(Math.round(value))
            Binding on value { value: lv.value; when: !slider.pressed }
        }
        Timer { id: throttle; interval: 150; onTriggered: lv.elegido(Math.round(slider.value)) }
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 404
        Layout.preferredHeight: col.implicitHeight + 24
        Layout.minimumWidth: 404
        Layout.minimumHeight: col.implicitHeight + 24
        Column {
            id: col
            x: 12; y: 12
            width: 380
            spacing: 8
            Grid {
                columns: 2
                spacing: 8
                Tile {
                    text: "Red"
                    icono: "wifi"
                    on: !!root.st.red.on
                    sub: root.st.red.texto || "…"
                    onClicked: { root.act("red"); root.expanded = false; }
                }
                Tile {
                    text: "Bluetooth"
                    icono: "bluetooth"
                    enabled: !!root.st.bt.hay
                    on: !!root.st.bt.on
                    sub: !root.st.bt.hay ? "Este equipo no tiene" : root.st.bt.on ? "Encendido" : "Apagado"
                    onClicked: root.act("bluetooth")
                }
                Tile {
                    text: "Fondo animado"
                    icono: "foto"
                    on: !!root.st.animar
                    sub: !root.st.grafica ? "Quieto: no hay gráfica" : root.st.animar ? "Se mueve" : "Quieto"
                    onClicked: root.act("animar")
                }
                Tile {
                    text: "No molestar"
                    icono: "silencio"
                    on: !!root.st.silencio
                    sub: root.st.silencio ? "Sin avisos en ningún piso" : "Avisos según el piso"
                    onClicked: root.act("silencio")
                }
                Tile {
                    text: "Ahorro"
                    icono: "energia"
                    on: root.st.energia[root.floorKey] === "power-saver"
                    sub: "Energía en " + root.floorName
                    onClicked: root.act("energia", root.floorKey)
                }
                Tile {
                    text: "Luz nocturna"
                    icono: "luna"
                    on: !!root.st.luz
                    sub: root.st.luz ? "Encendida" : "Apagada"
                    onClicked: root.act("luz")
                }
            }
            Level {
                icono: "volumen"
                value: root.st.volumen || 0
                onElegido: v => root.act("volumen", v)
            }
            Level {
                visible: (root.st.brillo !== undefined ? root.st.brillo : -1) >= 0
                icono: "sol"
                value: Math.max(0, root.st.brillo || 0)
                onElegido: v => root.act("brillo", v)
            }
            Item {
                width: parent.width
                height: 40
                Foto {
                    id: me
                    width: 32; height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    letra: (root.st.nombre || "").charAt(0).toUpperCase()
                    fuente: root.st.foto ? "file://" + root.st.foto : ""
                    elegida: true
                }
                Texto {
                    x: me.width + 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - buttons.width - 8
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    text: root.st.nombre || ""
                    font.weight: Font.Bold
                }
                Row {
                    id: buttons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Boton {
                        text: "Todos los ajustes"
                        icono: "ajustes"
                        onClicked: { runner.connectSource("gio launch /usr/share/applications/apogeo-ajustes.desktop"); root.expanded = false; }
                    }
                    Boton {
                        icono: "apagar"
                        onClicked: { root.expanded = false; root.act("apagar"); }
                        ToolTip.visible: hovered
                        ToolTip.text: "Apagar, reiniciar o cerrar sesión"
                    }
                }
            }
        }
    }
}
