import QtQuick
import QtQuick.Controls

// El interruptor de Ágape
AbstractButton {
    id: s
    checkable: true
    implicitWidth: 42
    implicitHeight: 24
    hoverEnabled: true
    background: Rectangle {
        radius: height / 2
        color: s.checked ? Tema.rosa : Qt.rgba(241 / 255, 230 / 255, 234 / 255, s.hovered ? 0.24 : 0.18)
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            x: s.checked ? parent.width - width - 3 : 3
            y: 3
            width: 18; height: 18; radius: 9
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Item {}
}
