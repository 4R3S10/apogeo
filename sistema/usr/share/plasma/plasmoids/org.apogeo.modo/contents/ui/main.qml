import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import Apogeo

// La barra fina de arriba de Órbita («C · Orbe central»), a la izquierda: el modo en el que estás, en pequeño y en su
// color. Lo sabe al momento por el escritorio virtual en el que estás (como el escritorio de Apogeo; modo.json, que
// Tema lee cada segundo, llegaba tarde al cambiar). Un clic abre la Órbita (como el orbe o Meta).
// Al lado, si en este modo tienes más de un escritorio abierto (apogeo-escritorios: Ctrl+Alt+← →), un punto por cada uno,
// el tuyo encendido; un clic en un punto te lleva a él.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    TaskManager.VirtualDesktopInfo { id: desktops }
    // La rejilla de escritorios: una fila por modo, una columna por escritorio («Navegar», «Navegar 2»…)
    readonly property int indice: desktops.desktopIds.indexOf(desktops.currentDesktop)
    readonly property int columnas: Math.max(1, Math.ceil(desktops.desktopIds.length / 3))
    readonly property int fila: indice >= 0 ? Math.floor(indice / columnas) : -1
    readonly property int columna: indice >= 0 ? indice % columnas : 0
    readonly property string escritorio: String(desktops.desktopNames[indice] || "").split(" ")[0].toLowerCase()
    readonly property string modo: ["jugar", "navegar", "estudiar"].indexOf(escritorio) >= 0 ? escritorio : Tema.modo || "navegar"
    readonly property color color: Tema.acentoDe(modo)

    P5Support.DataSource { id: runner; engine: "executable"; onNewData: source => disconnectSource(source) }
    function irA(id) {
        if (!id || id === desktops.currentDesktop) return;
        runner.connectSource("dbus-send --session --type=method_call --dest=org.kde.KWin /VirtualDesktopManager "
                             + "org.freedesktop.DBus.Properties.Set string:org.kde.KWin.VirtualDesktopManager string:current "
                             + "variant:string:" + id);
    }

    fullRepresentation: Item {
        // Jugar es solo la consola (a pantalla completa): aquí no se ve nada
        opacity: root.modo === "jugar" ? 0 : 1
        enabled: opacity > 0
        Layout.minimumWidth: linea.implicitWidth + 16
        Layout.preferredWidth: linea.implicitWidth + 16
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: runner.connectSource("dbus-send --session --type=method_call --dest=org.apogeo.Buscador /Buscador org.apogeo.Buscador.Toggle")
        }
        Row {
            id: linea
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Rectangle { width: 6; height: 6; radius: 3; color: root.color; anchors.verticalCenter: parent.verticalCenter }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: ({ jugar: "Jugar", navegar: "Navegar", estudiar: "Estudiar" })[root.modo] || ""
                color: root.color
                wrapMode: Text.NoWrap
                font { family: Tema.mono; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 2.2; capitalization: Font.AllUppercase }
            }
            // Los escritorios de este modo
            Row {
                id: puntos
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 4
                spacing: 2
                readonly property int abiertos: {
                    let n = 0;
                    for (let i = 0; i < escritorios.count; i++) { const p = escritorios.itemAt(i); if (p && p.abierto) n++; }
                    return n;
                }
                visible: root.fila > 0 && abiertos > 1
                Repeater {
                    id: escritorios
                    model: root.fila > 0 ? root.columnas : 0
                    delegate: Item {
                        id: punto
                        required property int index
                        readonly property string id_: desktops.desktopIds[root.fila * root.columnas + index] || ""
                        readonly property bool actual: index === root.columna
                        // Abierto: el primero, en el que estás o con ventanas (las que van en todos no cuentan)
                        readonly property int propias: {
                            let n = 0;
                            for (let i = 0; i < cuenta.count; i++) { const v = cuenta.itemAt(i); if (v && v.propia) n++; }
                            return n;
                        }
                        readonly property bool abierto: id_ !== "" && (index === 0 || actual || propias > 0)
                        visible: abierto
                        width: 14; height: 18
                        TaskManager.TasksModel {
                            id: tareas
                            filterByVirtualDesktop: true
                            virtualDesktop: punto.id_
                            groupMode: TaskManager.TasksModel.GroupDisabled
                        }
                        Repeater {
                            id: cuenta
                            model: tareas
                            delegate: Item { readonly property bool propia: !model.IsOnAllVirtualDesktops }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: punto.actual ? 7 : 6; height: width; radius: width / 2
                            color: punto.actual ? root.color : "transparent"
                            border.width: punto.actual ? 0 : 1.2
                            border.color: Qt.rgba(root.color.r, root.color.g, root.color.b, raton.containsMouse ? 0.95 : 0.55)
                            scale: raton.containsMouse && !punto.actual ? 1.25 : 1
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                        MouseArea {
                            id: raton
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.irA(punto.id_)
                        }
                    }
                }
            }
        }
    }
}
