import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import Apogeo

// Columna de pisos, como la pastilla de pestañas de Ágape: un botón por piso con su icono de línea; el piso en el que
// estás es la pastilla rosa con su brillo. La rueda del ratón sube o baja de piso y un clic va directo. El cambio lo
// hace apogeo-pisos (que también pone el fondo, los avisos y la energía de cada piso).
// Cada piso enseña cuántas ventanas tiene y, al pasar el ratón, una vista del piso (sus ventanas en su sitio, con el
// icono de cada app). Una ventana soltada encima de un piso se va a ese piso (lo hace el script de KWin apogeo-ventanas).
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    // Colores de Ágape (tema Berenjena oscuro)
    readonly property color accent: Tema.rosa
    readonly property color accentText: Tema.sobreRosa
    readonly property color text: Tema.texto
    readonly property color muted: Tema.apagado
    readonly property color hover: Tema.encima

    readonly property var icons: ({ "Jugar": "jugar", "Navegar": "navegar", "Estudiar": "estudiar" })
    property double lastWheel: 0

    TaskManager.VirtualDesktopInfo { id: desktops }
    Datos { id: datos }
    // Tus ventanas con su sitio en la pantalla (las cuenta KWin): se piden al pasar el ratón por un piso
    property var windows: []
    function loadWindows() { datos.pedir("Ventanas", [], d => { if (Array.isArray(d)) root.windows = d; }) }
    readonly property var tints: ({ "Jugar": Tema.wp[1], "Navegar": Tema.wp[0], "Estudiar": Qt.tint(Tema.wp[0], Qt.rgba(0.5, 0.5, 0.5, 0.3)) })

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

                    // Cuántas ventanas hay en este piso
                    TaskManager.TasksModel {
                        id: floorTasks
                        filterByVirtualDesktop: true
                        virtualDesktop: floor.modelData
                        groupMode: TaskManager.TasksModel.GroupDisabled
                    }

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
                        radius: Tema.r(14)
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

                    Rectangle { // el número de ventanas del piso
                        visible: floorTasks.count > 0
                        x: parent.width - width + 4; y: -4
                        width: Math.max(16, count.implicitWidth + 8); height: 16; radius: Tema.r(8)
                        color: floor.current ? root.accentText : root.accent
                        border.width: 2
                        border.color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.9)
                        Text {
                            id: count
                            anchors.centerIn: parent
                            text: floorTasks.count > 9 ? "9+" : floorTasks.count
                            color: floor.current ? root.accent : root.accentText
                            font { family: "Bricolage Grotesque"; pixelSize: 9; weight: Font.Black }
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.go(floor.index)
                        onContainsMouseChanged: if (containsMouse) root.loadWindows()
                    }
                    // La vista del piso: sus ventanas en su sitio, con el icono de cada app
                    PlasmaCore.ToolTipArea {
                        anchors.fill: parent
                        location: Tema.posicion === "abajo-izq" ? PlasmaCore.Types.RightEdge : PlasmaCore.Types.LeftEdge
                        mainItem: Item {
                            width: 248
                            height: 182
                            readonly property var here: root.windows.filter(w => !w.min && (w.pisos.indexOf("*") >= 0 || w.pisos.indexOf(floor.name) >= 0))
                            Row {
                                x: 4; y: 2
                                spacing: 8
                                Kirigami.Icon {
                                    width: 16; height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: Qt.resolvedUrl("../icons/" + (root.icons[floor.name] || "navegar") + ".svg")
                                    isMask: true
                                    color: root.text
                                }
                                Text { text: floor.name; color: root.text; font { family: "Bricolage Grotesque"; pixelSize: 15; weight: Font.Bold } }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: floorTasks.count === 0 ? "vacío" : floorTasks.count === 1 ? "1 ventana" : floorTasks.count + " ventanas"
                                    color: root.muted
                                    font { family: "Bricolage Grotesque"; pixelSize: 12 }
                                }
                            }
                            Rectangle { // la pantalla en pequeño, con el tono de su fondo
                                id: mini
                                x: 4; y: 28
                                width: 240; height: 135
                                radius: Tema.r(10)
                                clip: true
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.lighter(root.tints[floor.name] || "#4a2c4f", 1.25) }
                                    GradientStop { position: 1; color: Tema.fondo }
                                }
                                border.color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.1)
                                Repeater {
                                    model: parent.parent.here
                                    delegate: Rectangle {
                                        required property var modelData
                                        x: Math.max(0, modelData.x) * mini.width
                                        y: Math.max(0, modelData.y) * mini.height
                                        width: Math.max(18, Math.min(1, modelData.w) * mini.width)
                                        height: Math.max(14, Math.min(1, modelData.h) * mini.height)
                                        radius: 5
                                        color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.94)
                                        border.color: modelData.activa ? root.accent : Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.14)
                                        Kirigami.Icon {
                                            anchors.centerIn: parent
                                            width: Math.min(22, parent.height - 4); height: width
                                            source: modelData.app || (modelData.clase || "").toLowerCase() || "application-x-executable"
                                            fallback: "application-x-executable"
                                        }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.parent.here.length === 0
                                    text: "Sin ventanas"
                                    color: root.muted
                                    font { family: "Bricolage Grotesque"; pixelSize: 12 }
                                }
                            }
                            Text {
                                x: 4; y: 167
                                text: floor.current ? "Estás aquí" : "Clic para ir · suelta una ventana aquí para llevarla"
                                color: root.muted
                                font { family: "Bricolage Grotesque"; pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }
    }
}
