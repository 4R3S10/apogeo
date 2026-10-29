import QtQuick
import QtQuick.Effects
import Apogeo

// El portapapeles («P1») y los emojis («E1»): una tarjeta pequeña junto al ratón (la pone ahí apogeo-ventanas).
//  Copiado: lo último que has copiado, lo fijado (📌) arriba. Escribir filtra · flechas elegir · Intro pegar ·
//           Ctrl+P fijar · Supr quitar.
//  Emojis:  buscador en español y pestañas por tipo (la primera, los que más usas). Flechas elegir · Tab cambiar de
//           pestaña · Intro pegar.
// Esc o un clic fuera la cierran. La parte de dentro es apogeo-portapapeles («portapapeles»).
Window {
    id: win
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Portapapeles de Apogeo"
    visible: false
    width: card.width + 2 * margin
    height: card.height + 2 * margin

    readonly property int margin: 22   // (para la sombra)
    property string mode: "copiado"
    property int sel: 0
    readonly property string query: field.text.trim()

    // Copiado: lo fijado primero y, si escribes, lo que lo lleva
    readonly property var shown: {
        const q = query.toLowerCase();
        const all = portapapeles.items.filter(i => !q || i.texto.toLowerCase().indexOf(q) >= 0);
        return all.filter(i => i.fijado).concat(all.filter(i => !i.fijado));
    }
    // Emojis
    property int tab: 0
    readonly property var emojis: mode !== "emojis" ? [] : query ? portapapeles.buscarEmojis(query) : portapapeles.emojisDe(tab)
    readonly property int cols: 8

    function open(m) {
        mode = m;
        field.text = "";
        sel = 0;
        // (sin emojis usados todavía, la primera pestaña sería vacía: caras)
        if (m === "emojis") tab = portapapeles.emojisDe(0).length ? 0 : 1;
        show();
        requestActivate();
        field.forceActiveFocus();
        appear.restart();
    }
    function close() { hide(); field.text = ""; }
    function choose(i) {
        if (mode === "copiado") {
            const it = shown[i];
            if (!it) return;
            close();
            portapapeles.pegar(it.id);
        } else {
            const e = emojis[i];
            if (!e) return;
            close();
            portapapeles.pegarEmoji(e.e);
        }
    }
    function move(d) {
        const n = mode === "copiado" ? shown.length : emojis.length;
        if (!n) return;
        sel = Math.max(0, Math.min(n - 1, sel + d));
        (mode === "copiado" ? list : grid).positionViewAtIndex(sel, ListView.Contain);
    }
    function nextTab(d) {
        const ids = [0].concat(portapapeles.categorias.map(c => c.id));
        tab = ids[(ids.indexOf(tab) + d + ids.length) % ids.length];
        field.text = "";
        sel = 0;
    }
    function when(t) {
        const d = new Date(t * 1000), now = new Date();
        if (d.toDateString() === now.toDateString()) return Qt.formatTime(d, "HH:mm");
        if (now - d < 2 * 86400000 && new Date(now - 86400000).toDateString() === d.toDateString()) return "ayer";
        return Qt.formatDate(d, "d MMM");
    }

    Connections {
        target: portapapeles
        function onAbrir(m) { win.visible && win.mode === m ? win.close() : win.open(m) }
    }
    Component.onCompleted: if (showAtStart) open(showAtStart)
    onActiveChanged: if (!active && visible) close()
    onQueryChanged: sel = 0

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        offset.y: 10; blur: 28; spread: -4
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Rectangle {
        id: card
        x: win.margin; y: win.margin
        width: 380
        height: col.height
        radius: Tema.r(20)
        color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.97)
        border.color: Tema.borde
        clip: true
        ParallelAnimation {
            id: appear
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; from: 0.96; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }

        Column {
            id: col
            width: parent.width

            // El campo
            Item {
                width: parent.width
                height: 52
                Icono {
                    x: 18; anchors.verticalCenter: parent.verticalCenter; width: 17; height: 17
                    nombre: win.mode === "copiado" ? "copia" : "emoji"; color: Tema.rosa
                }
                TextInput {
                    id: field
                    x: 46
                    width: parent.width - x - 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tema.texto
                    selectionColor: Tema.rosa
                    selectedTextColor: Tema.sobreRosa
                    font.family: Tema.letra
                    font.pixelSize: 15
                    clip: true
                    focus: true
                    Text {
                        visible: !field.text
                        text: win.mode === "copiado" ? "Buscar en lo copiado" : "Buscar emoji…"
                        color: Tema.tenue
                        font: field.font
                    }
                    Keys.onEscapePressed: win.close()
                    Keys.onReturnPressed: win.choose(win.sel)
                    Keys.onEnterPressed: win.choose(win.sel)
                    Keys.onDownPressed: win.move(win.mode === "copiado" ? 1 : win.cols)
                    Keys.onUpPressed: win.move(win.mode === "copiado" ? -1 : -win.cols)
                    Keys.onRightPressed: event => { if (win.mode === "emojis") win.move(1); else event.accepted = false; }
                    Keys.onLeftPressed: event => { if (win.mode === "emojis") win.move(-1); else event.accepted = false; }
                    Keys.onTabPressed: if (win.mode === "emojis") win.nextTab(1)
                    Keys.onBacktabPressed: if (win.mode === "emojis") win.nextTab(-1)
                    Keys.onPressed: event => {
                        if (win.mode !== "copiado" || !win.shown[win.sel]) return;
                        if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                            portapapeles.fijar(win.shown[win.sel].id);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Delete && !field.text) {
                            portapapeles.quitar(win.shown[win.sel].id);
                            win.sel = Math.min(win.sel, Math.max(0, win.shown.length - 1));
                            event.accepted = true;
                        }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Tema.linea }

            // ---------- Copiado ----------
            ListView {
                id: list
                visible: win.mode === "copiado" && count > 0
                width: parent.width
                height: visible ? Math.min(contentHeight, 6 * 58) + 12 : 0
                topMargin: 6; bottomMargin: 6
                clip: true
                model: win.mode === "copiado" ? win.shown : []
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: fila
                    required property var modelData
                    required property int index
                    readonly property bool on: win.sel === index
                    readonly property bool image: !!modelData.imagen
                    width: list.width
                    height: 58
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8; anchors.topMargin: 2; anchors.bottomMargin: 2
                        radius: Tema.r(12)
                        color: fila.on ? Tema.rosaSuave : "transparent"
                        border.color: fila.on ? Qt.rgba(Tema.rosa.r, Tema.rosa.g, Tema.rosa.b, 0.6) : "transparent"
                    }
                    MouseArea {
                        id: sobre
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.sel = fila.index
                        onClicked: win.choose(fila.index)
                    }
                    // La imagen, en pequeño
                    Rectangle {
                        id: mini
                        visible: fila.image
                        x: 20; anchors.verticalCenter: parent.verticalCenter
                        width: 62; height: 40
                        radius: Tema.r(8)
                        color: Tema.encima
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: fila.modelData.imagen
                            sourceSize: Qt.size(124, 80)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Column {
                        x: fila.image ? 94 : 20
                        width: parent.width - x - 76
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Texto {
                            width: parent.width
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            text: fila.image ? "Imagen" : fila.modelData.texto.slice(0, 300).replace(/\s+/g, " ").trim()
                            font.pixelSize: 14
                            font.weight: fila.image ? Font.Bold : Font.Normal
                        }
                        Texto {
                            width: parent.width
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            text: (fila.image ? (fila.modelData.ancho ? fila.modelData.ancho + " × " + fila.modelData.alto + " · " : "")
                                              : (fila.modelData.texto.indexOf("\n") >= 0 ? (fila.modelData.texto.split("\n").length + " líneas · ") : ""))
                                  + win.when(fila.modelData.hora)
                            color: Tema.tenue
                            font.pixelSize: 11
                        }
                    }
                    // 📌 y ✕ (se ven al pasar por encima; la chincheta, siempre si está fijado)
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Chiquito {
                            icono: "chincheta"
                            activo: fila.modelData.fijado
                            visible: fila.modelData.fijado || fila.on
                            ayuda: fila.modelData.fijado ? "Soltar" : "Fijar"
                            onPulsado: portapapeles.fijar(fila.modelData.id)
                        }
                        Chiquito {
                            icono: "cerrar"
                            visible: fila.on
                            ayuda: "Quitar"
                            onPulsado: portapapeles.quitar(fila.modelData.id)
                        }
                    }
                }
            }
            // Vacío
            Column {
                visible: win.mode === "copiado" && list.count === 0
                width: parent.width
                topPadding: 26; bottomPadding: 26
                spacing: 4
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.query ? "Nada copiado con «" + win.query + "»" : "Aún no has copiado nada"
                    font.weight: Font.Bold
                }
                Texto {
                    visible: !win.query
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Lo que copies saldrá aquí"
                    color: Tema.tenue
                    font.pixelSize: 12
                }
            }

            // ---------- Emojis ----------
            // Las pestañas
            Row {
                visible: win.mode === "emojis"
                x: 10
                topPadding: 8
                spacing: 2
                Repeater {
                    model: [{ id: 0, nombre: "Los que más usas", icono: "" }].concat(portapapeles.categorias)
                    delegate: Rectangle {
                        id: pestana
                        required property var modelData
                        readonly property bool on: !win.query && win.tab === modelData.id
                        width: 34; height: 32
                        radius: Tema.r(10)
                        color: on ? Tema.rosaSuave : toca.containsMouse ? Tema.encima : "transparent"
                        Icono { visible: !pestana.modelData.icono; anchors.centerIn: parent; width: 16; height: 16; nombre: "reloj"; color: pestana.on ? Tema.rosa : Tema.apagado }
                        Text {
                            visible: !!pestana.modelData.icono
                            anchors.centerIn: parent
                            text: pestana.modelData.icono
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 17
                            opacity: pestana.on ? 1 : 0.6
                        }
                        Rectangle { visible: pestana.on; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 14; height: 2; radius: 1; color: Tema.rosa }
                        MouseArea {
                            id: toca
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { win.tab = pestana.modelData.id; field.text = ""; win.sel = 0; field.forceActiveFocus(); }
                        }
                    }
                }
            }
            GridView {
                id: grid
                visible: win.mode === "emojis" && count > 0
                x: 12
                width: win.cols * cellWidth
                height: visible ? 5 * cellHeight + 8 : 0
                topMargin: 6
                cellWidth: 44.5; cellHeight: 44
                clip: true
                model: win.emojis
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: celda
                    required property var modelData
                    required property int index
                    width: 42; height: 42
                    radius: Tema.r(10)
                    color: win.sel === index ? Tema.rosaSuave : "transparent"
                    border.color: win.sel === index ? Qt.rgba(Tema.rosa.r, Tema.rosa.g, Tema.rosa.b, 0.6) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: celda.modelData.e
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 25
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.sel = celda.index
                        onClicked: win.choose(celda.index)
                    }
                }
            }
            Column {
                visible: win.mode === "emojis" && grid.count === 0
                width: parent.width
                topPadding: 40; bottomPadding: 40
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: win.query ? "Ningún emoji con «" + win.query + "»" : "Aquí saldrán los que más uses"
                    color: Tema.apagado
                }
            }

            // ---------- Abajo: qué es / las teclas ----------
            Rectangle { width: parent.width; height: 1; color: Tema.linea }
            Item {
                width: parent.width
                height: 36
                Texto {
                    x: 18
                    width: parent.width - 36 - (vaciar.visible ? vaciar.width + 8 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: win.mode === "emojis" && win.emojis[win.sel] ? Tema.apagado : Tema.tenue
                    text: win.mode === "emojis"
                          ? (win.emojis[win.sel] && win.emojis[win.sel].d ? win.emojis[win.sel].d.charAt(0).toUpperCase() + win.emojis[win.sel].d.slice(1)
                                                                          : "Tab cambia de pestaña · Intro lo pega")
                          : "Intro pega · Ctrl+P fija · Supr quita"
                }
                Texto {
                    id: vaciar
                    visible: win.mode === "copiado" && portapapeles.items.some(i => !i.fijado)
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Vaciar"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: borrar.containsMouse ? Tema.rosa : Tema.apagado
                    MouseArea { id: borrar; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: { portapapeles.vaciar(); win.sel = 0; } }
                }
            }
        }
    }

    component Chiquito: Rectangle {
        id: c
        property string icono
        property bool activo: false
        property string ayuda
        signal pulsado()
        width: 28; height: 28
        radius: Tema.r(8)
        color: area.containsMouse ? Tema.pulsado : "transparent"
        Icono {
            anchors.centerIn: parent
            width: 15; height: 15
            nombre: c.icono
            color: c.activo ? Tema.rosa : area.containsMouse ? Tema.texto : Tema.apagado
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: c.pulsado() }
    }
}
