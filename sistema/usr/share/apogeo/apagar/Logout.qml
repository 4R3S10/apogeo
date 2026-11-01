import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.plasma5support as P5Support
import Apogeo

// Pantalla de apagar de Órbita («A1 · Tierra y botones»): la Tierra vista desde el espacio (la del arranque y la de
// entrar), oscura; en el centro el Núcleo, «¿Hasta luego?», desde cuándo está encendido y cuántas apps se cierran (Ágape
// guarda sus pestañas); tres botones grandes (Apagar, Reiniciar, Reposo) y, debajo, en pequeño, Ir a Windows (si hay un
// Windows escondido), Cerrar sesión, Bloquear y «Actualizar al apagar» si hay actualizaciones. Si se ha pedido algo
// concreto (apagar, reiniciar o salir), solo sale eso con su cuenta atrás de 30 segundos. Esc o un clic fuera cancelan;
// las flechas eligen e Intro hace.
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

    // ---------- La Tierra, oscura, que aparece ----------
    property bool open: false
    Component.onCompleted: open = true
    Rectangle { anchors.fill: parent; color: "#05070a"; opacity: root.open ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 320 } } }
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
        visible: tierra.status === Image.Ready
        blurEnabled: true; blur: 0.25; blurMax: 32
        brightness: -0.24
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 1.05
        Behavior on opacity { NumberAnimation { duration: 420 } }
        Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.02, 0.03, 0.04, 0.25) }
            GradientStop { position: 0.55; color: Qt.rgba(0.02, 0.03, 0.04, 0.1) }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0.03, 0.04, 0.6) }
        }
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
        { key: "logout", texto: root.showAllOptions ? "Cerrar sesión" : "Salir", icono: "salir",
          ver: canLogout && (showAllOptions || sdtype === ShutdownType.ShutdownTypeNone), run: () => root.logoutRequested() },
        { key: "lock", texto: "Bloquear", icono: "llave",
          ver: showAllOptions, run: () => root.lockScreenRequested() }
    ].filter(a => a.ver)
    property int current: 0

    // Los tres grandes (o lo que se ha pedido) y, debajo, los pequeños
    readonly property var grandes: showAllOptions ? actions.filter(a => ["halt", "reboot", "sleep"].indexOf(a.key) >= 0) : actions
    readonly property var pequenos: showAllOptions ? actions.filter(a => grandes.indexOf(a) < 0) : []
    readonly property var orden: grandes.concat(pequenos)
    function mover(n) { current = Math.max(0, Math.min(orden.length - 1, current + n)) }
    function hacer() { if (orden[current]) orden[current].run() }
    Item {
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: root.mover(-1)
        Keys.onRightPressed: root.mover(1)
        Keys.onUpPressed: { if (root.current >= root.grandes.length) root.current = 0 }
        Keys.onDownPressed: { if (root.current < root.grandes.length && root.pequenos.length) root.current = root.grandes.length }
        Keys.onTabPressed: root.current = (root.current + 1) % root.orden.length
        Keys.onReturnPressed: root.hacer()
        Keys.onEnterPressed: root.hacer()
    }

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.17)
        spacing: 0
        opacity: root.open ? 1 : 0
        transform: Translate { y: root.open ? 0 : 18; Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: 420 } }

        Nucleo {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 92; height: 92
            disco: false
            SequentialAnimation on pulso {
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 2400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 2400; easing.type: Easing.InOutSine }
            }
        }
        Item { width: 1; height: 24 }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            font { pixelSize: 44; weight: Font.Bold; letterSpacing: -0.6 }
            color: "#f2f4f8"
            text: root.showAllOptions ? "¿Hasta luego, " + root.firstName + "?"
                : sdtype === ShutdownType.ShutdownTypeReboot ? "Reiniciando"
                : sdtype === ShutdownType.ShutdownTypeHalt ? "Apagando" : "Cerrando la sesión"
        }
        Item { width: 1; height: 10 }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(0.91, 0.93, 0.96, 0.66)
            font.pixelSize: 15
            text: [root.uptime ? root.upText() : "",
                   root.apps.length ? (root.apps.length === 1 ? "1 app abierta" : root.apps.length + " apps abiertas")
                                      + (root.agape ? " (Ágape guarda tus pestañas)" : " (se cierran bien)") : ""].filter(t => t).join(" · ")
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Qt.rgba(0.91, 0.93, 0.96, 0.66)
            font.pixelSize: 13
            topPadding: 8
            visible: rebootToFirmwareSetup || rebootToBootLoaderMenu
            text: rebootToFirmwareSetup ? "Al reiniciar entrará en la configuración del equipo (UEFI)." : "Al reiniciar saldrá el menú de arranque."
        }
        Item { width: 1; height: 44 }

        // Los grandes: cristal; el elegido, encendido (blanco)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 18
            Repeater {
                model: root.grandes
                delegate: QQC2.AbstractButton {
                    id: b
                    required property var modelData
                    required property int index
                    readonly property bool on: root.current === index
                    width: 168; height: 128
                    hoverEnabled: true
                    onHoveredChanged: if (hovered) root.current = index
                    onClicked: modelData.run()
                    scale: on ? 1.04 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    RectangularShadow {
                        anchors.fill: parent
                        z: -2   // (detrás del botón: si no, su brillo blanco tapa el texto)
                        visible: b.on
                        offset.y: 10; blur: 34; spread: -8
                        radius: 20
                        color: Qt.rgba(1, 1, 1, 0.35)
                    }
                    background: Rectangle {
                        radius: 20
                        color: b.on ? "#eef0f4" : Qt.rgba(0.07, 0.08, 0.11, b.pressed ? 0.8 : 0.62)
                        border.color: b.on ? "transparent" : Qt.rgba(1, 1, 1, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    contentItem: Item {
                        Icono {
                            id: ico
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 34
                            width: 28; height: 28
                            nombre: b.modelData.icono
                            color: b.on ? "#0b0e14" : "#f2f4f8"
                        }
                        Texto {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: ico.y + ico.height + 14
                            width: parent.width - 12
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font { pixelSize: 15; weight: Font.Bold }
                            color: b.on ? "#0b0e14" : "#f2f4f8"
                            text: b.modelData.texto
                        }
                    }
                }
            }
        }
        Item { width: 1; height: 34 }

        // Los pequeños, en texto; y «Actualizar al apagar»
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 30
            visible: root.pequenos.length > 0 || updateNote.visible
            Repeater {
                model: root.pequenos
                delegate: QQC2.AbstractButton {
                    id: p
                    required property var modelData
                    required property int index
                    readonly property bool on: root.current === root.grandes.length + index
                    width: pt.implicitWidth + 16; height: 32
                    hoverEnabled: true
                    onHoveredChanged: if (hovered) root.current = root.grandes.length + index
                    onClicked: modelData.run()
                    background: Rectangle {
                        radius: 10
                        color: p.on ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    }
                    contentItem: Item {
                        Texto {
                            id: pt
                            anchors.centerIn: parent
                            text: p.modelData.texto
                            font { pixelSize: 14; weight: p.on ? Font.DemiBold : Font.Normal }
                            color: p.on ? "#f2f4f8" : Qt.rgba(0.91, 0.93, 0.96, 0.72)
                        }
                    }
                }
            }
            QQC2.AbstractButton {
                id: updateNote
                visible: root.showAllOptions && (root.updates.cuantas || 0) > 0 && maysd
                width: un.implicitWidth + 16; height: 32
                hoverEnabled: true
                onClicked: root.toggleUpdates()
                background: Rectangle { radius: 10; color: updateNote.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent" }
                contentItem: Item {
                    Row {
                        id: un
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14; height: 14; radius: 4
                            color: root.updates.marcado ? "#eef0f4" : "transparent"
                            border.color: Qt.rgba(1, 1, 1, 0.5)
                            Texto { anchors.centerIn: parent; visible: !!root.updates.marcado; text: "✓"; font { pixelSize: 10; weight: Font.Bold } color: "#0b0e14" }
                        }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Actualizar al apagar (" + root.updates.cuantas + ")"
                            font.pixelSize: 14
                            color: Qt.rgba(0.91, 0.93, 0.96, 0.72)
                        }
                    }
                }
            }
        }
    }

    // Abajo: la cuenta atrás (si se ha pedido algo) y cómo cancelar
    Texto {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 40
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 420 } }
        font { family: Tema.mono; pixelSize: 12; letterSpacing: 3; capitalization: Font.AllUppercase }
        color: Qt.rgba(0.91, 0.93, 0.96, 0.6)
        text: (root.showAllOptions ? "" : (sdtype === ShutdownType.ShutdownTypeReboot ? "Se reinicia" : sdtype === ShutdownType.ShutdownTypeHalt ? "Se apaga" : "Se cierra")
               + " en " + root.remaining + " s" + (softwareUpdatePending ? ", con las actualizaciones" : "") + " · ")
              + "Esc cancelar · ← → elegir · Intro"
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: root.cancelRequested() }
    }
}
