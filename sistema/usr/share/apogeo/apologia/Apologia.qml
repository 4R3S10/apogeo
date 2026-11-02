import QtQuick
import QtQuick.Controls
import Apogeo

// apologIA, la IA de Apogeo en tu PC. A la izquierda los chats (y abajo Modelos y Modificador); en el centro la
// conversación, arriba el modelo y abajo lo que escribes, con lo que va gastando (velocidad, RAM, memoria). Lo de dentro
// es apogeo-apologia («apogeo»).
ApplicationWindow {
    id: win
    visible: true
    width: 1180
    height: 780
    minimumWidth: 860
    minimumHeight: 560
    title: "apologIA"
    color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.74)   // (transparente, como COSMIC)
    font.family: Tema.letra

    property string page: "chat"       // chat · modelos · modificador
    property string aviso: ""

    function tam(n) {
        if (n >= 1073741824) return (n / 1073741824).toFixed(1).replace(".", ",") + " GB";
        if (n >= 1048576) return Math.round(n / 1048576) + " MB";
        return Math.round((n || 0) / 1024) + " KB";
    }
    function miles(n) { return n >= 1000 ? (n / 1000).toFixed(n >= 10000 ? 0 : 1).replace(".", ",") + "k" : "" + (n || 0) }
    function cifra(n) { return n >= 1e6 ? (n / 1e6).toFixed(1).replace(".", ",") + " M" : n >= 1e3 ? Math.round(n / 1e3) + " mil" : "" + n }
    function coma(x, d) { return Number(x).toFixed(d).replace(".", ",") }
    function nombreModelo(a) {
        const m = apogeo.modelos.find(x => x.archivo === a);
        if (!m) return a.replace(/\.gguf$/, "");
        // (dos copias del mismo modelo: se distinguen por su calidad)
        return apogeo.modelos.filter(x => x.nombre === m.nombre).length > 1 && m.cuant ? m.nombre + " · " + m.cuant : m.nombre;
    }
    function calidadBaja(q) { return /^(UD-)?(IQ1|IQ2|Q2|TQ)/.test(q || "") }
    function descarga(a) { return apogeo.descargas.find(d => d.archivo === a) || null }
    function tienes(a) { return apogeo.modelos.some(m => m.archivo === a) }
    function enviar() {
        if (apogeo.generando || !entrada.text.trim()) return;
        if (apogeo.enviar(entrada.text)) { entrada.text = ""; lista.pegado = true }
    }

    Connections {
        target: apogeo
        function onAviso(t) { win.aviso = t; avisoTimer.restart() }
        function onMostrar() { win.raise(); win.requestActivate() }
        function onMensajesChanged() { lista.pegado = true; Qt.callLater(lista.bajar) }
    }
    Timer { id: avisoTimer; interval: 6000; onTriggered: win.aviso = "" }

    // ---------- Izquierda: los chats ----------

    Rectangle {
        id: side
        width: 264
        height: parent.height
        color: Tema.cromo
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tema.linea }

        Column {
            id: sideTop
            x: 14; y: 16
            width: parent.width - 28
            spacing: 14
            Row {
                leftPadding: 6
                spacing: 10
                Marca { width: 28; height: 28; vivo: apogeo.generando; anchors.verticalCenter: parent.verticalCenter }
                Texto { text: "apologIA"; font.pixelSize: 19; font.weight: Font.ExtraBold; anchors.verticalCenter: parent.verticalCenter }
            }
            Boton {
                width: parent.width
                text: "Nuevo chat"
                icono: "mas"
                onClicked: { apogeo.nuevoChat(); win.page = "chat"; entrada.forceActiveFocus() }
            }
        }

        ListView {
            id: chatList
            x: 14
            y: sideTop.y + sideTop.height + 14
            width: parent.width - 28
            height: sideBottom.y - y - 8
            clip: true
            spacing: 2
            model: apogeo.chats
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Barra {}
            delegate: ChatItem {}
            Texto {
                visible: chatList.count === 0
                width: parent.width
                topPadding: 8
                leftPadding: 12
                text: "Tus chats saldrán aquí."
                color: Tema.tenue
                font.pixelSize: 13
            }
        }

        Column {
            id: sideBottom
            x: 14
            width: parent.width - 28
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            spacing: 2
            Rectangle { width: parent.width - 24; x: 12; height: 1; color: Tema.linea }
            Item { width: 1; height: 6 }
            NavItem {
                text: "Modelos"
                icono: "descargar"
                on: win.page === "modelos"
                extra: { const n = apogeo.descargas.filter(d => d.estado === "bajando" || d.estado === "comprobando").length; return n ? "" + n : "" }
                onClicked: win.page = "modelos"
            }
            NavItem { text: "Modificador"; icono: "ajustes"; on: win.page === "modificador"; onClicked: win.page = "modificador" }
        }
    }

    component NavItem: AbstractButton {
        id: ni
        property string icono
        property string extra
        property bool on: false
        width: parent.width
        height: 38
        hoverEnabled: true
        background: Rectangle {
            radius: Tema.r(11)
            color: ni.on ? Tema.rosaSuave : ni.hovered ? Tema.encima : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Item {
            Row {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Icono { nombre: ni.icono; color: ni.on ? Tema.rosa : ni.hovered ? Tema.texto : Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                Texto { text: ni.text; color: ni.on || ni.hovered ? Tema.texto : Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle {
                visible: ni.extra !== ""
                anchors.right: parent.right; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(20, cuenta.implicitWidth + 10); height: 20; radius: 10
                color: Tema.acento
                Texto { id: cuenta; anchors.centerIn: parent; text: ni.extra; color: Tema.sobreAcento; font.pixelSize: 11; font.weight: Font.Bold }
            }
        }
    }

    // La barra de desplazamiento: solo si hay algo que desplazar
    component Barra: ScrollBar {
        id: sb
        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: Tema.pulsado
            opacity: sb.size < 1 ? (sb.active || sb.hovered ? 1 : 0.5) : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    component MiniBoton: AbstractButton {
        id: mb
        property string icono
        property color tinta: Tema.apagado
        width: 28; height: 28
        hoverEnabled: true
        background: Rectangle { radius: Tema.r(8); color: mb.hovered ? Tema.pulsado : "transparent" }
        contentItem: Item {
            Icono { anchors.centerIn: parent; width: 15; height: 15; nombre: mb.icono; color: mb.hovered ? Tema.texto : mb.tinta }
        }
    }

    component ChatItem: AbstractButton {
        id: ci
        required property var modelData
        property bool editando: false
        property bool armado: false     // (el primer clic en la papelera pregunta; el segundo borra)
        readonly property bool on: modelData.id === apogeo.chatId && win.page === "chat"
        width: ListView.view.width
        height: 38
        hoverEnabled: true
        onHoveredChanged: if (!hovered) armado = false
        background: Rectangle {
            radius: Tema.r(11)
            color: ci.on ? Tema.rosaSuave : ci.hovered ? Tema.encima : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Item {
            Texto {
                visible: !ci.editando
                x: 12
                width: parent.width - 12 - (ci.hovered ? 64 : 8)
                anchors.verticalCenter: parent.verticalCenter
                text: ci.armado ? "¿Borrar este chat?" : ci.modelData.titulo
                color: ci.armado ? Tema.error : ci.on || ci.hovered ? Tema.texto : Tema.apagado
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
            TextInput {
                id: renombre
                visible: ci.editando
                x: 12
                width: parent.width - 24
                anchors.verticalCenter: parent.verticalCenter
                color: Tema.texto
                font.family: Tema.letra
                font.pixelSize: 14
                selectionColor: Tema.rosa
                selectedTextColor: Tema.sobreRosa
                clip: true
                onAccepted: { apogeo.renombrarChat(ci.modelData.id, text); ci.editando = false }
                onActiveFocusChanged: if (!activeFocus) ci.editando = false
                Keys.onEscapePressed: ci.editando = false
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: ci.hovered && !ci.editando
                spacing: 2
                MiniBoton {
                    icono: "lapiz"
                    onClicked: { ci.editando = true; renombre.text = ci.modelData.titulo; renombre.selectAll(); renombre.forceActiveFocus() }
                }
                MiniBoton {
                    icono: "cerrar"
                    tinta: ci.armado ? Tema.error : Tema.apagado
                    onClicked: { if (ci.armado) apogeo.borrarChat(ci.modelData.id); else ci.armado = true }
                }
            }
        }
        onClicked: { apogeo.abrirChat(modelData.id); win.page = "chat" }
        onDoubleClicked: { editando = true; renombre.text = modelData.titulo; renombre.selectAll(); renombre.forceActiveFocus() }
    }

    // ---------- El chat ----------

    Item {
        id: chatPage
        x: side.width
        width: win.width - x
        height: win.height
        visible: win.page === "chat"
        readonly property real col: Math.min(780, width - 64)

        // Arriba: el modelo (y si está cargando, listo o ha fallado)
        Item {
            id: bar
            width: parent.width
            height: 62
            AbstractButton {
                id: selector
                x: 22
                anchors.verticalCenter: parent.verticalCenter
                height: 40
                width: selRow.implicitWidth + 28
                hoverEnabled: true
                background: Rectangle {
                    radius: Tema.r(12)
                    color: selector.hovered || menu.visible ? Tema.encima : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                contentItem: Item {
                    Row {
                        id: selRow
                        anchors.centerIn: parent
                        spacing: 9
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: apogeo.motor === "listo" ? Tema.exito : apogeo.motor === "error" ? Tema.error
                                 : apogeo.motor === "cargando" ? Tema.acento : Tema.tenue
                            SequentialAnimation on opacity {
                                running: apogeo.motor === "cargando"
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation { to: 0.25; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                        Texto {
                            text: apogeo.modelo ? win.nombreModelo(apogeo.modelo) : "Elige un modelo"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            wrapMode: Text.NoWrap
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Texto {
                            visible: apogeo.motor === "cargando"
                            text: "cargando…"
                            color: Tema.apagado
                            wrapMode: Text.NoWrap
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Texto { text: "▾"; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                onClicked: menu.open()
            }
            Boton {
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                tipo: "plano"
                icono: "ajustes"
                text: "Modificador"
                onClicked: win.page = "modificador"
            }

            Popup {
                id: menu
                x: selector.x
                y: selector.y + selector.height + 6
                width: 400
                padding: 8
                background: Rectangle { radius: Tema.r(16); color: Tema.elevada; border.color: Tema.borde }
                contentItem: Column {
                    spacing: 2
                    Repeater {
                        model: apogeo.modelos
                        delegate: AbstractButton {
                            id: op
                            required property var modelData
                            width: 384
                            height: 54
                            hoverEnabled: true
                            background: Rectangle { radius: Tema.r(11); color: op.hovered ? Tema.encima : "transparent" }
                            contentItem: Item {
                                Column {
                                    x: 12
                                    width: parent.width - 52
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Texto { text: op.modelData.nombre; width: parent.width; wrapMode: Text.NoWrap; elide: Text.ElideRight }
                                    Texto {
                                        text: [op.modelData.parametros, op.modelData.cuant, win.tam(op.modelData.tamano)].filter(x => x).join(" · ")
                                        color: Tema.apagado
                                        font.pixelSize: 12
                                    }
                                }
                                Icono {
                                    visible: op.modelData.archivo === apogeo.modelo
                                    nombre: "hecho"
                                    color: Tema.acento
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            onClicked: {
                                menu.close();
                                if (modelData.archivo !== apogeo.modelo || apogeo.motor === "error" || apogeo.motor === "apagado")
                                    apogeo.elegirModelo(modelData.archivo);
                            }
                        }
                    }
                    Texto { visible: apogeo.modelos.length === 0; text: "Aún no tienes modelos."; color: Tema.apagado; padding: 12 }
                    Rectangle { width: 384; height: 1; color: Tema.linea }
                    AbstractButton {
                        id: mas
                        width: 384
                        height: 42
                        hoverEnabled: true
                        background: Rectangle { radius: Tema.r(11); color: mas.hovered ? Tema.encima : "transparent" }
                        contentItem: Row {
                            leftPadding: 12
                            spacing: 10
                            Icono { nombre: "buscar"; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                            Texto { text: "Buscar más modelos"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        onClicked: { menu.close(); win.page = "modelos" }
                    }
                }
            }
        }

        Rectangle {
            id: fallo
            visible: apogeo.motor === "error"
            x: (parent.width - width) / 2
            y: bar.height
            width: chatPage.col
            height: visible ? Math.max(52, falloT.implicitHeight + 24) : 0
            radius: Tema.r(14)
            color: Qt.rgba(Tema.error.r, Tema.error.g, Tema.error.b, 0.12)
            Texto {
                id: falloT
                x: 16
                width: parent.width - reintentar.width - 44
                anchors.verticalCenter: parent.verticalCenter
                text: apogeo.motorDetalle
            }
            Boton {
                id: reintentar
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "Reintentar"
                onClicked: apogeo.reintentar()
            }
        }

        ListView {
            id: lista
            y: bar.height + (fallo.visible ? fallo.height + 8 : 0)
            width: parent.width
            height: composer.y - y - 10
            clip: true
            model: apogeo.mensajes
            spacing: 24
            topMargin: 12
            bottomMargin: 12
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: Barra {}
            property bool pegado: true      // (abajo del todo: sigue a lo que va escribiendo)
            function bajar() { contentY = Math.max(originY - topMargin, originY + contentHeight + bottomMargin - height) }
            onMovementEnded: pegado = contentY >= originY + contentHeight + bottomMargin - height - 30
            onContentHeightChanged: if (pegado) bajar()
            onHeightChanged: if (pegado) bajar()
            delegate: Mensaje {
                required property var modelData
                required property int index
                m: modelData
                ultimo: index === lista.count - 1
            }
            footer: Item {
                width: lista.width
                height: apogeo.generando ? enCurso.height + 24 : 0
                Mensaje {
                    id: enCurso
                    y: 24
                    visible: apogeo.generando
                    vivo: true
                    m: ({ rol: "assistant", texto: apogeo.parcial, razon: apogeo.parcialRazon })
                }
            }
        }

        // Sin mensajes: la marca grande y una invitación
        Column {
            visible: apogeo.mensajes.length === 0 && !apogeo.generando
            anchors.horizontalCenter: lista.horizontalCenter
            y: lista.y + (lista.height - height) / 2 - 20
            spacing: 14
            Marca { width: 72; height: 72; anchors.horizontalCenter: parent.horizontalCenter }
            Item { width: 1; height: 4 }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: apogeo.modelos.length ? "¿Sobre qué quieres razonar?" : "Para empezar, baja un modelo"
                font.pixelSize: 26
                font.weight: Font.Bold
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                text: apogeo.modelos.length ? "Todo pasa en tu PC: nada sale de él."
                                            : "De Hugging Face, de GitHub o de cualquier enlace (en formato GGUF)."
                color: Tema.apagado
            }
            Boton {
                visible: !apogeo.modelos.length
                anchors.horizontalCenter: parent.horizontalCenter
                tipo: "principal"
                text: "Buscar modelos"
                onClicked: win.page = "modelos"
            }
        }

        // Abajo: lo que escribes
        Rectangle {
            id: composer
            x: (parent.width - width) / 2
            width: chatPage.col
            y: statsLine.y - height - 10
            height: Math.min(230, Math.max(58, entrada.implicitHeight + 18))
            radius: Tema.r(20)
            color: Tema.encima
            border.width: 1
            border.color: entrada.activeFocus ? Tema.tinte(0.2) : Tema.borde
            Flickable {
                id: escribe
                x: 16
                y: 9
                width: parent.width - 16 - 58
                height: parent.height - 18
                contentHeight: entrada.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextArea.flickable: TextArea {
                    id: entrada
                    placeholderText: "Escribe a apologIA…"
                    placeholderTextColor: Tema.tenue
                    color: Tema.texto
                    selectionColor: Tema.rosa
                    selectedTextColor: Tema.sobreRosa
                    font.family: Tema.letra
                    font.pixelSize: 15
                    wrapMode: TextArea.Wrap
                    leftPadding: 0; rightPadding: 0; topPadding: 10; bottomPadding: 10
                    background: null
                    focus: true
                    Keys.onPressed: (e) => {
                        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                            e.accepted = true;
                            win.enviar();
                        }
                    }
                }
            }
            AbstractButton {
                id: mandar
                readonly property bool parar: apogeo.generando
                readonly property bool listo: entrada.text.trim() !== ""
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                width: 40; height: 40
                hoverEnabled: true
                enabled: parar || listo
                background: Rectangle {
                    radius: Tema.r(14)
                    color: mandar.parar ? Tema.texto : mandar.listo ? (mandar.hovered ? Qt.lighter(Tema.acento, 1.08) : Tema.acento) : Tema.pulsado
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                contentItem: Item {
                    Rectangle { visible: mandar.parar; anchors.centerIn: parent; width: 12; height: 12; radius: 2; color: Tema.superficie }
                    Icono {
                        visible: !mandar.parar
                        anchors.centerIn: parent
                        nombre: "enviar"
                        color: mandar.listo ? Tema.sobreAcento : Tema.tenue
                    }
                }
                onClicked: parar ? apogeo.parar() : win.enviar()
            }
        }

        // Lo que gasta: velocidad, RAM, memoria de la conversación y GPU
        Texto {
            id: statsLine
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - height - 12
            color: Tema.tenue
            font.pixelSize: 12
            wrapMode: Text.NoWrap
            text: {
                const s = apogeo.stats, p = [];
                if (apogeo.motor === "listo" || apogeo.motor === "cargando") {
                    if (s.tps) p.push(win.coma(s.tps, 1) + " tok/s");
                    if (s.ram) p.push(s.ram + " de RAM");
                    if (s.contextoMax) p.push(win.miles(s.contexto || 0) + " de " + win.miles(s.contextoMax) + " de memoria");
                    if (apogeo.motor === "listo") p.push(s.gpu ? "GPU: " + s.gpu + " capas" : "en el procesador");
                }
                if (s.recortado) p.push("lo más antiguo ya no cabe en su memoria");
                return p.join("   ·   ") || "Todo pasa en tu PC";
            }
        }
    }

    component Mensaje: Item {
        id: msg
        property var m: ({})
        property bool ultimo: false
        property bool vivo: false
        readonly property bool tuyo: m.rol === "user"
        readonly property real col: chatPage.col
        width: lista.width
        height: tuyo ? burbuja.height : cuerpo.implicitHeight
        HoverHandler { id: encima }

        // Lo tuyo: a la derecha, en una burbuja
        Texto { id: medida; visible: false; text: msg.tuyo ? msg.m.texto : ""; font.pixelSize: 15; wrapMode: Text.NoWrap }
        Rectangle {
            id: burbuja
            visible: msg.tuyo
            width: Math.min(msg.col * 0.8, medida.implicitWidth + 36)
            x: (msg.width + msg.col) / 2 - width
            height: tuyoT.implicitHeight + 22
            radius: Tema.r(18)
            color: Tema.encima
            TextEdit {
                id: tuyoT
                x: 18; y: 11
                width: parent.width - 36
                text: msg.tuyo ? msg.m.texto : ""
                textFormat: TextEdit.PlainText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                color: Tema.texto
                selectionColor: Tema.rosa
                selectedTextColor: Tema.sobreRosa
                font.family: Tema.letra
                font.pixelSize: 15
            }
        }

        // Lo de apologIA: la marca a la izquierda, lo que pensó (plegado) y la respuesta
        Row {
            id: cuerpo
            visible: !msg.tuyo
            x: (msg.width - msg.col) / 2
            spacing: 14
            Marca { width: 24; height: 24; vivo: msg.vivo; y: 2 }
            Column {
                width: msg.col - 38
                spacing: 8
                AbstractButton {
                    id: piensa
                    property bool abierto: false
                    readonly property bool pensando: msg.vivo && !msg.m.texto
                    visible: !!msg.m.razon
                    height: 24
                    width: piensaRow.implicitWidth
                    background: Item {}
                    contentItem: Row {
                        id: piensaRow
                        spacing: 6
                        Texto {
                            text: piensa.pensando ? "Pensando…" : "Lo que ha pensado"
                            color: Tema.apagado
                            font.pixelSize: 13
                            font.italic: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Texto { text: piensa.abierto || piensa.pensando ? "▴" : "▾"; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: abierto = !abierto
                }
                Item {
                    visible: piensa.visible && (piensa.abierto || piensa.pensando)
                    width: parent.width
                    height: razonT.implicitHeight
                    Rectangle { width: 2; height: parent.height; radius: 1; color: Tema.linea }
                    TextEdit {
                        id: razonT
                        x: 14
                        width: parent.width - 14
                        text: msg.m.razon || ""
                        textFormat: TextEdit.PlainText
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        color: Tema.apagado
                        selectionColor: Tema.rosa
                        font.family: Tema.letra
                        font.pixelSize: 13
                    }
                }
                TextEdit {
                    visible: text !== ""
                    width: parent.width
                    text: msg.m.texto || ""
                    textFormat: TextEdit.MarkdownText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Tema.texto
                    selectionColor: Tema.rosa
                    selectedTextColor: Tema.sobreRosa
                    font.family: Tema.letra
                    font.pixelSize: 15
                    onLinkActivated: (l) => apogeo.web(l)
                }
                Girando { visible: msg.vivo && !msg.m.texto && !msg.m.razon }
                Texto { visible: !!msg.m.error; width: parent.width; text: msg.m.error || ""; color: Tema.error }
                Texto {
                    visible: !!msg.m.parado || !!msg.m.cortado
                    text: msg.m.parado ? "Parado" : "Se ha cortado: llegó al largo máximo (Modificador)"
                    color: Tema.tenue
                    font.pixelSize: 12
                }
                Row {
                    visible: !msg.vivo && (!!msg.m.texto || !!msg.m.error)
                    opacity: encima.hovered || msg.ultimo ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    spacing: 2
                    MiniBoton { visible: !!msg.m.texto; icono: "copia"; onClicked: apogeo.copiar(msg.m.texto) }
                    MiniBoton { visible: msg.ultimo && !apogeo.generando; icono: "actualizar"; onClicked: apogeo.regenerar() }
                    Texto {
                        leftPadding: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: [msg.m.modelo, msg.m.tps ? win.coma(msg.m.tps, 1) + " tok/s" : ""].filter(x => x).join(" · ")
                        color: Tema.tenue
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // ---------- Modelos ----------

    property int pestana: 0            // tus modelos · Hugging Face · GitHub · enlace o archivo
    property var hallados: ({ hf: [], github: [] })
    property var buscado: ({ hf: null, github: null })
    property string buscaError: ""
    property bool buscando: false
    property var repo: null
    property string repoError: ""
    property bool cargandoRepo: false
    property string colabPath: ""
    readonly property string origen: pestana === 2 ? "github" : "hf"

    function buscar(texto) {
        buscando = true;
        buscaError = "";
        apogeo.buscar(origen, texto.trim());
    }
    function abrirRepo(o, r) { repo = null; repoError = ""; cargandoRepo = true; apogeo.verArchivos(o, r) }
    function elegirPestana(i) {
        pestana = i; repo = null; repoError = ""; buscaError = "";
        if ((i === 1 || i === 2) && buscado[origen] === null) buscar(campoBusca.text);
    }
    onPageChanged: if (page === "modelos" && (pestana === 1 || pestana === 2) && buscado[origen] === null) buscar("")
    // La primera vez (sin modelos), directa al buscador de Hugging Face
    Component.onCompleted: if (!apogeo.modelos.length) { pestana = 1; page = "modelos" }

    Connections {
        target: apogeo
        function onResultados(o, texto, lista, error) {
            if (o !== win.origen || texto !== campoBusca.text.trim()) return;
            const h = Object.assign({}, win.hallados), b = Object.assign({}, win.buscado);
            h[o] = lista; b[o] = texto;
            win.hallados = h; win.buscado = b;
            win.buscaError = error; win.buscando = false;
        }
        function onArchivos(info, error) { win.cargandoRepo = false; win.repo = error ? null : info; win.repoError = error }
        function onColabListo(path) { win.colabPath = path }
    }

    // Lo elegido en el diálogo de KDE: un .gguf que ya tienes, o la carpeta de los modelos (si ya tienes alguno, antes
    // se pregunta si llevarlos)
    property string nuevaCarpeta: ""
    Connections {
        target: apogeo
        function onElegido(que, ruta) {
            if (que === "archivo") apogeo.importar(ruta);
            else if (apogeo.modelos.length) win.nuevaCarpeta = ruta;
            else apogeo.cambiarCarpeta(ruta, false);
        }
    }
    function legible(url) { return decodeURIComponent(url.replace(/^file:\/\//, "")) }

    Flickable {
        id: modelosPage
        x: side.width
        width: win.width - x
        height: win.height
        visible: win.page === "modelos"
        contentHeight: mcol.height + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Barra {}

        Column {
            id: mcol
            x: Math.max(32, (modelosPage.width - width) / 2)
            y: 26
            width: Math.min(900, modelosPage.width - 64)
            spacing: 18

            Column {
                width: parent.width
                spacing: 4
                Texto { text: "Modelos"; font.pixelSize: 26; font.weight: Font.ExtraBold }
                Texto {
                    width: parent.width
                    text: "Se guardan en " + apogeo.carpeta + ". Quedan " + apogeo.libre + " libres en ese disco; tienes "
                          + apogeo.ram + " de RAM."
                    color: Tema.apagado
                }
                Row {
                    topPadding: 8
                    spacing: 8
                    Boton { text: "Cambiar carpeta"; icono: "carpeta"; enabled: !apogeo.moviendo; onClicked: apogeo.preguntar("carpeta") }
                    Boton { tipo: "plano"; text: "Abrir la carpeta"; onClicked: apogeo.carpetaModelos() }
                }
            }

            Row {
                visible: apogeo.moviendo !== ""
                spacing: 10
                Girando {}
                Texto { text: apogeo.moviendo; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
            }

            Seccion {
                visible: win.nuevaCarpeta !== ""
                width: parent.width
                titulo: "¿Te llevo los modelos?"
                intro: "Tienes " + apogeo.modelos.length + (apogeo.modelos.length === 1 ? " modelo (" : " modelos (")
                       + win.tam(apogeo.modelos.reduce((t, m) => t + (m.enlace ? 0 : m.tamano), 0)) + ") en " + apogeo.carpeta
                       + ". ¿Los muevo a " + win.legible(win.nuevaCarpeta) + "?"
                Row {
                    topPadding: 10
                    spacing: 8
                    Boton { tipo: "principal"; text: "Moverlos"; onClicked: { apogeo.cambiarCarpeta(win.nuevaCarpeta, true); win.nuevaCarpeta = "" } }
                    Boton { text: "No, empezar vacía"; onClicked: { apogeo.cambiarCarpeta(win.nuevaCarpeta, false); win.nuevaCarpeta = "" } }
                    Boton { tipo: "plano"; text: "Cancelar"; onClicked: win.nuevaCarpeta = "" }
                }
                Texto {
                    width: parent.width
                    topPadding: 8
                    color: Tema.tenue
                    font.pixelSize: 12
                    text: "Si no los mueves, se quedan donde están y dejan de salir aquí (puedes volver a esa carpeta cuando quieras)."
                }
            }

            // Lo que se está bajando
            Repeater {
                model: apogeo.descargas
                delegate: Rectangle {
                    id: dl
                    required property var modelData
                    readonly property bool activa: modelData.estado === "bajando" || modelData.estado === "comprobando"
                    width: mcol.width
                    height: 66
                    radius: Tema.r(14)
                    color: Tema.encima
                    Column {
                        x: 16
                        width: parent.width - 150
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        Texto { text: dl.modelData.archivo; width: parent.width; wrapMode: Text.NoWrap; elide: Text.ElideMiddle }
                        Rectangle {
                            visible: dl.modelData.estado === "bajando"
                            width: parent.width; height: 4; radius: 2
                            color: Tema.tinte(0.12)
                            Rectangle {
                                width: dl.modelData.total ? parent.width * Math.min(1, dl.modelData.hecho / dl.modelData.total) : 0
                                height: 4; radius: 2
                                color: Tema.acento
                            }
                        }
                        Texto {
                            width: parent.width
                            wrapMode: Text.NoWrap
                            elide: Text.ElideRight
                            font.pixelSize: 12
                            color: dl.modelData.estado === "error" ? Tema.error : Tema.apagado
                            text: dl.modelData.estado === "bajando"
                                  ? win.tam(dl.modelData.hecho) + (dl.modelData.total ? " de " + win.tam(dl.modelData.total) : "") + (dl.modelData.velocidad ? " · " + dl.modelData.velocidad : "")
                                  : dl.modelData.estado === "comprobando" ? "Comprobando que ha llegado entero…"
                                  : dl.modelData.estado === "hecho" ? "Listo: ya está en tus modelos" : dl.modelData.error
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Boton {
                            visible: dl.modelData.estado === "error" && !!dl.modelData.f
                            text: "Otra vez"
                            onClicked: apogeo.descargar(dl.modelData.f, dl.modelData.repo)
                        }
                        Boton {
                            tipo: "plano"
                            text: dl.activa ? "Cancelar" : "Quitar"
                            onClicked: dl.activa ? apogeo.cancelarDescarga(dl.modelData.archivo) : apogeo.olvidarDescarga(dl.modelData.archivo)
                        }
                    }
                }
            }

            // El cuaderno de Colab, recién escrito
            Seccion {
                visible: win.colabPath !== ""
                width: parent.width
                titulo: "Cuaderno de Colab listo"
                intro: "Guardado en " + win.colabPath
                Texto {
                    width: parent.width
                    topPadding: 6
                    bottomPadding: 12
                    lineHeight: 1.3
                    text: "1. En Colab: Archivo → Subir cuaderno, y elige este archivo.\n"
                        + "2. Entorno de ejecución → Cambiar tipo de entorno → GPU T4 (gratis).\n"
                        + "3. Entorno de ejecución → Ejecutar todo. El chat sale al final del propio cuaderno."
                }
                Row {
                    spacing: 8
                    Boton { tipo: "principal"; text: "Abrir Colab"; onClicked: apogeo.web("https://colab.research.google.com/") }
                    Boton { text: "Ver el archivo"; icono: "carpeta"; onClicked: apogeo.verArchivo(win.colabPath) }
                    Boton { tipo: "plano"; text: "Cerrar"; onClicked: win.colabPath = "" }
                }
            }

            Segmentos {
                opciones: [{ texto: "Tus modelos", icono: "hecho" }, { texto: "Hugging Face", icono: "buscar" },
                           { texto: "GitHub", icono: "web" }, { texto: "Enlace o archivo", icono: "carpeta" }]
                actual: win.pestana
                onElegido: (i) => win.elegirPestana(i)
            }

            // Tus modelos
            Column {
                visible: win.pestana === 0
                width: parent.width
                spacing: 0
                Texto {
                    visible: apogeo.modelos.length === 0
                    width: parent.width
                    bottomPadding: 14
                    text: "Aún no tienes ninguno. Búscalos en Hugging Face o GitHub, pega un enlace o añade un .gguf que ya tengas."
                    color: Tema.apagado
                }
                Repeater {
                    model: apogeo.modelos
                    delegate: Item {
                        id: mf
                        required property var modelData
                        property bool armado: false
                        readonly property bool enUso: modelData.archivo === apogeo.modelo
                        width: mcol.width
                        height: 70
                        Rectangle { width: parent.width; height: 1; color: Tema.linea }
                        Column {
                            y: (parent.height - height) / 2
                            width: parent.width - botones.width - 20
                            spacing: 4
                            Row {
                                spacing: 10
                                Texto { text: mf.modelData.nombre; font.weight: Font.DemiBold; wrapMode: Text.NoWrap; anchors.verticalCenter: parent.verticalCenter }
                                Etiqueta { va: mf.modelData.va; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Texto {
                                width: parent.width
                                wrapMode: Text.NoWrap
                                elide: Text.ElideRight
                                color: Tema.apagado
                                font.pixelSize: 12
                                text: [mf.modelData.parametros, mf.modelData.cuant + (win.calidadBaja(mf.modelData.cuant) ? " (calidad baja)" : ""),
                                       win.tam(mf.modelData.tamano),
                                       mf.modelData.contextoMax ? "memoria máx. " + win.miles(mf.modelData.contextoMax) : "",
                                       mf.modelData.enlace ? "en otra carpeta" : ""].filter(x => x).join(" · ")
                            }
                        }
                        Row {
                            id: botones
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Boton {
                                tipo: mf.enUso ? "normal" : "principal"
                                grande: false
                                text: mf.enUso ? "En uso" : "Usar"
                                enabled: !mf.enUso || apogeo.motor === "error"
                                onClicked: { apogeo.elegirModelo(mf.modelData.archivo); win.page = "chat" }
                            }
                            Boton {
                                tipo: "plano"
                                text: mf.armado ? (mf.modelData.enlace ? "¿Quitar de la lista?" : "¿Borrar del disco?") : "Quitar"
                                onClicked: { if (mf.armado) apogeo.quitarModelo(mf.modelData.archivo); else mf.armado = true }
                            }
                        }
                        HoverHandler { onHoveredChanged: if (!hovered) mf.armado = false }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Tema.linea; visible: apogeo.modelos.length > 0 }
                Row {
                    topPadding: 16
                    spacing: 8
                    Boton { text: "Añadir un .gguf del PC"; icono: "mas"; onClicked: apogeo.preguntar("archivo") }
                }
            }

            // Buscar en Hugging Face o GitHub
            Column {
                visible: (win.pestana === 1 || win.pestana === 2) && !win.repo && !win.cargandoRepo
                width: parent.width
                spacing: 12
                Campo {
                    id: campoBusca
                    width: parent.width
                    leftPadding: 40
                    placeholderText: win.pestana === 2 ? "Buscar en GitHub (proyectos con modelos GGUF)…" : "Buscar en Hugging Face (qwen, llama, gemma, mistral…)"
                    onTextEdited: buscaTimer.restart()
                    onAccepted: { buscaTimer.stop(); win.buscar(text) }
                    Icono { x: 14; anchors.verticalCenter: parent.verticalCenter; nombre: "buscar"; color: Tema.tenue }
                    Timer { id: buscaTimer; interval: 450; onTriggered: win.buscar(campoBusca.text) }
                }
                Texto {
                    width: parent.width
                    color: win.buscaError ? Tema.error : Tema.apagado
                    font.pixelSize: 13
                    text: win.buscaError ? win.buscaError
                        : win.buscando ? "Buscando…"
                        : (win.hallados[win.origen] || []).length === 0 && win.buscado[win.origen] !== null ? "No hay nada con eso."
                        : win.pestana === 1 ? (win.buscado.hf ? "Lo más bajado con «" + win.buscado.hf + "»" : "Lo más bajado ahora")
                        : "Proyectos de GitHub con más estrellas. Dentro se ven sus .gguf (de sus versiones o del propio repositorio)."
                }
                Repeater {
                    model: win.hallados[win.origen] || []
                    delegate: AbstractButton {
                        id: rf
                        required property var modelData
                        width: mcol.width
                        height: rfCol.implicitHeight + 22
                        hoverEnabled: true
                        background: Rectangle { radius: Tema.r(12); color: rf.hovered ? Tema.encima : "transparent" }
                        contentItem: Item {
                            Column {
                                id: rfCol
                                x: 12
                                width: parent.width - cifras.width - 36
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Texto { text: rf.modelData.nombre; font.weight: Font.DemiBold; width: parent.width; wrapMode: Text.NoWrap; elide: Text.ElideRight }
                                Texto {
                                    width: parent.width
                                    text: rf.modelData.autor + (rf.modelData.detalle ? " · " + rf.modelData.detalle : "")
                                    color: Tema.apagado
                                    font.pixelSize: 12
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                }
                            }
                            Texto {
                                id: cifras
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                color: Tema.tenue
                                font.pixelSize: 12
                                text: rf.modelData.origen === "github" ? "★ " + win.cifra(rf.modelData.likes)
                                    : "↓ " + win.cifra(rf.modelData.descargas) + "   ♥ " + win.cifra(rf.modelData.likes)
                            }
                        }
                        onClicked: win.abrirRepo(rf.modelData.origen, rf.modelData.repo)
                    }
                }
            }

            // Un enlace (o un archivo que ya tengas)
            Column {
                visible: win.pestana === 3 && !win.repo && !win.cargandoRepo
                width: parent.width
                spacing: 12
                Texto {
                    width: parent.width
                    color: Tema.apagado
                    text: "Pega el enlace de un repositorio de Hugging Face o GitHub, o el de un archivo .gguf de cualquier web."
                }
                Row {
                    width: parent.width
                    spacing: 8
                    Campo {
                        id: campoEnlace
                        width: parent.width - ver.width - 8
                        placeholderText: "https://…"
                        onAccepted: ver.clicked()
                    }
                    Boton {
                        id: ver
                        height: 44
                        text: "Ver"
                        enabled: campoEnlace.text.trim() !== ""
                        onClicked: { win.repo = null; win.repoError = ""; win.cargandoRepo = true; apogeo.enlace(campoEnlace.text) }
                    }
                }
                Row {
                    topPadding: 6
                    spacing: 8
                    Boton { text: "Elegir un .gguf del PC"; icono: "carpeta"; onClicked: apogeo.preguntar("archivo") }
                }
                Texto {
                    width: parent.width
                    color: Tema.tenue
                    font.pixelSize: 12
                    text: "Solo se aceptan modelos GGUF: son solo datos. Los .bin o .pt de PyTorch pueden llevar código escondido y no se abren."
                }
            }

            Texto { visible: win.repoError !== "" && !win.repo; width: parent.width; text: win.repoError; color: Tema.error }
            Row {
                visible: win.cargandoRepo
                spacing: 10
                Girando {}
                Texto { text: "Mirando qué modelos tiene…"; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
            }

            // Un repositorio: sus archivos (cada uno, una versión del modelo con otra calidad y otro tamaño)
            Column {
                visible: !!win.repo && (win.pestana !== 0)
                width: parent.width
                spacing: 12
                Boton { tipo: "plano"; text: "← " + (win.pestana === 3 ? "Otro enlace" : "Resultados"); onClicked: { win.repo = null; win.repoError = "" } }
                Item {
                    width: parent.width
                    height: repoCol.implicitHeight
                    Column {
                        id: repoCol
                        width: parent.width - enWeb.width - 12
                        spacing: 4
                        Texto { text: win.repo ? win.repo.repo : ""; font.pixelSize: 20; font.weight: Font.ExtraBold; width: parent.width }
                        Texto {
                            width: parent.width
                            color: Tema.apagado
                            font.pixelSize: 13
                            text: win.repo ? [win.repo.arquitectura, win.repo.contextoMax ? "memoria máx. " + win.miles(win.repo.contextoMax) : "",
                                              win.repo.licencia ? "licencia " + win.repo.licencia : ""].filter(x => x).join(" · ") : ""
                        }
                    }
                    Boton {
                        id: enWeb
                        anchors.right: parent.right
                        tipo: "plano"
                        icono: "web"
                        text: "Ver en la web"
                        onClicked: apogeo.web(win.repo.web)
                    }
                }
                Aviso {
                    width: parent.width
                    text: win.repo && win.repo.conLicencia
                          ? "Este modelo pide aceptar su licencia en su web y tu token de Hugging Face" + (apogeo.tokenHf ? "." : " (en Modificador → Hugging Face).")
                          : ""
                }
                Texto {
                    visible: !!win.repo && win.repo.archivos.length === 0
                    width: parent.width
                    color: Tema.apagado
                    text: "Aquí no hay modelos GGUF."
                }
                Texto {
                    visible: !!win.repo && win.repo.archivos.length > 1
                    width: parent.width
                    color: Tema.tenue
                    font.pixelSize: 12
                    text: "Cada archivo es el mismo modelo con otra calidad: Q4_K_M suele ser el mejor equilibrio; Q8 es mejor y ocupa el doble; Q2 y Q3, más pequeños y peores."
                }
                Repeater {
                    model: win.repo ? win.repo.archivos : []
                    delegate: Item {
                        id: af
                        required property var modelData
                        readonly property var bajada: win.descarga(modelData.archivo)
                        readonly property bool loTienes: win.tienes(modelData.archivo)
                        width: mcol.width
                        height: 64
                        Rectangle { width: parent.width; height: 1; color: Tema.linea }
                        Column {
                            y: (parent.height - height) / 2
                            width: parent.width - afBotones.width - 20
                            spacing: 4
                            Row {
                                width: parent.width
                                spacing: 10
                                Texto {
                                    text: af.modelData.cuant || af.modelData.archivo
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.NoWrap
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Etiqueta { visible: af.modelData.tamano > 0; va: af.modelData.va; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Texto {
                                width: parent.width
                                wrapMode: Text.NoWrap
                                elide: Text.ElideMiddle
                                color: Tema.apagado
                                font.pixelSize: 12
                                text: [af.modelData.tamano ? win.tam(af.modelData.tamano) : "tamaño desconocido",
                                       win.calidadBaja(af.modelData.cuant) ? "calidad baja" : "",
                                       af.modelData.partes.length > 1 ? af.modelData.partes.length + " partes" : "",
                                       af.modelData.archivo].filter(x => x).join(" · ")
                            }
                        }
                        Row {
                            id: afBotones
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Boton {
                                visible: win.repo && win.repo.origen === "hf"
                                tipo: "plano"
                                text: "Colab"
                                icono: "nube"
                                onClicked: apogeo.colab(win.repo, af.modelData)
                            }
                            Boton {
                                icono: af.loTienes ? "" : "descargar"
                                enabled: !af.bajada || (af.bajada.estado !== "bajando" && af.bajada.estado !== "comprobando")
                                text: af.loTienes ? "Usar" : af.bajada && af.bajada.estado === "bajando"
                                      ? (af.bajada.total ? Math.floor(100 * af.bajada.hecho / af.bajada.total) + " %" : "Bajando…")
                                      : af.bajada && af.bajada.estado === "comprobando" ? "Comprobando…" : "Descargar"
                                onClicked: {
                                    if (af.loTienes) { apogeo.elegirModelo(af.modelData.archivo); win.page = "chat" }
                                    else apogeo.descargar(af.modelData, win.repo.repo);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component Etiqueta: Rectangle {
        id: et
        property string va
        readonly property color c: va === "rapido" ? Tema.exito : va === "lento" ? "#ffc857" : Tema.error
        implicitWidth: etT.implicitWidth + 16
        implicitHeight: 22
        radius: 11
        color: Qt.rgba(c.r, c.g, c.b, 0.14)
        Texto {
            id: etT
            anchors.centerIn: parent
            text: et.va === "rapido" ? "Va bien en tu PC" : et.va === "lento" ? "Justo para tu RAM" : "No cabe en la RAM: muy lento"
            color: et.c
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    // ---------- El modificador ----------

    function guardar(c) { apogeo.guardarAjustes(c) }
    Connections {
        target: apogeo
        // (al mover un deslizador se suelta de su valor: «Como venía» los vuelve a poner)
        function onAjustesChanged() {
            const a = apogeo.ajustes;
            if (!largo.pressed) largo.value = a.largo || 2048;
            if (!temp.pressed) temp.value = a.temperatura;
            if (!topP.pressed) topP.value = a.top_p;
            if (!topK.pressed) topK.value = a.top_k;
            if (!minP.pressed) minP.value = a.min_p;
            if (!rep.pressed) rep.value = a.repeticion;
            if (!hilos.pressed) hilos.value = a.hilos;
        }
    }

    Flickable {
        id: modPage
        x: side.width
        width: win.width - x
        height: win.height
        visible: win.page === "modificador"
        contentHeight: modCol.height + 60
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: Barra {}

        Column {
            id: modCol
            x: Math.max(32, (modPage.width - width) / 2)
            y: 26
            width: Math.min(820, modPage.width - 64)
            spacing: 18

            Item {
                width: parent.width
                height: modTitulo.implicitHeight
                Column {
                    id: modTitulo
                    width: parent.width - 160
                    spacing: 4
                    Texto { text: "Modificador"; font.pixelSize: 26; font.weight: Font.ExtraBold }
                    Texto { width: parent.width; text: "Cómo responde apologIA, en todos los chats (y en el cuaderno de Colab)."; color: Tema.apagado }
                }
                Boton { anchors.right: parent.right; tipo: "plano"; icono: "deshacer"; text: "Como venía"; onClicked: apogeo.restablecer() }
            }

            Seccion {
                width: parent.width
                titulo: "Instrucciones"
                intro: "Lo que el modelo lee antes de cada conversación: quién es, cómo debe hablar… Vacío: ninguna, responde a su manera."
                Rectangle {
                    width: parent.width
                    height: 150
                    radius: Tema.r(12)
                    color: Tema.encima
                    border.width: 1
                    border.color: sistema.activeFocus ? Tema.rosa : Tema.tinte(0.12)
                    Flickable {
                        x: 14; y: 4
                        width: parent.width - 28
                        height: parent.height - 8
                        contentHeight: sistema.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        TextArea.flickable: TextArea {
                            id: sistema
                            placeholderText: "Por ejemplo: «Eres un profesor de física paciente. Explica con ejemplos y en español.»"
                            placeholderTextColor: Tema.tenue
                            color: Tema.texto
                            selectionColor: Tema.rosa
                            selectedTextColor: Tema.sobreRosa
                            font.family: Tema.letra
                            font.pixelSize: 14
                            wrapMode: TextArea.Wrap
                            leftPadding: 0; rightPadding: 0
                            background: null
                            Component.onCompleted: text = apogeo.ajustes.sistema
                            onTextChanged: if (text !== apogeo.ajustes.sistema) guardaSistema.restart()
                            Timer { id: guardaSistema; interval: 500; onTriggered: win.guardar({ sistema: sistema.text }) }
                            Connections {
                                target: apogeo
                                function onAjustesChanged() { if (!sistema.activeFocus) sistema.text = apogeo.ajustes.sistema }
                            }
                        }
                    }
                }
                Item { width: 1; height: 14 }
            }

            Seccion {
                width: parent.width
                titulo: "Respuestas"
                Fila {
                    titulo: "Largo"
                    detalle: apogeo.ajustes.largo === 0 ? "Sin límite: acaba cuando ha terminado de responder."
                             : "Como mucho " + apogeo.ajustes.largo + " tokens (unas " + Math.round(apogeo.ajustes.largo * 0.7) + " palabras)."
                    Row {
                        spacing: 10
                        Texto { text: "Sin límite"; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                        Interruptor {
                            checked: apogeo.ajustes.largo === 0
                            onToggled: win.guardar({ largo: checked ? 0 : 2048 })
                        }
                    }
                }
                Fila {
                    visible: apogeo.ajustes.largo > 0
                    titulo: "Máximo"
                    detalle: Math.round(largo.value) + " tokens"
                    Deslizador {
                        id: largo
                        from: 128; to: 16384; stepSize: 128
                        value: apogeo.ajustes.largo || 2048
                        onPressedChanged: if (!pressed) win.guardar({ largo: Math.round(value) })
                    }
                }
                Fila {
                    titulo: "Pensar antes de responder"
                    detalle: "En los modelos que razonan (Qwen3, DeepSeek R1…): tardan más, pero aciertan más en lo difícil."
                    Interruptor { checked: apogeo.ajustes.pensar; onToggled: win.guardar({ pensar: checked }) }
                }
                Fila {
                    titulo: "Estilo"
                    detalle: "Preciso se ciñe a lo seguro; Creativo se arriesga más con las palabras."
                    Segmentos {
                        opciones: [{ texto: "Preciso" }, { texto: "Equilibrado" }, { texto: "Creativo" }]
                        actual: { apogeo.ajustes; return ["preciso", "equilibrado", "creativo"].indexOf(apogeo.estiloActual()) }
                        onElegido: (i) => apogeo.estilo(["preciso", "equilibrado", "creativo"][i])
                    }
                }
                Fila {
                    titulo: "Creatividad"
                    detalle: "Temperatura " + win.coma(temp.value, 2) + (temp.value > 1.3 ? ": muy alta, puede desvariar" : "")
                    Deslizador {
                        id: temp
                        from: 0; to: 2; stepSize: 0.05
                        value: apogeo.ajustes.temperatura
                        onPressedChanged: if (!pressed) win.guardar({ temperatura: Math.round(value * 100) / 100 })
                    }
                }
                AbstractButton {
                    id: avanzado
                    property bool abierto: false
                    width: parent.width
                    height: 44
                    background: Item {}
                    contentItem: Texto { text: (avanzado.abierto ? "▴ " : "▾ ") + "Más ajustes de cómo elige las palabras"; color: Tema.apagado; verticalAlignment: Text.AlignVCenter }
                    onClicked: abierto = !abierto
                }
                Fila {
                    visible: avanzado.abierto
                    titulo: "Top P"
                    detalle: win.coma(topP.value, 2) + ": solo entre las palabras que suman esa probabilidad"
                    Deslizador { id: topP; from: 0.05; to: 1; stepSize: 0.01; value: apogeo.ajustes.top_p; onPressedChanged: if (!pressed) win.guardar({ top_p: Math.round(value * 100) / 100 }) }
                }
                Fila {
                    visible: avanzado.abierto
                    titulo: "Top K"
                    detalle: topK.value === 0 ? "Sin límite de candidatas" : "Entre las " + Math.round(topK.value) + " palabras más probables"
                    Deslizador { id: topK; from: 0; to: 200; stepSize: 1; value: apogeo.ajustes.top_k; onPressedChanged: if (!pressed) win.guardar({ top_k: Math.round(value) }) }
                }
                Fila {
                    visible: avanzado.abierto
                    titulo: "Min P"
                    detalle: win.coma(minP.value, 2) + ": descarta las palabras mucho menos probables que la mejor"
                    Deslizador { id: minP; from: 0; to: 0.5; stepSize: 0.01; value: apogeo.ajustes.min_p; onPressedChanged: if (!pressed) win.guardar({ min_p: Math.round(value * 100) / 100 }) }
                }
                Fila {
                    visible: avanzado.abierto
                    titulo: "No repetirse"
                    detalle: win.coma(rep.value, 2) + (rep.value <= 1.001 ? ": sin castigo" : ": castiga repetir palabras")
                    Deslizador { id: rep; from: 1; to: 1.5; stepSize: 0.01; value: apogeo.ajustes.repeticion; onPressedChanged: if (!pressed) win.guardar({ repeticion: Math.round(value * 100) / 100 }) }
                }
            }

            Seccion {
                width: parent.width
                titulo: "Memoria y equipo"
                intro: "Cambiar esto vuelve a cargar el modelo (la conversación no se pierde)."
                Fila {
                    titulo: "Memoria de la conversación"
                    detalle: "Cuánto recuerda a la vez. Más memoria gasta más RAM."
                    Segmentos {
                        readonly property var valores: [4096, 8192, 16384, 32768, 0]
                        opciones: [{ texto: "4k" }, { texto: "8k" }, { texto: "16k" }, { texto: "32k" }, { texto: "Máxima" }]
                        actual: valores.indexOf(apogeo.ajustes.contexto)
                        onElegido: (i) => win.guardar({ contexto: valores[i] })
                    }
                }
                Fila {
                    titulo: "GPU"
                    detalle: apogeo.ajustes.gpu === "cpu" ? "Todo en el procesador y la RAM."
                             : "Pone en la GPU lo que quepa, el resto en la RAM y, si no cabe, lo lee del disco."
                    Segmentos {
                        opciones: [{ texto: "Automática" }, { texto: "Solo procesador" }]
                        actual: apogeo.ajustes.gpu === "cpu" ? 1 : 0
                        onElegido: (i) => win.guardar({ gpu: i ? "cpu" : "auto" })
                    }
                }
                Fila {
                    titulo: "Hilos del procesador"
                    detalle: Math.round(hilos.value) === 0 ? "Los que elija llama.cpp" : Math.round(hilos.value) + " de " + apogeo.nucleos
                    Deslizador {
                        id: hilos
                        from: 0; to: apogeo.nucleos; stepSize: 1
                        value: apogeo.ajustes.hilos
                        onPressedChanged: if (!pressed) win.guardar({ hilos: Math.round(value) })
                    }
                }
            }

            Seccion {
                width: parent.width
                titulo: "Hugging Face"
                intro: "Algunos modelos (Llama, Gemma…) piden aceptar su licencia en huggingface.co. Para bajarlos, pega aquí tu token "
                       + "(huggingface.co → Settings → Access Tokens, de solo lectura). Se guarda solo en este PC."
                Row {
                    topPadding: 8
                    bottomPadding: 6
                    spacing: 8
                    Campo {
                        id: token
                        width: 360
                        echoMode: TextInput.Password
                        placeholderText: apogeo.tokenHf ? "Guardado (escribe otro para cambiarlo)" : "hf_…"
                        onAccepted: guardaToken.clicked()
                    }
                    Boton {
                        id: guardaToken
                        height: 44
                        text: "Guardar"
                        enabled: token.text.trim() !== ""
                        onClicked: { apogeo.guardarToken(token.text); token.text = "" }
                    }
                    Boton { visible: apogeo.tokenHf; height: 44; tipo: "plano"; text: "Borrar"; onClicked: apogeo.guardarToken("") }
                }
            }
        }
    }

    // Un aviso abajo
    Rectangle {
        visible: win.aviso !== ""
        x: side.width + (win.width - side.width - width) / 2
        y: win.height - height - 96
        width: Math.min(560, avisoT.implicitWidth + 36)
        height: avisoT.implicitHeight + 22
        radius: Tema.r(14)
        color: Tema.elevada
        border.color: Tema.borde
        Texto { id: avisoT; x: 18; y: 11; width: Math.min(524, implicitWidth); text: win.aviso }
    }
}
