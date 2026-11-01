import QtQuick
import QtQuick.Shapes
import Apogeo

// La marca de Apología: una A hecha de nodos y conexiones (una red neuronal). Arriba violeta, el travesaño azul y los
// pies del color del texto. «vivo» la hace latir (mientras piensa).
Item {
    id: m
    property bool vivo: false
    implicitWidth: 28
    implicitHeight: 28
    readonly property real k: width / 90
    readonly property var nodos: [[45, 13, 7, "#b59cff"], [31.5, 47, 6, "#8ab4ff"], [58.5, 47, 6, "#8ab4ff"],
                                  [18, 79, 6, ""], [72, 79, 6, ""]]
    readonly property var lados: [[0, 1], [1, 3], [0, 2], [2, 4], [1, 2], [1, 4], [2, 3]]

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Tema.tinte(0.7)
            strokeWidth: Math.max(1, 3 * m.k)
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathMultiline {
                paths: m.lados.map(l => [Qt.point(m.nodos[l[0]][0] * m.k, m.nodos[l[0]][1] * m.k),
                                         Qt.point(m.nodos[l[1]][0] * m.k, m.nodos[l[1]][1] * m.k)])
            }
        }
    }
    Repeater {
        model: m.nodos
        delegate: Rectangle {
            required property var modelData
            required property int index
            width: modelData[2] * 2 * m.k
            height: width
            radius: width / 2
            x: modelData[0] * m.k - width / 2
            y: modelData[1] * m.k - height / 2
            color: modelData[3] || Tema.texto
            SequentialAnimation on scale {
                running: m.vivo
                loops: Animation.Infinite
                alwaysRunToEnd: true
                PauseAnimation { duration: index * 120 }
                NumberAnimation { to: 1.35; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: 600 - index * 120 }
            }
        }
    }
}
