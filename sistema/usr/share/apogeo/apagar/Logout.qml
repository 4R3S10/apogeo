import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.plasma5support as P5Support
import Apogeo

// Pantalla de apagar de Apogeo («A1 · La isla se abre»): la isla de abajo crece hacia arriba y se convierte en el menú.
// Arriba tu foto, «¿Hasta luego?» y desde cuándo está encendido; en medio, Apagar, Reiniciar, Reposo, Ir a Windows (si
// hay un Windows escondido), Salir y Bloquear; abajo, cuántas apps se cierran (Ágape guarda sus pestañas) y «Actualizar
// al apagar» si hay actualizaciones. Si se ha pedido algo concreto (apagar, reiniciar o salir), solo sale eso con su
// cuenta atrás de 30 segundos. Esc o un clic fuera cancelan; las flechas eligen e Intro hace.
// Las señales y lo que da ksmserver (sdtype, maysd, canLogout, spdMethods, softwareUpdatePending…) son los de Plasma.
// Desde Plasma 6.8 la pantalla de apagar es la del escritorio de Plasma (shells/org.kde.plasma.desktop/contents/logout,
// una por pantalla): apogeo-bloqueo pone esta en su lugar, como la de bloqueo.
Item {
    id: root

    signal logoutRequested()
    signal haltRequested()
    signal haltUpdateRequested()
    signal suspendRequested(int spdMethod)
    signal rebootRequested()
    signal rebootRequested2(int opt)
    signal rebootUpdateRequested()
    signal cancelRequested()
    signal lockScreenRequested()
    signal cancelSoftwareUpdateRequested()

    readonly property bool showAllOptions: sdtype === ShutdownType.ShutdownTypeDefault
    property int remaining: 30
    readonly property string firstName: (kuser.fullName || kuser.loginName || "").split(" ")[0]

    function halt() { softwareUpdatePending ? root.haltUpdateRequested() : root.haltRequested() }
    function reboot() { softwareUpdatePending ? root.rebootUpdateRequested() : root.rebootRequested() }

    KCoreAddons.KUser { id: kuser }

    QQC2.Action { shortcut: "Escape"; onTriggered: root.cancelRequested() }

    Timer {
        running: !root.showAllOptions
        repeat: true
        interval: 1000
        onTriggered: {
            root.remaining--;
            if (root.remaining <= 0) {
                if (sdtype === ShutdownType.ShutdownTypeReboot) root.reboot();
                else if (sdtype === ShutdownType.ShutdownTypeHalt) root.halt();
                else root.logoutRequested();
            }
        }
    }

    // ---------- Lo que se cuenta: encendido, Windows, actualizaciones y tus apps ----------
    property int uptime: 0
    property bool windows: false
    property var updates: ({ cuantas: 0, marcado: false })
    property var apps: []
    readonly property bool agape: apps.some(a => (a.clase + " " + a.app).toLowerCase().indexOf("ares") >= 0)
    readonly property string cmdUptime: "cat /proc/uptime"
    readonly property string cmdWindows: "/usr/lib/apogeo/apogeo-windows estado"
    readonly property string cmdUpdates: "/usr/lib/apogeo/apogeo-actualizar-al-apagar estado"
    readonly property string cmdApps: "dbus-send --session --print-reply=literal --dest=org.apogeo.Datos /Datos org.apogeo.Datos.Ventanas"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: [root.cmdUptime, root.cmdWindows, root.cmdUpdates, root.cmdApps]
        onNewData: (source, data) => {
            const out = String(data.stdout || "").trim();
            try {
                if (source === root.cmdUptime) root.uptime = parseInt(out) || 0;
                else if (source === root.cmdWindows) root.windows = !!JSON.parse(out).windows;
                else if (source === root.cmdUpdates) root.updates = JSON.parse(out);
                else if (source === root.cmdApps) root.apps = JSON.parse(out);
            } catch (e) {}
            disconnectSource(source);
        }
    }
    function run(cmd) { runner.connectSource(cmd) }
    function toggleUpdates() {
        const want = !root.updates.marcado;
        root.updates = Object.assign({}, root.updates, { marcado: want });   // se ve ya; luego se confirma
        root.run("sh -c 'pkexec /usr/lib/apogeo/apogeo-actualizar-al-apagar " + (want ? "marcar" : "quitar")
                 + "; true' #" + Date.now());
        confirm.restart();
    }
    Timer { id: confirm; interval: 1500; onTriggered: root.run(root.cmdUpdates) }
    function upText() {
        const h = Math.floor(root.uptime / 3600), m = Math.floor(root.uptime % 3600 / 60);
        return "Encendido desde hace " + (h ? h + " h " : "") + m + " min";
    }

    // ---------- La cortina y la isla que crece ----------
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: card.open ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
    }
    MouseArea { anchors.fill: parent; onClicked: root.cancelRequested() }

    readonly property var actions: [
        { key: "halt", texto: softwareUpdatePending ? "Actualizar y apagar" : "Apagar", icono: "apagar",
          ver: maysd && (showAllOptions || sdtype === ShutdownType.ShutdownTypeHalt), run: () => root.halt() },
        { key: "reboot", texto: softwareUpdatePending ? "Actualizar y reiniciar" : "Reiniciar", icono: "actualizar",
          ver: maysd && (showAllOptions || sdtype === ShutdownType.ShutdownTypeReboot), run: () => root.reboot() },
        { key: "sleep", texto: "Reposo", icono: "luna",
          ver: showAllOptions && spdMethods.SuspendState, run: () => root.suspendRequested(2) },
        { key: "windows", texto: "Ir a Windows", icono: "jugar",
          ver: showAllOptions && maysd && root.windows, run: () => {
              root.run("sh -c 'printf %s \\'{\"modo\":\"escritorio\"}\\' | pkexec /usr/lib/apogeo/apogeo-windows ir'");
              root.cancelRequested();
          } },
        { key: "logout", texto: "Salir", icono: "salir",
          ver: canLogout && (showAllOptions || sdtype === ShutdownType.ShutdownTypeNone), run: () => root.logoutRequested() },
        { key: "lock", texto: "Bloquear", icono: "llave",
          ver: showAllOptions, run: () => root.lockScreenRequested() }
    ].filter(a => a.ver)
    property int current: 0

    RectangularShadow {
        anchors.fill: card
        offset.y: 18
        blur: 50
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: card.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
    }
    Rectangle {
        id: card
        // Empieza con el tamaño de la isla, abajo en el centro, y crece hacia arriba
        property bool open: false
        Component.onCompleted: open = true
        readonly property real fullWidth: Math.max(560, buttons.implicitWidth + 48)
        readonly property real fullHeight: col.implicitHeight + 44
        width: open ? fullWidth : 420
        height: open ? fullHeight : 54
        x: (root.width - width) / 2
        y: root.height - height - 14
        radius: open ? 26 : 22
        color: Qt.rgba(33 / 255, 25 / 255, 36 / 255, 0.97)
        border.color: Tema.borde
        clip: true
        Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: 280 } }
        Rectangle { // el brillo de 1 px de arriba
            x: parent.radius; y: 1
            width: parent.width - 2 * parent.radius; height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }
        MouseArea { anchors.fill: parent } // (los clics dentro no cancelan)

        Column {
            id: col
            x: 22; y: 22
            width: card.fullWidth - 44
            spacing: 0
            opacity: card.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InQuad } }

            // Tu foto, el saludo y desde cuándo está encendido; a la derecha, Cancelar
            Item {
                width: parent.width
                height: 48
                Foto {
                    id: face
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46; height: 46
                    anillo: true
                    letra: root.firstName.charAt(0).toUpperCase()
                    fuente: kuser.faceIconUrl.toString().indexOf("file:") === 0 ? kuser.faceIconUrl : ""
                }
                Column {
                    anchors.left: face.right
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Texto {
                        font.pixelSize: 20
                        font.weight: Font.Black
                        text: root.showAllOptions ? "¿Hasta luego, " + root.firstName + "?"
                            : sdtype === ShutdownType.ShutdownTypeReboot ? "Reiniciando"
                            : sdtype === ShutdownType.ShutdownTypeHalt ? "Apagando" : "Cerrando la sesión"
                    }
                    Texto {
                        color: Tema.apagado
                        font.pixelSize: 13
                        text: root.showAllOptions ? (root.uptime ? root.upText() : "Elige qué hacer")
                            : "En " + root.remaining + (root.remaining === 1 ? " segundo" : " segundos")
                              + (softwareUpdatePending ? ", con las actualizaciones" : "")
                    }
                }
                QQC2.AbstractButton {
                    id: cancel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: cancelRow.implicitWidth + 20
                    height: 30
                    hoverEnabled: true
                    onClicked: root.cancelRequested()
                    background: Rectangle { radius: Tema.r(9); color: cancel.hovered ? Tema.encima : "transparent" }
                    contentItem: Item {
                        Row {
                            id: cancelRow
                            anchors.centerIn: parent
                            spacing: 6
                            Texto { text: "Cancelar"; font.pixelSize: 13; color: cancel.hovered ? Tema.texto : Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: esc.implicitWidth + 12; height: 20; radius: Tema.r(6)
                                color: Tema.encima
                                anchors.verticalCenter: parent.verticalCenter
                                Texto { id: esc; anchors.centerIn: parent; text: "Esc"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Tema.tenue }
                            }
                        }
                    }
                }
            }
            Texto {
                width: parent.width
                color: Tema.apagado
                font.pixelSize: 12
                topPadding: 8
                visible: rebootToFirmwareSetup || rebootToBootLoaderMenu
                text: rebootToFirmwareSetup ? "Al reiniciar entrará en la configuración del equipo (UEFI)." : "Al reiniciar saldrá el menú de arranque."
            }
            Item { width: 1; height: 18 }

            // Los botones
            Row {
                id: buttons
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Repeater {
                    model: root.actions
                    delegate: QQC2.AbstractButton {
                        id: b
                        required property var modelData
                        required property int index
                        readonly property bool on: root.current === index
                        width: 96; height: 92
                        hoverEnabled: true
                        focus: on
                        onHoveredChanged: if (hovered) root.current = index
                        onClicked: modelData.run()
                        Keys.onReturnPressed: modelData.run()
                        Keys.onEnterPressed: modelData.run()
                        Keys.onLeftPressed: root.current = Math.max(0, root.current - 1)
                        Keys.onRightPressed: root.current = Math.min(root.actions.length - 1, root.current + 1)
                        RectangularShadow {
                            anchors.fill: parent
                            visible: b.on
                            offset.y: 6; blur: 24; spread: -6
                            radius: Tema.r(18)
                            color: Tema.rosa
                            opacity: 0.85
                        }
                        background: Rectangle {
                            radius: Tema.r(18)
                            color: b.on ? Tema.rosa : (b.pressed ? Tema.pulsado : Tema.encima)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        contentItem: Item {
                            Icono {
                                id: ico
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 22
                                width: 24; height: 24
                                nombre: b.modelData.icono
                                color: b.on ? Tema.sobreRosa : Tema.texto
                            }
                            Texto {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: ico.y + ico.height + 12
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font.weight: Font.Bold
                                font.pixelSize: 13
                                color: b.on ? Tema.sobreRosa : Tema.texto
                                text: b.modelData.texto
                            }
                        }
                    }
                }
            }

            // Lo que se cierra y «Actualizar al apagar»
            Item { width: 1; height: 16; visible: info.visible }
            Row {
                id: info
                width: parent.width
                spacing: 10
                visible: root.showAllOptions && (appsNote.visible || updateNote.visible)
                Rectangle {
                    id: appsNote
                    visible: root.apps.length > 0
                    width: updateNote.visible ? (parent.width - 10) / 2 : parent.width
                    height: 42; radius: Tema.r(14)
                    color: Tema.encima
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 14
                        spacing: 10
                        Icono { width: 16; height: 16; nombre: "apps"; color: Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 13
                            width: appsNote.width - 54
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            text: (root.apps.length === 1 ? "1 app abierta" : root.apps.length + " apps abiertas")
                                  + "<font color='" + Tema.apagado + "'> · " + (root.agape ? "Ágape guarda tus pestañas" : "se cierran bien") + "</font>"
                        }
                    }
                }
                QQC2.AbstractButton {
                    id: updateNote
                    visible: (root.updates.cuantas || 0) > 0 && maysd
                    width: appsNote.visible ? (parent.width - 10) / 2 : parent.width
                    height: 42
                    hoverEnabled: true
                    onClicked: root.toggleUpdates()
                    background: Rectangle { radius: Tema.r(14); color: root.updates.marcado ? Tema.rosaSuave : (updateNote.hovered ? Tema.pulsado : Tema.encima) }
                    contentItem: Item {
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 14
                            spacing: 10
                            Icono { width: 16; height: 16; nombre: "descargar"; color: root.updates.marcado ? Tema.rosa : Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
                            Texto {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 13
                                color: root.updates.marcado ? Tema.rosa : Tema.texto
                                text: "Actualizar al apagar · " + root.updates.cuantas
                            }
                        }
                        Interruptor {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            checkable: false   // (lo cambia toggleUpdates; así no se rompe el enlace)
                            checked: !!root.updates.marcado
                            onClicked: root.toggleUpdates()
                        }
                    }
                }
            }
        }
    }
}
