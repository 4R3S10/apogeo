pragma Singleton
import QtQuick
import QtCore

// Los colores, la letra y las medidas de Apogeo para todo lo hecho en QML. Lo de serie es Ágape (tema Berenjena
// oscuro); si cambias el aspecto (Ajustes → Aspecto), apogeo-pisos deja tus fichas en ~/.config/apogeo/aspecto.json y
// aquí se leen (y se vuelven a mirar cada segundo: el cambio se ve solo, sin reiniciar nada).
// Con «Del fondo» cada piso tiene sus colores: las fichas son las del piso en el que estás y en «pisos» van las de los
// tres. Quien sabe en qué piso estás (el fondo de Plasma) pone «piso» y así sus colores cambian al momento.
QtObject {
    id: tema

    // ---------- Tus fichas (o las de serie) ----------
    property var f: ({})
    property string piso: ""
    readonly property var _p: piso !== "" && f.pisos && f.pisos[piso] ? f.pisos[piso] : null
    function c(k, d) { return _p && _p[k] !== undefined ? _p[k] : (f[k] !== undefined ? f[k] : d) }
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

    // El color del cielo a esta hora (la tarjeta del tiempo): [arriba, abajo]. salida y puesta, «HH:MM» (del tiempo);
    // nublado o lluvia lo apagan.
    function colorCielo(ahora, salida, puesta, codigo) {
        const min = s => { const m = /^(\d\d):(\d\d)$/.exec(s || ""); return m ? +m[1] * 60 + +m[2] : -1; };
        const t = ahora.getHours() * 60 + ahora.getMinutes();
        const sa = min(salida) >= 0 ? min(salida) : 7 * 60 + 30, pu = min(puesta) >= 0 ? min(puesta) : 19 * 60 + 30;
        let c;
        if (t >= sa - 45 && t < sa + 60) c = ["#4b5aa6", "#f2a07f"];          // amanecer
        else if (t >= pu - 60 && t < pu + 30) c = ["#f39a5c", "#6a3f96"];     // atardecer
        else if (t >= sa + 60 && t < pu - 60) c = ["#3f8fd8", "#86c3ee"];     // de día
        else c = ["#0f1533", "#33265c"];                                       // de noche
        const gris = codigo >= 51 ? 0.55 : codigo === 3 || codigo === 45 || codigo === 48 ? 0.4 : 0;
        return gris ? c.map(x => Qt.tint(x, Qt.rgba(0.35, 0.38, 0.45, gris))) : c;
    }

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
    property Timer vigila: Timer { interval: 1000; running: true; repeat: true; onTriggered: tema.leer() }

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
