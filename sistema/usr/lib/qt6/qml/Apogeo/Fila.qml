import QtQuick

// Una fila de ajuste: el nombre (y una explicación) a la izquierda y el control a la derecha; «ancha», debajo
Item {
    id: fila
    property string titulo
    property string detalle
    property bool ancha: false
    property bool linea: true
    default property alias contenido: caja.data
    width: parent ? parent.width : 0
    implicitHeight: ancha ? textos.implicitHeight + caja.height + 30
                          : Math.max(54, textos.implicitHeight + 18, caja.height + 18)
    Rectangle { visible: fila.linea; width: parent.width; height: 1; color: Tema.linea }
    Column {
        id: textos
        width: fila.ancha ? fila.width : fila.width - caja.width - 18
        y: fila.ancha ? 12 : (fila.height - implicitHeight) / 2
        spacing: 2
        Texto { text: fila.titulo; width: parent.width }
        Texto { text: fila.detalle; visible: text !== ""; width: parent.width; color: Tema.apagado; font.pixelSize: 12 }
    }
    Item {
        id: caja
        width: fila.ancha ? fila.width : childrenRect.width
        height: childrenRect.height
        x: fila.ancha ? 0 : fila.width - width
        y: fila.ancha ? textos.y + textos.implicitHeight + 10 : (fila.height - height) / 2
    }
}
