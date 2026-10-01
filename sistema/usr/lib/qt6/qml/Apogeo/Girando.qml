import QtQuick

// Esperando (la rueda de Ágape)
Item {
    width: 22; height: 22
    Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 2.5; border.color: Tema.tenue }
    Rectangle {
        property real angulo: 0
        width: 7; height: 7; radius: 3.5
        color: Tema.rosa
        x: parent.width / 2 - 3.5 + 8 * Math.cos(angulo)
        y: parent.height / 2 - 3.5 + 8 * Math.sin(angulo)
        NumberAnimation on angulo { from: 0; to: 2 * Math.PI; duration: 800; loops: Animation.Infinite }
    }
}
