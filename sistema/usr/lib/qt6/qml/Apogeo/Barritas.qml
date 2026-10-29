import QtQuick

// Las barritas que bailan mientras suena algo (la música del panel y de la isla). Es un baile, no el sonido de verdad:
// leerlo gastaría mucho. Paradas, se quedan bajitas.
Row {
    id: b
    property int cuantas: 12
    property bool sonando: false
    property color color: Tema.rosa
    property real grosor: 3
    spacing: grosor
    Repeater {
        model: b.cuantas
        delegate: Rectangle {
            id: barra
            required property int index
            readonly property real fase: (index * 0.37) % 1
            anchors.bottom: parent ? parent.bottom : undefined
            width: b.grosor
            radius: b.grosor / 2
            color: b.color
            height: b.height * 0.18
            SequentialAnimation on height {
                running: b.sonando && b.visible
                loops: Animation.Infinite
                alwaysRunToEnd: false
                PauseAnimation { duration: barra.fase * 300 }
                NumberAnimation { to: b.height * (0.45 + 0.55 * ((barra.index * 7) % 5) / 4); duration: 260 + barra.fase * 220; easing.type: Easing.InOutSine }
                NumberAnimation { to: b.height * (0.15 + 0.3 * barra.fase); duration: 300 + barra.fase * 180; easing.type: Easing.InOutSine }
                NumberAnimation { to: b.height * (0.35 + 0.4 * (1 - barra.fase)); duration: 240 + barra.fase * 200; easing.type: Easing.InOutSine }
                NumberAnimation { to: b.height * 0.18; duration: 280; easing.type: Easing.InOutSine }
            }
        }
    }
}
