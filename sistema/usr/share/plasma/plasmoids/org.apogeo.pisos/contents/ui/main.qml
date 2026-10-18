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

    // Cambiar de piso: se le pide a KWin directamente (al momento y al piso exacto; antes se abría un programa por cada
    // cambio, con retraso, y con varios seguidos se colaba en otro)
    function go(index) {
        const ids = desktops.desktopIds;
        if (index < 0 || index >= ids.length || ids[index] === desktops.currentDesktop) return;
        runner.connectSource("dbus-send --session --type=method_call --dest=org.kde.KWin /VirtualDesktopManager "
                             + "org.freedesktop.DBus.Properties.Set string:org.kde.KWin.VirtualDesktopManager string:current "
                             + "variant:string:" + ids[index]);
    }
    readonly property int currentIndex: desktops.desktopIds.indexOf(desktops.currentDesktop)
    property real wheelSum: 0

    fullRepresentation: Item {
        Layout.preferredWidth: 48
        Layout.preferredHeight: column.implicitHeight + 12
        Layout.minimumHeight: Layout.preferredHeight

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                // Un piso por golpe de rueda: se suman los pasitos (ratones finos y touchpads) hasta un golpe entero, y
                // después de cambiar se espera a que acabe el deslizamiento
                const now = Date.now();
                if (now - root.lastWheel < 450) { root.wheelSum = 0; return; }
                root.wheelSum += wheel.angleDelta.y;
                if (Math.abs(root.wheelSum) < 120) return;
                root.lastWheel = now;
                root.go(root.currentIndex + (root.wheelSum > 0 ? -1 : 1));
                root.wheelSum = 0;
            }
        }

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: desktops.desktopIds
                delegate: Item {
                    id: floor
                    required property var modelData
                    required property int index
                    readonly property bool current: modelData === desktops.currentDesktop
                    readonly property string name: desktops.desktopNames[index] || ""
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 40
                    implicitHeight: 40

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
                        radius: 14
                        color: floor.current ? root.accent : (hover.containsMouse ? root.hover : "transparent")
                        Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: Qt.resolvedUrl("../icons/" + (root.icons[floor.name] || "navegar") + ".svg")
                        isMask: true
                        color: floor.current ? root.accentText : (hover.containsMouse ? root.text : root.muted)
                        Behavior on color { ColorAnimation { duration: 180 } }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.go(floor.index)
                    }
                    QQC2.ToolTip.visible: hover.containsMouse
                    QQC2.ToolTip.text: floor.name
                    QQC2.ToolTip.delay: 400
                }
            }
        }
    }
}
