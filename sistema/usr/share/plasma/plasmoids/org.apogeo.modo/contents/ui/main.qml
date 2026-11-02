import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import Apogeo

// La barra fina de arriba de Órbita, a la izquierda (como en COSMIC): un punto del color del modo y «Escritorios» (la vista
// de Meta+W) y «Aplicaciones» (la Órbita). Antes: el modo en el que estás, en pequeño y en su
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

    // (Escritorios: el atajo «Apogeo vista» de KWin, Meta+W; Aplicaciones: la Órbita)
    function vista() {
        runner.connectSource("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/kwin "
                             + "org.kde.kglobalaccel.Component.invokeShortcut string:'Apogeo vista'");
    }
    function orbita() {
        runner.connectSource("dbus-send --session --type=method_call --dest=org.apogeo.Buscador /Buscador org.apogeo.Buscador.Toggle");
    }

    fullRepresentation: Item {
        // Jugar es solo la consola (a pantalla completa): aquí no se ve nada
        opacity: root.modo === "jugar" ? 0 : 1
        enabled: opacity > 0
        Layout.minimumWidth: linea.implicitWidth + 16
        Layout.preferredWidth: linea.implicitWidth + 16
        // Como en COSMIC: «Escritorios» y «Aplicaciones», sueltos sobre el fondo (el punto, del color del modo)
        Row {
            id: linea
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Rectangle { width: 6; height: 6; radius: 3; color: root.color; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: [{ t: "Escritorios", f: "vista" }, { t: "Aplicaciones", f: "orbita" }]
                delegate: Texto {
                    id: boton
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.t
                    color: raton.containsMouse ? Tema.texto : Qt.rgba(Tema.texto.r, Tema.texto.g, Tema.texto.b, 0.86)
                    wrapMode: Text.NoWrap
                    font { family: Tema.letra; pixelSize: 13; weight: Font.Medium }
                    MouseArea {
                        id: raton
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: boton.modelData.f === "vista" ? root.vista() : root.orbita()
                    }
                }
            }
        }
    }
}
