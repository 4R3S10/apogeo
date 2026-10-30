import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import Apogeo

// La barra fina de arriba de Órbita («C · Orbe central»), a la izquierda: el modo en el que estás, en pequeño y en su
// color (lo dice apogeo-pisos en ~/.config/apogeo/modo.json: Tema lo lee). Un clic abre la Órbita (como el orbe o Meta).
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    readonly property string modo: Tema.modo || "navegar"
    readonly property color color: Tema.claro ? ({ jugar: "#6f52c9", navegar: "#0b86a8", estudiar: "#a85a00" })[modo] || Tema.acento
                                              : ({ jugar: "#b79cff", navegar: "#45d6ff", estudiar: "#ffb35c" })[modo] || Tema.acento

    P5Support.DataSource { id: runner; engine: "executable"; onNewData: source => disconnectSource(source) }

    fullRepresentation: Item {
        // Jugar es solo la consola (a pantalla completa): aquí no se ve nada
        opacity: root.modo === "jugar" ? 0 : 1
        enabled: opacity > 0
        Layout.minimumWidth: fila.implicitWidth + 16
        Layout.preferredWidth: fila.implicitWidth + 16
        Row {
            id: fila
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
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: runner.connectSource("dbus-send --session --type=method_call --dest=org.apogeo.Buscador /Buscador org.apogeo.Buscador.Toggle")
        }
    }
}
