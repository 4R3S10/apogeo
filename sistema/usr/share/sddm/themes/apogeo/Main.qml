import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Inicio de sesión de Apogeo, con la estética de Ágape: a la izquierda la tarjeta (la hora grande, tu nombre, en qué piso
// empiezas y la contraseña) y detrás el fondo de Ágape del piso elegido. Cada piso es una sesión («Apogeo · Jugar»,
// etc.): así la elección llega a la sesión sin que esta pantalla toque tus archivos.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#120d14"

    // Colores y letra de Ágape (tema Berenjena oscuro)
    readonly property color text: "#f1e6ea"
    readonly property color muted: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.62)
    readonly property color hover: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.07)
    readonly property color border: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.1)
    readonly property color accent: "#e0a9b4"
    readonly property color accentText: "#2a1c26"
    readonly property string font: "Bricolage Grotesque"
    readonly property var floors: [
        { key: "jugar", name: "Jugar", kind: 7 },      // Luces
        { key: "navegar", name: "Navegar", kind: 0 },  // Tinta
        { key: "estudiar", name: "Estudiar", kind: 2 } // Seda
    ]
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

    // Fondo de Ágape del piso elegido (el mismo sombreador que el escritorio, quieto)
    ShaderEffect {
        id: fx
        width: Math.round(root.width / 3)
        height: Math.round(root.height / 3)
        property real t: 40
        property real kind: root.floors[root.floor].kind
        property real light: 0
        property size res: Qt.size(root.width, root.height)
        property color base: "#120d14"
        property color c1: "#4a2c4f"
        property color c2: "#7a4458"
        property color c3: "#e0a9b4"
        fragmentShader: "file:///usr/share/plasma/wallpapers/org.apogeo.fondo/contents/shaders/fondo.frag.qsb"
    }
    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: fx
        textureSize: Qt.size(fx.width, fx.height)
        smooth: true
        hideSource: true
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.2 }

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
        width: 440
        height: parent.height - 80
        radius: 20
        color: Qt.rgba(33 / 255, 25 / 255, 36 / 255, 0.92)
        border.color: root.border
        Rectangle { // el brillo de 1 px de arriba
            x: parent.radius; y: 1
            width: parent.width - 2 * parent.radius; height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        Image {
            x: 40; y: 40
            width: 44; height: 44
            source: "logo.svg"
            sourceSize: Qt.size(88, 88)
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                id: bigClock
                color: root.text
                font { family: root.font; pixelSize: 72; weight: Font.ExtraBold; letterSpacing: -1 }
                function update() { text = Qt.formatDateTime(new Date(), "HH:mm") }
                Component.onCompleted: update()
                Timer { interval: 5000; running: true; repeat: true; onTriggered: bigClock.update() }
            }
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
                    Rectangle { anchors.fill: parent; anchors.margins: -3; radius: width / 2; color: "transparent"; border.width: 2; border.color: root.accent }
                }
                Text {
                    text: "Hola, " + (root.userReal[root.user] || "")
                    color: root.text
                    width: parent.width - (face.visible ? face.width + parent.spacing : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.Wrap
                    font { family: root.font; pixelSize: 24; weight: Font.Bold }
                    MouseArea {
                        anchors.fill: parent
                        enabled: userModel.count > 1
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.user = (root.user + 1) % userModel.count // otro usuario
                    }
                }
            }
            Text {
                text: userModel.count > 1 ? "¿En qué piso empiezas? (pulsa tu nombre para cambiar de usuario)" : "¿En qué piso empiezas?"
                color: root.muted
                width: parent.width
                wrapMode: Text.Wrap
                font { family: root.font; pixelSize: 15 }
            }

            // Pisos: el control segmentado de Ágape
            Rectangle {
                width: seg.implicitWidth + 6
                height: 40
                radius: 14
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
                                radius: 11
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
                                onClicked: { root.floor = opt.index; password.forceActiveFocus(); }
                            }
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
                Keys.onUpPressed: root.floor = Math.max(0, root.floor - 1)
                Keys.onDownPressed: root.floor = Math.min(root.floors.length - 1, root.floor + 1)
            }

            Text {
                text: root.error
                visible: root.error !== ""
                color: "#ff8f9a"
                font { family: root.font; pixelSize: 14 }
            }
        }

        // Fecha y botones de reiniciar / apagar (los botones de Ágape)
        Text {
            id: date
            x: 40
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            color: root.muted
            font { family: root.font; pixelSize: 14 }
            function update() {
                const d = Qt.locale("es_ES").toString(new Date(), "dddd d 'de' MMMM");
                text = d.charAt(0).toUpperCase() + d.slice(1);
            }
            Component.onCompleted: update()
            Timer { interval: 60000; running: true; repeat: true; onTriggered: date.update() }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 32
            anchors.verticalCenter: date.verticalCenter
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
