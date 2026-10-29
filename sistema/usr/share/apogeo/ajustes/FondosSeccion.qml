import QtQuick
import QtQuick.Controls
import Apogeo

// Ajustes → Fondos: el fondo de cada piso. Los animados de Apogeo (el de siempre, por defecto) y, con Aura, imágenes y
// vídeos de internet (Wallhaven, MotionBGS, Bing del día) y de tu biblioteca: lo que eliges en Aura va solo al piso en
// el que estás. Debajo, tu biblioteca de Aura para ponerla en cualquier piso y «que cambie solo». Se ve al momento.
Seccion {
    id: sec
    property string palabras: "fondos fondo de pantalla imagen video animado aura wallhaven bing internet biblioteca cambie solo wallpaper"
    titulo: "Fondos"
    intro: "Cada piso con el suyo. Lo que elijas se pone al momento; también con el botón derecho en el escritorio."

    property int floor: 1
    readonly property var floors: [
        { clave: "jugar", texto: "Jugar", icono: "jugar" },
        { clave: "navegar", texto: "Navegar", icono: "navegar" },
        { clave: "estudiar", texto: "Estudiar", icono: "estudiar" }
    ]
    readonly property string fk: floors[floor].clave
    readonly property var lib: apogeo.library
    readonly property string current: apogeo.settings.pisos[fk].fondo
    readonly property var rot: apogeo.settings.fondos.cambiar[fk]
    // El fondo tuyo que tiene el piso ({} si es uno animado)
    readonly property var ahora: { apogeo.library; return apogeo.wallpaperInfo(current) }
    readonly property var animado: lib.animados.find(a => a.valor === current) || null
    property bool todaLaBiblioteca: false
    function pick(valor) { apogeo.set("pisos." + sec.fk + ".fondo", valor) }

    // Una miniatura: animada, imagen o vídeo
    component Tile: Column {
        id: tile
        property var item
        property real side: 150
        property bool elegible: true
        readonly property bool on: elegible && item && item.valor === sec.current
        spacing: 6
        width: side
        Item {
            width: tile.side; height: Math.round(tile.side * 0.56)
            Fondo { anchors.fill: parent; visible: tile.item.tipo === "animado"; tipo: tile.item.indice || 0; radio: 12 }
            Rectangle {
                anchors.fill: parent
                visible: tile.item.tipo !== "animado"
                radius: Tema.r(12)
                color: Tema.encima
                clip: true
                Image {
                    anchors.fill: parent
                    source: tile.item.mini || ""
                    sourceSize: Qt.size(Math.round(tile.side * 2), Math.round(tile.side * 1.12))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Icono {
                    anchors.centerIn: parent
                    visible: !!tile.item.video && !tile.item.mini
                    nombre: "video"; color: Tema.rosa
                }
                Rectangle {  // (un vídeo: el ▶ en la esquina)
                    visible: !!tile.item.video && !!tile.item.mini
                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 6
                    width: 24; height: 24; radius: Tema.r(8)
                    color: "#cc120d14"
                    Icono { anchors.centerIn: parent; nombre: "reproducir"; width: 12; height: 12; color: Tema.texto }
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: Tema.r(15)
                color: "transparent"
                border.width: 2
                border.color: tile.on ? Tema.rosa : area.containsMouse && tile.elegible ? Tema.borde : "transparent"
            }
            MouseArea {
                id: area
                anchors.fill: parent
                enabled: tile.elegible
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sec.pick(tile.item.valor)
            }
        }
        Texto {
            visible: tile.item.nombre !== undefined
            width: parent.width
            text: tile.item.nombre || ""
            color: tile.on ? Tema.texto : Tema.apagado
            font.pixelSize: 12
            font.weight: tile.on ? Font.Bold : Font.Normal
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }

    component Grid_: Flow {
        id: g
        property var items: []
        readonly property int cols: Math.max(3, Math.floor((width + 12) / 162))
        readonly property real side: Math.floor((width - (cols - 1) * spacing) / cols)
        width: parent.width
        spacing: 12
        Repeater {
            model: g.items
            delegate: Tile { required property var modelData; item: modelData; side: g.side }
        }
    }

    Fila {
        linea: false
        titulo: "Piso"
        detalle: "El que estás cambiando"
        Segmentos { opciones: sec.floors; actual: sec.floor; onElegido: i => sec.floor = i }
    }

    Fila {
        titulo: "Animados de Apogeo"
        detalle: "Los de siempre: se mueven despacio y apenas gastan"
        ancha: true
        Grid_ { items: sec.lib.animados }
    }

    Fila {
        titulo: "Con Aura"
        detalle: "Lo que pones en Aura va solo al piso en el que estás. Los vídeos van en bucle y sin sonido, y se paran si una ventana los tapa"
        ancha: true
        Row {
            width: parent.width
            spacing: 20
            Tile {
                id: previa
                side: 240
                elegible: false
                item: sec.ahora.valor ? { tipo: "aura", video: sec.ahora.video, mini: sec.ahora.mini }
                                      : { tipo: "animado", indice: sec.animado ? sec.animado.indice : 0 }
            }
            Column {
                width: parent.width - previa.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Texto {
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.weight: Font.DemiBold
                    text: sec.ahora.valor ? "Ahora: «" + sec.ahora.nombre + "»" + (sec.ahora.video ? " (vídeo)" : "")
                                          : "Ahora: el animado «" + (sec.animado ? sec.animado.nombre : "") + "»"
                }
                Texto {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Tema.apagado
                    font.pixelSize: 12
                    text: "Wallhaven, vídeos MotionBGS, Bing del día y tu biblioteca"
                }
                Boton {
                    tipo: "principal"
                    icono: "imagen"
                    text: "Elegir con Aura"
                    onClicked: apogeo.chooseWithAura(sec.fk)
                }
                Texto {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: Tema.tenue
                    font.pixelSize: 11
                    text: "Te lleva a " + sec.floors[sec.floor].texto + " y abre Aura"
                }
            }
        }
    }

    Fila {
        titulo: "Tu biblioteca"
        detalle: sec.lib.aura.length ? "Lo que has bajado con Aura y tus carpetas de fondos: ponlo en cualquier piso"
                                     : "Aún está vacía: lo que bajes con Aura aparece aquí"
        ancha: true
        Column {
            width: parent.width
            spacing: 12
            Row {
                spacing: 8
                Boton { text: "Mirar de nuevo"; tipo: "plano"; icono: "actualizar"; onClicked: apogeo.refreshLibrary() }
                Boton {
                    visible: sec.lib.aura.length > 12
                    tipo: "plano"
                    text: sec.todaLaBiblioteca ? "Ver menos" : "Ver todos (" + sec.lib.aura.length + ")"
                    onClicked: sec.todaLaBiblioteca = !sec.todaLaBiblioteca
                }
            }
            Grid_ {
                visible: sec.lib.aura.length > 0
                items: sec.todaLaBiblioteca ? sec.lib.aura : sec.lib.aura.slice(0, 12)
            }
        }
    }

    Fila {
        titulo: "Que cambie solo"
        detalle: sec.rot.activo ? "Pasa por tus fondos en " + sec.floors[sec.floor].texto : "Apagado: se queda el que elijas"
        Interruptor {
            checked: sec.rot.activo
            onToggled: apogeo.set("fondos.cambiar." + sec.fk + ".activo", checked)
        }
    }
    Fila {
        visible: sec.rot.activo
        titulo: "Cada cuánto"
        Segmentos {
            readonly property var claves: ["15min", "hora", "dia", "piso"]
            opciones: [{ texto: "15 min" }, { texto: "Cada hora" }, { texto: "Cada día" }, { texto: "Al entrar en el piso" }]
            actual: Math.max(0, claves.indexOf(sec.rot.cada))
            onElegido: i => apogeo.set("fondos.cambiar." + sec.fk + ".cada", claves[i])
        }
    }
    Fila {
        visible: sec.rot.activo
        titulo: "De dónde"
        detalle: sec.lib.aura.length ? "" : "Con la biblioteca vacía, de los animados"
        Segmentos {
            readonly property var claves: ["aura", "animados", "ambos"]
            opciones: [{ texto: "Tu biblioteca" }, { texto: "Animados" }, { texto: "Los dos" }]
            actual: Math.max(0, claves.indexOf(sec.rot.de))
            onElegido: i => apogeo.set("fondos.cambiar." + sec.fk + ".de", claves[i])
        }
    }
}
