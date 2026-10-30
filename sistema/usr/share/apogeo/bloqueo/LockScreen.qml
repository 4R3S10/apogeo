import QtQuick
import Apogeo
import QtQuick.Controls
import QtQuick.Effects
import org.kde.coreaddons as KCoreAddons

// Pantalla de bloqueo de Apogeo («N2 · Hora recortada»): la hora gigante, recortada en el fondo de tu modo (dentro de los
// números se ve nítido; fuera, desenfocado y oscuro), la fecha debajo y una línea para la contraseña. Arriba a la
// izquierda, los modos: el tuyo en su color (clic, o ↑ ↓, para volver a otro). Sustituye a la de Plasma (la copia
// apogeo-bloqueo). Si algún día no carga, el bloqueo de KDE pone su pantalla básica y se puede desbloquear igual.
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

    // El fondo de tu modo, si es una foto (lo apunta apogeo-pisos en el del bloqueo): desenfocado y oscuro detrás de todo
    // y nítido dentro de los números. Con un fondo animado o un vídeo, sobre él, una sombra y los números en blanco
    readonly property string archivo: {
        try { return String(wallpaperIntegration.configuration.Archivo || ""); } catch (e) { return ""; }
    }
    readonly property bool foto: /\.(jpe?g|png|webp|avif|jxl|bmp)$/i.test(archivo) && fotoImg.status === Image.Ready
    readonly property color modoColor: ({ jugar: "#b79cff", navegar: "#45d6ff", estudiar: "#ffb35c" })[floors[floor].key]
    Image {
        id: fotoImg
        anchors.fill: parent
        source: /\.(jpe?g|png|webp|avif|jxl|bmp)$/i.test(root.archivo) ? "file://" + root.archivo : ""
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: fotoImg
        visible: root.foto
        blurEnabled: true; blur: 1; blurMax: 64
        brightness: -0.38
        saturation: -0.1
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.foto
        color: "#05080c"
        opacity: 0.55
    }
    // (un poco de oscuridad en los bordes, para que la hora flote)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.02, 0.03, 0.05, 0.35) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0.03, 0.05, 0.55) }
        }
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

    // ---------- La hora recortada ----------
    readonly property real tam: Math.min(400, width / 3.2, height / 2.3)
    property string hora: Qt.formatDateTime(new Date(), "HH:mm")
    property string fecha: Qt.locale("es_ES").toString(new Date(), "dddd, d 'de' MMMM")
    Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: {
            root.hora = Qt.formatDateTime(new Date(), "HH:mm");
            root.fecha = Qt.locale("es_ES").toString(new Date(), "dddd, d 'de' MMMM");
        }
    }
    // Los números como máscara (del tamaño de la pantalla, como la foto): dentro, la foto nítida con un brillo del color
    // del modo; sin foto, en blanco. Encima, su borde fino
    Item {
        id: horaCaja
        width: parent.width
        height: root.tam * 1.05
        y: parent.height * 0.38 - height / 2
    }
    component Numeros: Text {
        x: 0; y: horaCaja.y
        width: root.width; height: horaCaja.height
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.hora
        font { family: Tema.letra; pixelSize: root.tam; weight: Font.ExtraBold; letterSpacing: -root.tam * 0.05 }
    }
    Item {
        id: mascara
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Numeros { color: "white" }
    }
    Item {
        anchors.fill: parent
        visible: root.foto
        MultiEffect {
            anchors.fill: parent
            source: fotoImg
            maskEnabled: true
            maskSource: mascara
        }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.modoColor; shadowBlur: 1; shadowOpacity: 0.35; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }
    Numeros {
        visible: !root.foto
        color: Qt.rgba(1, 1, 1, 0.92)
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.modoColor; shadowBlur: 1; shadowOpacity: 0.4; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }
    Numeros {
        color: "transparent"
        style: Text.Outline
        styleColor: Qt.rgba(1, 1, 1, 0.35)
    }
    Text {
        id: fechaTexto
        anchors.horizontalCenter: parent.horizontalCenter
        y: horaCaja.y + horaCaja.height + 18
        text: root.fecha
        color: "#dfe5ee"
        font { family: Tema.letra; pixelSize: 26; weight: Font.Light; letterSpacing: 0.5 }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 0.6; shadowVerticalOffset: 2 }
    }

    // ---------- Arriba a la izquierda: los modos (el tuyo en su color) ----------
    Row {
        x: 48; y: 40
        spacing: 22
        Repeater {
            model: root.floors
            delegate: Row {
                id: modoFila
                required property var modelData
                required property int index
                readonly property bool on: index === root.floor
                readonly property color c: ({ jugar: "#b79cff", navegar: "#45d6ff", estudiar: "#ffb35c" })[modelData.key]
                spacing: 8
                opacity: on ? 1 : modoArea.containsMouse ? 0.8 : 0.45
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Rectangle { width: 6; height: 6; radius: 3; color: modoFila.c; visible: modoFila.on; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: modoFila.modelData.name.toUpperCase()
                    color: modoFila.on ? modoFila.c : "#cfd6e0"
                    font { family: Tema.mono; pixelSize: 12; letterSpacing: 3 }
                    MouseArea { id: modoArea; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(modoFila.index) }
                }
            }
        }
    }

    // ---------- Abajo: la contraseña, una línea con el cursor del color del modo ----------
    Item {
        id: entrada
        width: Math.min(420, parent.width - 80)
        height: 40
        x: (parent.width - width) / 2
        y: parent.height - 120
        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: entrada; property: "x"; to: (root.width - entrada.width) / 2 + 12; duration: 50 }
            NumberAnimation { target: entrada; property: "x"; to: (root.width - entrada.width) / 2 - 12; duration: 80 }
            NumberAnimation { target: entrada; property: "x"; to: (root.width - entrada.width) / 2; duration: 50 }
        }
        Text {
            id: etiqueta
            anchors.verticalCenter: parent.verticalCenter
            text: "CONTRASEÑA"
            color: Qt.rgba(1, 1, 1, 0.55)
            font { family: Tema.mono; pixelSize: 11; letterSpacing: 2.5 }
        }
        TextField {
            id: password
            anchors.left: etiqueta.right; anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 40
            echoMode: TextInput.Password
            passwordCharacter: "●"
            color: "#eceef3"
            font { family: Tema.mono; pixelSize: 15; letterSpacing: 4 }
            leftPadding: 2
            focus: true
            enabled: !root.busy && !retry.running
            cursorDelegate: Rectangle {
                width: 2
                color: root.modoColor
                visible: password.cursorVisible
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.modoColor; shadowBlur: 0.6; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
            }
            background: Item {
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                    width: parent.width; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: password.activeFocus ? root.modoColor : Qt.rgba(1, 1, 1, 0.45) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.12) }
                    }
                }
            }
            onAccepted: root.unlock()
            onTextEdited: root.start()
            Keys.onUpPressed: root.pick(Math.max(0, root.floor - 1))
            Keys.onDownPressed: root.pick(Math.min(root.floors.length - 1, root.floor + 1))
            Keys.onEscapePressed: text = ""
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: entrada.y + entrada.height + 10
        width: Math.min(520, parent.width - 80)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.error !== "" ? root.error : root.symbolOn ? "o dibuja tu símbolo en cualquier parte de la pantalla" : ""
        color: root.error !== "" ? Tema.error : Qt.rgba(1, 1, 1, 0.5)
        font { family: Tema.letra; pixelSize: 13 }
    }

    // Elegir piso: se cambia ya, detrás del bloqueo, para que al desbloquear estés en él
    function pick(i) {
        if (i === floor) return;
        floor = i;
        Qt.openUrlExternally("apogeo-piso:" + i);
        password.forceActiveFocus();
    }
}
