import QtQuick
import QtQuick.Controls

TextField {
    id: f
    implicitWidth: 360
    implicitHeight: 44
    color: Tema.texto
    placeholderTextColor: Tema.tenue
    selectionColor: Tema.rosa
    selectedTextColor: Tema.sobreRosa
    font.family: Tema.letra
    font.pixelSize: 15
    leftPadding: 14
    rightPadding: 14
    background: Rectangle {
        radius: 12
        color: Tema.encima
        border.width: 1
        border.color: f.activeFocus ? Tema.rosa : Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.12)
        Rectangle { // el anillo de foco de Ágape
            anchors.fill: parent
            anchors.margins: -3
            radius: 15
            color: "transparent"
            border.width: 3
            border.color: Tema.rosaSuave
            visible: f.activeFocus
        }
    }
}
