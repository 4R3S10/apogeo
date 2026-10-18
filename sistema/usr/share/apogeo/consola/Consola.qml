import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Apogeo

// La consola del piso Jugar («C8 · Cinta panorámica»): tus juegos en una cinta de portadas abajo; el elegido se agranda y
// pinta la pantalla con su arte. Arriba: Inicio (lo descargado, lo último jugado primero) y una pestaña por tienda o
// plataforma con toda tu biblioteca para descargar y quitar. Mando o teclado: ← → elegir · A/Intro jugar o descargar ·
// X/Supr quitar · LB RB/Q E pestaña · B/Esc atrás · ↓ bajar a Navegar. «consola» es apogeo-consola.
Window {
    id: win
    title: "Jugar"
    color: "#0f0a10"
    visible: true
    Component.onCompleted: showFullScreen()

    readonly property var lib: consola.tabs
    readonly property var allTabs: [
        { clave: "inicio", texto: "Inicio" }, { clave: "steam", texto: "Steam" }, { clave: "epic", texto: "Epic" },
        { clave: "emuladores", texto: "Emuladores" }, { clave: "ps5", texto: "PS5" }, { clave: "windows", texto: "Windows" }
    ]
    // Windows solo si hay alguno; las demás, siempre (aunque estén vacías: ahí se explica qué hacer)
    readonly property var shownTabs: allTabs.filter(t => t.clave !== "windows" || (lib.windows || []).length > 0)
    property int tab: 0
    readonly property string tabKey: shownTabs[Math.min(tab, shownTabs.length - 1)].clave
    property string sys: ""                       // el sistema elegido en Emuladores ("" = todos)
    readonly property var systems: {
        const o = [];
        for (const g of (lib.emuladores || [])) if (!o.some(s => s.clave === g.system)) o.push({ clave: g.system, texto: g.systemName });
        return o;
    }
    readonly property var list: (lib[tabKey] || []).filter(g => tabKey !== "emuladores" || sys === "" || g.system === sys)
    property var selByTab: ({})
    readonly property int sel: Math.max(0, Math.min(selByTab[tabKey + sys] || 0, list.length - 1))
    readonly property var game: list.length ? list[sel] : null
    readonly property var dl: game ? (lib.descargas || {})[game.id] : undefined
    property string toast: ""
    property bool asking: false                   // «¿Quitar…?»

    function select(i) {
        const s = Object.assign({}, selByTab);
        s[tabKey + sys] = Math.max(0, Math.min(i, list.length - 1));
        selByTab = s;
        cinta.positionViewAtIndex(sel, ListView.Contain);
    }
    function setTab(i) { tab = (i + shownTabs.length) % shownTabs.length; sys = ""; }
    function say(t) { toast = t; toastTimer.restart(); }
    Timer { id: toastTimer; interval: 4500; onTriggered: win.toast = "" }

    function primary() {
        if (!game || (dl && dl.estado !== "error")) return;
        if (game.installed) {
            const msg = consola.play(game);
            if (msg) say(msg);
            else { say("Abriendo " + game.name + "…"); hideTimer.restart(); }
        } else {
            const msg = consola.install(game);
            say(msg || (game.store === "steam" ? "Steam te pregunta dónde descargarlo" : game.store === "ps5" ? "Convirtiendo con AnyPS5…" : "Descargando " + game.name + "…"));
        }
    }
    function secondary() {
        if (!game || dl || !game.installed || game.store === "windows") return;
        asking = true;
    }
    function confirmRemove() {
        asking = false;
        const msg = consola.uninstall(game);
        say(msg || (game.store === "steam" ? "Steam te pide que lo confirmes" : game.store === "emu" ? "A la papelera (se puede recuperar)" : "Quitando " + game.name + "…"));
    }
    Timer { id: hideTimer; interval: 1200; onTriggered: win.visibility = Window.Minimized } // (el juego se ve)

    function key(k) {
        if (asking) {
            if (k === "a") confirmRemove();
            else if (k === "b") asking = false;
            return;
        }
        if (k === "izquierda") select(sel - 1);
        else if (k === "derecha") select(sel + 1);
        else if (k === "a") primary();
        else if (k === "x") secondary();
        else if (k === "lb") setTab(tab - 1);
        else if (k === "rb") setTab(tab + 1);
        else if (k === "abajo") consola.floor(1);
        else if (k === "arriba" && tabKey === "emuladores" && systems.length) {
            const i = systems.findIndex(s => s.clave === sys);
            sys = i + 1 < systems.length ? systems[i + 1].clave : "";
        }
    }
    Connections {
        target: consola
        function onPad(button) { if (win.active) win.key(button) }
        function onShown() { win.showFullScreen(); win.raise(); win.requestActivate(); consola.refresh(); }
    }
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const m = { [Qt.Key_Left]: "izquierda", [Qt.Key_Right]: "derecha", [Qt.Key_Up]: "arriba", [Qt.Key_Down]: "abajo",
                        [Qt.Key_Return]: "a", [Qt.Key_Enter]: "a", [Qt.Key_Space]: "a", [Qt.Key_Escape]: "b",
                        [Qt.Key_Delete]: "x", [Qt.Key_X]: "x", [Qt.Key_Q]: "lb", [Qt.Key_E]: "rb", [Qt.Key_Tab]: "rb",
                        [Qt.Key_Backtab]: "lb" };
            if (m[e.key]) { win.key(m[e.key]); e.accepted = true; }
        }
    }

    function ago(t) {
        if (!t) return "";
        const s = Date.now() / 1000 - t;
        if (s < 3600) return "hace un rato";
        if (s < 86400) return "hace " + Math.round(s / 3600) + " h";
        if (s < 172800) return "ayer";
        if (s < 604800) return "hace " + Math.round(s / 86400) + " días";
        if (s < 2592000) return "hace " + Math.round(s / 604800) + " semanas";
        return "hace " + Math.round(s / 2592000) + " meses";
    }
    function gb(b) { return b > 0 ? (b / 1073741824 >= 1 ? (b / 1073741824).toFixed(1).replace(".", ",") + " GB" : Math.max(1, Math.round(b / 1048576)) + " MB") : "" }
    readonly property var storeNames: ({ steam: "Steam", epic: "Epic", emu: "", ps5: "PS5 · AnyPS5", windows: "Windows" })
    function where(g) { return g.store === "emu" ? g.systemName : storeNames[g.store] || "" }
    // Un color por juego (para cuando no hay portada)
    function tint(name) { let h = 0; for (const c of name) h = (h * 31 + c.charCodeAt(0)) % 360; return Qt.hsla(h / 360, 0.45, 0.32, 1) }

    // ---------- El fondo: el arte del elegido ----------
    Item {
        id: fondo
        anchors.fill: parent
        property string src: win.game ? (win.game.hero || win.game.cover) : ""
        property bool flip: false
        onSrcChanged: { flip = !flip; (flip ? b : a).source = src; }
        Rectangle { anchors.fill: parent; color: win.game ? win.tint(win.game.name) : "#1e1621"; opacity: 0.55 }
        Image {
            id: a
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: !fondo.flip && status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 450 } }
        }
        Image {
            id: b
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: fondo.flip && status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 450 } }
        }
        // Oscuro a la izquierda y abajo (para leer encima)
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#f00f0a10" }
                GradientStop { position: 0.45; color: "#990f0a10" }
                GradientStop { position: 0.8; color: "#330f0a10" }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 0.8; color: "#f00f0a10" }
            }
        }
    }

    // ---------- Arriba: las pestañas, los pisos y tú ----------
    Row {
        x: 48; y: 28
        spacing: 6
        Repeater {
            model: win.shownTabs
            delegate: Rectangle {
                id: t
                required property var modelData
                required property int index
                readonly property bool on: win.tab === index
                width: tl.implicitWidth + 36; height: 40; radius: 14
                color: on ? Tema.rosa : tm.containsMouse ? Tema.encima : "transparent"
                Texto { id: tl; anchors.centerIn: parent; text: t.modelData.texto; font.pixelSize: 16; font.weight: t.on ? Font.Bold : Font.Normal; color: t.on ? Tema.sobreRosa : Tema.apagado }
                MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.setTab(t.index) }
            }
        }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 48; y: 28
        spacing: 14
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: ["Jugar", "Navegar", "Estudiar"]
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: pl.implicitWidth + 22; height: 30; radius: 11
                    color: index === 0 ? Tema.rosaSuave : pm.containsMouse ? Tema.encima : "transparent"
                    Texto { id: pl; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 13; color: parent.index === 0 ? Tema.texto : Tema.apagado }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: consola.floor(parent.index) }
                }
            }
        }
        Texto { id: reloj; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 15; font.weight: Font.DemiBold; text: Qt.formatTime(new Date(), "HH:mm") }
        Timer { interval: 10000; running: true; repeat: true; onTriggered: reloj.text = Qt.formatTime(new Date(), "HH:mm") }
        Rectangle {
            width: 40; height: 40; radius: 20
            color: Tema.rosaSuave
            border.width: 2; border.color: Tema.rosa
            clip: true
            Image { anchors.fill: parent; anchors.margins: 2; source: consola.avatar; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
        }
    }

    // Emuladores: los sistemas (↑ para cambiar)
    Row {
        visible: win.tabKey === "emuladores" && win.systems.length > 1
        x: 48; y: 84
        spacing: 6
        Repeater {
            model: [{ clave: "", texto: "Todos" }].concat(win.systems)
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: win.sys === modelData.clave
                width: sl.implicitWidth + 24; height: 30; radius: 15
                color: on ? Tema.rosaSuave : Qt.rgba(18 / 255, 13 / 255, 20 / 255, 0.55)
                border.color: Tema.borde
                Texto { id: sl; anchors.centerIn: parent; text: parent.modelData.texto; font.pixelSize: 13; color: parent.on ? Tema.texto : Tema.apagado }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.sys = parent.modelData.clave }
            }
        }
    }

    // ---------- El elegido ----------
    Column {
        visible: !!win.game
        x: 48; y: 150
        width: parent.width * 0.55
        spacing: 0
        Texto {
            text: {
                const g = win.game;
                if (!g) return "";
                const w = win.where(g).toUpperCase();
                if (!g.installed) return (g.store === "ps5" ? "SIN CONVERTIR" : "SIN DESCARGAR") + (w ? " · " + w : "");
                return (g.last ? "JUGADO " + win.ago(g.last).toUpperCase() : "DESCARGADO") + (w ? " · " + w : "");
            }
            color: Tema.rosa
            font.pixelSize: 13; font.weight: Font.Bold; font.letterSpacing: 1.6
        }
        Texto {
            width: parent.width
            text: win.game ? win.game.name : ""
            font.pixelSize: 58; font.weight: Font.ExtraBold
            maximumLineCount: 2; elide: Text.ElideRight
            lineHeight: 0.95
        }
        Item { width: 1; height: 18 }
        Row {
            spacing: 10
            // Jugar · Descargar · el progreso
            Rectangle {
                id: boton
                readonly property bool busy: !!win.dl
                width: busy ? 280 : bl.implicitWidth + 64
                height: 54; radius: 27
                color: busy ? Qt.rgba(18 / 255, 13 / 255, 20 / 255, 0.7) : Tema.rosa
                border.color: busy ? Tema.borde : "transparent"
                RectangularShadow { anchors.fill: parent; z: -1; visible: !boton.busy; offset.y: 6; blur: 26; spread: -4; radius: parent.radius; color: Tema.rosa; opacity: 0.8 }
                Rectangle {
                    visible: boton.busy && win.dl.estado !== "error"
                    x: 0; y: 0; height: parent.height; radius: parent.radius
                    width: parent.width * Math.max(0.06, (win.dl && win.dl.progreso) || 0)
                    color: Tema.rosaSuave
                }
                Texto {
                    id: bl
                    anchors.centerIn: parent
                    text: boton.busy ? (win.dl.estado === "error" ? win.dl.mensaje : (win.dl.estado === "quitando" ? "Quitando… " : "Descargando… ") + Math.round((win.dl.progreso || 0) * 100) + " %")
                        : win.game && win.game.installed ? "▶  Jugar" : win.game && win.game.store === "ps5" ? "Convertir con AnyPS5" : "↓  Descargar"
                    color: boton.busy ? Tema.texto : Tema.sobreRosa
                    font.pixelSize: boton.busy ? 14 : 18; font.weight: Font.ExtraBold
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.primary() }
            }
            Rectangle {
                visible: !!win.game && win.game.installed && !win.dl && win.game.store !== "windows"
                width: ql.implicitWidth + 40; height: 54; radius: 27
                color: qm.containsMouse ? Tema.pulsado : Qt.rgba(18 / 255, 13 / 255, 20 / 255, 0.55)
                border.color: Tema.borde
                Texto { id: ql; anchors.centerIn: parent; text: win.game && win.game.store === "ps5" ? "Quitar lo convertido" : "Quitar del PC"; font.pixelSize: 15 }
                MouseArea { id: qm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.secondary() }
            }
            Repeater {
                model: win.game ? [win.gb(win.game.size), win.dl && win.dl.mensaje && win.dl.estado !== "error" ? win.dl.mensaje : ""].filter(x => x) : []
                delegate: Rectangle {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: cl.implicitWidth + 24; height: 32; radius: 16
                    color: Qt.rgba(18 / 255, 13 / 255, 20 / 255, 0.55); border.color: Tema.borde
                    Texto { id: cl; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 13 }
                }
            }
        }
    }

    // ---------- Vacío: qué hacer ----------
    Column {
        visible: !win.game
        x: 48; y: 170
        width: parent.width * 0.5
        spacing: 16
        Texto {
            width: parent.width
            font.pixelSize: 40; font.weight: Font.ExtraBold
            text: ({ inicio: "Aún no tienes juegos descargados", steam: "Entra en Steam", epic: "Entra en Epic con Heroic",
                     emuladores: "Pon tus juegos y a jugar", ps5: "Tus juegos de PS5", windows: "" })[win.tabKey] || ""
        }
        Texto {
            width: parent.width
            color: Tema.apagado
            font.pixelSize: 17
            text: ({
                inicio: "Elige Steam, Epic, Emuladores o PS5 arriba (LB / RB) y descarga lo que te apetezca.",
                steam: "Abre Steam y entra con tu cuenta: aquí saldrá toda tu biblioteca para descargar y quitar.",
                epic: "Abre Heroic y entra con tu cuenta de Epic: aquí saldrá toda tu biblioteca.",
                emuladores: "Copia tus juegos (tus copias de tus discos y cartuchos) en la carpeta de cada sistema, dentro de " + consola.folder + ". Salen aquí solos, con su portada. En LEEME.txt tienes cómo.",
                ps5: "Pon cada juego volcado de tu PS5 en una carpeta dentro de " + consola.folder + "/PS5 y Apogeo lo convierte con AnyPS5. Es experimental: por ahora van muy pocos juegos."
            })[win.tabKey] || ""
        }
        Rectangle {
            visible: win.tabKey !== "inicio"
            width: ol.implicitWidth + 48; height: 48; radius: 24
            color: Tema.rosa
            Texto {
                id: ol
                anchors.centerIn: parent
                color: Tema.sobreRosa; font.pixelSize: 16; font.weight: Font.Bold
                text: ({ steam: "Abrir Steam", epic: "Abrir Heroic", emuladores: "Abrir la carpeta", ps5: "Abrir la carpeta" })[win.tabKey] || ""
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: consola.open(({ steam: "steam", epic: "epic" })[win.tabKey] || "carpeta")
            }
        }
    }

    // ---------- La cinta de portadas ----------
    ListView {
        id: cinta
        x: 48
        width: parent.width - 48
        height: 270
        anchors.bottom: parent.bottom; anchors.bottomMargin: 74
        orientation: ListView.Horizontal
        spacing: 16
        model: win.list
        currentIndex: win.sel
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0; preferredHighlightEnd: width * 0.6
        highlightMoveDuration: 220
        boundsBehavior: Flickable.StopAtBounds
        clip: false
        delegate: Item {
            id: d
            required property var modelData
            required property int index
            readonly property bool on: index === win.sel
            width: on ? 172 : 124
            height: cinta.height
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Rectangle {
                id: carta
                anchors.bottom: parent.bottom
                width: parent.width; height: width * 1.5
                radius: 16
                // (detrás de las cajas de los emuladores, que no llenan la carta, un oscuro neutro)
                color: d.modelData.store === "emu" && portada.status === Image.Ready ? "#1a131c" : win.tint(d.modelData.name)
                clip: true
                opacity: d.modelData.installed || d.on ? 1 : 0.55
                Image {
                    id: portada
                    anchors.fill: parent
                    source: d.modelData.cover
                    sourceSize: Qt.size(344, 516)
                    // (las cajas de los emuladores tienen cada una su forma: enteras, sin recortar)
                    fillMode: d.modelData.store === "emu" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    asynchronous: true
                }
                // Sin portada: el nombre sobre su color
                Texto {
                    visible: portada.status !== Image.Ready
                    anchors.fill: parent; anchors.margins: 12
                    verticalAlignment: Text.AlignBottom
                    text: d.modelData.name
                    font.pixelSize: d.on ? 17 : 14; font.weight: Font.ExtraBold
                    maximumLineCount: 4; elide: Text.ElideRight
                }
                // Sin descargar: la flechita
                Rectangle {
                    visible: !d.modelData.installed
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                    width: 28; height: 28; radius: 14
                    color: "#cc0f0a10"
                    Texto { anchors.centerIn: parent; text: "↓"; font.pixelSize: 15; font.weight: Font.Bold }
                }
            }
            Rectangle {
                visible: d.on
                anchors.fill: carta; anchors.margins: -5
                radius: 20
                color: "transparent"
                border.width: 3; border.color: Tema.rosa
            }
            RectangularShadow {
                visible: d.on
                anchors.fill: carta; z: -1
                blur: 40; spread: 2; radius: 20
                color: Tema.rosa; opacity: 0.45
            }
            MouseArea {
                anchors.fill: carta
                cursorShape: Qt.PointingHandCursor
                onClicked: d.on ? win.primary() : win.select(d.index)
            }
        }
    }

    // ---------- Abajo: los botones del mando ----------
    Row {
        x: 48
        anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        spacing: 22
        Repeater {
            model: [
                { b: ["A"], t: win.game && !win.game.installed ? "Descargar" : "Jugar" },
                { b: ["X"], t: "Quitar" },
                { b: ["LB", "RB"], t: "Pestaña" },
                { b: ["↓"], t: "Navegar" }
            ]
            delegate: Row {
                required property var modelData
                spacing: 5
                Repeater {
                    model: parent.modelData.b
                    delegate: Rectangle {
                        required property string modelData
                        width: Math.max(24, bt.implicitWidth + 12); height: 24; radius: 12
                        color: Tema.encima; border.color: Tema.borde
                        Texto { id: bt; anchors.centerIn: parent; text: parent.modelData; font.pixelSize: 11; font.weight: Font.Bold }
                    }
                }
                Texto { text: parent.modelData.t; color: Tema.apagado; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Texto {
        anchors.right: parent.right; anchors.rightMargin: 48
        anchors.bottom: parent.bottom; anchors.bottomMargin: 27
        text: "Meta+Tab en un juego: Discord y la música"
        color: Tema.apagado; font.pixelSize: 13
    }

    // ---------- Avisos y «¿Quitar?» ----------
    Rectangle {
        visible: win.toast !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: 96
        width: tt.implicitWidth + 40; height: 44; radius: 22
        color: Qt.rgba(33 / 255, 25 / 255, 36 / 255, 0.95); border.color: Tema.borde
        Texto { id: tt; anchors.centerIn: parent; text: win.toast; font.pixelSize: 15 }
    }
    Rectangle {
        visible: win.asking
        anchors.fill: parent
        color: "#aa0a070b"
        MouseArea { anchors.fill: parent; onClicked: win.asking = false }
        Rectangle {
            anchors.centerIn: parent
            width: 520; height: qc.implicitHeight + 56; radius: 24
            color: Tema.cromo; border.color: Tema.borde
            Column {
                id: qc
                anchors.centerIn: parent
                width: parent.width - 56
                spacing: 12
                Texto { text: "¿Quitar " + (win.game ? win.game.name : "") + "?"; font.pixelSize: 22; font.weight: Font.Bold; width: parent.width; elide: Text.ElideRight }
                Texto {
                    width: parent.width
                    color: Tema.apagado
                    text: !win.game ? "" : win.game.store === "emu" ? "Va a la papelera: se puede recuperar."
                        : win.game.store === "ps5" ? "Solo lo convertido; tu volcado se queda en su carpeta."
                        : "Se borra del PC. Tus partidas guardadas en la nube siguen; lo puedes volver a descargar cuando quieras."
                }
                Row {
                    spacing: 10
                    Boton { tipo: "principal"; text: "A · Quitar"; onClicked: win.confirmRemove() }
                    Boton { text: "B · Cancelar"; onClicked: win.asking = false }
                }
            }
        }
    }
}
