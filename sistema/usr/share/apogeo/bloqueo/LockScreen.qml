import QtQuick
import QtQuick.Controls

// Pantalla de bloqueo de Apogeo («Tarjeta con piso», como la de inicio de sesión): tu nombre, el piso al que vuelves y
// la contraseña. Sustituye a la de Plasma (la copia apogeo-bloqueo). Si algún día no carga, el bloqueo de KDE pone su
// pantalla básica y se puede desbloquear igual.
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

    readonly property color text: "#f1e6ea"
    readonly property color muted: "#a9949f"
    readonly property var floors: [
        { key: "jugar", name: "Jugar", icon: "🎮", accent: "#ff8fc6" },
        { key: "navegar", name: "Navegar", icon: "♥", accent: "#e0a9b4" },
        { key: "estudiar", name: "Estudiar", icon: "✎", accent: "#c9b8c9" }
    ]
    // El piso en el que estabas: el fondo del bloqueo es el suyo (lo pone apogeo-pisos)
    property int floor: {
        try {
            const img = String(wallpaperIntegration.configuration.Image || "");
            const k = floors.findIndex(f => img.indexOf("/" + f.key + ".") >= 0);
            return k >= 0 ? k : 1;
        } catch (e) {
            return 1;
        }
    }
    property string error: ""
    property bool busy: false
    property string pending: ""   // contraseña escrita antes de que KDE la pida

    onClearPassword: { password.text = ""; pending = ""; }

    // KDE ignora «empezar» durante los primeros segundos del bloqueo (el margen para volver sin contraseña), así que se
    // pide cada vez que tocas el ratón o el teclado y justo antes de comprobar la contraseña, como hace el suyo
    function start() { authenticator.startAuthenticating() }
    Component.onCompleted: start()

    Connections {
        target: authenticator
        function onFailed(kind) {
            if (kind != 0) return; // huella u otros métodos sin contraseña: no se enseña
            root.busy = false;
            root.pending = "";
            watchdog.stop();
            root.error = "Contraseña incorrecta";
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
        error = "";
        busy = true;
        watchdog.restart();
        if (authenticator.promptForSecret) {
            authenticator.respond(password.text);
        } else {
            pending = password.text;
            start();
        }
    }

    // Oscurece un poco el fondo para que la tarjeta resalte
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.25
    }

    // Mover el ratón o pulsar una tecla lleva a la contraseña
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPressed: { root.start(); password.forceActiveFocus(); }
        onPositionChanged: root.start()
    }

    Rectangle {
        id: card
        x: 40; y: 40
        width: Math.min(440, parent.width - 80)
        height: parent.height - 80
        radius: 28
        color: Qt.rgba(30 / 255, 22 / 255, 33 / 255, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.08)

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: card; property: "x"; to: 52; duration: 50 }
            NumberAnimation { target: card; property: "x"; to: 28; duration: 80 }
            NumberAnimation { target: card; property: "x"; to: 40; duration: 50 }
        }

        Image {
            x: 44; y: 44
            width: 64; height: 64
            source: "file:///usr/share/apogeo/logo.svg"
            sourceSize: Qt.size(128, 128)
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 44
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                text: "Hola de nuevo, " + (kscreenlocker_userName || "")
                color: root.text
                width: parent.width
                wrapMode: Text.Wrap
                font { family: "Nunito"; pixelSize: 36; weight: Font.ExtraBold }
            }
            Text {
                text: "¿A qué piso vuelves?"
                color: root.muted
                font { family: "Nunito"; pixelSize: 17 }
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
                            onClicked: root.pick(index)
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
                enabled: !root.busy && !retry.running
                background: Rectangle {
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.color: password.activeFocus ? root.floors[root.floor].accent : "transparent"
                    border.width: 2
                }
                onAccepted: root.unlock()
                onTextEdited: root.start()
                Keys.onUpPressed: root.pick(Math.max(0, root.floor - 1))
                Keys.onDownPressed: root.pick(Math.min(root.floors.length - 1, root.floor + 1))
                Keys.onEscapePressed: text = ""
            }

            Text {
                text: root.error
                visible: root.error !== ""
                color: "#ff8f9a"
                width: parent.width
                wrapMode: Text.Wrap
                font { family: "Nunito"; pixelSize: 15 }
            }
        }

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
    }

    // Elegir piso: se cambia ya, detrás del bloqueo, para que al desbloquear estés en él
    function pick(i) {
        if (i === floor) return;
        floor = i;
        Qt.openUrlExternally("apogeo-piso:" + i);
        password.forceActiveFocus();
    }
}
