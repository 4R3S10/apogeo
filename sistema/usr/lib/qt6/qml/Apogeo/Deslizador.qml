import QtQuick
import QtQuick.Controls

// El deslizador de Ágape (el tirador rosa con borde claro y halo)
Slider {
    id: d
    implicitWidth: 220
    implicitHeight: 24
    background: Rectangle {
        x: d.leftPadding
        y: d.topPadding + d.availableHeight / 2 - height / 2
        width: d.availableWidth
        height: 4
        radius: 2
        color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.16)
        Rectangle { width: d.visualPosition * parent.width; height: parent.height; radius: 2; color: Tema.rosa }
    }
    handle: Rectangle {
        x: d.leftPadding + d.visualPosition * (d.availableWidth - width)
        y: d.topPadding + d.availableHeight / 2 - height / 2
        width: 16; height: 16; radius: 8
        color: Tema.rosa
        border.width: 3
        border.color: Tema.texto
        Rectangle { anchors.centerIn: parent; width: 24; height: 24; radius: 12; color: "transparent"; border.width: 4; border.color: Tema.rosaSuave; z: -1 }
    }
}
