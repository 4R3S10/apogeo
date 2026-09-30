import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

// Columna de pisos, como la pastilla de pestañas de Ágape: un botón por piso con su icono de línea; el piso en el que
// estás es la pastilla rosa con su brillo. La rueda del ratón sube o baja de piso y un clic va directo. El cambio lo
// hace apogeo-pisos (que también pone el fondo, los avisos y la energía de cada piso).
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    // Colores de Ágape (tema Berenjena oscuro)
    readonly property color accent: "#e0a9b4"
    readonly property color accentText: "#2a1c26"
    readonly property color text: "#f1e6ea"
    readonly property color muted: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.62)
    readonly property color hover: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.07)

    readonly property var icons: ({ "Jugar": "jugar", "Navegar": "navegar", "Estudiar": "estudiar" })
    property double lastWheel: 0

    TaskManager.VirtualDesktopInfo { id: desktops }

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    function pisos(args) {
        runner.connectSource("/usr/lib/apogeo/apogeo-pisos " + args)
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 46
        Layout.preferredHeight: column.implicitHeight + 8
        Layout.minimumHeight: Layout.preferredHeight

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const now = Date.now();
                if (now - root.lastWheel < 350 || wheel.angleDelta.y === 0) return; // un piso por golpe de rueda
                root.lastWheel = now;
                root.pisos(wheel.angleDelta.y > 0 ? "subir" : "bajar");
            }
        }

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: desktops.desktopIds
                delegate: Item {
                    id: floor
                    required property var modelData
                    required property int index
                    readonly property bool current: modelData === desktops.currentDesktop
                    readonly property string name: desktops.desktopNames[index] || ""
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 38
                    implicitHeight: 38

                    // El brillo de la pastilla activa (0 4px 18px -4px el rosa)
                    RectangularShadow {
                        anchors.fill: pill
                        visible: floor.current
                        offset.y: 4
                        blur: 18
                        spread: -4
                        radius: pill.radius
                        color: root.accent
                        opacity: 0.85
                    }
                    Rectangle {
                        id: pill
                        anchors.fill: parent
                        radius: 12
                        color: floor.current ? root.accent : (hover.containsMouse ? root.hover : "transparent")
                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        source: Qt.resolvedUrl("../icons/" + (root.icons[floor.name] || "navegar") + ".svg")
                        isMask: true
                        color: floor.current ? root.accentText : (hover.containsMouse ? root.text : root.muted)
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.pisos("ir " + floor.index)
                    }
                    QQC2.ToolTip.visible: hover.containsMouse
                    QQC2.ToolTip.text: floor.name
                    QQC2.ToolTip.delay: 400
                }
            }
        }
    }
}
