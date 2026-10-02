pragma Singleton
import QtQuick

// Los colores, la letra y las medidas de Ágape (tema Berenjena oscuro), para todo lo de Apogeo hecho en QML.
QtObject {
    readonly property color fondo: "#120d14"
    readonly property color superficie: "#1e1621"
    readonly property color cromo: "#211924"
    readonly property color texto: "#f1e6ea"
    readonly property color apagado: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.62)
    readonly property color tenue: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.38)
    readonly property color encima: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.07)
    readonly property color pulsado: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.13)
    readonly property color borde: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.1)
    readonly property color linea: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.08)
    readonly property color cristal: Qt.rgba(30 / 255, 22 / 255, 33 / 255, 0.74)
    readonly property color rosa: "#e0a9b4"
    readonly property color rosaSuave: Qt.rgba(224 / 255, 169 / 255, 180 / 255, 0.2)
    readonly property color sobreRosa: "#2a1c26"
    readonly property color aviso: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.14)
    readonly property string letra: "Bricolage Grotesque"
    readonly property var fondos: ["tinta", "humo", "seda", "marmol", "relieve", "remolino", "dunas", "luces"]
    readonly property var nombresFondos: ["Tinta", "Humo", "Seda", "Mármol", "Relieve", "Remolino", "Dunas", "Luces"]

    // El tiempo de los fondos animados (a 30 imágenes por segundo como mucho, como Ágape). Quien lo usa pone «animar».
    property bool animar: false
    property real tiempo: 40
    property Timer reloj: Timer {
        interval: 33
        repeat: true
        running: animar && GraphicsInfo.api !== GraphicsInfo.Software
        onTriggered: tiempo += 0.033
    }
}
