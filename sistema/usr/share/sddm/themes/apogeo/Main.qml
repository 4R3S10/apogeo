import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Inicio de sesión de Órbita, como el bloqueo («N2 · Hora recortada»): detrás, la Tierra vista desde el espacio (la del
// arranque, tierra.png del tema de Plymouth: al entrar vienes de ella); la hora gigante recortada en ella (dentro de los
// números se ve nítida; fuera, desenfocada y oscura), la fecha debajo y una línea para la contraseña. Arriba a la
// izquierda, los modos: en el que entras, en su color (clic, ← → o ↑ ↓). Sin la foto de la Tierra (aún no se ha bajado),
// el fondo animado del modo y los números en blanco. Cada modo es una sesión («Apogeo · Jugar», etc.): así la elección
// llega a la sesión sin que esta pantalla toque tus archivos.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: c("fondo", "#080a0f")

    // Colores y letra: los de Órbita o tu identidad, si la has cambiado (Ajustes → Identidad, «Clásico» o «Como Ágape»):
    // Apogeo deja una copia de tus colores en /var/lib/apogeo/aspecto-login.json, que esta pantalla sí puede leer
    property var f: ({})
    function c(k, d) { return f[k] !== undefined ? f[k] : d }
    Component.onCompleted: {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            try { root.f = x.responseText ? JSON.parse(x.responseText) : {}; } catch (e) { root.f = {}; }
        };
        x.open("GET", "file:///var/lib/apogeo/aspecto-login.json");
        try { x.send(); } catch (e) {}
    }
    readonly property color text: c("texto", "#e9edf5")
    readonly property color muted: Qt.rgba(text.r, text.g, text.b, 0.62)
    readonly property color hover: Qt.rgba(text.r, text.g, text.b, 0.07)
    readonly property color border: Qt.rgba(text.r, text.g, text.b, 0.1)
    // Los del piso elegido (con «Del fondo», cada piso tiene los suyos), si los hay
    readonly property var p: f.pisos && f.pisos[floors[floor].key] ? f.pisos[floors[floor].key] : ({})
    function cp(k, d) { return p[k] !== undefined ? p[k] : c(k, d) }
    readonly property color accent: modeColor(floor)
    // El color de cada modo (el tuyo, si lo has cambiado; si no, el de Órbita)
    function modeColor(i) {
        const x = f.pisos && f.pisos[floors[i].key] ? f.pisos[floors[i].key] : {};
        return x.acento !== undefined ? x.acento : c("acento", floors[i].color);
    }
    readonly property color accentText: cp("sobreAcento", "#041318")
    readonly property string font: c("letra", "Geist")
    readonly property var wp: cp("wp", ["#0b1118", "#12303d", "#45d6ff"])
    readonly property var floors: [
        { key: "jugar", name: "Jugar", kind: 9, color: "#b79cff" },      // Nebulosa
        { key: "navegar", name: "Navegar", kind: 8, color: "#45d6ff" },  // Órbitas
        { key: "estudiar", name: "Estudiar", kind: 10, color: "#ffb35c" } // Aurora
    ]
    // El fondo animado de ese piso (el suyo, si es uno de Apogeo; si es una foto o un vídeo tuyo, el de serie del piso
    // con sus colores: esos esta pantalla no los puede leer)
    readonly property int kind: p.estilo !== undefined && p.estilo >= 0 ? p.estilo : floors[floor].kind
    property int floor: 1
    property int user: Math.max(0, userModel.lastIndex)
    property var sessionIndex: ({})   // piso → índice de su sesión
    property var userNames: []
    property var userReal: []
    property var userIcons: []
    property string error: ""

    // Las sesiones y los usuarios solo se pueden leer como modelos: se copian a listas
    Repeater {
        model: sessionModel
        delegate: Item {
            required property int index
            required property string file
            Component.onCompleted: {
                // apogeo-1-navegar.desktop… (el número las ordena: sin sesión anterior, SDDM marca la primera, Navegar)
                const m = /apogeo-(?:\d-)?([a-z]+)\.desktop$/.exec(file || "");
                if (!m) return;
                const s = root.sessionIndex; s[m[1]] = index; root.sessionIndex = s;
                if (index === sessionModel.lastIndex) root.floor = Math.max(0, root.floors.findIndex(f => f.key === m[1]));
            }
        }
    }
    Repeater {
        model: userModel
        delegate: Item {
            required property int index
            required property string name
            required property string realName
            required property string icon
            Component.onCompleted: {
                const ic = root.userIcons.slice(); ic[index] = icon || ""; root.userIcons = ic;
                const n = root.userNames.slice(); n[index] = name; root.userNames = n;
                const r = root.userReal.slice(); r[index] = realName || name; root.userReal = r;
            }
        }
    }

    // Sin la Tierra: el fondo animado del piso elegido (el mismo sombreador que el escritorio), moviéndose a 30 imágenes
    // por segundo (sin gráfica de verdad, quieto). Al cambiar de piso, se funde con el nuevo.
    property real time: 40
    Timer {
        interval: 33; repeat: true
        running: !root.foto && GraphicsInfo.api !== GraphicsInfo.Software
        onTriggered: root.time += 0.033
    }
    ShaderEffect {
        id: fx
        visible: !root.foto
        width: Math.round(root.width / 3)
        height: Math.round(root.height / 3)
        property real t: root.time
        property real kind: root.kind
        property real light: 0
        property size res: Qt.size(root.width, root.height)
        property color base: root.color
        property color c1: root.wp[0]
        property color c2: root.wp[1]
        property color c3: root.wp[2]
        Behavior on c1 { ColorAnimation { duration: 600 } }
        Behavior on c2 { ColorAnimation { duration: 600 } }
        Behavior on c3 { ColorAnimation { duration: 600 } }
        fragmentShader: "file:///usr/share/plasma/wallpapers/org.apogeo.fondo/contents/shaders/fondo.frag.qsb"
    }
    ShaderEffectSource {
        id: fxView
        anchors.fill: parent
        visible: !root.foto
        sourceItem: fx
        textureSize: Qt.size(fx.width, fx.height)
        smooth: true
        hideSource: true
    }
    onKindChanged: fade.restart()
    SequentialAnimation {
        id: fade
        NumberAnimation { target: fxView; property: "opacity"; to: 0.35; duration: 120 }
        NumberAnimation { target: fxView; property: "opacity"; to: 1; duration: 420; easing.type: Easing.OutCubic }
    }
    Rectangle { anchors.fill: parent; visible: !root.foto; color: "#05080c"; opacity: 0.45 }

    // La Tierra desde el espacio: desenfocada y oscura detrás de todo, nítida dentro de los números
    readonly property bool foto: tierra.status === Image.Ready
    Image {
        id: tierra
        anchors.fill: parent
        source: "file:///usr/share/plymouth/themes/apogeo/tierra.png"
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: tierra
        visible: root.foto
        blurEnabled: true; blur: 1; blurMax: 64
        brightness: -0.18
        saturation: -0.1
    }
    // (un poco de oscuridad arriba y abajo, para que la hora flote)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.02, 0.03, 0.05, 0.35) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0.03, 0.05, 0.55) }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: password.forceActiveFocus() }

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
        font { family: root.font; pixelSize: root.tam; weight: Font.ExtraBold; letterSpacing: -root.tam * 0.05 }
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
            source: tierra
            maskEnabled: true
            maskSource: mascara
        }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.accent; shadowBlur: 1; shadowOpacity: 0.35; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }
    Numeros {
        visible: !root.foto
        color: Qt.rgba(1, 1, 1, 0.92)
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.accent; shadowBlur: 1; shadowOpacity: 0.4; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }
    Numeros {
        color: "transparent"
        style: Text.Outline
        styleColor: Qt.rgba(1, 1, 1, 0.35)
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: horaCaja.y + horaCaja.height + 18
        text: root.fecha
        color: "#dfe5ee"
        font { family: root.font; pixelSize: 26; weight: Font.Light; letterSpacing: 0.5 }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.6); shadowBlur: 0.6; shadowVerticalOffset: 2 }
    }

    // ---------- Arriba a la izquierda: los modos (en el que entras, en su color) ----------
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
                readonly property color c: root.modeColor(index)
                spacing: 8
                opacity: on ? 1 : modoArea.containsMouse ? 0.8 : 0.45
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Rectangle { width: 6; height: 6; radius: 3; color: modoFila.c; visible: modoFila.on; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: modoFila.modelData.name.toUpperCase()
                    color: modoFila.on ? modoFila.c : "#cfd6e0"
                    font { family: "Geist Mono"; pixelSize: 12; letterSpacing: 3 }
                    MouseArea { id: modoArea; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.floor = modoFila.index; password.forceActiveFocus(); } }
                }
            }
        }
    }

    // ---------- Abajo: quién entra (solo si hay más de una cuenta) y la contraseña, una línea con el cursor del modo ----------
    Text {
        visible: userModel.count > 1
        anchors.horizontalCenter: parent.horizontalCenter
        y: entrada.y - 34
        text: (root.userReal[root.user] || "") + "  ⇄"
        color: Qt.rgba(1, 1, 1, 0.7)
        font { family: root.font; pixelSize: 15 }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.user = (root.user + 1) % userModel.count; password.forceActiveFocus(); } // otra cuenta
        }
    }
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
            font { family: "Geist Mono"; pixelSize: 11; letterSpacing: 2.5 }
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
            font { family: "Geist Mono"; pixelSize: 15; letterSpacing: 4 }
            leftPadding: 2
            focus: true
            cursorDelegate: Rectangle {
                width: 2
                color: root.accent
                visible: password.cursorVisible
            }
            background: Item {
                Rectangle {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                    width: parent.width; height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: password.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.45) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.12) }
                    }
                }
            }
            onAccepted: root.login()
            // ← → (o ↑ ↓) cambian el modo en el que entras (en una contraseña con puntos, mover el cursor no sirve de mucho)
            Keys.onLeftPressed: root.floor = (root.floor + 2) % 3
            Keys.onRightPressed: root.floor = (root.floor + 1) % 3
            Keys.onUpPressed: root.floor = (root.floor + 2) % 3
            Keys.onDownPressed: root.floor = (root.floor + 1) % 3
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: entrada.y + entrada.height + 10
        text: root.error
        visible: root.error !== ""
        color: "#ff6b81"
        font { family: root.font; pixelSize: 13 }
    }

    // Reiniciar y apagar (los botones de Ágape), abajo a la derecha
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        spacing: 2
        Repeater {
            model: [
                { icon: "reiniciar", tip: "Reiniciar", run: () => sddm.reboot(), can: sddm.canReboot },
                { icon: "apagar", tip: "Apagar", run: () => sddm.powerOff(), can: sddm.canPowerOff }
            ]
            delegate: Item {
                required property var modelData
                visible: modelData.can
                width: 34; height: 34
                Rectangle { anchors.fill: parent; radius: 12; color: btn.containsMouse ? root.hover : "transparent" }
                Image {
                    id: btnIcon
                    anchors.centerIn: parent
                    width: 17; height: 17
                    source: modelData.icon + ".svg"
                    sourceSize: Qt.size(34, 34)
                    visible: false
                }
                MultiEffect {
                    anchors.fill: btnIcon
                    source: btnIcon
                    colorization: 1
                    colorizationColor: btn.containsMouse ? root.text : root.muted
                }
                MouseArea { id: btn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.run() }
                ToolTip.visible: btn.containsMouse
                ToolTip.text: modelData.tip
            }
        }
    }

    function login() {
        const key = floors[floor].key;
        const s = sessionIndex[key] !== undefined ? sessionIndex[key] : sessionModel.lastIndex;
        error = "";
        sddm.login(userNames[user] || userModel.lastUser, password.text, s);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.error = "Contraseña incorrecta";
            password.text = "";
            shake.restart();
            password.forceActiveFocus();
        }
    }
}
