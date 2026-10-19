pragma Singleton
import QtQuick
import QtCore

// Los colores, la letra y las medidas de Apogeo para todo lo hecho en QML. Lo de serie es Ágape (tema Berenjena
// oscuro); si cambias el aspecto (Ajustes → Aspecto), apogeo-pisos deja tus fichas en ~/.config/apogeo/aspecto.json y
// aquí se leen (y se vuelven a mirar cada pocos segundos: el cambio se ve solo, sin reiniciar nada).
QtObject {
    id: tema

    // ---------- Tus fichas (o las de serie) ----------
    property var f: ({})
    function c(k, d) { return f[k] !== undefined ? f[k] : d }
    readonly property bool claro: !!c("claro", false)
    readonly property color _texto: c("texto", "#f1e6ea")
    function tinte(a) { return Qt.rgba(_texto.r, _texto.g, _texto.b, a) }

    readonly property color fondo: c("fondo", "#120d14")
    readonly property color superficie: c("superficie", "#1e1621")
    readonly property color cromo: Qt.tint(superficie, tinte(0.03))
    readonly property color texto: _texto
    readonly property color apagado: tinte(0.62)
    readonly property color tenue: tinte(0.38)
    readonly property color encima: tinte(claro ? 0.06 : 0.07)
    readonly property color pulsado: tinte(claro ? 0.11 : 0.13)
    readonly property color borde: tinte(claro ? 0.12 : 0.1)
    readonly property color linea: tinte(0.08)
    readonly property color cristal: Qt.rgba(superficie.r, superficie.g, superficie.b, Math.min(0.97, c("cristal", 0.55) + 0.19))
    readonly property color rosa: c("acento", "#e0a9b4")
    readonly property color rosaSuave: Qt.rgba(rosa.r, rosa.g, rosa.b, 0.2)
    readonly property color sobreRosa: c("sobreAcento", "#2a1c26")
    readonly property color vivo: c("vivo", "#ff8fc6")
    readonly property color aviso: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.14)
    readonly property string letra: c("letra", "Bricolage Grotesque")
    // Los fondos animados: base y sus tres colores
    readonly property var wp: c("wp", ["#4a2c4f", "#7a4458", "#e0a9b4"])
    // Las esquinas (Rectas · Suaves · Redondas): r(16) es un radio de 16 con tus esquinas
    readonly property real radio: c("radio", 1)
    function r(n) { return Math.max(2, Math.round(n * radio)) }
    readonly property string posicion: c("posicion", "abajo-dcha")

    readonly property var fondos: ["tinta", "humo", "seda", "marmol", "relieve", "remolino", "dunas", "luces"]
    readonly property var nombresFondos: ["Tinta", "Humo", "Seda", "Mármol", "Relieve", "Remolino", "Dunas", "Luces"]

    // ---------- Leer tus fichas ----------
    readonly property url archivo: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/apogeo/aspecto.json"
    property string _ultimo: ""
    function leer() {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            const t = x.responseText || "";
            if (t === tema._ultimo) return;
            tema._ultimo = t;
            try { tema.f = t ? JSON.parse(t) : {}; } catch (e) { tema.f = {}; }
        };
        x.open("GET", archivo);
        try { x.send(); } catch (e) {}
    }
    Component.onCompleted: leer()
    property Timer vigila: Timer { interval: 3000; running: true; repeat: true; onTriggered: tema.leer() }

    // El tiempo de los fondos animados (a 30 imágenes por segundo como mucho, como Ágape). Quien lo usa pone «animar».
    property bool animar: false
    property real tiempo: 40
    property Timer reloj: Timer {
        interval: 33
        repeat: true
        running: tema.animar && GraphicsInfo.api !== GraphicsInfo.Software
        onTriggered: tema.tiempo += 0.033
    }
}
