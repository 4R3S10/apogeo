import QtQuick

// El núcleo de una neurona: 0 lleno, 1 anillo, 2 rombo, 3 doble (ayuda a reconocerlas)
Item {
    id: k
    property int tipo: 0
    property real tamano: 15
    property bool on: false
    property color tinta: "#e0a9b4"
    width: tamano; height: tamano
    Rectangle {
        anchors.centerIn: parent
        width: k.tipo === 2 ? k.tamano * 0.8 : k.tamano; height: width
        radius: k.tipo === 2 ? 2 : width / 2
        rotation: k.tipo === 2 ? 45 : 0
        color: k.on || k.tipo === 0 ? k.tinta : "#1e1621"
        border.color: k.tinta
        border.width: 1.6
    }
    Rectangle {
        visible: k.tipo === 3 || k.tipo === 1
        anchors.centerIn: parent
        width: k.tipo === 3 ? k.tamano * 0.45 : k.tamano * 0.25; height: width; radius: width / 2
        color: k.tinta
    }
}
