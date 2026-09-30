import QtQuick
import QtQuick.Controls
import QtQuick.Effects

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

    // Colores y letra de Ágape (tema Berenjena oscuro)
    readonly property color text: "#f1e6ea"
    readonly property color muted: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.62)
    readonly property color hover: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.07)
    readonly property color border: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.1)
    readonly property color accent: "#e0a9b4"
    readonly property color accentText: "#2a1c26"
    readonly property string font: "Bricolage Grotesque"
    readonly property var floors: [
        { key: "jugar", name: "Jugar", fondo: "remolino" },
        { key: "navegar", name: "Navegar", fondo: "tinta" },
        { key: "estudiar", name: "Estudiar", fondo: "seda" }
    ]
    // El piso en el que estabas: el fondo del bloqueo es el suyo (lo pone apogeo-pisos)
    property int floor: {
        try {
            const k = floors.findIndex(f => f.fondo === String(wallpaperIntegration.configuration.Estilo || ""));
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
        radius: 20
        color: Qt.rgba(33 / 255, 25 / 255, 36 / 255, 0.92)
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

            // La hora grande, como en la nueva pestaña de Ágape
            Text {
                id: bigClock
                color: root.text
                font { family: root.font; pixelSize: 72; weight: Font.ExtraBold; letterSpacing: -1 }
                function update() { text = Qt.formatDateTime(new Date(), "HH:mm") }
                Component.onCompleted: update()
                Timer { interval: 5000; running: true; repeat: true; onTriggered: bigClock.update() }
            }
            Text {
                text: "Hola de nuevo, " + (kscreenlocker_userName || "")
                color: root.text
                width: parent.width
                wrapMode: Text.Wrap
                font { family: root.font; pixelSize: 24; weight: Font.Bold }
            }
            Text {
                text: "¿A qué piso vuelves?"
                color: root.muted
                font { family: root.font; pixelSize: 15 }
            }

            // Pisos: el control segmentado de Ágape (la pastilla rosa con brillo es el elegido)
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
                    radius: 14
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
                text: root.error
                visible: root.error !== ""
                color: "#ff8f9a"
                width: parent.width
                wrapMode: Text.Wrap
                font { family: root.font; pixelSize: 14 }
            }
        }

        Text {
            id: clock
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
            Timer { interval: 60000; running: true; repeat: true; onTriggered: clock.update() }
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
