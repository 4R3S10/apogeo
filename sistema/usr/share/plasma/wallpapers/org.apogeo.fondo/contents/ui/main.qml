import QtQuick
import org.kde.plasma.plasmoid

// Fondo de Apogeo: los fondos animados de Ágape con sus colores (Berenjena). Se dibuja a un tercio de la resolución y
// como mucho a 30 imágenes por segundo (son suaves y así apenas gasta), como en Ágape. Cada piso pone su estilo.
WallpaperItem {
    id: root

    readonly property var styles: ["tinta", "humo", "seda", "marmol", "relieve", "remolino", "dunas"]
    readonly property int kind: Math.max(0, styles.indexOf(root.configuration.Estilo))
    // Sin gráfica (el dibujo lo haría el procesador) se queda quieto: primero la salud del equipo
    readonly property bool animate: root.configuration.Animar && GraphicsInfo.api !== GraphicsInfo.Software
    property real time: 40

    Rectangle { anchors.fill: parent; color: "#120d14" }

    ShaderEffect {
        id: fx
        width: Math.max(2, Math.round(root.width / 3))
        height: Math.max(2, Math.round(root.height / 3))
        property real t: root.time
        property real kind: root.kind
        property real light: 0
        property size res: Qt.size(root.width, root.height)
        property color base: "#120d14"
        property color c1: "#4a2c4f"
        property color c2: "#7a4458"
        property color c3: "#e0a9b4"
        fragmentShader: Qt.resolvedUrl("../shaders/fondo.frag.qsb")
    }
    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: fx
        textureSize: Qt.size(fx.width, fx.height)
        smooth: true
        live: true
        hideSource: true
    }

    // 30 imágenes por segundo como mucho (lo mismo que Ágape)
    Timer {
        interval: 33
        repeat: true
        running: root.animate && root.visible
        onTriggered: root.time += 0.033
    }
}
