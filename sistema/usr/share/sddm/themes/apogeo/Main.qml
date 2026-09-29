import QtQuick
import QtQuick.Controls

// Inicio de sesión de Apogeo: una tarjeta a la izquierda con tu nombre, en qué piso empiezas y la contraseña. El fondo
// de la derecha es el del piso elegido. Cada piso es una sesión («Apogeo · Jugar», etc.): así la elección llega a la
// sesión sin que esta pantalla toque tus archivos.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#120d14"

    readonly property color text: "#f1e6ea"
    readonly property color muted: "#a9949f"
    readonly property var floors: [
        { key: "jugar", name: "Jugar", icon: "🎮", accent: "#ff8fc6" },
        { key: "navegar", name: "Navegar", icon: "♥", accent: "#e0a9b4" },
        { key: "estudiar", name: "Estudiar", icon: "✎", accent: "#c9b8c9" }
    ]
    property int floor: 1
    property int user: Math.max(0, userModel.lastIndex)
    property var sessionIndex: ({})   // piso → índice de su sesión
    property var userNames: []
    property var userReal: []
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
            Component.onCompleted: {
                const n = root.userNames.slice(); n[index] = name; root.userNames = n;
                const r = root.userReal.slice(); r[index] = realName || name; root.userReal = r;
            }
        }
    }

    // Fondo del piso elegido (cambia con un fundido)
    Repeater {
        model: root.floors
        delegate: Image {
            required property var modelData
            required property int index
            anchors.fill: parent
            source: "file:///usr/share/apogeo/fondos/" + modelData.key + ".jpg"
            fillMode: Image.PreserveAspectCrop
            opacity: index === root.floor ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        }
    }

    Rectangle {
        id: card
        x: 40; y: 40
        width: 440
        height: parent.height - 80
        radius: 28
        color: Qt.rgba(30 / 255, 22 / 255, 33 / 255, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Image {
            x: 44; y: 44
            width: 64; height: 64
            source: "logo.svg"
            sourceSize: Qt.size(128, 128)
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 44
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                text: "Hola, " + (root.userReal[root.user] || "")
                color: root.text
                font { family: "Nunito"; pixelSize: 40; weight: Font.ExtraBold }
                MouseArea {
                    anchors.fill: parent
                    enabled: userModel.count > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.user = (root.user + 1) % userModel.count // otro usuario
                }
            }
            Text {
                text: userModel.count > 1 ? "¿En qué piso empiezas? (pulsa tu nombre para cambiar de usuario)" : "¿En qué piso empiezas?"
                color: root.muted
                font { family: "Nunito"; pixelSize: 17 }
                width: parent.width
                wrapMode: Text.Wrap
            }

            Row {
                spacing: 8
                Repeater {
                    model: root.floors
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: index === root.floor
                        width: label.implicitWidth + 30
                        height: 40
                        radius: 20
                        color: on ? modelData.accent : Qt.rgba(1, 1, 1, pill.containsMouse ? 0.12 : 0.06)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.icon + "  " + modelData.name
                            color: parent.on ? "#2a1a22" : root.text
                            font { family: "Nunito"; pixelSize: 16; weight: Font.Bold }
                        }
                        MouseArea {
                            id: pill
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.floor = index; password.forceActiveFocus(); }
                        }
                    }
                }
            }

            Item { width: 1; height: 8 }

            TextField {
                id: password
                width: parent.width
                height: 52
                echoMode: TextInput.Password
                placeholderText: "Contraseña"
                placeholderTextColor: root.muted
                color: root.text
                font { family: "Nunito"; pixelSize: 17 }
                leftPadding: 18
                focus: true
                background: Rectangle {
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.color: password.activeFocus ? root.floors[root.floor].accent : "transparent"
                    border.width: 2
                }
                onAccepted: root.login()
                Keys.onUpPressed: root.floor = Math.max(0, root.floor - 1)
                Keys.onDownPressed: root.floor = Math.min(root.floors.length - 1, root.floor + 1)
            }

            Text {
                text: root.error
                visible: root.error !== ""
                color: "#ff8f9a"
                font { family: "Nunito"; pixelSize: 15 }
            }
        }

        // Hora y botones de apagar / reiniciar
        Text {
            id: clock
            x: 44
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            color: root.muted
            font { family: "Nunito"; pixelSize: 17 }
            function update() {
                text = Qt.formatDateTime(new Date(), "HH:mm") + " · " + Qt.locale("es_ES").toString(new Date(), "dddd d 'de' MMMM");
            }
            Component.onCompleted: update()
            Timer { interval: 5000; running: true; repeat: true; onTriggered: clock.update() }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 36
            anchors.verticalCenter: clock.verticalCenter
            spacing: 8
            Repeater {
                model: [
                    { label: "⟳", tip: "Reiniciar", run: () => sddm.reboot(), can: sddm.canReboot },
                    { label: "⏻", tip: "Apagar", run: () => sddm.powerOff(), can: sddm.canPowerOff }
                ]
                delegate: Rectangle {
                    required property var modelData
                    visible: modelData.can
                    width: 40; height: 40; radius: 12
                    color: Qt.rgba(1, 1, 1, btn.containsMouse ? 0.12 : 0.05)
                    Text { anchors.centerIn: parent; text: modelData.label; color: root.text; font.pixelSize: 18 }
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
