import QtQuick
import QtQuick.Effects

// Un icono de línea de Ágape (iconos/*.svg, en blanco) pintado del color que se pida
Item {
    id: icono
    property string nombre
    property color color: Tema.texto
    width: 16; height: 16
    Image {
        id: img
        anchors.fill: parent
        source: icono.nombre ? Qt.resolvedUrl("iconos/" + icono.nombre + ".svg") : ""
        sourceSize: Qt.size(icono.width * 2, icono.height * 2)
        visible: false
    }
    // (la transparencia del color no la aplica el coloreado: va aparte)
    MultiEffect { anchors.fill: parent; source: img; colorization: 1; colorizationColor: icono.color; opacity: icono.color.a }
}
