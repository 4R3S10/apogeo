pragma Singleton
import QtQuick
import QtCore

// Los colores, la letra y las medidas de Apogeo —Órbita— para todo lo hecho en QML. La base es grafito; el acento y el
// carácter vienen del modo: Navegar (cian), Estudiar (ámbar y papel) y Jugar (violeta). Si cambias el aspecto
// (Ajustes → Identidad), apogeo-pisos deja tus fichas en ~/.config/apogeo/aspecto.json y aquí se leen (y se vuelven a
// mirar cada segundo: el cambio se ve solo, sin reiniciar nada).
// Con «Del fondo» cada piso tiene sus colores: las fichas son las del piso en el que estás y en «pisos» van las de los
// tres. Quien sabe en qué piso estás (el fondo de Plasma, o el modo de ~/.config/apogeo/modo.json) pone «piso».
QtObject {
    id: tema

    // ---------- Tus fichas (o las de Órbita) ----------
    property var f: ({})
    property string piso: ""
    readonly property var _p: piso !== "" && f.pisos && f.pisos[piso] ? f.pisos[piso] : null
    function c(k, d) { return _p && _p[k] !== undefined ? _p[k] : (f[k] !== undefined ? f[k] : d) }
    readonly property bool claro: !!c("claro", false)
    readonly property color _texto: c("texto", "#e9edf5")
    function tinte(a) { return Qt.rgba(_texto.r, _texto.g, _texto.b, a) }

    readonly property color fondo: c("fondo", "#080a0f")
    readonly property color superficie: c("superficie", "#0f131a")
    readonly property color elevada: c("elevada", Qt.lighter(superficie, 1.18))
    readonly property color cromo: Qt.tint(superficie, tinte(0.03))
    readonly property color texto: _texto
    readonly property color apagado: tinte(0.62)
    readonly property color tenue: tinte(0.38)
    readonly property color encima: tinte(claro ? 0.06 : 0.07)
    readonly property color pulsado: tinte(claro ? 0.11 : 0.13)
    readonly property color borde: tinte(claro ? 0.12 : 0.1)
    readonly property color linea: tinte(0.08)
    readonly property color cristal: Qt.rgba(superficie.r, superficie.g, superficie.b, Math.min(0.97, c("cristal", 0.55) + 0.19))

    // El acento del modo. «rosa» y «sobreRosa» se quedan como alias para no romper nada de lo que ya existe.
    readonly property color acento: c("acento", piso === "jugar" ? "#b79cff" :
                                      piso === "estudiar" ? "#ffb35c" : "#45d6ff")
    readonly property color rosa: acento
    readonly property color rosaSuave: Qt.rgba(acento.r, acento.g, acento.b, 0.16)
    readonly property color sobreAcento: c("sobreAcento", "#041318")
    readonly property color sobreRosa: sobreAcento
    readonly property color vivo: c("vivo", acento)
    // Lo encendido (los botones y las pastillas del panel rápido): en Órbita, blanco sobre el cristal grafito («W1»); con
    // otro estilo, su acento
    readonly property bool _orbita: !f.nombre || f.nombre === "Órbita"
    readonly property color encendido: c("encendido", _orbita ? "#eef0f4" : acento)
    readonly property color sobreEncendido: c("sobreEncendido", _orbita ? "#0b0e14" : sobreAcento)
    readonly property color exito: "#57e3b0"
    readonly property color error: "#ff6b81"
    readonly property color aviso: Qt.rgba(255 / 255, 200 / 255, 87 / 255, 0.14)

    readonly property string letra: c("letra", "Geist")
    readonly property string mono: c("mono", "Geist Mono")
    readonly property string serif: "Source Serif 4"   // (para leer y escribir apuntes)
    readonly property real letraPt: c("letraPt", 10)
    // Los fondos animados: base y sus tres colores (el tercero es el acento del modo)
    readonly property var wp: c("wp", ["#0b1118", piso === "jugar" ? "#2b2147" :
                                       piso === "estudiar" ? "#3a2a17" : "#12303d", acento])
    // Las esquinas (Rectas · Suaves · Redondas): r(16) es un radio de 16 con tus esquinas
    readonly property real radio: c("radio", 0.7)
    function r(n) { return Math.max(2, Math.round(n * radio)) }
    readonly property string posicion: c("posicion", "abajo-dcha")

    // ---------- El modo (la fuente de verdad que publica apogeo-pisos) ----------
    property string modo: ""
    readonly property url archivoModo: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/apogeo/modo.json"
    property string _ultimoModo: ""
    function leerModo() {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            const t = x.responseText || "";
            if (t === tema._ultimoModo) return;
            tema._ultimoModo = t;
            try {
                const m = t ? JSON.parse(t) : null;
                if (m && m.modo) {
                    tema.modo = m.modo;
                    if (tema.piso !== m.modo) tema.piso = m.modo;
                }
            } catch (e) {}
        };
        x.open("GET", archivoModo);
        try { x.send(); } catch (e) {}
    }

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

    readonly property var fondos: ["tinta", "humo", "seda", "marmol", "relieve", "remolino", "dunas", "luces", "orbitas", "nebulosa", "aurora"]
    readonly property var nombresFondos: ["Tinta", "Humo", "Seda", "Mármol", "Relieve", "Remolino", "Dunas", "Luces", "Órbitas", "Nebulosa", "Aurora"]

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
    Component.onCompleted: { leer(); leerModo(); }
    property Timer vigila: Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: { tema.leer(); tema.leerModo(); }
    }

    // El tiempo de los fondos animados (a 30 imágenes por segundo como mucho). Quien lo usa pone «animar».
    property bool animar: false
    property real tiempo: 40
    property Timer reloj: Timer {
        interval: 33
        repeat: true
        running: tema.animar && GraphicsInfo.api !== GraphicsInfo.Software
        onTriggered: tema.tiempo += 0.033
    }
}
