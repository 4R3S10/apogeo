import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Apogeo

// Ajustes → Identidad: Órbita (grafito, Geist y un acento por modo). Arriba, cómo queda (en pequeño, al momento);
// debajo, cada detalle a mano. Todo se aplica solo en todo el sistema (lo hace apogeo-pisos con apogeo_aspecto) y
// «Volver a lo de serie» lo deja como venía.
Seccion {
    id: sec
    property string palabras: "identidad aspecto tema color colores acento claro oscuro esquinas redondas cristal transparencia tamaño animaciones personalizar orbita"
    titulo: "Identidad"
    intro: "La piel de todo Apogeo: Órbita. Grafito, Geist y un acento por modo (cian al navegar, ámbar al estudiar, violeta al jugar)."

    readonly property var a: apogeo.settings.aspecto || ({})
    readonly property var t: apogeo.lookTokens(a)          // las fichas de cómo queda (las mismas que se aplican)
    function put(k, v) { apogeo.set("aspecto." + k, v) }

    // ---------- Así queda ----------
    Rectangle {
        id: preview
        width: parent.width
        height: 200
        radius: Tema.r(16)
        clip: true
        readonly property real rr: sec.t.radio || 1
        function r(n) { return Math.max(2, Math.round(n * rr)) }
        gradient: Gradient {
            GradientStop { position: 0; color: sec.t.wp ? sec.t.wp[1] : Tema.fondo }
            GradientStop { position: 0.55; color: sec.t.wp ? sec.t.wp[0] : Tema.fondo }
            GradientStop { position: 1; color: sec.t.fondo || Tema.fondo }
        }
        // una ventana
        Rectangle {
            x: 52; y: 30
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
        // la barra fina de arriba (el modo y la hora) y el orbe abajo, con los otros dos modos a sus lados
        Item {
            anchors.fill: parent
            Row {
                x: 12; y: 9; spacing: 5
                Rectangle { width: 5; height: 5; radius: 2.5; color: sec.t.acento || Tema.rosa; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "NAVEGAR"; color: sec.t.acento || Tema.rosa; font { family: Tema.mono; pixelSize: 9; letterSpacing: 2 } }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 12; y: 7
                text: "18:40"; color: sec.t.texto || Tema.texto
                font { family: Tema.mono; pixelSize: 10; bold: true }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                spacing: 14
                Rectangle { width: 12; height: 12; radius: 6; color: "transparent"; border.width: 1.5; border.color: "#b79cff"; anchors.verticalCenter: parent.verticalCenter }
                Rectangle {
                    width: 24; height: 24; radius: 12; color: "transparent"; border.width: 2; border.color: sec.t.acento || Tema.rosa
                    Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: "white" }
                }
                Rectangle { width: 12; height: 12; radius: 6; color: "transparent"; border.width: 1.5; border.color: "#ffb35c"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ---------- A tu gusto ----------
    Fila {
        titulo: "El color de cada modo"
        detalle: (sec.a.color || "fondo") === "fondo"
                 ? "Sale de su fondo de pantalla: todo se tiñe de él (un fondo animado de Apogeo se queda con el suyo)"
                 : "El violeta de Jugar, el cian de Navegar y el ámbar de Estudiar"
        Segmentos {
            readonly property var valores: ["fondo", "modo"]
            opciones: [{ texto: "Del fondo" }, { texto: "Del modo" }]
            actual: Math.max(0, valores.indexOf(sec.a.color || "fondo"))
            onElegido: i => sec.put("color", valores[i])
        }
    }
    Fila {
        titulo: "Color"
        detalle: sec.a.acento ? "El tuyo, en los tres modos" : (sec.a.color || "fondo") === "fondo" ? "El de cada fondo" : "El de cada modo"
        Row {
            spacing: 8
            Repeater {
                model: ["", "#45d6ff", "#b79cff", "#ffb35c", "#57e3b0", "#ff6b81"]
                delegate: AbstractButton {
                    id: sw
                    required property string modelData
                    required property int index
                    readonly property bool on: sec.a.acento === modelData
                    width: 24; height: 24
                    hoverEnabled: true
                    onClicked: sec.put("acento", modelData)
                    ToolTip.visible: hovered && index === 0
                    ToolTip.text: "El de cada modo"
                    background: Rectangle {
                        radius: 12
                        color: sw.modelData || "transparent"
                        border.width: sw.on ? 2 : sw.modelData ? 0 : 1
                        border.color: sw.on || sw.modelData ? Tema.texto : Tema.apagado
                        // (el de cada modo: los tres colores, uno por modo)
                        Row {
                            visible: !sw.modelData
                            anchors.centerIn: parent
                            spacing: 2
                            Repeater {
                                model: ["#b79cff", "#45d6ff", "#ffb35c"]
                                delegate: Rectangle { required property string modelData; width: 5; height: 5; radius: 2.5; color: modelData }
                            }
                        }
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
        detalle: sec.a.modo === "hora" ? "Claro de 8:00 a 20:00"
               : sec.a.modo === "piso" ? "Grafito en los tres modos, cada uno con su color" : ""
        Segmentos {
            readonly property var valores: ["piso", "oscuro", "claro", "hora"]
            opciones: [{ texto: "Por modo" }, { texto: "Oscuro" }, { texto: "Claro" }, { texto: "La hora" }]
            actual: Math.max(0, valores.indexOf(sec.a.modo))
            onElegido: i => sec.put("modo", valores[i])
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
        detalle: "Lo transparente de la barra de arriba, la Órbita y los menús"
        Deslizador {
            width: 180
            from: 0; to: 100; stepSize: 5
            value: sec.a.cristal !== undefined ? sec.a.cristal : 55
            onPressedChanged: if (!pressed) sec.put("cristal", Math.round(value))
        }
    }
    Fila {
        titulo: "Tamaño"
        detalle: "La letra y el orbe"
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
        linea: false
        titulo: "Volver a lo de serie"
        detalle: "Órbita tal como viene: el acento de cada modo, grafito, esquinas suaves"
        Boton {
            text: "Volver"
            icono: "actualizar"
            enabled: JSON.stringify(sec.a) !== JSON.stringify(apogeo.lookDefault)
            onClicked: apogeo.set("aspecto", apogeo.lookDefault)
        }
    }
}
