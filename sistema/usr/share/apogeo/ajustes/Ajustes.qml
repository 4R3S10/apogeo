import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Effects
import Apogeo

// Ajustes de Apogeo, como «Personalizar» de Ágape: el buscador y las secciones a la izquierda, las tarjetas de cristal
// con los ajustes a la derecha. La parte de dentro es apogeo-ajustes («apogeo»); lo que se cambia se guarda al momento.
ApplicationWindow {
    id: win
    visible: true
    width: 1100
    height: 740
    minimumWidth: 860
    minimumHeight: 560
    title: "Ajustes de Apogeo"
    color: Tema.superficie
    font.family: Tema.letra

    readonly property var s: apogeo.settings
    readonly property var floors: [
        { clave: "jugar", texto: "Jugar", icono: "jugar" },
        { clave: "navegar", texto: "Navegar", icono: "navegar" },
        { clave: "estudiar", texto: "Estudiar", icono: "estudiar" }
    ]
    property int floor: 1
    readonly property string fk: floors[floor].clave
    readonly property var mine: s.pisos[fk]
    property string query: ""

    // Los fondos de muestra se mueven solo con la ventana delante (y si los fondos se animan)
    Binding { target: Tema; property: "animar"; value: apogeo.animate && win.active && win.s.animar }

    function plain(t) { return (t || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "") }
    function shown(sec) { return query === "" || plain(sec.titulo + " " + sec.palabras).indexOf(plain(query)) >= 0 }

    readonly property var sections: [pisos, isla, salud, agape, perfil, actualizaciones]
    property Item current: pisos
    property Item wanted: null       // la tocada a la izquierda (aunque no pueda subir del todo, por ser de las últimas)
    function go(sec) {
        wanted = sec;
        current = sec;
        scroll.to = Math.max(0, Math.min(sec.y, flick.contentHeight - flick.height));
        scroll.restart();
    }
    NumberAnimation { id: scroll; target: flick; property: "contentY"; duration: 280; easing.type: Easing.OutCubic }
    Component.onCompleted: {
        const first = { pisos: pisos, isla: isla, salud: salud, agape: agape, perfil: perfil, actualizaciones: actualizaciones }[apogeo.section];
        if (first && first !== pisos) Qt.callLater(() => go(first));
    }

    // ---------- La columna de la izquierda ----------

    Column {
        id: nav
        x: 22; y: 18
        width: 220
        spacing: 2
        Campo {
            width: parent.width
            implicitHeight: 36
            font.pixelSize: 13
            leftPadding: 36
            placeholderText: "Buscar un ajuste"
            onTextEdited: win.query = text.trim()
            Icono { x: 13; anchors.verticalCenter: parent.verticalCenter; nombre: "buscar"; color: Tema.tenue }
        }
        Item { width: 1; height: 8 }
        Repeater {
            model: [
                { sec: pisos, icono: "pisos" }, { sec: isla, icono: "isla" }, { sec: salud, icono: "salud" },
                { sec: agape, icono: "navegar" }, { sec: perfil, icono: "usuario" }, { sec: actualizaciones, icono: "actualizar" }
            ]
            delegate: NavItem {
                required property var modelData
                visible: modelData.sec.visible
                text: modelData.sec.titulo
                icono: modelData.icono
                on: win.current === modelData.sec
                onClicked: win.go(modelData.sec)
            }
        }
        Rectangle { width: parent.width - 24; x: 12; height: 1; color: Tema.borde; visible: win.query === "" }
        Item { width: 1; height: 4 }
        NavItem {
            visible: win.query === ""
            text: "Red, sonido, pantalla…"
            icono: "ajustes"
            onClicked: apogeo.open("sistema")
        }
    }

    component NavItem: AbstractButton {
        id: ni
        property string icono
        property bool on: false
        width: nav.width
        height: 38
        hoverEnabled: true
        background: Rectangle {
            radius: 11
            color: ni.on ? Tema.rosaSuave : ni.hovered ? Tema.encima : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Row {
            leftPadding: 12
            spacing: 10
            Icono { nombre: ni.icono; color: ni.on ? Tema.rosa : ni.hovered ? Tema.texto : Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
            Texto { text: ni.text; color: ni.on || ni.hovered ? Tema.texto : Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---------- Las tarjetas ----------

    Flickable {
        id: flick
        x: nav.x + nav.width + 22
        y: 18
        width: win.width - x - 16
        height: win.height - y
        contentHeight: body.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Tema.pulsado }
        }
        onContentYChanged: {
            if (win.wanted && scroll.running) { win.current = win.wanted; return; }
            if (win.wanted && !scroll.running && Math.abs(contentY - scroll.to) < 1) return; // (el final del salto)
            win.wanted = null;
            // La sección que se ve arriba es la marcada a la izquierda
            let cur = win.sections.find(x => x.visible) || pisos;
            for (const sec of win.sections) if (sec.visible && sec.y <= contentY + 60) cur = sec;
            win.current = cur;
        }

        Column {
            id: body
            width: flick.width - 14
            spacing: 16

            Texto {
                visible: !win.sections.some(x => x.visible)
                width: parent.width
                topPadding: 60
                horizontalAlignment: Text.AlignHCenter
                color: Tema.apagado
                text: "No hay ningún ajuste con «" + win.query + "»."
            }

            // ----- Pisos -----
            Seccion {
                id: pisos
                property string palabras: "fondo animado avisos notificaciones energia ahorro apps aplicaciones no molestar jugar navegar estudiar"
                width: parent.width
                visible: win.shown(pisos)
                titulo: "Pisos"
                intro: "Lo que cambia en cada piso. Los avisos que no salen se quedan en el historial."
                Fila {
                    linea: false
                    titulo: "Piso"
                    detalle: "El que estás cambiando"
                    Segmentos {
                        opciones: win.floors
                        actual: win.floor
                        onElegido: i => win.floor = i
                    }
                }
                Fila {
                    titulo: "Fondo"
                    ancha: true
                    Flow {
                        id: walls
                        width: parent.width
                        spacing: 10
                        readonly property real side: Math.floor((width - (Tema.fondos.length - 1) * spacing - 8) / Tema.fondos.length)
                        Repeater {
                            model: Tema.fondos.length
                            delegate: Column {
                                id: wall
                                required property int index
                                readonly property bool on: Tema.fondos[index] === win.mine.fondo
                                spacing: 6
                                Item {
                                    width: walls.side; height: Math.round(walls.side * 0.56)
                                    Fondo { anchors.fill: parent; tipo: wall.index; radio: 12 }
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        radius: 15
                                        color: "transparent"
                                        border.width: 2
                                        border.color: wall.on ? Tema.rosa : wallArea.containsMouse ? Tema.borde : "transparent"
                                    }
                                    MouseArea {
                                        id: wallArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: apogeo.set("pisos." + win.fk + ".fondo", Tema.fondos[wall.index])
                                    }
                                }
                                Texto {
                                    text: Tema.nombresFondos[wall.index]
                                    color: wall.on ? Tema.texto : Tema.apagado
                                    font.pixelSize: 12
                                    font.weight: wall.on ? Font.Bold : Font.Normal
                                }
                            }
                        }
                    }
                }
                Fila {
                    titulo: "Avisos"
                    detalle: win.mine.avisos ? "Te pueden llegar mientras estás en " + win.floors[win.floor].texto
                                             : "Lo que llegue se queda en el historial para luego"
                    Interruptor {
                        checked: win.mine.avisos
                        onToggled: apogeo.set("pisos." + win.fk + ".avisos", checked)
                    }
                }
                Fila {
                    titulo: "Energía"
                    detalle: "Nunca «rendimiento»: primero la salud del PC"
                    Segmentos {
                        opciones: [{ texto: "Ahorro" }, { texto: "Equilibrada" }]
                        actual: win.mine.energia === "power-saver" ? 0 : 1
                        onElegido: i => apogeo.set("pisos." + win.fk + ".energia", i === 0 ? "power-saver" : "balanced")
                    }
                }
                Fila {
                    titulo: "Apps al llegar"
                    detalle: "Se abren la primera vez que entras en el piso"
                    ancha: true
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: { win.s; return apogeo.floorApps(win.fk) } // (se recalcula al cambiar los ajustes)
                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                width: chipRow.implicitWidth + 16
                                height: 34
                                radius: 10
                                color: Tema.encima
                                Row {
                                    id: chipRow
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    Image {
                                        width: 20; height: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "image://icono/" + chip.modelData.icon
                                        sourceSize: Qt.size(40, 40)
                                    }
                                    Texto { text: chip.modelData.name; wrapMode: Text.NoWrap; anchors.verticalCenter: parent.verticalCenter }
                                    AbstractButton {
                                        id: rm
                                        width: 22; height: 22
                                        anchors.verticalCenter: parent.verticalCenter
                                        hoverEnabled: true
                                        background: Rectangle { radius: 7; color: rm.hovered ? Tema.pulsado : "transparent" }
                                        contentItem: Item { Icono { anchors.centerIn: parent; width: 12; height: 12; nombre: "cerrar"; color: rm.hovered ? Tema.texto : Tema.tenue } }
                                        onClicked: apogeo.removeApp(win.fk, chip.modelData.id)
                                        ToolTip.visible: hovered
                                        ToolTip.text: "Quitar"
                                    }
                                }
                            }
                        }
                        Boton {
                            height: 34
                            text: "Añadir"
                            icono: "mas"
                            onClicked: picker.open()
                        }
                    }
                }
                Item { width: 1; height: 10 }
                Texto { text: "En todos los pisos"; color: Tema.tenue; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.8; font.capitalization: Font.AllUppercase; bottomPadding: 2 }
                Fila {
                    titulo: "Animar los fondos"
                    detalle: apogeo.animate ? "A 30 imágenes por segundo como mucho, como en Ágape"
                                            : "Este equipo no tiene gráfica: se quedan quietos para no cargar el procesador"
                    Interruptor {
                        enabled: apogeo.animate
                        checked: win.s.animar && apogeo.animate
                        onToggled: apogeo.set("animar", checked)
                    }
                }
                Fila {
                    titulo: "No molestar"
                    detalle: "Sin avisos en ningún piso (también desde el panel rápido de la isla)"
                    Interruptor {
                        checked: win.s.silencio
                        onToggled: apogeo.set("silencio", checked)
                    }
                }
            }

            // ----- Isla -----
            Seccion {
                id: isla
                property string palabras: "barra esconder ocultar temperatura fps musica temporizador estudio"
                width: parent.width
                visible: win.shown(isla)
                titulo: "Isla"
                intro: "Tu barra de abajo. En cada piso enseña cosas distintas."
                Fila {
                    linea: false
                    titulo: "Isla: esconderse sola"
                    detalle: win.s.isla.esconder ? "Sale al acercar el ratón al borde de abajo" : "Siempre a la vista"
                    Interruptor { checked: win.s.isla.esconder; onToggled: apogeo.set("isla.esconder", checked) }
                }
                Fila {
                    titulo: "Barra de pisos: esconderse sola"
                    detalle: win.s.isla.esconderPisos ? "Sale al acercar el ratón al borde derecho" : "Siempre a la vista"
                    Interruptor { checked: win.s.isla.esconderPisos; onToggled: apogeo.set("isla.esconderPisos", checked) }
                }
                Fila {
                    titulo: "En Jugar: temperatura y FPS"
                    detalle: "Lo caliente que está el equipo y a cuántos FPS como mucho van los juegos"
                    Interruptor { checked: win.s.isla.jugar; onToggled: apogeo.set("isla.jugar", checked) }
                }
                Fila {
                    titulo: "En Navegar: la música"
                    detalle: "Lo que suena, con sus botones"
                    Interruptor { checked: win.s.isla.navegar; onToggled: apogeo.set("isla.navegar", checked) }
                }
                Fila {
                    titulo: "En Estudiar: el temporizador"
                    detalle: "25 minutos de estudio y 5 de descanso, y lo que llevas hoy"
                    Interruptor { checked: win.s.isla.estudiar; onToggled: apogeo.set("isla.estudiar", checked) }
                }
            }

            // ----- Salud del PC -----
            Seccion {
                id: salud
                property string palabras: "temperatura calor grados fps juegos velocidad ventiladores"
                width: parent.width
                visible: win.shown(salud)
                titulo: "Salud del PC"
                intro: "Primero la salud del equipo: nunca se fuerza, y si se calienta se le deja respirar."
                Fila {
                    linea: false
                    titulo: "Ahora"
                    detalle: "Se mira cada 3 segundos"
                    Row {
                        spacing: 16
                        Repeater {
                            model: [{ k: "cpu", n: "Procesador" }, { k: "gpu", n: "Gráfica" }]
                            delegate: Row {
                                required property var modelData
                                visible: apogeo.temps[modelData.k] !== undefined
                                spacing: 6
                                Icono { nombre: "temperatura"; color: (apogeo.temps[parent.modelData.k] || 0) >= apogeo.limit ? "#ff8f9a" : Tema.rosa; anchors.verticalCenter: parent.verticalCenter }
                                Texto { text: parent.modelData.n + " " + apogeo.temps[parent.modelData.k] + " °C"; wrapMode: Text.NoWrap; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                        Texto {
                            visible: apogeo.temps.cpu === undefined && apogeo.temps.gpu === undefined
                            text: "Sin sensores (¿máquina virtual?)"
                            color: Tema.apagado
                            wrapMode: Text.NoWrap
                        }
                    }
                }
                Fila {
                    titulo: "Temperatura máxima"
                    detalle: apogeo.healthMessage || ("A partir de " + limitSlider.value + " °C se baja la velocidad poco a poco; por debajo de "
                             + (limitSlider.value - 8) + " °C se devuelve")
                    Row {
                        spacing: 12
                        Deslizador {
                            id: limitSlider
                            from: 70; to: 85; stepSize: 1
                            snapMode: Slider.SnapAlways
                            value: apogeo.limit
                            anchors.verticalCenter: parent.verticalCenter
                            onPressedChanged: if (!pressed && value !== apogeo.limit) apogeo.setLimit(value)
                        }
                        Texto { width: 50; horizontalAlignment: Text.AlignRight; text: limitSlider.value + " °C"; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Fila {
                    titulo: "FPS máximos en los juegos"
                    detalle: "Juegos de Windows (Proton): menos calor y menos ruido. Vale al volver a entrar"
                    Segmentos {
                        opciones: [{ texto: "30" }, { texto: "45" }, { texto: "60" }]
                        actual: [30, 45, 60].indexOf(win.s.fps)
                        onElegido: i => apogeo.set("fps", [30, 45, 60][i])
                    }
                }
            }

            // ----- Ágape -----
            Seccion {
                id: agape
                property string palabras: "navegador llave token copia restaurar otro equipo bienvenida instalar"
                width: parent.width
                visible: win.shown(agape)
                titulo: "Ágape"
                intro: apogeo.agapeInstalled ? "Tu navegador. Se actualiza solo con tu llave." : "Tu navegador. Todavía no está instalado."
                Fila {
                    id: keyRow
                    linea: false
                    property bool editing: !apogeo.agapeInstalled
                    property string message: ""
                    property bool busy: false
                    titulo: apogeo.agapeInstalled ? "Llave de Ágape" : "Instalar Ágape"
                    detalle: keyRow.message !== "" ? keyRow.message
                           : win.installing ? "Descargando… " + Math.round(win.downloaded * 100) + " %"
                           : !apogeo.agapeInstalled ? "Escribe tu llave para descargarlo; se guarda solo en este equipo"
                           : apogeo.hasToken ? "Guardada solo en este equipo (para descargarlo y actualizarlo)" : "Sin llave: no se podrá actualizar"
                    Row {
                        spacing: 8
                        Campo {
                            id: keyField
                            visible: keyRow.editing
                            implicitWidth: 260
                            implicitHeight: 36
                            font.pixelSize: 13
                            echoMode: TextInput.Password
                            placeholderText: "Llave de Ágape"
                            onAccepted: saveKey.clicked()
                        }
                        Boton {
                            id: saveKey
                            visible: keyRow.editing
                            text: apogeo.agapeInstalled ? "Guardar" : "Descargar"
                            enabled: keyField.text.trim() !== "" && !keyRow.busy && !win.installing
                            onClicked: {
                                keyRow.message = "";
                                if (apogeo.agapeInstalled) { keyRow.busy = true; apogeo.saveToken(keyField.text); }
                                else { win.installing = true; win.downloaded = 0; apogeo.installAgape(keyField.text); }
                                keyField.text = "";
                            }
                        }
                        Girando { visible: keyRow.busy || win.installing; anchors.verticalCenter: parent.verticalCenter }
                        Boton {
                            visible: !keyRow.editing
                            text: apogeo.hasToken ? "Cambiar…" : "Poner llave…"
                            icono: "llave"
                            onClicked: { keyRow.editing = true; keyField.forceActiveFocus(); }
                        }
                    }
                    Connections {
                        target: apogeo
                        function onTokenSaved(ok, message) {
                            keyRow.busy = false;
                            keyRow.message = ok ? "Llave guardada" : message;
                            if (ok) keyRow.editing = false;
                        }
                        function onProgress(value) { win.downloaded = value }
                        function onInstalled(ok, message) {
                            win.installing = false;
                            keyRow.message = ok ? "Ágape instalado" : message;
                            if (ok) keyRow.editing = false;
                        }
                    }
                }
                Fila {
                    visible: apogeo.agapeInstalled
                    titulo: "Llevar Ágape a otro equipo"
                    detalle: "En Ágape: Personalizar → Avanzado → Crear una copia"
                    Boton { text: "Abrir Ágape"; onClicked: apogeo.open("agape") }
                }
                Fila {
                    visible: apogeo.agapeInstalled
                    titulo: "Traer una copia"
                    detalle: win.restored ? "Copia traída: Ágape se reinicia para ponerlo todo en su sitio"
                           : win.restoring ? "Escribe en Ágape la contraseña de la copia"
                           : "Un archivo .agape de tu otro equipo; Ágape te pedirá su contraseña"
                    Row {
                        spacing: 8
                        Girando { visible: win.restoring; anchors.verticalCenter: parent.verticalCenter }
                        Boton { text: "Elegir la copia…"; icono: "copia"; onClicked: copyDialog.open() }
                    }
                }
                Fila {
                    titulo: "Bienvenida de Apogeo"
                    detalle: "Tu nombre y tu foto, Ágape y tu copia, y cómo moverte por los pisos"
                    Boton { text: "Abrir"; onClicked: apogeo.open("bienvenida") }
                }
            }

            // ----- Tu perfil -----
            Seccion {
                id: perfil
                property string palabras: "nombre foto avatar cuenta usuario contraseña"
                width: parent.width
                visible: win.shown(perfil)
                titulo: "Tu perfil"
                intro: "Tu nombre y tu foto salen al iniciar sesión, en la pantalla de bloqueo y en el panel rápido."
                Item {
                    width: parent.width
                    height: 112
                    Foto {
                        id: bigFace
                        x: 4; y: 14
                        width: 80; height: 80
                        anillo: true
                        tipo: Math.max(0, win.face)
                        foto: win.photo
                        letra: win.name.trim().charAt(0).toUpperCase()
                        fuente: win.face < 0 && apogeo.iconFile ? "file://" + apogeo.iconFile : ""
                    }
                    Column {
                        x: 112; y: 10
                        width: parent.width - 112
                        spacing: 12
                        Row {
                            spacing: 10
                            Repeater {
                                model: 4
                                delegate: Foto {
                                    required property int index
                                    width: 36; height: 36
                                    tipo: index
                                    letra: win.name.trim().charAt(0).toUpperCase()
                                    elegida: win.face === index
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.face = parent.index }
                                }
                            }
                            Rectangle {
                                width: 36; height: 36; radius: 18
                                color: pickPhoto.containsMouse ? Tema.pulsado : Tema.encima
                                border.width: win.face === 4 ? 2 : 1.5
                                border.color: win.face === 4 ? Tema.rosa : Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.2)
                                Icono { anchors.centerIn: parent; nombre: "foto"; color: Tema.apagado }
                                MouseArea { id: pickPhoto; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: photoDialog.open() }
                                ToolTip.visible: pickPhoto.containsMouse
                                ToolTip.text: "Elegir una foto…"
                            }
                        }
                        Row {
                            spacing: 8
                            Campo {
                                implicitWidth: 260
                                implicitHeight: 36
                                font.pixelSize: 13
                                text: win.name
                                placeholderText: "Tu nombre"
                                maximumLength: 40
                                onTextEdited: win.name = text
                                onAccepted: win.saveProfile()
                            }
                            Boton {
                                text: "Guardar"
                                enabled: win.name.trim() !== "" && (win.face >= 0 || win.name.trim() !== apogeo.currentName)
                                onClicked: win.saveProfile()
                            }
                            Texto { text: win.profileMessage; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter; wrapMode: Text.NoWrap }
                        }
                    }
                }
                Fila {
                    titulo: "Contraseña"
                    detalle: "La de iniciar sesión y desbloquear"
                    Boton { text: "Cambiar…"; onClicked: apogeo.open("usuarios") }
                }
            }

            // ----- Actualizaciones -----
            Seccion {
                id: actualizaciones
                property string palabras: "version actualizar sistema paquetes pacman"
                width: parent.width
                visible: win.shown(actualizaciones)
                titulo: "Actualizaciones"
                intro: "Apogeo y todo el sistema se actualizan juntos."
                Fila {
                    linea: false
                    titulo: "Apogeo"
                    detalle: apogeo.version
                    Row {
                        spacing: 8
                        Girando { visible: apogeo.updates.estado === "buscando"; anchors.verticalCenter: parent.verticalCenter }
                        Boton {
                            visible: apogeo.updates.estado !== "hay"
                            text: "Buscar actualizaciones"
                            icono: "actualizar"
                            enabled: apogeo.updates.estado !== "buscando"
                            onClicked: apogeo.checkUpdates()
                        }
                        Boton {
                            visible: apogeo.updates.estado === "hay"
                            tipo: "principal"
                            text: "Actualizar ahora"
                            onClicked: apogeo.runUpdate()
                        }
                    }
                }
                Fila {
                    visible: apogeo.updates.estado !== "nada"
                    titulo: ({ buscando: "Buscando…", "al-dia": "Todo al día", hay: apogeo.updates.cuantas === 1 ? "Hay 1 actualización" : "Hay " + apogeo.updates.cuantas + " actualizaciones",
                               error: "No se ha podido buscar" })[apogeo.updates.estado] || ""
                    detalle: apogeo.updates.estado === "hay"
                             ? apogeo.updates.lista.join(", ") + (apogeo.updates.cuantas > apogeo.updates.lista.length ? "…" : "") + ". Se abre una terminal que te pide tu contraseña."
                             : apogeo.updates.estado === "error" ? "¿Hay conexión a internet?" : ""
                    Icono { visible: apogeo.updates.estado === "al-dia"; nombre: "hecho"; color: Tema.rosa }
                }
            }
        }
    }

    // ---------- Tu foto: como en la bienvenida ----------

    property int face: -1          // -1 la que tienes; 0…3 inicial o icono; 4 una foto tuya
    property url photo: ""
    property string name: apogeo.currentName
    property string profileMessage: ""
    function saveProfile() {
        profileMessage = "";
        if (face < 0) {
            const err = apogeo.saveName(name);
            profileMessage = err || "Guardado";
            return;
        }
        faceOut.grabToImage(r => {
            if (!r.saveToFile(apogeo.avatarPath)) { profileMessage = "No se ha podido guardar la foto."; return; }
            const err = apogeo.saveProfile(name);
            profileMessage = err || "Guardado";
            if (!err) { face = -1; bigFace.fuente = ""; bigFace.fuente = Qt.binding(() => win.face < 0 && apogeo.iconFile ? "file://" + apogeo.iconFile : ""); }
        }, Qt.size(256, 256));
    }
    Cara {
        id: faceOut
        x: -1000
        width: 256; height: 256
        tipo: Math.max(0, win.face)
        foto: win.photo
        letra: win.name.trim().charAt(0).toUpperCase()
    }
    FileDialog {
        id: photoDialog
        title: "Elige tu foto"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.svg)"]
        onAccepted: { win.photo = selectedFile; win.face = 4; }
    }

    // ---------- Ágape ----------

    property bool installing: false
    property real downloaded: 0
    property bool restoring: false
    property bool restored: false
    FileDialog {
        id: copyDialog
        title: "Elige tu copia de Ágape"
        currentFolder: apogeo.mediaFolder
        nameFilters: ["Copias de Ágape (*.agape)"]
        onAccepted: {
            const info = apogeo.copyInfo(selectedFile.toString());
            if (!info.path) return;
            win.restored = false;
            win.restoring = true;
            apogeo.restoreCopy(info.path);
        }
    }
    Connections {
        target: apogeo
        function onRestored() { win.restoring = false; win.restored = true; }
    }

    // ---------- Elegir una app para el piso ----------

    Popup {
        id: picker
        anchors.centerIn: Overlay.overlay
        width: 420
        height: Math.min(520, win.height - 80)
        modal: true
        padding: 14
        property var all: []
        onAboutToShow: { all = apogeo.allApps(); find.text = ""; find.forceActiveFocus(); }
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
        background: Rectangle { radius: 20; color: Tema.cromo; border.color: Tema.borde }
        contentItem: Column {
            spacing: 10
            Texto { text: "Añadir a " + win.floors[win.floor].texto; font.pixelSize: 17; font.weight: Font.ExtraBold }
            Campo {
                id: find
                width: parent.width
                implicitHeight: 38
                font.pixelSize: 13
                placeholderText: "Buscar una app"
            }
            ListView {
                width: parent.width
                height: picker.height - 120
                clip: true
                spacing: 2
                model: picker.all.filter(a => win.plain(a.name).indexOf(win.plain(find.text)) >= 0
                                              && win.mine.apps.indexOf(a.id) < 0)
                ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Tema.pulsado } }
                delegate: AbstractButton {
                    id: appRow
                    required property var modelData
                    width: ListView.view.width
                    height: 42
                    hoverEnabled: true
                    background: Rectangle { radius: 11; color: appRow.hovered ? Tema.encima : "transparent" }
                    contentItem: Row {
                        leftPadding: 10
                        spacing: 12
                        Image { width: 24; height: 24; source: "image://icono/" + appRow.modelData.icon; sourceSize: Qt.size(48, 48); anchors.verticalCenter: parent.verticalCenter; asynchronous: true }
                        Texto { text: appRow.modelData.name; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: { apogeo.addApp(win.fk, modelData.id); picker.close(); }
                }
            }
        }
    }
}
