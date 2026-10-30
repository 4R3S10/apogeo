import QtQuick
import QtQuick.Effects
import org.kde.layershell as LayerShell
import Apogeo

// El centro de control de Jugar (el botón PS o Xbox, como en la PS5): una fila de tarjetas abajo, encima del juego y sin
// pararlo: lo que suena (⏮ ⏯ ⏭), Discord (tu micro y abrirlo al lado del juego), los avisos que han llegado en la
// partida, el volumen y volver a la consola. ← → elegir · ✕ (A) hacer · ↑ ↓ el volumen · ○ (B) o el botón otra vez,
// cerrar. Con el botón central mantenido, → ← cambian de canción y ↑ ↓ el volumen: sale solo un aviso pequeño arriba.
// Va en la capa de encima de todo (layer-shell); mientras está abierto, el mando es solo suyo (lo coge apogeo-consola).
Window {
    id: win
    property bool abierto: false
    flags: Qt.FramelessWindowHint | (abierto ? 0 : Qt.WindowTransparentForInput)
    color: "transparent"
    LayerShell.Window.scope: "apogeo-centro"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.wantsToBeOnActiveScreen: true
    LayerShell.Window.keyboardInteractivity: abierto ? LayerShell.Window.KeyboardInteractivityExclusive
                                                     : LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.activateOnShow: abierto
    title: "Centro de control"
    visible: false
    Component.onCompleted: Tema.piso = "jugar"

    readonly property var btn: consola.mando === "xbox" ? { a: "A", b: "B" } : { a: "✕", b: "○" }
    property var d: ({ musica: {}, discord: {}, avisos: [], volumen: null })
    readonly property bool suena: !!(d.musica && d.musica.titulo)
    // Lo que se puede elegir, en orden (sin música, «Abrir Spotify» en vez de los tres botones)
    readonly property var focos: (suena ? ["anterior", "pausa", "siguiente"] : ["spotify"])
                                 .concat(["micro", "discord", "volumen", "consola"])
    property int foco: 0
    readonly property string elegido: focos[Math.min(foco, focos.length - 1)]

    function leer() { try { d = JSON.parse(consola.centro()); } catch (e) {} }
    function abrir() {
        leer();
        foco = focos.indexOf("pausa") >= 0 ? 1 : 0;
        toast = "";
        if (visible) hide();          // (de solo el aviso a abierto: la capa se pide otra vez, ahora con el teclado)
        abierto = true;
        consola.setCentro(true);
        show(); raise(); requestActivate();
        aparecer.restart();
    }
    function cerrar() {
        if (!abierto) return;
        abierto = false;
        consola.setCentro(false);
        hide();
    }
    function mover(n) { foco = Math.max(0, Math.min(focos.length - 1, foco + n)); }
    function luego() { leerLuego.restart(); }
    Timer { id: leerLuego; interval: 450; onTriggered: win.leer() }
    Timer { interval: 1500; repeat: true; running: win.abierto; onTriggered: win.leer() }

    function hacer(que) {
        if (que === "anterior") consola.musica("Previous");
        else if (que === "siguiente") consola.musica("Next");
        else if (que === "pausa") consola.musica("PlayPause");
        else if (que === "spotify") { cerrar(); consola.spotify(); return; }
        else if (que === "micro") consola.micro();
        else if (que === "volumen") consola.volumen(0);
        else if (que === "discord") { cerrar(); consola.discord(); return; }
        else if (que === "consola") { cerrar(); consola.traer(); return; }
        luego();
    }
    function key(k) {
        if (k === "izquierda") mover(-1);
        else if (k === "derecha") mover(1);
        else if (k === "a") hacer(elegido);
        else if (k === "b" || k === "start") cerrar();
        else if ((k === "arriba" || k === "abajo") && elegido === "volumen") { consola.volumen(k === "arriba" ? 0.05 : -0.05); luego(); }
    }

    // ----- El aviso pequeño de los atajos (botón central mantenido + flechas) -----
    property string toast: ""
    property string toastIcono: ""
    function avisar(icono, texto) {
        toastIcono = icono; toast = texto;
        if (!visible) show();
        toastTimer.restart();
    }
    Timer { id: toastTimer; interval: 1800; onTriggered: { win.toast = ""; if (!win.abierto) win.hide(); } }
    function atajo(que) {
        if (que === "siguiente" || que === "anterior") {
            consola.musica(que === "siguiente" ? "Next" : "Previous");
            avisar(que, que === "siguiente" ? "Siguiente canción" : "Canción anterior");
            cancion.restart();          // (y en cuanto cambia, cuál es)
        } else {
            consola.volumen(que === "subir" ? 0.05 : -0.05);
            volumenLuego.restart();
        }
    }
    Timer {
        id: cancion; interval: 700
        onTriggered: { win.leer(); if (win.suena) win.avisar(win.toastIcono, win.d.musica.titulo + (win.d.musica.artista ? " · " + win.d.musica.artista : "")); }
    }
    Timer {
        id: volumenLuego; interval: 120
        onTriggered: { win.leer(); if (win.d.volumen) win.avisar("volumen", "Volumen " + Math.round(win.d.volumen.nivel * 100) + " %"); }
    }

    Connections {
        target: consola
        function onGuia() { win.abierto ? win.cerrar() : win.abrir() }
        function onAtajo(what) { win.atajo(what) }
        function onPad(button) { if (win.abierto) win.key(button) }
        function onShown() { win.cerrar() }
    }
    onActiveChanged: if (!active && abierto) cerrar()

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const m = { [Qt.Key_Left]: "izquierda", [Qt.Key_Right]: "derecha", [Qt.Key_Up]: "arriba", [Qt.Key_Down]: "abajo",
                        [Qt.Key_Return]: "a", [Qt.Key_Enter]: "a", [Qt.Key_Space]: "a", [Qt.Key_Escape]: "b" };
            if (m[e.key]) { win.key(m[e.key]); e.accepted = true; }
        }
    }

    // ----- El aviso de arriba -----
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.toast ? 32 : 12
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        opacity: win.toast && !win.abierto ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        width: Math.min(tr.implicitWidth + 28, win.width - 48); height: 40; radius: 20
        color: Qt.rgba(0.03, 0.04, 0.06, 0.86)
        border.color: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, 0.35)
        Row {
            id: tr
            anchors.centerIn: parent
            spacing: 10
            Icono { nombre: win.toastIcono === "anterior" ? "anterior" : win.toastIcono === "volumen" ? "volumen" : "siguiente"; color: Tema.acento; anchors.verticalCenter: parent.verticalCenter }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, win.width - 120)
                text: win.toast; elide: Text.ElideRight; wrapMode: Text.NoWrap
                font { pixelSize: 13; weight: Font.Medium }
                color: "#e9edf5"
            }
        }
    }

    // ----- El centro -----
    Rectangle {   // el juego se oscurece un poco por abajo (se sigue viendo)
        anchors.fill: parent
        visible: win.abierto
        gradient: Gradient {
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.62) }
        }
        MouseArea { anchors.fill: parent; onClicked: win.cerrar() }
    }

    Item {
        id: panel
        visible: win.abierto
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        width: col.width; height: col.height
        scale: Math.min(1, (win.width - 48) / col.width)
        transformOrigin: Item.Bottom
        ParallelAnimation {
            id: aparecer
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "anchors.bottomMargin"; from: 16; to: 40; duration: 220; easing.type: Easing.OutCubic }
        }
        MouseArea { anchors.fill: parent }   // (un clic entre tarjetas no lo cierra)

        Column {
            id: col
            spacing: 14
            Row {
                spacing: 10
                x: 4
                Nucleo { width: 22; height: 22; disco: false; anchors.verticalCenter: parent.verticalCenter }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CENTRO DE CONTROL"
                    font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 2.6 }
                    color: Qt.rgba(0.91, 0.93, 0.96, 0.7)
                }
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "← → elegir · " + win.btn.a + " hacer · " + win.btn.b + " cerrar"
                    font { family: Tema.mono; pixelSize: 10 }
                    color: Qt.rgba(0.91, 0.93, 0.96, 0.45)
                }
            }
            Row {
                spacing: 14

                // Lo que suena
                Tarjeta {
                    width: 384
                    Row {
                        spacing: 14
                        Rectangle {
                            width: 96; height: 96; radius: 12
                            color: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, 0.14)
                            clip: true
                            Icono { anchors.centerIn: parent; width: 28; height: 28; nombre: "musica"; color: Tema.acento; visible: portada.status !== Image.Ready }
                            Image {
                                id: portada
                                anchors.fill: parent
                                source: win.suena ? (win.d.musica.portada || "") : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }
                        Column {
                            width: 384 - 36 - 96 - 14
                            spacing: 4
                            Etiqueta { text: win.suena ? (win.d.musica.app || "Música") : "Música" }
                            Texto {
                                width: parent.width
                                text: win.suena ? win.d.musica.titulo : "No suena nada"
                                elide: Text.ElideRight; wrapMode: Text.NoWrap
                                font { pixelSize: 16; weight: Font.Bold }
                                color: "#e9edf5"
                            }
                            Texto {
                                width: parent.width
                                text: win.suena ? (win.d.musica.artista || "") : "Spotify, con un botón"
                                elide: Text.ElideRight; wrapMode: Text.NoWrap
                                font.pixelSize: 13
                                color: Qt.rgba(0.91, 0.93, 0.96, 0.6)
                            }
                            Item { width: 1; height: 6 }
                            Row {
                                spacing: 8
                                visible: win.suena
                                Mando { clave: "anterior"; icono: "anterior" }
                                Mando { clave: "pausa"; icono: win.d.musica.sonando ? "pausa" : "reproducir"; ancho: 52 }
                                Mando { clave: "siguiente"; icono: "siguiente" }
                            }
                            Mando { clave: "spotify"; icono: "musica"; texto: "Abrir Spotify"; visible: !win.suena }
                        }
                    }
                }

                // Discord
                Tarjeta {
                    width: 236
                    Column {
                        spacing: 4
                        width: 200
                        Row {
                            spacing: 8
                            Etiqueta { text: "Discord" }
                            Rectangle {
                                visible: (win.d.discord.mensajes || 0) > 0
                                width: Math.max(18, mn.implicitWidth + 10); height: 18; radius: 9
                                color: "#ff6b81"
                                Texto { id: mn; anchors.centerIn: parent; text: win.d.discord.mensajes || ""; font { pixelSize: 11; weight: Font.Bold } color: "white" }
                            }
                        }
                        Texto {
                            text: win.d.discord.abierto ? ((win.d.discord.mensajes || 0) > 0 ? "Tienes mensajes" : "Abierto") : "Cerrado"
                            font { pixelSize: 16; weight: Font.Bold }
                            color: "#e9edf5"
                        }
                        Texto {
                            text: win.d.discord.micro === false ? "Tu micro está apagado" : "Tu micro está encendido"
                            font.pixelSize: 13
                            color: win.d.discord.micro === false ? "#ff6b81" : Qt.rgba(0.91, 0.93, 0.96, 0.6)
                        }
                        Item { width: 1; height: 6 }
                        Row {
                            spacing: 8
                            Mando { clave: "micro"; icono: win.d.discord.micro === false ? "silencio" : "micro"; rojo: win.d.discord.micro === false }
                            Mando { clave: "discord"; icono: "ventana"; texto: win.d.discord.abierto ? "Al lado" : "Abrir" }
                        }
                    }
                }

                // Los avisos de la partida
                Tarjeta {
                    width: 300
                    Column {
                        width: 264
                        spacing: 6
                        Row {
                            spacing: 8
                            Etiqueta { text: "Avisos" }
                            Etiqueta { text: win.d.avisos.length ? String(win.d.avisos.length) : ""; color: Tema.acento }
                        }
                        Texto {
                            visible: !win.d.avisos.length
                            text: "Nada nuevo"
                            font { pixelSize: 16; weight: Font.Bold }
                            color: "#e9edf5"
                        }
                        Texto {
                            visible: !win.d.avisos.length
                            width: parent.width
                            text: "Lo que llegue mientras juegas se guarda aquí, sin taparte la partida"
                            font.pixelSize: 12
                            color: Qt.rgba(0.91, 0.93, 0.96, 0.55)
                        }
                        Repeater {
                            model: win.d.avisos.slice(0, 3)
                            Column {
                                required property var modelData
                                width: 264
                                Texto {
                                    width: parent.width
                                    text: modelData.titulo || modelData.app
                                    elide: Text.ElideRight; wrapMode: Text.NoWrap
                                    font { pixelSize: 13; weight: Font.DemiBold }
                                    color: "#e9edf5"
                                }
                                Texto {
                                    width: parent.width
                                    text: (modelData.hora ? modelData.hora + " · " : "") + (modelData.texto || modelData.app)
                                    elide: Text.ElideRight; wrapMode: Text.NoWrap
                                    font.pixelSize: 11
                                    color: Qt.rgba(0.91, 0.93, 0.96, 0.55)
                                }
                            }
                        }
                    }
                }

                // El volumen
                Tarjeta {
                    width: 220
                    enfocada: win.elegido === "volumen"
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -18
                        onClicked: { win.foco = win.focos.indexOf("volumen"); }
                        onWheel: w => { consola.volumen(w.angleDelta.y > 0 ? 0.05 : -0.05); win.luego(); }
                    }
                    Column {
                        width: 184
                        spacing: 4
                        Etiqueta { text: "Volumen" }
                        Texto {
                            text: !win.d.volumen ? "—" : win.d.volumen.mudo ? "En silencio" : Math.round(win.d.volumen.nivel * 100) + " %"
                            font { family: Tema.mono; pixelSize: 22; weight: Font.Bold }
                            color: "#e9edf5"
                        }
                        Item { width: 1; height: 10 }
                        Rectangle {
                            width: parent.width; height: 6; radius: 3
                            color: Qt.rgba(1, 1, 1, 0.12)
                            Rectangle {
                                width: parent.width * (win.d.volumen ? win.d.volumen.nivel : 0); height: parent.height; radius: 3
                                color: win.d.volumen && win.d.volumen.mudo ? Qt.rgba(1, 1, 1, 0.3) : Tema.acento
                                Behavior on width { NumberAnimation { duration: 120 } }
                            }
                        }
                        Item { width: 1; height: 6 }
                        Texto {
                            text: win.elegido === "volumen" ? "↑ ↓ cambiar · " + win.btn.a + " silencio" : "Rueda o ↑ ↓ al elegirlo"
                            font { family: Tema.mono; pixelSize: 10 }
                            color: Qt.rgba(0.91, 0.93, 0.96, 0.5)
                        }
                    }
                }

                // Volver a la consola
                Tarjeta {
                    width: 176
                    enfocada: win.elegido === "consola"
                    MouseArea { anchors.fill: parent; anchors.margins: -18; onClicked: win.hacer("consola") }
                    Column {
                        width: 140
                        spacing: 10
                        Icono { nombre: "jugar"; width: 28; height: 28; color: Tema.acento }
                        Texto {
                            width: parent.width
                            text: "Volver a la consola"
                            font { pixelSize: 16; weight: Font.Bold }
                            color: "#e9edf5"
                        }
                        Texto {
                            width: parent.width
                            text: "El juego sigue abierto"
                            font.pixelSize: 12
                            color: Qt.rgba(0.91, 0.93, 0.96, 0.55)
                        }
                    }
                }
            }
        }
    }

    // ----- Las piezas -----
    component Tarjeta: Rectangle {
        property bool enfocada: false
        default property alias contenido: dentro.data
        height: 168
        radius: 18
        color: Qt.rgba(0.06, 0.07, 0.1, 0.9)
        border.width: enfocada ? 2 : 1
        border.color: enfocada ? Tema.acento : Qt.rgba(1, 1, 1, 0.08)
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Item { id: dentro; x: 18; y: 18; width: parent.width - 36; height: parent.height - 36 }
    }
    component Etiqueta: Texto {
        font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.8; capitalization: Font.AllUppercase }
        color: Qt.rgba(0.91, 0.93, 0.96, 0.55)
        wrapMode: Text.NoWrap
    }
    // Un botón del centro (se elige con el mando o se pulsa con el ratón)
    component Mando: Rectangle {
        id: m
        property string clave
        property string icono
        property string texto: ""
        property int ancho: 40
        property bool rojo: false
        readonly property bool on: win.elegido === clave
        width: texto ? mt.implicitWidth + 50 : ancho
        height: 36; radius: 18
        color: on ? Tema.acento : rojo ? Qt.rgba(1, 0.42, 0.5, 0.18) : Qt.rgba(1, 1, 1, ma.containsMouse ? 0.12 : 0.07)
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: on ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        Row {
            anchors.centerIn: parent
            spacing: 8
            Icono { nombre: m.icono; color: m.on ? Tema.sobreAcento : m.rojo ? "#ff6b81" : "#e9edf5"; anchors.verticalCenter: parent.verticalCenter }
            Texto { id: mt; visible: m.texto !== ""; text: m.texto; anchors.verticalCenter: parent.verticalCenter; font { pixelSize: 13; weight: Font.DemiBold } color: m.on ? Tema.sobreAcento : "#e9edf5" }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { win.foco = win.focos.indexOf(m.clave); win.hacer(m.clave); }
        }
    }
}
