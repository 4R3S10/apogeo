import QtQuick
import Apogeo
import QtQuick.Controls
import QtQuick.Effects
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.mpris as Mpris

// Pantalla de bloqueo de Apogeo («Tarjeta con piso», como la de inicio de sesión): tu nombre, el piso al que vuelves y
// la contraseña. A la derecha, la hora bien grande con la fecha y, si suena algo, la canción con sus botones. Sustituye a la de Plasma (la copia apogeo-bloqueo). Si algún día no carga, el bloqueo de KDE pone su
// pantalla básica y se puede desbloquear igual.
// «Tu símbolo» (D7): si tienes uno (Ajustes → Bloqueo), lo dibujas con el ratón en cualquier parte de la pantalla y
// entras. El dibujo va por el mismo camino que la contraseña, con «apogeo-simbolo:» delante: lo comprueba
// apogeo-simbolo (/etc/pam.d/kde) y, si no es, no llega a la contraseña (no cuenta como contraseña equivocada).
//
// Lo que pide el bloqueo de KDE a este archivo: viewVisible, notification, clearPassword() y notificationRepeated(); el
// resto lo da él: authenticator (la contraseña), kscreenlocker_userName y el fondo (detrás de todo).
Item {
    id: root
    property bool debug: false
    property string notification
    property bool viewVisible: false
    signal clearPassword()
    signal notificationRepeated()

    implicitWidth: 800
    implicitHeight: 600

    // Los colores y la letra del modo (de serie, Órbita)
    readonly property color text: Tema.texto
    readonly property color muted: Tema.apagado
    readonly property color hover: Tema.encima
    readonly property color border: Tema.borde
    readonly property color accent: Tema.rosa
    readonly property color accentText: Tema.sobreRosa
    readonly property string font: Tema.letra
    readonly property var floors: [
        { key: "jugar", name: "Jugar", fondo: "nebulosa" },
        { key: "navegar", name: "Navegar", fondo: "orbitas" },
        { key: "estudiar", name: "Estudiar", fondo: "aurora" }
    ]
    // El piso en el que estabas: el fondo del bloqueo es el suyo (lo pone apogeo-pisos)
    property int floor: {
        try {
            const cfg = wallpaperIntegration.configuration;
            // El piso lo apunta apogeo-pisos; si no está (versiones de antes), se deduce del fondo
            let k = floors.findIndex(f => f.key === String(cfg.Piso || ""));
            if (k < 0) k = floors.findIndex(f => f.fondo === String(cfg.Estilo || ""));
            return k >= 0 ? k : 1;
        } catch (e) {
            return 1;
        }
    }
    property string error: ""
    property bool busy: false
    property string pending: ""   // contraseña escrita antes de que KDE la pida

    // ---------- Tu símbolo ----------
    KCoreAddons.KUser { id: kuser }
    property bool hasSymbol: false
    property bool lastWasSymbol: false
    property int symbolFails: 0
    readonly property bool symbolOn: hasSymbol && symbolFails < 5
    function checkSymbol() {
        // (el archivo solo lo puedes leer tú; lo guarda Ajustes → Bloqueo)
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => { if (x.readyState === XMLHttpRequest.DONE) root.hasSymbol = x.responseText.length > 10; };
        x.open("GET", "file:///var/lib/apogeo/simbolo/" + kuser.loginName + ".json");
        try { x.send(); } catch (e) { root.hasSymbol = false; }
    }
    // El dibujo: 64 puntos en un cuadro de 0 a 127 (sin deformarlo; así btoa no lo cambia), en base64, con «apogeo-simbolo:» delante
    function encode(pts) {
        let len = 0;
        for (let i = 1; i < pts.length; i++) len += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y);
        const n = 64, step = len / (n - 1), out = [pts[0]];
        let acc = 0, prev = pts[0], i = 1;
        while (i < pts.length && out.length < n) {
            const cur = pts[i], d = Math.hypot(cur.x - prev.x, cur.y - prev.y);
            if (acc + d >= step && d > 0) {
                const t = (step - acc) / d;
                const q = { x: prev.x + t * (cur.x - prev.x), y: prev.y + t * (cur.y - prev.y) };
                out.push(q); prev = q; acc = 0;
            } else { acc += d; prev = cur; i++; }
        }
        while (out.length < n) out.push(pts[pts.length - 1]);
        const xs = out.map(p => p.x), ys = out.map(p => p.y);
        const x0 = Math.min(...xs), y0 = Math.min(...ys);
        const s = Math.max(Math.max(...xs) - x0, Math.max(...ys) - y0) || 1;
        let bin = "";
        for (const p of out) bin += String.fromCharCode(Math.round((p.x - x0) / s * 127), Math.round((p.y - y0) / s * 127));
        return "apogeo-simbolo:" + Qt.btoa(bin);
    }
    function unlockSymbol(pts) {
        if (busy || retry.running || pts.length < 8) return;
        lastWasSymbol = true;
        send(encode(pts));
    }

    onClearPassword: { password.text = ""; pending = ""; }

    // KDE ignora «empezar» durante los primeros segundos del bloqueo (el margen para volver sin contraseña), así que se
    // pide cada vez que tocas el ratón o el teclado y justo antes de comprobar la contraseña, como hace el suyo
    function start() { authenticator.startAuthenticating() }
    Component.onCompleted: { start(); checkSymbol(); }

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) return; // huella u otros métodos sin contraseña: no se enseña
            root.busy = false;
            root.pending = "";
            watchdog.stop();
            if (root.lastWasSymbol) {
                root.symbolFails++;
                root.error = root.symbolOn ? "No es tu símbolo" : "Usa tu contraseña";
                ink.fail();
            } else {
                root.error = "Contraseña incorrecta";
            }
            root.lastWasSymbol = false;
            password.text = "";
            shake.start();
            retry.restart();
        }
        function onSucceeded() {
            Qt.quit();
        }
        function onPromptForSecretChanged() {
            // KDE ya pide la contraseña: si la habías escrito, se le da
            if (authenticator.promptForSecret && root.pending !== "") {
                const p = root.pending;
                root.pending = "";
                authenticator.respond(p);
            }
            password.forceActiveFocus();
        }
        function onErrorMessageChanged() {
            if (authenticator.errorMessage) root.error = authenticator.errorMessage;
        }
    }
    // Tras un fallo, KDE espera un poco antes de dejar probar otra vez
    Timer {
        id: retry
        interval: 3000
        onTriggered: {
            root.start();
            password.forceActiveFocus();
        }
    }
    // Si KDE no contesta, la casilla no se queda bloqueada
    Timer {
        id: watchdog
        interval: 6000
        onTriggered: {
            root.busy = false;
            root.pending = "";
            root.error = "No ha respondido. Vuelve a intentarlo.";
            root.start();
            password.forceActiveFocus();
        }
    }

    function unlock() {
        if (busy || password.text === "") return;
        lastWasSymbol = false;
        send(password.text);
    }
    function send(secret) {
        error = "";
        busy = true;
        watchdog.restart();
        if (authenticator.promptForSecret) {
            authenticator.respond(secret);
        } else {
            pending = secret;
            start();
        }
    }

    // Oscurece un poco el fondo para que la tarjeta resalte
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.25
    }

    // Mover el ratón o pulsar una tecla lleva a la contraseña; arrastrar (con tu símbolo puesto) dibuja
    MouseArea {
        id: drawArea
        anchors.fill: parent
        hoverEnabled: true
        property var pts: []
        property bool drawing: false
        onPressed: mouse => {
            root.start();
            pts = [{ x: mouse.x, y: mouse.y }];
            drawing = false;
        }
        onPositionChanged: mouse => {
            root.start();
            if (!pressed || !root.symbolOn) return;
            const last = pts[pts.length - 1];
            if (Math.hypot(mouse.x - last.x, mouse.y - last.y) < 3) return;
            pts.push({ x: mouse.x, y: mouse.y });
            if (!drawing && Math.hypot(mouse.x - pts[0].x, mouse.y - pts[0].y) > 14) { drawing = true; ink.begin(); }
            if (drawing) ink.add(mouse.x, mouse.y, pts);
        }
        onReleased: {
            if (drawing) {
                drawing = false;
                ink.done();
                root.unlockSymbol(pts);
            } else {
                password.forceActiveFocus();
            }
        }
    }

    // El trazo del símbolo: rosa con brillo mientras dibujas; si no es, se pone rojo y se apaga
    Canvas {
        id: ink
        anchors.fill: parent
        property var pts: []
        property color tint: Tema.acento
        opacity: 0
        function begin() { pts = []; tint = Tema.acento; fade.stop(); opacity = 1; }
        function add(x, y, all) { pts = all; requestPaint(); }
        function done() { fade.start(); }
        function fail() { tint = Tema.error; requestPaint(); fade.restart(); }
        NumberAnimation on opacity { id: fade; running: false; to: 0; duration: 900; easing.type: Easing.InQuad }
        onPaint: {
            const c = getContext("2d");
            c.reset();
            if (pts.length < 2) return;
            c.lineCap = "round"; c.lineJoin = "round";
            for (const [w, a] of [[16, 0.12], [8, 0.3], [3.5, 1]]) {
                c.strokeStyle = Qt.rgba(tint.r, tint.g, tint.b, a);
                c.lineWidth = w;
                c.beginPath();
                c.moveTo(pts[0].x, pts[0].y);
                for (let i = 1; i < pts.length; i++) c.lineTo(pts[i].x, pts[i].y);
                c.stroke();
            }
        }
    }

    // La tarjeta de Ágape: el cromo casi opaco, borde del 10 %, brillo arriba y radio 20
    RectangularShadow {
        anchors.fill: card
        offset.y: 16
        blur: 44
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Rectangle {
        id: card
        x: 40; y: 40
        width: Math.min(440, parent.width - 80)
        height: parent.height - 80
        radius: Tema.r(20)
        color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.92)
        border.color: root.border
        Rectangle { // el brillo de 1 px de arriba
            x: parent.radius; y: 1
            width: parent.width - 2 * parent.radius; height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: card; property: "x"; to: 52; duration: 50 }
            NumberAnimation { target: card; property: "x"; to: 28; duration: 80 }
            NumberAnimation { target: card; property: "x"; to: 40; duration: 50 }
        }

        Image {
            x: 40; y: 40
            width: 44; height: 44
            source: "file:///usr/share/apogeo/logo.svg"
            sourceSize: Qt.size(88, 88)
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Row {
                width: parent.width
                spacing: 14
                Item { // tu foto (la de la bienvenida o Ajustes), en círculo con el borde rosa
                    id: face
                    width: 48; height: 48
                    anchors.verticalCenter: parent.verticalCenter
                    visible: faceImg.status === Image.Ready
                    Image {
                        id: faceImg
                        anchors.fill: parent
                        source: {
                            const f = typeof kscreenlocker_userImage !== "undefined" ? String(kscreenlocker_userImage || "") : "";
                            return f === "" ? "" : f.startsWith("/") ? "file://" + f : f;
                        }
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
                    MultiEffect { anchors.fill: parent; source: faceImg; maskEnabled: true; maskSource: faceMask }
                    Rectangle { anchors.fill: parent; anchors.margins: -3; radius: width / 2; color: "transparent"; border.width: 2; border.color: root.accent }
                }
                Text {
                    text: "Hola de nuevo, " + (kscreenlocker_userName || "")
                    color: root.text
                    width: parent.width - (face.visible ? face.width + parent.spacing : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.Wrap
                    font { family: root.font; pixelSize: 24; weight: Font.Bold }
                }
            }
            Text {
                text: "¿A qué modo vuelves?"
                color: root.muted
                font { family: root.font; pixelSize: 15 }
            }

            // Pisos: el control segmentado (la pastilla de acento con brillo es la elegida)
            Rectangle {
                width: seg.implicitWidth + 6
                height: 40
                radius: Tema.r(14)
                color: root.hover
                Row {
                    id: seg
                    anchors.centerIn: parent
                    spacing: 3
                    Repeater {
                        model: root.floors
                        delegate: Item {
                            id: opt
                            required property var modelData
                            required property int index
                            readonly property bool on: index === root.floor
                            width: optRow.implicitWidth + 26
                            height: 34
                            RectangularShadow {
                                anchors.fill: optBg
                                visible: opt.on
                                offset.y: 4; blur: 18; spread: -4
                                radius: optBg.radius
                                color: root.accent
                                opacity: 0.85
                            }
                            Rectangle {
                                id: optBg
                                anchors.fill: parent
                                radius: Tema.r(11)
                                color: opt.on ? root.accent : (optArea.containsMouse ? root.hover : "transparent")
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            Row {
                                id: optRow
                                anchors.centerIn: parent
                                spacing: 7
                                Item {
                                    width: 16; height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        id: optIcon
                                        anchors.fill: parent
                                        source: "file:///usr/share/plasma/plasmoids/org.apogeo.pisos/contents/icons/" + opt.modelData.key + ".svg"
                                        sourceSize: Qt.size(32, 32)
                                        visible: false
                                    }
                                    MultiEffect {
                                        anchors.fill: parent
                                        source: optIcon
                                        colorization: 1
                                        colorizationColor: opt.on ? root.accentText : root.muted
                                    }
                                }
                                Text {
                                    text: opt.modelData.name
                                    color: opt.on ? root.accentText : root.muted
                                    font { family: root.font; pixelSize: 14; weight: opt.on ? Font.Bold : Font.DemiBold }
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                id: optArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pick(opt.index)
                            }
                        }
                    }
                }
            }

            Item { width: 1; height: 6 }

            // La contraseña, como la barra de direcciones de Ágape
            TextField {
                id: password
                width: parent.width
                height: 44
                echoMode: TextInput.Password
                placeholderText: "Contraseña"
                placeholderTextColor: root.muted
                color: root.text
                font { family: root.font; pixelSize: 15 }
                leftPadding: 14
                focus: true
                enabled: !root.busy && !retry.running
                background: Rectangle {
                    radius: Tema.r(14)
                    color: root.hover
                    border.color: password.activeFocus ? root.accent : "transparent"
                    border.width: 1
                }
                onAccepted: root.unlock()
                onTextEdited: root.start()
                Keys.onUpPressed: root.pick(Math.max(0, root.floor - 1))
                Keys.onDownPressed: root.pick(Math.min(root.floors.length - 1, root.floor + 1))
                Keys.onEscapePressed: text = ""
            }

            Text {
                text: "o dibuja tu símbolo en cualquier parte de la pantalla"
                visible: root.symbolOn && root.error === ""
                color: root.muted
                font { family: root.font; pixelSize: 13 }
            }
            Text {
                text: root.error
                visible: root.error !== ""
                color: Tema.error
                width: parent.width
                wrapMode: Text.Wrap
                font { family: root.font; pixelSize: 14 }
            }
        }

    }

    // ---------- A la derecha: la hora y lo que suena ----------
    Column {
        id: side
        anchors.left: card.right
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: player.visible ? -60 : 0
        visible: width > 360
        spacing: 2
        Text {
            id: bigClock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.text
            font { family: root.font; pixelSize: Math.min(176, side.width / 3.6); weight: Font.ExtraBold; letterSpacing: -4 }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.5); shadowBlur: 0.8; shadowVerticalOffset: 6 }
            function update() { text = Qt.formatDateTime(new Date(), "HH:mm") }
            Component.onCompleted: update()
            Timer { interval: 2000; running: true; repeat: true; onTriggered: bigClock.update() }
        }
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.text
            opacity: 0.85
            font { family: root.font; pixelSize: 22; weight: Font.DemiBold }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.5); shadowBlur: 0.6; shadowVerticalOffset: 3 }
            function update() {
                const d = Qt.locale("es_ES").toString(new Date(), "dddd, d 'de' MMMM");
                text = d.charAt(0).toUpperCase() + d.slice(1);
            }
            Component.onCompleted: update()
            Timer { interval: 60000; running: true; repeat: true; onTriggered: clock.update() }
        }
    }

    // La canción que suena (Spotify, Ágape, VLC…): carátula, título y sus botones
    Mpris.Mpris2Model { id: mpris }
    readonly property var playing: mpris.currentPlayer
    RectangularShadow {
        anchors.fill: player
        visible: player.visible
        offset.y: 12; blur: 36
        radius: player.radius
        color: Qt.rgba(0, 0, 0, 0.4)
    }
    Rectangle {
        id: player
        visible: side.visible && !!root.playing && root.playing.track !== ""
        anchors.horizontalCenter: side.horizontalCenter
        anchors.top: side.bottom
        anchors.topMargin: 28
        width: Math.min(420, side.width - 80)
        height: 92
        radius: Tema.r(20)
        color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.86)
        border.color: root.border
        Rectangle {
            id: art
            x: 14; anchors.verticalCenter: parent.verticalCenter
            width: 64; height: 64
            radius: Tema.r(12)
            color: root.hover
            clip: true
            Icono { anchors.centerIn: parent; width: 24; height: 24; nombre: "musica"; color: root.muted; visible: cover.status !== Image.Ready }
            Image {
                id: cover
                anchors.fill: parent
                source: root.playing ? root.playing.artUrl : ""
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
            }
        }
        Column {
            anchors.left: art.right; anchors.leftMargin: 14
            anchors.right: buttons.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                text: root.playing ? root.playing.track : ""
                color: root.text
                elide: Text.ElideRight
                font { family: root.font; pixelSize: 15; weight: Font.Bold }
            }
            Text {
                width: parent.width
                text: root.playing ? root.playing.artist : ""
                color: root.muted
                elide: Text.ElideRight
                font { family: root.font; pixelSize: 13 }
            }
        }
        Row {
            id: buttons
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: [
                    { icon: "anterior", go: () => root.playing.Previous(), on: root.playing && root.playing.canGoPrevious },
                    { icon: root.playing && root.playing.playbackStatus === Mpris.PlaybackStatus.Playing ? "pausa" : "reproducir",
                      go: () => root.playing.PlayPause(), on: true, main: true },
                    { icon: "siguiente", go: () => root.playing.Next(), on: root.playing && root.playing.canGoNext }
                ]
                delegate: AbstractButton {
                    id: mb
                    required property var modelData
                    width: modelData.main ? 44 : 36; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !!modelData.on
                    opacity: enabled ? 1 : 0.4
                    hoverEnabled: true
                    onClicked: modelData.go()
                    background: Rectangle {
                        radius: width / 2
                        color: mb.modelData.main ? root.accent : (mb.hovered ? root.hover : "transparent")
                    }
                    contentItem: Item {
                        Icono {
                            anchors.centerIn: parent
                            width: mb.modelData.main ? 18 : 15; height: width
                            nombre: mb.modelData.icon
                            color: mb.modelData.main ? root.accentText : root.text
                        }
                    }
                }
            }
        }
    }

    // Elegir piso: se cambia ya, detrás del bloqueo, para que al desbloquear estés en él
    function pick(i) {
        if (i === floor) return;
        floor = i;
        Qt.openUrlExternally("apogeo-piso:" + i);
        password.forceActiveFocus();
    }
}
