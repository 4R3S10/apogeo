import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.volume as PulseAudio
import Apogeo

// Al final de la isla («I1 · Una sola isla»): la red, el sonido, los avisos sin leer y la hora. Al pulsarla sale el panel
// rápido de la derecha (org.apogeo.derecho, por el atajo del script de KWin apogeo-bordes). Aquí también salen tus avisos
// urgentes en pantalla, con el estilo de Apogeo (Avisos.qml; los demás los enseña la isla dinámica). (Sustituye al reloj y a la bandeja de KDE: en la bandeja solo
// quedan los iconos de tus apps.)
PlasmoidItem {
    id: root
    preferredRepresentation: compactRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

    // ---------- Lo que se ve en la isla: red, sonido, avisos y hora (en vivo, sin preguntar a nadie) ----------
    // Los avisos urgentes en pantalla, con el estilo de Apogeo (abajo a la derecha)
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
    function tick() {
        const d = new Date();
        clock = Qt.formatTime(d, "HH:mm");
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.tick() }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.netCmd) {
                const lines = String(data.stdout || "").split("\n");
                const up = t => lines.some(l => l.indexOf(t + ":connected") === 0);
                root.netIcon = up("wifi") ? "wifi" : up("ethernet") ? "cable" : "sinred";
            }
            disconnectSource(source);
        }
    }
    // Abre (o cierra) el panel rápido de la derecha
    function panel() {
        runner.connectSource("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/kwin "
                             + "org.kde.kglobalaccel.Component.invokeShortcut string:apogeo-panel-derecho");
    }

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
            radius: Tema.r(13)
            color: area.containsMouse ? Tema.encima : "transparent"
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
                    width: Math.max(15, n.implicitWidth + 7); height: 15; radius: Tema.r(7.5)
                    color: Tema.rosa
                    Texto { id: n; anchors.centerIn: parent; text: compact.unread > 9 ? "9+" : compact.unread; font.pixelSize: 9; font.weight: Font.Black; color: Tema.sobreRosa }
                }
            }
            Texto { id: clockText; anchors.verticalCenter: parent.verticalCenter; text: root.clock; font.pixelSize: 15; font.weight: Font.Bold; color: Tema.texto }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.panel()
        }
    }
    fullRepresentation: Item {}
}
