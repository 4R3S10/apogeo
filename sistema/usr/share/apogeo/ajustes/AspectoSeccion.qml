import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Apogeo

// Ajustes → Identidad: arriba, los estilos completos de un clic (Órbita es el de serie y viene puesto); en medio, cómo
// queda (en pequeño, al momento); debajo, cada detalle a mano. Todo se aplica solo en todo el sistema (lo hace
// apogeo-pisos con apogeo_aspecto) y «Volver a lo de serie» lo deja como venía. La identidad clásica (Berenjena, rosa,
// Bricolage) sigue disponible como «Clásico», y «Del fondo» toma los colores de la foto o el vídeo de cada piso.
Seccion {
    id: sec
    property string palabras: "identidad aspecto tema estilo color colores acento claro oscuro letra fuente tipografia geist bricolage esquinas redondas cristal transparencia tamaño animaciones isla posicion personalizar orbita clasico"
    titulo: "Identidad"
    intro: "La piel de todo Apogeo. De serie, Órbita: grafito, Geist y un acento por modo (cian al navegar, ámbar al estudiar, violeta al jugar)."

    readonly property var a: apogeo.settings.aspecto || ({})
    readonly property var t: apogeo.lookTokens(a)          // las fichas de cómo queda (las mismas que se aplican)
    readonly property var estilos: apogeo.lookStyles
    readonly property var orden: ["orbita", "fondo", "agape", "apogeo", "medianoche", "bosque", "arena", "papel"]
    readonly property bool sigueAgape: a.estilo === "agape"
    readonly property bool sigueFondo: a.estilo === "fondo"
    function put(k, v) { apogeo.set("aspecto." + k, v) }

    // ---------- Los estilos ----------
    Flow {
        width: parent.width
        spacing: 10
        bottomPadding: 6
        Repeater {
            model: sec.orden
            delegate: AbstractButton {
                id: card
                required property string modelData
                readonly property var e: sec.estilos[modelData] || ({})
                readonly property bool on: sec.a.estilo === modelData
                width: 118; height: 108
                hoverEnabled: true
                onClicked: {
                    sec.put("estilo", modelData);
                    sec.put("acento", "");
                    if (e.letra) sec.put("letra", e.letra);
                    if (modelData === "orbita") sec.put("modo", "piso");
                    else if (modelData !== "agape" && modelData !== "fondo" && sec.a.modo !== "hora")
                        sec.put("modo", e.claro ? "claro" : "oscuro");
                }
                background: Rectangle {
                    radius: Tema.r(16)
                    color: card.hovered ? Tema.encima : "transparent"
                    border.width: card.on ? 2 : 1
                    border.color: card.on ? Tema.rosa : Tema.borde
                }
                contentItem: Column {
                    padding: 8
                    spacing: 6
                    Rectangle { // en pequeño: su fondo, una ventana y la isla con su acento
                        width: card.width - 16; height: 64
                        radius: Tema.r(10)
                        gradient: Gradient {
                            GradientStop { position: 0; color: card.e.wp ? card.e.wp[1] : "#000" }
                            GradientStop { position: 1; color: card.e.fondo || "#000" }
                        }
                        Rectangle { x: 8; y: 8; width: 62; height: 34; radius: Tema.r(6); color: card.e.superficie || "#000"; opacity: 0.95 }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 5
                            width: 60; height: 12; radius: 6
                            color: card.e.superficie || "#000"
                            Rectangle { x: 3; y: 2; width: 8; height: 8; radius: 3; color: card.e.acento || "#fff" }
                        }
                    }
                    Row {
                        spacing: 6
                        Texto { text: card.e.nombre || ""; font.weight: Font.Bold; font.pixelSize: 13 }
                        Icono { visible: card.on; nombre: "hecho"; width: 14; height: 14; color: Tema.rosa; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }

    // ---------- Así queda ----------
    Rectangle {
        id: preview
        width: parent.width
        height: 200
        radius: Tema.r(16)
        clip: true
        readonly property bool arriba: sec.t.posicion === "arriba-dcha"
        readonly property real rr: sec.t.radio || 1
        function r(n) { return Math.max(2, Math.round(n * rr)) }
        gradient: Gradient {
            GradientStop { position: 0; color: sec.t.wp ? sec.t.wp[1] : Tema.fondo }
            GradientStop { position: 0.55; color: sec.t.wp ? sec.t.wp[0] : Tema.fondo }
            GradientStop { position: 1; color: sec.t.fondo || Tema.fondo }
        }
        // una ventana
        Rectangle {
            x: 52; y: preview.arriba ? 52 : 22
            width: parent.width * 0.5; height: 112
            radius: preview.r(12)
            color: sec.t.superficie || Tema.superficie
            border.color: Qt.rgba(0.5, 0.5, 0.5, 0.18)
            Rectangle { x: 14; y: 14; width: 70; height: 8; radius: 4; color: sec.t.acento || Tema.rosa }
            Column {
                x: 14; y: 32; spacing: 7
                Repeater { model: [0.8, 0.6, 0.7]; delegate: Rectangle { required property real modelData; width: (preview.width * 0.5 - 28) * modelData; height: 7; radius: 3.5; color: sec.t.texto || Tema.texto; opacity: 0.18 } }
            }
            Text {
                x: 14; y: 80
                text: "Hola, así se ve la letra"
                color: sec.t.texto || Tema.texto
                font.family: sec.t.letra || Tema.letra
                font.pixelSize: Math.round((sec.t.letraPt || 10) * 1.3)
            }
        }
        // el panel de widgets, asomando por la izquierda (Meta+A)
        Rectangle {
            x: 8; y: 10
            width: 34; height: parent.height - 20; radius: preview.r(12)
            color: sec.t.fondo || Tema.fondo
            border.color: Qt.rgba(0.5, 0.5, 0.5, 0.2)
            Column {
                x: 6; y: 8; spacing: 6
                Rectangle { width: 22; height: 22; radius: 11; color: sec.t.acento || Tema.rosa }
                Repeater { model: 4; delegate: Rectangle { width: 22; height: 18; radius: preview.r(6); color: Qt.rgba(0.5, 0.5, 0.5, 0.2) } }
            }
        }
        // la isla
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: preview.arriba ? 10 : parent.height - height - 10
            width: 190; height: Math.round((sec.t.isla || 56) * 0.55); radius: preview.r(14)
            color: Qt.rgba(0, 0, 0, 0); border.color: Qt.rgba(0.5, 0.5, 0.5, 0.2)
            Rectangle { anchors.fill: parent; radius: parent.radius; color: sec.t.superficie || Tema.superficie; opacity: sec.t.cristal || 0.55 }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 6; spacing: 6
                Rectangle { width: parent.parent.height - 10; height: width; radius: preview.r(7); color: sec.t.acento || Tema.rosa }
                Repeater { model: 4; delegate: Rectangle { width: 16; height: 16; radius: preview.r(5); color: Qt.rgba(0.5, 0.5, 0.5, 0.35) } }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: "18:40"; color: sec.t.texto || Tema.texto
                font.family: sec.t.letra || Tema.letra; font.pixelSize: 11; font.bold: true
            }
        }
    }

    // ---------- A tu gusto ----------
    Fila {
        visible: sec.sigueAgape
        titulo: "Sigue a Ágape"
        detalle: "Los colores, claro u oscuro, la letra, las esquinas, el cristal y las animaciones los eliges en Ágape → Personalizar"
        Boton { text: "Abrir Ágape"; icono: "navegar"; onClicked: apogeo.open("agape") }
    }
    Fila {
        visible: sec.sigueFondo
        titulo: "Del fondo"
        detalle: "Cada modo coge los colores de su foto o su vídeo. A los fondos animados les das tú el color, en Fondos"
    }
    Fila {
        enabled: !sec.sigueAgape && !sec.sigueFondo
        opacity: enabled ? 1 : 0.45
        titulo: "Color"
        detalle: sec.a.acento ? "El tuyo" : "El del estilo"
        Row {
            spacing: 8
            Repeater {
                model: ["", "#45d6ff", "#b79cff", "#ffb35c", "#57e3b0", "#ff6b81", "#e0a9b4"]
                delegate: AbstractButton {
                    id: sw
                    required property string modelData
                    required property int index
                    readonly property color col: modelData || ((sec.estilos[sec.a.estilo] || {}).acento || Tema.rosa)
                    readonly property bool on: sec.a.acento === modelData
                    width: 24; height: 24
                    visible: index === 0 || modelData !== ((sec.estilos[sec.a.estilo] || {}).acento)
                    onClicked: sec.put("acento", modelData)
                    ToolTip.visible: hovered && index === 0
                    ToolTip.text: "El del estilo"
                    background: Rectangle {
                        radius: 12
                        color: sw.col
                        border.width: sw.on ? 2 : 0
                        border.color: Tema.texto
                    }
                }
            }
            AbstractButton {
                id: mine
                width: 24; height: 24
                hoverEnabled: true
                onClicked: colorDialog.open()
                ToolTip.visible: hovered
                ToolTip.text: "Otro color…"
                background: Rectangle { radius: 12; color: "transparent"; border.color: Tema.apagado; border.width: 1 }
                contentItem: Item { Icono { anchors.centerIn: parent; width: 12; height: 12; nombre: "mas"; color: Tema.apagado } }
            }
            ColorDialog {
                id: colorDialog
                selectedColor: Tema.rosa
                onAccepted: sec.put("acento", String(selectedColor).slice(0, 7))
            }
        }
    }
    Fila {
        enabled: !sec.sigueAgape
        opacity: enabled ? 1 : 0.45
        titulo: "Claro u oscuro"
        detalle: sec.a.modo === "hora" ? "Claro de 8:00 a 20:00"
               : sec.a.modo === "piso" && sec.a.estilo === "orbita" ? "Estudiar en papel de 8:00 a 20:00; lo demás, grafito" : ""
        Segmentos {
            readonly property var valores: ["piso", "oscuro", "claro", "hora"]
            opciones: [{ texto: "Por modo" }, { texto: "Oscuro" }, { texto: "Claro" }, { texto: "La hora" }]
            actual: Math.max(0, valores.indexOf(sec.a.modo))
            onElegido: i => sec.put("modo", valores[i])
        }
    }
    Fila {
        enabled: !sec.sigueAgape
        opacity: enabled ? 1 : 0.45
        titulo: "Letra"
        detalle: sec.a.letra || "Geist"
        Segmentos {
            readonly property var valores: ["Geist", "Geist Mono", "Noto Sans"]
            opciones: [{ texto: "Geist" }, { texto: "Geist Mono" }, { texto: "Otra…" }]
            actual: valores.indexOf(sec.a.letra) >= 0 ? valores.indexOf(sec.a.letra) : 2
            onElegido: i => i < 2 ? sec.put("letra", valores[i]) : fontDialog.open()
        }
        FontDialog {
            id: fontDialog
            onAccepted: sec.put("letra", selectedFont.family)
        }
    }
    Fila {
        enabled: !sec.sigueAgape
        opacity: enabled ? 1 : 0.45
        titulo: "Esquinas"
        Segmentos {
            readonly property var valores: ["rectas", "suaves", "redondas"]
            opciones: [{ texto: "Rectas" }, { texto: "Suaves" }, { texto: "Redondas" }]
            actual: Math.max(0, valores.indexOf(sec.a.esquinas))
            onElegido: i => sec.put("esquinas", valores[i])
        }
    }
    Fila {
        enabled: !sec.sigueAgape
        opacity: enabled ? 1 : 0.45
        titulo: "Cristal"
        detalle: "Lo transparente de la isla, la columna y los menús"
        Deslizador {
            width: 180
            from: 0; to: 100; stepSize: 5
            value: sec.a.cristal !== undefined ? sec.a.cristal : 55
            onPressedChanged: if (!pressed) sec.put("cristal", Math.round(value))
        }
    }
    Fila {
        titulo: "Tamaño"
        detalle: "La letra y la isla"
        Segmentos {
            readonly property var valores: ["compacto", "normal", "grande"]
            opciones: [{ texto: "Compacto" }, { texto: "Normal" }, { texto: "Grande" }]
            actual: Math.max(0, valores.indexOf(sec.a.tamano))
            onElegido: i => sec.put("tamano", valores[i])
        }
    }
    Fila {
        enabled: !sec.sigueAgape
        opacity: enabled ? 1 : 0.45
        titulo: "Animaciones"
        Segmentos {
            readonly property var valores: ["sin", "rapidas", "suaves"]
            opciones: [{ texto: "Sin" }, { texto: "Rápidas" }, { texto: "Suaves" }]
            actual: Math.max(0, valores.indexOf(sec.a.animaciones))
            onElegido: i => sec.put("animaciones", valores[i])
        }
    }
    Fila {
        titulo: "Isla"
        Segmentos {
            readonly property var valores: ["abajo-dcha", "arriba-dcha"]
            opciones: [{ texto: "Abajo" }, { texto: "Arriba" }]
            actual: sec.a.posicion === "arriba-dcha" ? 1 : 0
            onElegido: i => sec.put("posicion", valores[i])
        }
    }
    Fila {
        linea: false
        titulo: "Volver a lo de serie"
        detalle: "Los colores del fondo, con la isla como venía"
        Boton {
            text: "Volver"
            icono: "actualizar"
            enabled: JSON.stringify(sec.a) !== JSON.stringify(apogeo.lookDefault)
            onClicked: apogeo.set("aspecto", apogeo.lookDefault)
        }
    }
}
