import QtQuick

// Una tarjeta de cristal con su título (como las secciones de «Personalizar» de Ágape)
Rectangle {
    id: s
    property string titulo
    property string intro
    default property alias filas: col.data
    implicitHeight: col.implicitHeight + 34
    radius: 18
    color: Tema.cristal
    border.color: Tema.borde
    Rectangle { x: s.radius; y: 1; width: s.width - 2 * s.radius; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
    Column {
        id: col
        x: 22; y: 20
        width: s.width - 44
        spacing: 0
        Texto { text: s.titulo; font.pixelSize: 17; font.weight: Font.ExtraBold; width: parent.width; bottomPadding: 4 }
        Texto { text: s.intro; visible: s.intro !== ""; color: Tema.apagado; width: parent.width; bottomPadding: 6 }
    }
}
