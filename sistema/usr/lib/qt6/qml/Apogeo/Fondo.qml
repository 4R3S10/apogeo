import QtQuick
import QtQuick.Effects

// Un fondo animado de Ágape (el mismo sombreador que el escritorio), a un tercio de resolución. «radio» redondea.
Item {
    id: f
    property int tipo: 0            // 0 Tinta, 1 Humo, 2 Seda, 3 Mármol, 4 Relieve, 5 Remolino, 6 Dunas
    property real radio: 0
    ShaderEffect {
        id: fx
        width: Math.max(2, Math.round(f.width / 3))
        height: Math.max(2, Math.round(f.height / 3))
        visible: false
        property real t: Tema.tiempo
        property real kind: f.tipo
        property real light: 0
        property size res: Qt.size(f.width, f.height)
        property color base: "#120d14"
        property color c1: "#4a2c4f"
        property color c2: "#7a4458"
        property color c3: "#e0a9b4"
        fragmentShader: "file:///usr/share/plasma/wallpapers/org.apogeo.fondo/contents/shaders/fondo.frag.qsb"
    }
    ShaderEffectSource {
        id: src
        anchors.fill: parent
        sourceItem: fx
        textureSize: Qt.size(fx.width, fx.height)
        smooth: true
        visible: f.radio <= 0
    }
    Rectangle { id: mascara; anchors.fill: parent; radius: f.radio; visible: false; layer.enabled: true }
    MultiEffect { anchors.fill: parent; visible: f.radio > 0; source: src; maskEnabled: true; maskSource: mascara }
}
