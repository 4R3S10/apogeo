import QtQuick
import QtQuick.Effects

// Tu foto en círculo. Con «fuente» es una imagen (la de tu cuenta); si no, una Cara.
Item {
    id: f
    property int tipo: 0
    property url foto: ""
    property string letra: ""
    property url fuente: ""
    property bool elegida: false   // borde fino (en una lista de opciones)
    property bool anillo: false    // borde grueso con brillo (la grande)
    Cara { id: cara; anchors.fill: parent; tipo: f.tipo; foto: f.foto; letra: f.letra; visible: false }
    Image { id: img; anchors.fill: parent; source: f.fuente; sourceSize: Qt.size(f.width * 2, f.height * 2); fillMode: Image.PreserveAspectCrop; visible: false; cache: false }
    Rectangle { id: mascara; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
    RectangularShadow {
        anchors.fill: parent
        visible: f.anillo
        radius: width / 2
        blur: 30; spread: -6; offset.y: 8
        color: Tema.rosa
    }
    MultiEffect { anchors.fill: parent; source: f.fuente.toString() !== "" ? img : cara; maskEnabled: true; maskSource: mascara }
    Rectangle {
        anchors.fill: parent
        anchors.margins: f.anillo ? -3 : -4
        radius: width / 2
        color: "transparent"
        border.width: f.anillo ? 3 : 2
        border.color: Tema.rosa
        visible: f.anillo || f.elegida
    }
}
