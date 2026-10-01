import QtQuick

// Una cara para tu foto: tu inicial, un icono o tu foto, sobre un degradado del tema (cuadrada; se recorta al mostrarla)
Rectangle {
    id: c
    property int tipo: 0       // 0 inicial, 1 corazón, 2 mando, 3 música, 4 tu foto
    property url foto: ""
    property string letra: ""
    readonly property var tonos: [["#e0a9b4", "#7a4458"], ["#8e2e66", "#4a2c4f"], ["#ff8fc6", "#7a4458"], ["#5b3445", "#2a1830"]]
    gradient: Gradient {
        GradientStop { position: 0; color: c.tonos[Math.min(c.tipo, 3)][0] }
        GradientStop { position: 1; color: c.tonos[Math.min(c.tipo, 3)][1] }
    }
    Texto {
        anchors.centerIn: parent
        visible: c.tipo === 0
        text: c.letra
        color: "#ffffff"
        font.pixelSize: Math.max(1, Math.round(c.height * 0.42))
        font.weight: Font.Black
    }
    Icono {
        anchors.centerIn: parent
        visible: c.tipo >= 1 && c.tipo <= 3
        width: c.height * 0.46; height: width
        nombre: ["", "navegar", "jugar", "musica"][Math.min(c.tipo, 3)]
        color: "#ffffff"
    }
    Image {
        anchors.fill: parent
        visible: c.tipo === 4
        source: c.tipo === 4 ? c.foto : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(512, 512)
        asynchronous: true
    }
}
