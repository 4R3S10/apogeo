import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import Apogeo

// La isla de Apogeo (abajo, se esconde sola), con los botones y chips de Ágape. Siempre: el buscador (la pastilla rosa).
// Además, según el piso:
//  - Jugar: temperatura, el límite de FPS y un botón para ver el escritorio.
//  - Navegar: tus ventanas del piso y la música que suena.
//  - Estudiar: temporizador de concentración (25 min estudio / 5 descanso), lo estudiado hoy y tus ventanas.
// Lo de cada piso se puede quitar en Ajustes de Apogeo → Isla (apogeo-pisos lo escribe en la configuración de este widget).
// La hora, el sonido, la red y los avisos son los widgets de Plasma que van a su lado en el mismo panel.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    // Colores de Ágape (tema Berenjena oscuro)
    readonly property color accent: "#e0a9b4"
    readonly property color accentText: "#2a1c26"
    readonly property color accentSoft: Qt.rgba(224 / 255, 169 / 255, 180 / 255, 0.2)
    readonly property color text: "#f1e6ea"
    readonly property color muted: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.62)
    readonly property color hover: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.07)
    readonly property color press: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.13)
    readonly property color border: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.1)
    readonly property color warn: "#ff8f9a"
    readonly property string font: "Bricolage Grotesque"

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    readonly property int floorIndex: Math.max(0, desktops.desktopIds.indexOf(desktops.currentDesktop))
    readonly property string floor: desktops.desktopNames[floorIndex] || "Navegar"

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

    // ---------- Temporizador de concentración (piso Estudiar): el mismo que el del escritorio (apogeo-pisos) ----------
    Datos { id: datos }
    property var estudio: ({})
    readonly property bool focusRunning: !!estudio.corriendo
    readonly property bool focusBreak: !!estudio.fase && estudio.fase !== "estudio"
    readonly property int focusLeft: estudio.quedan !== undefined ? estudio.quedan : 25 * 60
    function studied() { return estudio.hoy || 0 }
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.floor === "Estudiar" && Plasmoid.configuration.extraEstudiar
        onTriggered: datos.pedir("Estudio", [], d => { if (d) root.estudio = d; })
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

    function icon(name) { return Qt.resolvedUrl("../icons/" + name + ".svg") }

    // Botón de Ágape (34 × 34, radio 12): sin fondo; al pasar el ratón, el fondo suave. «on» = la pastilla rosa con brillo
    component AgapeButton: Item {
        id: btn
        property string iconName
        property bool on: false
        property string tip
        signal clicked()
        implicitWidth: 34
        implicitHeight: 34
        RectangularShadow {
            anchors.fill: bg
            visible: btn.on
            offset.y: 4; blur: 18; spread: -4
            radius: bg.radius
            color: root.accent
            opacity: 0.85
        }
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: 12
            color: btn.on ? root.accent : (area.pressed ? root.press : area.containsMouse ? root.hover : "transparent")
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 17; height: 17
            source: root.icon(btn.iconName)
            isMask: true
            color: btn.on ? root.accentText : (area.containsMouse ? root.text : root.muted)
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
        QQC2.ToolTip.visible: tip !== "" && area.containsMouse
        QQC2.ToolTip.text: tip
        QQC2.ToolTip.delay: 500
    }

    // Chip de Ágape: icono + texto sobre el fondo suave; «on» = rosa
    component Chip: Item {
        id: chip
        property string iconName
        property alias text: label.text
        property color fg: root.text
        property bool on: false
        signal clicked()
        signal rightClicked()
        implicitWidth: row.implicitWidth + 22
        implicitHeight: 34
        RectangularShadow {
            anchors.fill: chipBg
            visible: chip.on
            offset.y: 4; blur: 18; spread: -4
            radius: chipBg.radius
            color: root.accent
            opacity: 0.85
        }
        Rectangle {
            id: chipBg
            anchors.fill: parent
            radius: 12
            color: chip.on ? root.accent : (chipArea.containsMouse ? root.press : root.hover)
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 7
            Kirigami.Icon {
                visible: chip.iconName !== ""
                Layout.preferredWidth: 15; Layout.preferredHeight: 15
                source: chip.iconName ? root.icon(chip.iconName) : ""
                isMask: true
                color: chip.on ? root.accentText : root.muted
            }
            QQC2.Label {
                id: label
                color: chip.on ? root.accentText : chip.fg
                font.family: root.font
                font.weight: chip.on ? Font.Bold : Font.DemiBold
                font.pixelSize: 13
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? chip.rightClicked() : chip.clicked()
        }
    }

    component Separator: Rectangle {
        implicitWidth: 1
        implicitHeight: 22
        color: root.border
        Layout.leftMargin: 3
        Layout.rightMargin: 3
    }

    fullRepresentation: RowLayout {
        spacing: 4
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth

        // El buscador (apps, archivos, calculadora, la web…): la pastilla rosa, como el botón principal de Ágape
        AgapeButton {
            iconName: "buscar"
            on: true
            tip: "Buscar"
            onClicked: root.run("dbus-send --session --type=method_call --dest=org.apogeo.Buscador /Buscador org.apogeo.Buscador.Toggle")
        }

        Separator {}

        // ----- Jugar -----
        Chip {
            visible: root.floor === "Jugar" && root.temp > 0 && Plasmoid.configuration.extraJugar
            iconName: "temperatura"
            text: Math.round(root.temp) + " °C"
            fg: root.temp >= Plasmoid.configuration.limite ? root.warn : root.text
        }
        Chip {
            visible: root.floor === "Jugar" && Plasmoid.configuration.extraJugar
            iconName: "fps"
            text: Plasmoid.configuration.fps + " FPS"
        }
        AgapeButton {
            visible: root.floor === "Jugar"
            iconName: "consola"
            tip: "Consola de juegos"
            onClicked: root.run("/usr/lib/apogeo/apogeo-juegos consola")
        }
        AgapeButton {
            visible: root.floor === "Jugar"
            iconName: "escritorio"
            tip: "Ver el escritorio"
            onClicked: root.run("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'string:Show Desktop'")
        }

        // ----- Estudiar -----
        Chip {
            visible: root.floor === "Estudiar" && Plasmoid.configuration.extraEstudiar
            iconName: root.focusRunning ? "pausa" : "reloj"
            on: root.focusRunning
            text: root.mmss(root.focusLeft) + " · " + (root.focusBreak ? "descanso" : "estudio")
            onClicked: datos.hacer("EstudioAccion", ["alternar", ""])
            onRightClicked: datos.hacer("EstudioAccion", ["reiniciar", ""])
        }
        Chip {
            visible: root.floor === "Estudiar" && Plasmoid.configuration.extraEstudiar
            iconName: "libro"
            text: "Hoy " + root.hm(root.studied())
        }
        Separator { visible: root.floor === "Estudiar" && tasks.count > 0 && Plasmoid.configuration.extraEstudiar }

        // ----- Ventanas del piso (Navegar y Estudiar) -----
        Repeater {
            model: root.floor === "Jugar" ? null : tasks
            delegate: Item {
                id: task
                required property var model
                required property int index
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: task.model.IsActive ? root.press : (hoverTask.containsMouse ? root.hover : "transparent")
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 22; height: 22
                    source: task.model.decoration
                    opacity: task.model.IsMinimized ? 0.5 : 1
                }
                Rectangle { // la rayita rosa de la ventana activa
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -3
                    width: task.model.IsActive ? 14 : 4
                    height: 3; radius: 2
                    color: root.accent
                    opacity: task.model.IsMinimized ? 0.35 : 1
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
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

        // ----- Música (Navegar): la del widget de música de Ágape -----
        Separator { visible: music.visible }
        Rectangle {
            id: music
            visible: root.floor === "Navegar" && Plasmoid.configuration.extraNavegar && !!root.player && (root.player.track || "") !== ""
            Layout.preferredHeight: 34
            Layout.preferredWidth: musicRow.implicitWidth + 12
            radius: 12
            color: root.hover
            RowLayout {
                id: musicRow
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24
                    radius: 7
                    clip: true
                    color: root.accentSoft
                    Image {
                        anchors.fill: parent
                        source: root.player ? root.player.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                QQC2.Label {
                    text: root.player ? root.player.track : ""
                    font.family: root.font
                    font.weight: Font.DemiBold
                    font.pixelSize: 13
                    color: root.text
                    elide: Text.ElideRight
                    Layout.maximumWidth: 170
                }
                AgapeButton {
                    implicitWidth: 28; implicitHeight: 28
                    iconName: root.player && root.player.playbackStatus === Mpris.PlaybackStatus.Playing ? "pausa" : "reproducir"
                    onClicked: root.player.PlayPause()
                }
                AgapeButton {
                    implicitWidth: 28; implicitHeight: 28
                    iconName: "siguiente"
                    onClicked: root.player.Next()
                }
            }
        }

        Separator {}
    }
}
