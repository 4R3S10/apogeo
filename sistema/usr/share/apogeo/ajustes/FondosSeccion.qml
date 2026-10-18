import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Apogeo

// Ajustes → Fondos («F1»): el fondo de cada piso. Los animados de Apogeo (el de siempre, por defecto), tus imágenes y
// vídeos en alta calidad, los de tu carpeta (lo que metas ahí entra solo), la galería de internet (imágenes destacadas de
// Wikimedia Commons, con licencia libre) y «que cambie solo». Lo que se elige se ve al momento.
Seccion {
    id: sec
    property string palabras: "fondos fondo de pantalla imagen video animado galeria internet carpeta cambie solo wallpaper"
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
    function pick(valor) { apogeo.set("pisos." + sec.fk + ".fondo", valor) }

    // Una miniatura: animada, imagen o vídeo
    component Tile: Column {
        id: tile
        property var item
        property real side: 150
        property bool removable: false
        readonly property bool on: item && item.valor === sec.current
        spacing: 6
        width: side
        Item {
            width: tile.side; height: Math.round(tile.side * 0.56)
            Fondo { anchors.fill: parent; visible: tile.item.tipo === "animado"; tipo: tile.item.indice || 0; radio: 12 }
            Rectangle {
                anchors.fill: parent
                visible: tile.item.tipo !== "animado"
                radius: 12
                color: Tema.encima
                clip: true
                Image {
                    anchors.fill: parent
                    visible: !tile.item.video
                    source: tile.item && !tile.item.video && tile.item.url ? tile.item.url : ""
                    sourceSize: Qt.size(320, 180)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Column {
                    anchors.centerIn: parent
                    visible: !!tile.item.video
                    spacing: 4
                    Icono { anchors.horizontalCenter: parent.horizontalCenter; nombre: "video"; color: Tema.rosa }
                    Texto { text: "Vídeo"; color: Tema.apagado; font.pixelSize: 11 }
                }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: 15
                color: "transparent"
                border.width: 2
                border.color: tile.on ? Tema.rosa : area.containsMouse ? Tema.borde : "transparent"
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sec.pick(tile.item.valor)
            }
            AbstractButton {
                id: quitar
                visible: tile.removable && (area.containsMouse || hovered)
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
                width: 24; height: 24
                hoverEnabled: true
                background: Rectangle { radius: 8; color: quitar.hovered ? "#e5484d" : "#cc120d14" }
                contentItem: Icono { nombre: "cerrar"; width: 12; height: 12; color: Tema.texto }
                onClicked: apogeo.removeWallpaper(tile.item.valor)
                ToolTip.visible: hovered; ToolTip.text: "Quitar de tus fondos"
            }
        }
        Texto {
            width: parent.width
            text: tile.item.nombre
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
        property bool removable: false
        readonly property int cols: Math.max(3, Math.floor((width + 12) / 162))
        readonly property real side: Math.floor((width - (cols - 1) * spacing) / cols)
        width: parent.width
        spacing: 12
        Repeater {
            model: g.items
            delegate: Tile { required property var modelData; item: modelData; side: g.side; removable: g.removable }
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
        titulo: "Tus fondos"
        detalle: "Imágenes y vídeos en alta calidad (4K o más). Los vídeos van en bucle y sin sonido, y se paran si una ventana los tapa"
        ancha: true
        Column {
            width: parent.width
            spacing: 12
            Boton { text: "Añadir imagen o vídeo"; icono: "mas"; onClicked: addDialog.open() }
            Grid_ { items: sec.lib.tuyos; removable: true; visible: sec.lib.tuyos.length > 0 }
        }
    }

    Fila {
        titulo: "De tu carpeta"
        detalle: sec.lib.rutaCarpeta + " · lo que metas ahí aparece aquí solo"
        ancha: true
        Column {
            width: parent.width
            spacing: 12
            Row {
                spacing: 8
                Boton { text: "Abrir la carpeta"; icono: "carpeta"; onClicked: apogeo.openFolder() }
                Boton { text: "Usar otra carpeta"; tipo: "plano"; onClicked: folderDialog.open() }
                Boton { text: "Mirar de nuevo"; tipo: "plano"; icono: "actualizar"; onClicked: apogeo.refreshLibrary() }
            }
            Grid_ { items: sec.lib.carpeta; visible: sec.lib.carpeta.length > 0 }
        }
    }

    Fila {
        titulo: "Galería de internet"
        detalle: "Imágenes destacadas de Wikimedia Commons: fotos de alta calidad con licencia libre. Se guardan en tu carpeta de fondos"
        ancha: true
        Column {
            width: parent.width
            spacing: 12
            Row {
                spacing: 8
                Campo {
                    id: buscar
                    width: 300
                    implicitHeight: 36
                    font.pixelSize: 13
                    leftPadding: 36
                    placeholderText: "Buscar fondos (montañas, espacio…)"
                    onAccepted: apogeo.searchGallery(text)
                    Icono { x: 13; anchors.verticalCenter: parent.verticalCenter; nombre: "buscar"; color: Tema.tenue }
                }
                Boton { text: "Buscar"; tipo: "principal"; onClicked: apogeo.searchGallery(buscar.text) }
            }
            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: apogeo.suggestions
                    delegate: Boton {
                        required property var modelData
                        tipo: "plano"
                        text: modelData.texto
                        onClicked: { buscar.text = ""; apogeo.searchGallery(modelData.buscar) }
                    }
                }
            }
            Texto {
                visible: text !== ""
                color: Tema.apagado
                text: ({ buscando: "Buscando…", "nada-encontrado": "No hay fotos destacadas con eso. Prueba en inglés (por ejemplo «mountains»).", "sin-red": "No hay internet ahora mismo." })[apogeo.gallery.estado] || ""
            }
            Flow {
                id: galeria
                width: parent.width
                spacing: 12
                readonly property int cols: Math.max(3, Math.floor((width + 12) / 200))
                readonly property real side: Math.floor((width - (cols - 1) * spacing) / cols)
                Repeater {
                    model: apogeo.gallery.lista
                    delegate: Column {
                        id: foto
                        required property var modelData
                        readonly property bool bajando: apogeo.gallery.bajando === modelData.url
                        width: galeria.side
                        spacing: 5
                        Rectangle {
                            width: parent.width; height: Math.round(width * 0.56)
                            radius: 12
                            color: Tema.encima
                            clip: true
                            Image { anchors.fill: parent; source: foto.modelData.mini; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            Rectangle {
                                anchors.fill: parent
                                color: "#99120d14"
                                visible: fotoArea.containsMouse || foto.bajando
                                Boton {
                                    anchors.centerIn: parent
                                    tipo: "principal"
                                    icono: foto.bajando ? "" : "descargar"
                                    text: foto.bajando ? "Bajando…" : "Poner en " + sec.floors[sec.floor].texto
                                    enabled: !foto.bajando
                                    onClicked: apogeo.downloadGallery(foto.modelData, sec.fk)
                                }
                            }
                            MouseArea { id: fotoArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                        }
                        Texto { width: parent.width; text: foto.modelData.titulo; font.pixelSize: 12; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                        Texto {
                            width: parent.width
                            text: foto.modelData.ancho + "×" + foto.modelData.alto + " · " + foto.modelData.licencia + (foto.modelData.autor ? " · " + foto.modelData.autor : "")
                            color: Tema.tenue; font.pixelSize: 11; elide: Text.ElideRight; wrapMode: Text.NoWrap
                        }
                    }
                }
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
        Segmentos {
            readonly property var claves: ["todos", "tuyos", "carpeta", "animados"]
            opciones: [{ texto: "Tuyos y carpeta" }, { texto: "Tus fondos" }, { texto: "Tu carpeta" }, { texto: "Animados" }]
            actual: Math.max(0, claves.indexOf(sec.rot.de))
            onElegido: i => apogeo.set("fondos.cambiar." + sec.fk + ".de", claves[i])
        }
    }

    FileDialog {
        id: addDialog
        title: "Elige imágenes o vídeos para tus fondos"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Imágenes y vídeos (*.jpg *.jpeg *.png *.webp *.avif *.jxl *.mp4 *.webm *.mkv *.mov *.m4v)"]
        onAccepted: apogeo.addWallpapers(selectedFiles)
    }
    FolderDialog {
        id: folderDialog
        title: "Elige la carpeta de tus fondos"
        onAccepted: apogeo.setFolder(selectedFolder)
    }
}
