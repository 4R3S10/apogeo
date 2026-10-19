import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.volume as PulseAudio
import Apogeo

// Panel rápido de Apogeo, al final de la isla («I1 · Una sola isla»): en la isla se ve la red, el sonido, los avisos
// sin leer y la hora; al pulsar se abre el panel: la hora y el día, lo de todos los días en mosaicos con la forma de
// Ágape (red, bluetooth, fondo animado, no molestar, ahorro de energía del piso, luz nocturna), el volumen y el brillo,
// tus avisos (los últimos, para abrirlos o quitarlos) y abajo tú, «Todos los ajustes» y apagar. Lo de los mosaicos lo
// lee y lo cambia «apogeo-ajustes rapido», solo mientras está abierto. (Sustituye al reloj y a la bandeja de KDE: en la
// bandeja solo quedan los iconos de tus apps.)
PlasmoidItem {
    id: root
    toolTipMainText: ""
    toolTipSubText: ""
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    // ---------- Lo que se ve en la isla: red, sonido, avisos y hora (en vivo, sin preguntar a nadie) ----------
    // Los avisos en pantalla, con el estilo de Apogeo (abajo a la derecha)
    Avisos {}

    // La red: lo que diga NetworkManager (cada 20 s; es muy rápido)
    property string netIcon: "wifi"
    readonly property string netCmd: "nmcli -t -f TYPE,STATE device"
    Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: runner.connectSource(root.netCmd) }
    readonly property var sink: PulseAudio.PreferredDevice.sink   // (el altavoz que se usa ahora)
    readonly property bool muted: !!sink && (sink.muted || sink.volume <= 0)
    NotificationManager.Notifications {
        id: notifs
        showExpired: true
        showDismissed: true
        showJobs: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        limit: 30
        lastRead: Plasmoid.configuration.leidos ? new Date(Plasmoid.configuration.leidos) : new Date(0)
    }
    property string clock: ""
    property string date: ""
    function tick() {
        const d = new Date();
        clock = Qt.formatTime(d, "HH:mm");
        const s = Qt.locale("es_ES").toString(d, "dddd d 'de' MMMM");
        date = s.charAt(0).toUpperCase() + s.slice(1);
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }

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
            } else if (source === root.netCmd) {
                const lines = String(data.stdout || "").split("\n");
                const up = t => lines.some(l => l.indexOf(t + ":connected") === 0);
                root.netIcon = up("wifi") ? "wifi" : up("ethernet") ? "cable" : "sinred";
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
    Component.onCompleted: refresh() // (una vez al empezar: al abrirlo ya está todo)
    // Solo mientras se ve: cerrado no gasta nada
    Timer { interval: 2500; repeat: true; running: root.expanded; triggeredOnStart: true; onTriggered: root.refresh() }

    // En la isla: red · sonido · avisos (con los que no has visto) · la hora, en una sola pastilla
    compactRepresentation: Item {
        id: compact
        readonly property int unread: notifs.unreadNotificationsCount
        Layout.minimumWidth: chip.implicitWidth + 4
        Layout.preferredWidth: chip.implicitWidth + 4
        Layout.minimumHeight: 38
        implicitHeight: 38
        Rectangle {
            id: bg
            anchors.centerIn: parent
            width: chip.implicitWidth; height: 38
            radius: 13
            color: root.expanded ? Tema.pulsado : area.containsMouse ? Tema.encima : "transparent"
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        Row {
            id: chip
            anchors.centerIn: parent
            spacing: 11
            leftPadding: 11
            rightPadding: 12
            Icono { anchors.verticalCenter: parent.verticalCenter; nombre: root.netIcon; color: root.netIcon === "sinred" ? Tema.rosa : Tema.apagado }
            Icono { anchors.verticalCenter: parent.verticalCenter; nombre: root.muted ? "silencio" : "volumen"; color: Tema.apagado }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                Icono { anchors.fill: parent; nombre: "campana"; color: compact.unread > 0 ? Tema.texto : Tema.apagado }
                Rectangle { // los avisos sin leer
                    visible: compact.unread > 0
                    x: 8; y: -5
                    width: Math.max(15, n.implicitWidth + 7); height: 15; radius: 7.5
                    color: Tema.rosa
                    Texto { id: n; anchors.centerIn: parent; text: compact.unread > 9 ? "9+" : compact.unread; font.pixelSize: 9; font.weight: Font.Black; color: Tema.sobreRosa }
                }
            }
            Texto { anchors.verticalCenter: parent.verticalCenter; text: root.clock; font.pixelSize: 15; font.weight: Font.Bold }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }
    // Al abrir el panel, los avisos cuentan como vistos
    onExpandedChanged: if (expanded) Plasmoid.configuration.leidos = new Date().toISOString()
    function ago(d) {
        const s = Math.max(0, (Date.now() - d.getTime()) / 1000);
        if (s < 60) return "ahora";
        if (s < 3600) return Math.floor(s / 60) + " min";
        if (s < 86400) return Math.floor(s / 3600) + " h";
        return Math.floor(s / 86400) + " d";
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
        implicitWidth: 404
        implicitHeight: col.implicitHeight + 24
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Column {
            id: col
            x: 12; y: 12
            width: 380
            spacing: 8
            // La hora y el día
            Row {
                spacing: 12
                bottomPadding: 4
                Texto { text: root.clock; font.pixelSize: 34; font.weight: Font.Black; anchors.baseline: dia.baseline }
                Texto { id: dia; text: root.date; color: Tema.apagado; font.pixelSize: 14 }
            }
            Grid {
                columns: 2
                spacing: 8
                Tile {
                    text: "Red"
                    icono: root.netIcon
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
            Level { // (siempre está, aunque la pantalla no deje cambiar el brillo: así el panel no cambia de tamaño)
                enabled: (root.st.brillo !== undefined ? root.st.brillo : -1) >= 0
                opacity: enabled ? 1 : 0.45
                icono: "sol"
                value: Math.max(0, root.st.brillo || 0)
                onElegido: v => root.act("brillo", v)
            }
            // Tus avisos: los últimos, para abrirlos (clic) o quitarlos (✕)
            Rectangle {
                width: parent.width
                height: avisos.implicitHeight + 16
                radius: 16
                color: Tema.encima
                Column {
                    id: avisos
                    x: 12; y: 8
                    width: parent.width - 24
                    spacing: 2
                    Item {
                        width: parent.width
                        height: 26
                        Texto { anchors.verticalCenter: parent.verticalCenter; text: "Avisos"; font.weight: Font.Bold }
                        AbstractButton {
                            id: clearAll
                            visible: notifs.count > 0
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: clearText.implicitWidth + 16; height: 24
                            hoverEnabled: true
                            onClicked: notifs.clear(NotificationManager.Notifications.ClearExpired)
                            background: Rectangle { radius: 8; color: clearAll.hovered ? Tema.pulsado : "transparent" }
                            contentItem: Texto { id: clearText; text: "Borrar todo"; font.pixelSize: 12; color: Tema.apagado; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                    Texto {
                        visible: notifs.count === 0
                        text: "Nada nuevo"
                        color: Tema.apagado
                        font.pixelSize: 13
                        bottomPadding: 4
                    }
                    Repeater {
                        model: notifs
                        delegate: AbstractButton {
                            id: nd
                            required property var model
                            required property int index
                            visible: index < 4
                            width: avisos.width
                            height: visible ? 50 : 0
                            hoverEnabled: true
                            onClicked: { notifs.invokeDefaultAction(notifs.index(index, 0)); root.expanded = false; }
                            background: Rectangle { radius: 12; color: nd.hovered ? Tema.pulsado : "transparent" }
                            contentItem: Item {
                                Kirigami.Icon {
                                    id: appIcon
                                    x: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26; height: 26
                                    source: nd.model.applicationIconName || nd.model.iconName || "apogeo"
                                }
                                Column {
                                    x: appIcon.x + appIcon.width + 10
                                    width: parent.width - x - 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    Texto { width: parent.width; elide: Text.ElideRight; wrapMode: Text.NoWrap; font.weight: Font.Bold; font.pixelSize: 13; text: nd.model.summary || nd.model.applicationName || "" }
                                    Texto { width: parent.width; elide: Text.ElideRight; wrapMode: Text.NoWrap; color: Tema.apagado; font.pixelSize: 12; textFormat: Text.PlainText
                                            text: (nd.model.applicationName ? nd.model.applicationName + " · " : "") + root.ago(nd.model.created || new Date()) + (nd.model.body ? " · " + String(nd.model.body).replace(/<[^>]*>/g, "") : "") }
                                }
                                AbstractButton {
                                    id: close
                                    anchors.right: parent.right
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26; height: 26
                                    visible: nd.hovered
                                    hoverEnabled: true
                                    onClicked: notifs.close(notifs.index(nd.index, 0))
                                    background: Rectangle { radius: 8; color: close.hovered ? Tema.pulsado : "transparent" }
                                    contentItem: Item { Icono { anchors.centerIn: parent; width: 12; height: 12; nombre: "cerrar"; color: Tema.apagado } }
                                }
                            }
                        }
                    }
                }
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
