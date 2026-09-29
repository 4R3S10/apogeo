import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami

// Columna de pisos: un círculo por piso (el actual, grande y con su color). La rueda del ratón sube o baja de piso
// y un clic va directo. El cambio lo hace apogeo-pisos, que también pone el fondo, los avisos y la energía de cada piso.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    readonly property var floors: ({
        "Jugar": { accent: "#ff8fc6", icon: "jugar" },
        "Navegar": { accent: "#e0a9b4", icon: "navegar" },
        "Estudiar": { accent: "#c9b8c9", icon: "estudiar" }
    })
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
        Layout.preferredWidth: Kirigami.Units.gridUnit * 2.2
        Layout.preferredHeight: column.implicitHeight + Kirigami.Units.largeSpacing * 2
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
            spacing: Kirigami.Units.largeSpacing

            Repeater {
                model: desktops.desktopIds
                delegate: Item {
                    id: floor
                    required property var modelData
                    required property int index
                    readonly property bool current: modelData === desktops.currentDesktop
                    readonly property string name: desktops.desktopNames[index] || ""
                    readonly property var info: root.floors[name] || { accent: "#e0a9b4", icon: "navegar" }
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 38
                    implicitHeight: 38

                    Rectangle {
                        anchors.centerIn: parent
                        width: floor.current ? 38 : (hover.containsMouse ? 30 : 26)
                        height: width
                        radius: width / 2
                        color: floor.current ? floor.info.accent : Qt.rgba(1, 1, 1, hover.containsMouse ? 0.2 : 0.1)
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(parent.width * 0.62)
                            height: width
                            source: Qt.resolvedUrl("../icons/" + floor.info.icon + ".svg")
                            isMask: true
                            color: floor.current ? "#2a1a22" : "#f1e6ea"
                        }
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
