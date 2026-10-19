import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Apogeo

// Ajustes → Aspecto («K2 con vista previa»): arriba, los estilos completos de un clic (Apogeo es el de siempre y viene
// puesto); en medio, cómo queda (en pequeño, al momento); debajo, cada detalle a mano. Todo se aplica solo en todo el
// sistema (lo hace apogeo-pisos con apogeo_aspecto) y «Volver a lo de Apogeo» lo deja como venía.
Seccion {
    id: sec
    property string palabras: "aspecto tema estilo color colores acento claro oscuro letra fuente esquinas redondas cristal transparencia tamaño animaciones isla columna posicion personalizar"
    titulo: "Aspecto"
    intro: "Los colores, la letra y las formas de todo Apogeo. Lo de serie es la estética de Ágape."

    readonly property var a: apogeo.settings.aspecto || ({})
    readonly property var t: apogeo.lookTokens(a)          // las fichas de cómo queda (las mismas que se aplican)
    readonly property var estilos: apogeo.lookStyles
    readonly property var orden: ["apogeo", "medianoche", "bosque", "arena", "papel"]
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
                width: 132; height: 112
                hoverEnabled: true
                onClicked: {
                    sec.put("estilo", modelData);
                    sec.put("acento", "");
                    if (sec.a.modo !== "hora") sec.put("modo", e.claro ? "claro" : "oscuro");
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
        readonly property bool izquierda: sec.t.posicion === "abajo-izq"
        readonly property real rr: sec.t.radio || 1
        function r(n) { return Math.max(2, Math.round(n * rr)) }
        gradient: Gradient {
            GradientStop { position: 0; color: sec.t.wp ? sec.t.wp[1] : Tema.fondo }
            GradientStop { position: 0.55; color: sec.t.wp ? sec.t.wp[0] : Tema.fondo }
            GradientStop { position: 1; color: sec.t.fondo || Tema.fondo }
        }
        // una ventana
        Rectangle {
            x: preview.izquierda ? 70 : 28; y: preview.arriba ? 52 : 22
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
        // la columna de pisos
        Rectangle {
            x: preview.izquierda ? 10 : parent.width - width - 10
            y: (parent.height - height) / 2
            width: 26; height: 82; radius: preview.r(13)
            color: Qt.rgba(0, 0, 0, 0); border.color: Qt.rgba(0.5, 0.5, 0.5, 0.2)
            Rectangle { anchors.fill: parent; radius: parent.radius; color: sec.t.superficie || Tema.superficie; opacity: sec.t.cristal || 0.55 }
            Column {
                anchors.centerIn: parent; spacing: 6
                Repeater { model: 3; delegate: Rectangle { required property int index; width: 16; height: 16; radius: preview.r(6); color: index === 1 ? (sec.t.acento || Tema.rosa) : Qt.rgba(0.5, 0.5, 0.5, 0.25) } }
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
        titulo: "Color"
        detalle: sec.a.acento ? "El tuyo" : "El del estilo"
        Row {
            spacing: 8
            Repeater {
                model: ["", "#e0a9b4", "#b8a4f0", "#8fc9e8", "#9ed9b0", "#f2c48d", "#f28d8d"]
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
        titulo: "Claro u oscuro"
        detalle: sec.a.modo === "hora" ? "Claro de 8:00 a 20:00" : ""
        Segmentos {
            readonly property var valores: ["oscuro", "claro", "hora"]
            opciones: [{ texto: "Oscuro" }, { texto: "Claro" }, { texto: "Según la hora" }]
            actual: Math.max(0, valores.indexOf(sec.a.modo))
            onElegido: i => sec.put("modo", valores[i])
        }
    }
    Fila {
        titulo: "Letra"
        detalle: sec.a.letra || "Bricolage Grotesque"
        Segmentos {
            readonly property var valores: ["Bricolage Grotesque", "Noto Sans"]
            opciones: [{ texto: "Bricolage" }, { texto: "Noto Sans" }, { texto: "Otra…" }]
            actual: valores.indexOf(sec.a.letra) >= 0 ? valores.indexOf(sec.a.letra) : 2
            onElegido: i => i < 2 ? sec.put("letra", valores[i]) : fontDialog.open()
        }
        FontDialog {
            id: fontDialog
            onAccepted: sec.put("letra", selectedFont.family)
        }
    }
    Fila {
        titulo: "Esquinas"
        Segmentos {
            readonly property var valores: ["rectas", "suaves", "redondas"]
            opciones: [{ texto: "Rectas" }, { texto: "Suaves" }, { texto: "Redondas" }]
            actual: Math.max(0, valores.indexOf(sec.a.esquinas))
            onElegido: i => sec.put("esquinas", valores[i])
        }
    }
    Fila {
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
        titulo: "Animaciones"
        Segmentos {
            readonly property var valores: ["sin", "rapidas", "suaves"]
            opciones: [{ texto: "Sin" }, { texto: "Rápidas" }, { texto: "Suaves" }]
            actual: Math.max(0, valores.indexOf(sec.a.animaciones))
            onElegido: i => sec.put("animaciones", valores[i])
        }
    }
    Fila {
        titulo: "Isla y columna"
        Segmentos {
            readonly property var valores: ["abajo-dcha", "abajo-izq", "arriba-dcha"]
            opciones: [{ texto: "Abajo · dcha" }, { texto: "Abajo · izq" }, { texto: "Arriba · dcha" }]
            actual: Math.max(0, valores.indexOf(sec.a.posicion))
            onElegido: i => sec.put("posicion", valores[i])
        }
    }
    Fila {
        linea: false
        titulo: "Volver a lo de Apogeo"
        detalle: "Los colores, la letra y las formas de serie"
        Boton {
            text: "Volver"
            icono: "actualizar"
            enabled: JSON.stringify(sec.a) !== JSON.stringify(apogeo.lookDefault)
            onClicked: apogeo.set("aspecto", apogeo.lookDefault)
        }
    }
}
