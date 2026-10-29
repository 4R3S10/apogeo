import QtQuick
import QtQuick.Effects
import org.kde.layershell as LayerShell
import Apogeo

// La guía de atajos («G1 + G3»): una tarjeta grande en el centro con los atajos de Apogeo y, arriba y resaltados, los
// del piso en el que estás. Sale mientras mantienes Meta (sin quitarle el teclado ni el ratón a nada: al soltar se va) o
// con Meta+/ (entonces Esc o un clic la cierran). Va en la capa de encima de todo (layer-shell, como los avisos de
// Plasma): se ve también sobre un juego a pantalla completa. La parte de dentro es apogeo-buscador («buscador»).
Window {
    id: win
    // Mientras mantienes Meta no se lleva el teclado ni los clics (no molesta a un juego ni a lo que estés haciendo)
    property bool held: false
    flags: Qt.FramelessWindowHint | (held ? Qt.WindowTransparentForInput : 0)
    color: "transparent"
    LayerShell.Window.scope: "apogeo-atajos"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.wantsToBeOnActiveScreen: true
    LayerShell.Window.keyboardInteractivity: held ? LayerShell.Window.KeyboardInteractivityNone
                                                  : LayerShell.Window.KeyboardInteractivityExclusive
    LayerShell.Window.activateOnShow: !held
    title: "Atajos de Apogeo"
    visible: false

    property string piso: ""
    property bool carrusel: false   // (el piso tiene las ventanas en carrusel: sus atajos, con los del piso)
    readonly property var atajosCarrusel: [
        [["Meta", "Alt", "← →"], "Carrusel: la columna de al lado"],
        [["Meta", "Alt", "⇧", "← →"], "Carrusel: mover la ventana"],
        [["Meta", "Alt", "R"], "Carrusel: cambiar el ancho"],
        [["Meta", "Alt", "Espacio"], "Carrusel: soltarla o volver"],
        [["Meta", "Alt", "Intro"], "Carrusel: centrarla"]]
    readonly property var pisos: ({
        "Jugar": { icono: "jugar", atajos: [
            [["Meta", "Tab"], "Modo partida: el juego y Discord"],
            [["⇧ dcha", "F12"], "Enseñar o esconder el HUD"],
            [["Alt", "Tab"], "Cambiar de ventana"],
            [["Meta", "⇧", "S"], "Captura de la partida"]] },
        "Navegar": { icono: "navegar", atajos: [
            [["Ctrl", "K"], "Todo lo de Ágape"],
            [["Ctrl", "T"], "Pestaña nueva"],
            [["Ctrl", "⇧", "T"], "Reabrir la que cerraste"],
            [["Ctrl", "/"], "Dos webs a la vez"],
            [["Ctrl", "⇧", "P"], "Vídeo flotante"],
            [["Ctrl", "⇧", "S"], "Captura de la web"]] },
        "Estudiar": { icono: "estudiar", atajos: [
            [["Meta", "← →"], "Apuntes y PDF lado a lado"],
            [["Meta", "⇧", "S"], "Sacar el texto de una captura"],
            [["Meta"], "Escribe una cuenta: «15% de 80»"],
            [["Meta", "V"], "Lo que has copiado"]] }
    })
    readonly property var grupos: [
        { titulo: "Pisos y paneles", atajos: [
            [["Meta", "F1 · F2 · F3"], "Jugar · Navegar · Estudiar"],
            [["Meta", "A"], "Panel de widgets (izquierda)"],
            [["Meta", "N"], "Panel rápido y avisos (derecha)"],
            [["Meta", "Ctrl", "↑ ↓"], "El piso de arriba o de abajo"],
            [["Meta", "Ctrl", "⇧", "↑ ↓"], "Llevar la ventana a otro piso"]] },
        { titulo: "Ventanas", atajos: [
            [["Meta", "← →"], "Mitad izquierda o derecha"],
            [["Meta", "↑ ↓"], "Mitad de arriba o de abajo"],
            [["Meta", "RePág"], "Grande"],
            [["Meta", "AvPág"], "Minimizar"],
            [["Meta", "W"], "Ver todas"],
            [["Meta", "D"], "Ver el escritorio"]] },
        { titulo: "Buscar y copiar", atajos: [
            [["Meta"], "Apps, archivos y cuentas"],
            [["Meta", "V"], "Lo que has copiado"],
            [["Meta", "."], "Emojis"],
            [["Meta", "E"], "Tus archivos"]] },
        { titulo: "Pantalla", atajos: [
            [["Meta", "⇧", "S"], "Captura (o Impr Pant)"],
            [["Meta", "L"], "Bloquear"],
            [["Meta", "+ −"], "Lupa"],
            [["Ctrl", "Alt", "T"], "Terminal"],
            [["Meta", "/"], "Esta guía"]] }
    ]

    function open(mantenida) {
        if (visible && !mantenida && !held) { close(); return; }
        if (visible) hide();
        held = mantenida;
        piso = buscador.piso();
        carrusel = buscador.carrusel(piso);
        show();
        if (!held) requestActivate();
        appear.restart();
    }
    function close() { hide(); held = false; }

    Connections {
        target: buscador
        function onAtajos(mantenida) { win.open(mantenida) }
        function onSoltada() { if (win.held) win.close() }
        function onToggled() { if (win.visible) win.close() }
    }
    Component.onCompleted: if (atajosAtStart) open(false)
    onActiveChanged: if (!active && visible && !held) close()

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => { if (e.key === Qt.Key_Escape) { win.close(); e.accepted = true; } }
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: card.opacity
        MouseArea { anchors.fill: parent; onClicked: win.close() }
    }
    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        offset.y: 12; blur: 34; spread: -4
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: card.opacity
        scale: card.scale
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(820, win.width - 48)
        height: col.height + 44
        radius: Tema.r(22)
        color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.97)
        border.color: Tema.borde
        MouseArea { anchors.fill: parent }   // (un clic dentro no la cierra)
        ParallelAnimation {
            id: appear
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; from: 0.97; to: 1; duration: 190; easing.type: Easing.OutCubic }
        }

        Column {
            id: col
            x: 26; y: 22
            width: parent.width - 52
            spacing: 16

            Item {
                width: parent.width
                height: 24
                Texto {
                    text: "Atajos de Apogeo"
                    font.pixelSize: 19
                    font.weight: Font.ExtraBold
                    anchors.verticalCenter: parent.verticalCenter
                }
                Texto {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.held ? "Suelta Meta para cerrar" : "Esc para cerrar"
                    color: Tema.tenue
                    font.pixelSize: 12
                }
            }

            // Los del piso en el que estás
            Rectangle {
                id: floorBox
                readonly property var p: win.pisos[win.piso]
                visible: !!p
                width: parent.width
                height: visible ? floorCol.height + 24 : 0
                radius: Tema.r(14)
                color: Qt.rgba(Tema.vivo.r, Tema.vivo.g, Tema.vivo.b, 0.1)
                border.color: Qt.rgba(Tema.vivo.r, Tema.vivo.g, Tema.vivo.b, 0.35)
                Column {
                    id: floorCol
                    x: 16; y: 12
                    width: parent.width - 32
                    spacing: 8
                    Row {
                        spacing: 8
                        Icono { nombre: floorBox.p ? floorBox.p.icono : ""; color: Tema.vivo; anchors.verticalCenter: parent.verticalCenter }
                        Texto { text: "Ahora en " + win.piso; color: Tema.vivo; font.weight: Font.ExtraBold; font.pixelSize: 14 }
                    }
                    Grid {
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 6
                        Repeater {
                            model: floorBox.p ? floorBox.p.atajos.concat(win.carrusel ? win.atajosCarrusel : []) : []
                            Atajo { width: (floorCol.width - 18) / 2; ancho: 110; teclas: modelData[0]; que: modelData[1] }
                        }
                    }
                }
            }

            // Todos
            Grid {
                id: groups
                width: parent.width
                columns: 2
                columnSpacing: 28
                rowSpacing: 18
                Repeater {
                    model: win.grupos
                    Column {
                        width: (groups.width - groups.columnSpacing) / 2
                        spacing: 6
                        Texto { text: modelData.titulo; font.weight: Font.ExtraBold; font.pixelSize: 14 }
                        Repeater {
                            model: modelData.atajos
                            Atajo { width: parent.width; teclas: modelData[0]; que: modelData[1] }
                        }
                    }
                }
            }
        }
    }

    // Una fila: las teclas en pastillitas y lo que hacen
    component Atajo: Row {
        id: atajo
        property var teclas: []
        property string que: ""
        property int ancho: 172   // (lo que ocupan las teclas)
        spacing: 10
        Row {
            id: chips
            width: atajo.ancho
            spacing: 4
            Repeater {
                model: atajo.teclas
                Rectangle {
                    width: Math.max(24, k.implicitWidth + 14)
                    height: 22
                    radius: Tema.r(6)
                    color: Tema.encima
                    border.color: Tema.borde
                    Text {
                        id: k
                        anchors.centerIn: parent
                        text: modelData
                        color: Tema.texto
                        font.family: Tema.letra
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
        Texto {
            width: atajo.width - chips.width - atajo.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: atajo.que
            color: Tema.apagado
            font.pixelSize: 13
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }
}
