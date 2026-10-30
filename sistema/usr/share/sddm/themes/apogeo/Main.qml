import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Inicio de sesión de Órbita («8 · Inicio de sesión»): detrás, el fondo animado del modo que eliges, moviéndose y con sus
// colores (cambian al elegir otro); arriba la hora grande y la fecha; en el centro, una tarjeta de cristal con tu foto,
// tu nombre, la contraseña y en qué modo entras: el orbe, como en el escritorio (el modo elegido en el centro y los otros
// dos en bolitas a sus lados; ← → o un clic en una bolita). Cada modo es una sesión («Apogeo · Jugar», etc.): así la elección llega
// a la sesión sin que esta pantalla toque tus archivos.
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

    // El fondo animado del piso elegido (el mismo sombreador que el escritorio), moviéndose a 30 imágenes por segundo
    // (sin gráfica de verdad, quieto). Al cambiar de piso, se funde con el nuevo.
    property real time: 40
    Timer {
        interval: 33; repeat: true
        running: GraphicsInfo.api !== GraphicsInfo.Software
        onTriggered: root.time += 0.033
    }
    ShaderEffect {
        id: fx
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
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.22 }

    // La marca de Órbita, arriba a la izquierda (el Núcleo y su nombre)
    Row {
        x: 34; y: 28
        spacing: 10
        Image {
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30
            source: "logo.svg"
            sourceSize: Qt.size(60, 60)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "ÓRBITA"
            color: root.muted
            font { family: "Geist Mono"; pixelSize: 12; weight: Font.DemiBold; letterSpacing: 3.4 }
        }
    }

    // La hora grande y la fecha, arriba en el centro
    Column {
        id: clockCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.1
        spacing: 2
        Text {
            id: bigClock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.text
            font { family: root.font; pixelSize: 96; weight: Font.ExtraBold; letterSpacing: -2 }
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.25)
            function update() { text = Qt.formatDateTime(new Date(), "HH:mm") }
            Component.onCompleted: update()
            Timer { interval: 5000; running: true; repeat: true; onTriggered: bigClock.update() }
        }
        Text {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.85)
            font { family: root.font; pixelSize: 20; weight: Font.DemiBold }
            function update() {
                const d = Qt.locale("es_ES").toString(new Date(), "dddd d 'de' MMMM");
                text = d.charAt(0).toUpperCase() + d.slice(1);
            }
            Component.onCompleted: update()
            Timer { interval: 60000; running: true; repeat: true; onTriggered: date.update() }
        }
    }

    RectangularShadow {
        anchors.fill: card
        offset.y: 16
        blur: 44
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    // La tarjeta de cristal, en el centro (un poco por debajo de la mitad)
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(clockCol.y + clockCol.height + 28, Math.round(parent.height * 0.56 - height / 2))
        width: 440
        height: inner.implicitHeight + 72
        radius: 26
        readonly property color sup: Qt.tint(root.c("superficie", "#0f131a"), Qt.rgba(root.text.r, root.text.g, root.text.b, 0.03))
        color: Qt.rgba(sup.r, sup.g, sup.b, 0.62)
        border.color: root.border
        Rectangle { // el brillo de arriba, del color del piso
            x: parent.radius; y: 1
            width: parent.width - 2 * parent.radius; height: 1
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
        }

        Column {
            id: inner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 40
            y: 36
            spacing: 14

            Column {
                width: parent.width
                spacing: 12
                Item { // tu foto (la de la bienvenida o Ajustes), en círculo con el borde del color del piso; sin foto, el logo
                    id: face
                    width: 96; height: 96
                    anchors.horizontalCenter: parent.horizontalCenter
                    Image {
                        anchors.centerIn: parent
                        visible: faceImg.status !== Image.Ready
                        width: 64; height: 64
                        source: "logo.svg"
                        sourceSize: Qt.size(128, 128)
                    }
                    Image {
                        id: faceImg
                        anchors.fill: parent
                        source: {
                            // (sin foto propia, SDDM da su cara gris de siempre: esa no se pone)
                            const f = root.userIcons[root.user] || "";
                            return f === "" || f.indexOf("/sddm/faces/") >= 0 ? "" : f.startsWith("/") ? "file://" + f : f;
                        }
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
                    MultiEffect { anchors.fill: parent; source: faceImg; maskEnabled: true; maskSource: faceMask }
                    Rectangle { visible: faceImg.status === Image.Ready; anchors.fill: parent; anchors.margins: -4; radius: width / 2; color: "transparent"; border.width: 3; border.color: root.accent }
                }
                Text {
                    text: "Hola, " + (root.userReal[root.user] || "")
                    color: root.text
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font { family: root.font; pixelSize: 26; weight: Font.Bold }
                    MouseArea {
                        anchors.fill: parent
                        enabled: userModel.count > 1
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.user = (root.user + 1) % userModel.count // otro usuario
                    }
                }
            }
            Text {
                text: userModel.count > 1 ? "¿En qué modo entras? ← → (pulsa tu nombre para cambiar de usuario)" : "¿En qué modo entras?  ← →"
                color: root.muted
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font { family: root.font; pixelSize: 15 }
            }

            // Los modos: el orbe del elegido en el centro y los otros dos en bolitas a sus lados (Jugar, Navegar y
            // Estudiar dan la vuelta: ← a la izquierda, → a la derecha). Igual que abajo en el escritorio.
            Item {
                id: orbs
                width: parent.width
                height: 104
                Repeater {
                    model: root.floors
                    delegate: Item {
                        id: orb
                        required property var modelData
                        required property int index
                        // -1 a la izquierda, 0 en el centro, 1 a la derecha
                        readonly property int slot: ((index - root.floor + 4) % 3) - 1
                        readonly property bool on: slot === 0
                        readonly property color tint: root.modeColor(index)
                        readonly property real size: on ? 58 : 28
                        width: 120; height: orbs.height
                        x: orbs.width / 2 - width / 2 + slot * 118
                        z: on ? 2 : 1
                        Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                        RectangularShadow { // el halo del elegido
                            anchors.fill: disc
                            radius: width / 2
                            blur: 26; spread: -2
                            color: orb.tint
                            opacity: orb.on ? 0.55 : 0
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                        }
                        Rectangle {
                            id: disc
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: orb.on ? 4 : 19
                            width: orb.size; height: width; radius: width / 2
                            color: orb.on ? "#0b0e14" : "#151b24"
                            border.width: orb.on ? 2 : 1.5
                            border.color: orb.on || orbArea.containsMouse ? orb.tint : Qt.rgba(orb.tint.r, orb.tint.g, orb.tint.b, 0.6)
                            Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                            Rectangle { // el núcleo
                                anchors.centerIn: parent
                                width: orb.on ? 16 : 0; height: width; radius: width / 2
                                color: "#e9edf5"
                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 72
                            text: orb.modelData.name
                            color: orb.on ? orb.tint : root.muted
                            font {
                                family: "Geist Mono"; pixelSize: orb.on ? 13 : 11
                                weight: orb.on ? Font.Bold : Font.DemiBold
                                letterSpacing: orb.on ? 2.6 : 1.4
                                capitalization: Font.AllUppercase
                            }
                        }
                        MouseArea {
                            id: orbArea
                            anchors.fill: disc
                            anchors.margins: -10
                            hoverEnabled: true
                            cursorShape: orb.on ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: { root.floor = orb.index; password.forceActiveFocus(); }
                        }
                    }
                }
            }

            Item { width: 1; height: 6 }

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
                background: Rectangle {
                    radius: 14
                    color: root.hover
                    border.color: password.activeFocus ? root.accent : "transparent"
                    border.width: 1
                }
                onAccepted: root.login()
                // ← → giran los modos (en una contraseña con puntos, mover el cursor no sirve de mucho)
                Keys.onLeftPressed: root.floor = (root.floor + 2) % 3
                Keys.onRightPressed: root.floor = (root.floor + 1) % 3
                Keys.onUpPressed: root.floor = (root.floor + 2) % 3
                Keys.onDownPressed: root.floor = (root.floor + 1) % 3
            }

            Text {
                text: root.error
                visible: root.error !== ""
                color: "#ff6b81"
                font { family: root.font; pixelSize: 14 }
            }
        }

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
            password.forceActiveFocus();
        }
    }
}
