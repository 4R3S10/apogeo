import QtQuick
import QtQuick.Shapes
import "neuronas.js" as Dibujo

// Una neurona de «Entrar con neuronas» (para elegir las tuyas en Ajustes)
Item {
    id: n
    property int numero: 0
    property bool on: false
    property color tinta: on ? "#ff8fc6" : "#bfe0a9b4"
    implicitWidth: 60
    implicitHeight: 60
    Shape {
        x: n.width / 2; y: n.height / 2
        scale: n.width / 60
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: n.tinta
            strokeWidth: 1.7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: Dibujo.forma(n.numero) }
        }
    }
    Nucleo { anchors.centerIn: parent; tamano: n.width / 4; tipo: Dibujo.nucleo(n.numero); on: n.on; tinta: n.tinta }
}
