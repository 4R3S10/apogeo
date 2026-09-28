import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

// La isla de Apogeo (abajo, se esconde sola). Siempre: el corazón (buscador). Además, según el piso:
//  - Jugar: temperatura, el límite de FPS y un botón para ver el escritorio.
//  - Navegar: tus ventanas del piso y la música que suena.
//  - Estudiar: temporizador de concentración (25 min estudio / 5 descanso), lo estudiado hoy y tus ventanas.
// La hora, el sonido, la red y los avisos son los widgets de Plasma que van a su lado en el mismo panel.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    readonly property int floorIndex: Math.max(0, desktops.desktopIds.indexOf(desktops.currentDesktop))
    readonly property string floor: desktops.desktopNames[floorIndex] || "Navegar"
    readonly property var accents: ({ "Jugar": "#ff8fc6", "Navegar": "#e0a9b4", "Estudiar": "#c9b8c9" })
    readonly property color accent: accents[floor] || "#e0a9b4"
    readonly property color ink: "#2a1a22"
    readonly property color chipBg: Qt.rgba(1, 1, 1, 0.07)

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.tempCmd) root.temp = parseInt(data.stdout) / 1000 || 0;
            disconnectSource(source);
        }
    }
    function run(cmd) { runner.connectSource(cmd) }

    // ---------- Temperatura (piso Jugar) ----------
    readonly property string tempCmd: "sh -c 'for d in /sys/class/hwmon/hwmon*; do case $(cat $d/name) in k10temp|zenpower|coretemp|amdgpu) cat $d/temp1_input;; esac; done 2>/dev/null | sort -n | tail -1'"
    property real temp: 0
    Timer {
        interval: 4000; repeat: true; triggeredOnStart: true
        running: root.floor === "Jugar"
        onTriggered: root.run(root.tempCmd)
    }

    // ---------- Temporizador de concentración (piso Estudiar) ----------
    property bool focusRunning: false
    property bool focusBreak: false
    property int focusLeft: 25 * 60
    function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
    function studied() {
        return Plasmoid.configuration.studyDate === today() ? Plasmoid.configuration.studySeconds : 0;
    }
    Timer {
        interval: 1000; repeat: true
        running: root.focusRunning
        onTriggered: {
            if (!root.focusBreak) {
                if (Plasmoid.configuration.studyDate !== root.today()) {
                    Plasmoid.configuration.studyDate = root.today();
                    Plasmoid.configuration.studySeconds = 0;
                }
                Plasmoid.configuration.studySeconds += 1;
            }
            if (--root.focusLeft <= 0) {
                // Fin de la fase: suena bajito (en Estudiar no hay avisos) y empieza la siguiente
                root.focusBreak = !root.focusBreak;
                root.focusLeft = (root.focusBreak ? 5 : 25) * 60;
                root.run("paplay /usr/share/sounds/apogeo/stereo/message-new-instant.oga");
            }
        }
    }
    function mmss(s) { return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
    function hm(s) { const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? h + " h " + m + " min" : m + " min" }

    // ---------- Música ----------
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer

    // ---------- Ventanas del piso ----------
    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: true
        virtualDesktop: desktops.currentDesktop
        filterByActivity: true
        activity: activities.currentActivity
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    component Chip: Rectangle {
        property alias text: label.text
        property color fg: "#f1e6ea"
        signal clicked()
        signal rightClicked()
        implicitWidth: label.implicitWidth + 24
        implicitHeight: 36
        radius: 11
        color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : root.chipBg
        Behavior on color { ColorAnimation { duration: 120 } }
        QQC2.Label {
            id: label
            anchors.centerIn: parent
            color: parent.fg
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? parent.rightClicked() : parent.clicked()
        }
    }

    component Separator: Rectangle {
        implicitWidth: 1
        implicitHeight: 22
        color: Qt.rgba(1, 1, 1, 0.1)
    }

    fullRepresentation: RowLayout {
        spacing: 6
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth

        // El corazón: abre el buscador (apps, archivos, calculadora, la web…)
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: root.accent
            Behavior on color { ColorAnimation { duration: 250 } }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 18; height: 18
                source: Qt.resolvedUrl("corazon.svg")
                isMask: true
                color: root.ink
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.run("qdbus org.kde.krunner /App org.kde.krunner.App.toggleDisplay")
            }
        }

        Separator {}

        // ----- Jugar -----
        Chip {
            visible: root.floor === "Jugar" && root.temp > 0
            text: "🌡 " + Math.round(root.temp) + " °C"
            fg: root.temp >= 80 ? "#ff8f9a" : "#f1e6ea"
        }
        Chip {
            visible: root.floor === "Jugar"
            text: "60 FPS máx."
        }
        Chip {
            visible: root.floor === "Jugar"
            text: "▣ Escritorio"
            onClicked: root.run("qdbus org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'")
        }

        // ----- Estudiar -----
        Chip {
            visible: root.floor === "Estudiar"
            color: root.focusRunning ? root.accent : root.chipBg
            fg: root.focusRunning ? "#1b161f" : "#f1e6ea"
            text: (root.focusRunning ? "⏸ " : "▶ ") + root.mmss(root.focusLeft) + " · " + (root.focusBreak ? "descanso" : "estudio")
            onClicked: root.focusRunning = !root.focusRunning
            onRightClicked: { root.focusRunning = false; root.focusBreak = false; root.focusLeft = 25 * 60; }
        }
        Chip {
            visible: root.floor === "Estudiar"
            text: "Hoy: " + root.hm(root.studied())
        }
        Separator { visible: root.floor === "Estudiar" && tasks.count > 0 }

        // ----- Ventanas del piso (Navegar y Estudiar) -----
        Repeater {
            model: root.floor === "Jugar" ? null : tasks
            delegate: Item {
                id: task
                required property var model
                required property int index
                Layout.preferredWidth: 36
                Layout.preferredHeight: 40
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 2
                    width: 36; height: 36; radius: 10
                    color: hoverTask.containsMouse || task.model.IsActive ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 26; height: 26
                        source: task.model.decoration
                    }
                }
                Rectangle { // la rayita de la ventana activa
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: task.model.IsActive ? 16 : 6
                    height: 3; radius: 2
                    color: root.accent
                    opacity: task.model.IsMinimized ? 0.35 : 1
                    Behavior on width { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: hoverTask
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        const idx = tasks.makeModelIndex(task.index);
                        if (mouse.button === Qt.MiddleButton) tasks.requestClose(idx);
                        else if (task.model.IsActive) tasks.requestToggleMinimized(idx);
                        else tasks.requestActivate(idx);
                    }
                }
                QQC2.ToolTip.visible: hoverTask.containsMouse
                QQC2.ToolTip.text: task.model.display || ""
                QQC2.ToolTip.delay: 500
            }
        }

        // ----- Música (Navegar) -----
        Separator { visible: music.visible }
        Rectangle {
            id: music
            visible: root.floor === "Navegar" && !!root.player && (root.player.track || "") !== ""
            Layout.preferredHeight: 36
            Layout.preferredWidth: musicRow.implicitWidth + 16
            radius: 11
            color: root.chipBg
            RowLayout {
                id: musicRow
                anchors.centerIn: parent
                spacing: 8
                Image {
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                    source: root.player ? root.player.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                QQC2.Label {
                    text: root.player ? root.player.track : ""
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.maximumWidth: 180
                }
                QQC2.Label {
                    text: root.player && root.player.playbackStatus === Mpris.PlaybackStatus.Playing ? "⏸" : "▶"
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.player.PlayPause() }
                }
                QQC2.Label {
                    text: "⏭"
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.player.Next() }
                }
            }
        }

        Separator {}
    }
}
