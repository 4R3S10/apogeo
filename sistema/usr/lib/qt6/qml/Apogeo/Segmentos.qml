import QtQuick
import QtQuick.Effects

// El control segmentado de Ágape: opciones [{ texto, icono }], la elegida en la pastilla rosa con brillo
Rectangle {
    id: seg
    property var opciones: []
    property int actual: 0
    signal elegido(int indice)
    implicitWidth: fila.implicitWidth + 6
    implicitHeight: 36
    radius: 12
    color: Tema.encima
    Row {
        id: fila
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: seg.opciones
            delegate: Item {
                id: op
                required property var modelData
                required property int index
                readonly property bool on: index === seg.actual
                width: contenido.implicitWidth + 26
                height: 30
                RectangularShadow {
                    anchors.fill: parent
                    visible: op.on
                    offset.y: 4; blur: 14; spread: -4
                    radius: 9
                    color: Tema.rosa
                    opacity: 0.85
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: op.on ? Tema.rosa : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Row {
                    id: contenido
                    anchors.centerIn: parent
                    spacing: 7
                    Icono {
                        visible: !!op.modelData.icono
                        nombre: op.modelData.icono || ""
                        color: op.on ? Tema.sobreRosa : zona.containsMouse ? Tema.texto : Tema.apagado
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Texto {
                        text: op.modelData.texto
                        wrapMode: Text.NoWrap
                        color: op.on ? Tema.sobreRosa : zona.containsMouse ? Tema.texto : Tema.apagado
                        font.pixelSize: 13
                        font.weight: op.on ? Font.Bold : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: zona
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!op.on) seg.elegido(op.index)
                }
            }
        }
    }
}
