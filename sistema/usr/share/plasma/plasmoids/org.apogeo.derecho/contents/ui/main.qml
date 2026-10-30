import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.volume as PulseAudio
import Apogeo

// El panel rápido de Apogeo («2 · Dos paneles altos»), alto, a la derecha: sale con Meta+N, empujando el ratón contra el
// borde o pulsando la red, el sonido o la hora de la isla (el script de KWin apogeo-bordes), y hace sitio. De arriba
// abajo: cuánto lleva encendido el PC con «Aspecto», «Todos los ajustes» y apagar; los pisos; la red, el sonido y el
// micro en pastillas; lo de todos los días en botones redondos (bluetooth, fondo animado, no molestar, ahorro del piso,
// luz nocturna); el volumen y el brillo; tus avisos (juntos por app, con sus botones y «Responder») y, abajo, el tiempo
// de las próximas horas y días con el color del cielo a esta hora. El fondo es «Cristal con tu fondo» (Cristal); en
// Órbita, «cristal grafito» (W1): neutro, sin el brillo del modo, y lo encendido en blanco.
// Lo de los botones lo lee y lo cambia «apogeo-ajustes rapido», solo con el panel abierto («abierto», lo pone el script).
// No coge el teclado, salvo mientras respondes a un aviso.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    property bool escribiendo: false   // respondiendo a un aviso: entonces coge el teclado
    Plasmoid.status: escribiendo && abierto ? PlasmaCore.Types.AcceptingInputStatus : PlasmaCore.Types.ActiveStatus

    readonly property bool abierto: !!Plasmoid.configuration.abierto

    TaskManager.VirtualDesktopInfo { id: desktops }
    readonly property int floorIndex: Math.max(0, desktops.desktopIds.indexOf(desktops.currentDesktop))
    readonly property string floorKey: ["jugar", "navegar", "estudiar"][floorIndex] || "navegar"
    readonly property string floorName: desktops.desktopNames[floorIndex] || "Navegar"

    readonly property var sink: PulseAudio.PreferredDevice.sink        // (el altavoz que se usa ahora)
    readonly property var source: PulseAudio.PreferredDevice.source    // (y el micro)
    NotificationManager.Notifications {
        id: notifs
        showExpired: true
        showDismissed: true
        showJobs: false
        groupMode: NotificationManager.Notifications.GroupApplicationsFlat
        groupLimit: 2
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        limit: 30
    }

    Datos { id: datos }
    property var st: ({ red: {}, bt: {}, energia: {} })
    property var pc: ({})
    property var tiempo: ({})
    readonly property string tool: "/usr/lib/apogeo/apogeo-ajustes rapido"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.tool) {
                try { root.st = JSON.parse(data.stdout); } catch (e) {}
            }
            disconnectSource(source);
        }
    }
    function refresh() { runner.connectSource(tool) }
    function act(what, value) {
        runner.connectSource(tool + " " + what + (value !== undefined ? " " + value : ""));
        after.restart();
    }
    Timer { id: after; interval: 450; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
    // Solo con el panel abierto: cerrado no gasta nada
    property int vuelta: 0
    Timer {
        interval: 2500; repeat: true; running: root.abierto; triggeredOnStart: true
        onTriggered: {
            root.refresh();
            datos.pedir("Pc", [], d => { if (d) root.pc = d; });
            if (root.vuelta++ % 24 === 0) datos.pedir("Tiempo", [], d => { if (d) root.tiempo = d; });
        }
    }
    onAbiertoChanged: { if (abierto) vuelta = 0; else escribiendo = false; }
    property date ahora: new Date()
    Timer { interval: 60000; repeat: true; running: root.abierto; onTriggered: root.ahora = new Date() }

    // Cambiar de piso: se le pide a KWin directamente (como la columna de pisos de antes)
    function go(index) {
        const ids = desktops.desktopIds;
        if (index < 0 || index >= ids.length || ids[index] === desktops.currentDesktop) return;
        runner.connectSource("dbus-send --session --type=method_call --dest=org.kde.KWin /VirtualDesktopManager "
                             + "org.freedesktop.DBus.Properties.Set string:org.kde.KWin.VirtualDesktopManager string:current "
                             + "variant:string:" + ids[index]);
    }
    function open(app) { runner.connectSource("gio launch /usr/share/applications/" + app + ".desktop") }
    function encendido(s) {
        s = Math.round(s || 0);
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d ? d + " d " + h + " h" : h ? h + " h " + m + " min" : m + " min";
    }
    function ago(d) {
        const s = Math.max(0, (Date.now() - d.getTime()) / 1000);
        if (s < 60) return "ahora";
        if (s < 3600) return Math.floor(s / 60) + " min";
        if (s < 86400) return Math.floor(s / 3600) + " h";
        return Math.floor(s / 86400) + " d";
    }
    function cielo(c, dia) {
        if (c === 0) return dia === false ? "luna" : "sol";
        if (c <= 2) return "nubes-sol";
        if (c === 3) return "nube";
        if (c === 45 || c === 48) return "niebla";
        if (c >= 95) return "tormenta";
        if (c >= 71 && c <= 77 || c === 85 || c === 86) return "nieve";
        return "lluvia";
    }
    function cieloTexto(c) {
        if (c === 0) return "Despejado";
        if (c <= 2) return "Poco nuboso";
        if (c === 3) return "Nublado";
        if (c === 45 || c === 48) return "Niebla";
        if (c >= 95) return "Tormenta";
        if (c >= 71 && c <= 77 || c === 85 || c === 86) return "Nieve";
        return "Lluvia";
    }

    // ---------- Piezas ----------

    component Tarjeta: Rectangle {
        default property alias contenido: caja.data
        property real relleno: 14
        width: parent ? parent.width : 0
        height: caja.childrenRect.height + 2 * relleno
        radius: Tema.r(18)
        color: Tema.encima
        Item { id: caja; x: parent.relleno; y: parent.relleno; width: parent.width - 2 * parent.relleno }
    }
    // Una pastilla: la red, el sonido, el micro (encendida, en el color del piso)
    component Pastilla: AbstractButton {
        id: pa
        property string icono
        property string sub
        property bool on: false
        height: 54
        hoverEnabled: true
        background: Rectangle {
            radius: height / 2
            color: pa.on ? (pa.hovered ? Qt.darker(Tema.encendido, 1.06) : Tema.encendido) : (pa.hovered ? Tema.pulsado : Tema.encima)
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        contentItem: Item {
            Icono { id: pIco; x: 14; anchors.verticalCenter: parent.verticalCenter; nombre: pa.icono; color: pa.on ? Tema.sobreEncendido : Tema.texto }
            Column {
                x: pIco.x + pIco.width + 9
                width: parent.width - x - 10
                anchors.verticalCenter: parent.verticalCenter
                Texto { width: parent.width; text: pa.text; font.pixelSize: 13; font.weight: Font.Bold; color: pa.on ? Tema.sobreEncendido : Tema.texto; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                Texto { width: parent.width; text: pa.sub; font.pixelSize: 11; color: pa.on ? Qt.rgba(Tema.sobreEncendido.r, Tema.sobreEncendido.g, Tema.sobreEncendido.b, 0.7) : Tema.apagado; elide: Text.ElideRight; wrapMode: Text.NoWrap }
            }
        }
    }
    // Un botón redondo de lo de todos los días (el nombre, al pasar el ratón)
    component Redondo: AbstractButton {
        id: re
        property string icono
        property bool on: false
        width: 50; height: 50
        hoverEnabled: true
        opacity: enabled ? 1 : 0.45
        ToolTip.visible: hovered
        ToolTip.text: text
        ToolTip.delay: 400
        background: Item {
            RectangularShadow { anchors.fill: parent; visible: re.on; radius: width / 2; blur: 14; spread: -4; offset.y: 4; color: Qt.rgba(1, 1, 1, 0.22) }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: re.on ? Tema.encendido : re.hovered ? Tema.pulsado : Tema.encima
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
        contentItem: Item { Icono { anchors.centerIn: parent; width: 18; height: 18; nombre: re.icono; color: re.on ? Tema.sobreEncendido : Tema.texto } }
    }
    // Un botón pequeño de un aviso (los de la app y «Responder», lleno)
    component Chico: AbstractButton {
        id: ch
        property bool lleno: false
        property string icono
        height: 28
        width: icono ? 28 : chTexto.implicitWidth + 20
        hoverEnabled: true
        background: Rectangle {
            radius: height / 2
            color: ch.lleno ? (ch.hovered ? Qt.darker(Tema.encendido, 1.08) : Tema.encendido) : (ch.hovered ? Tema.pulsado : Tema.encima)
            border.width: ch.lleno ? 0 : 1
            border.color: Tema.borde
        }
        contentItem: Item {
            Texto { id: chTexto; visible: !ch.icono; anchors.centerIn: parent; text: ch.text; font.pixelSize: 12; font.weight: Font.Bold; color: ch.lleno ? Tema.sobreEncendido : Tema.texto; wrapMode: Text.NoWrap }
            Icono { visible: !!ch.icono; anchors.centerIn: parent; width: 14; height: 14; nombre: ch.icono || "cerrar"; color: ch.lleno ? Tema.sobreEncendido : Tema.texto }
        }
    }
    component Level: Rectangle {
        id: lv
        property string icono
        property int value: 0
        signal elegido(int value)
        width: parent ? parent.width : 0
        height: 44
        radius: Tema.r(16)
        color: Tema.encima
        Icono { x: 14; anchors.verticalCenter: parent.verticalCenter; nombre: lv.icono; color: Tema.apagado }
        Deslizador {
            id: slider
            x: 40
            width: parent.width - 54
            anchors.verticalCenter: parent.verticalCenter
            from: 0; to: 100; stepSize: 1
            onMoved: throttle.restart()
            onPressedChanged: if (!pressed) lv.elegido(Math.round(value))
            Binding on value { value: lv.value; when: !slider.pressed }
        }
        Timer { id: throttle; interval: 150; onTriggered: lv.elegido(Math.round(slider.value)) }
    }
    component Mini: AbstractButton {
        id: mb
        property string icono
        width: 34; height: 34
        hoverEnabled: true
        ToolTip.visible: hovered
        ToolTip.text: text
        ToolTip.delay: 400
        background: Rectangle { radius: Tema.r(11); color: mb.hovered ? Tema.pulsado : Tema.encima }
        contentItem: Item { Icono { anchors.centerIn: parent; nombre: mb.icono; color: Tema.texto } }
    }

    fullRepresentation: Item {
        id: vista
        Layout.minimumWidth: 300
        Layout.preferredWidth: 360
        Layout.fillWidth: true
        Layout.fillHeight: true

        // «Cristal con tu fondo»
        Cristal { anchors.fill: parent; activo: root.abierto; brillo: !Tema._orbita; oscuro: Tema._orbita ? 0.64 : 0.52 }

        Column {
            id: arriba
            x: 14; y: 16
            width: parent.width - 28
            spacing: 10

            // --- Encendido · Aspecto · Ajustes · Apagar ---
            Item {
                width: parent.width; height: 38
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Texto { text: "Encendido"; color: Tema.tenue; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.9; font.capitalization: Font.AllUppercase }
                    Texto { text: root.pc.encendido === undefined ? "…" : root.encendido(root.pc.encendido); font.pixelSize: 16; font.weight: Font.Black; wrapMode: Text.NoWrap }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Mini { icono: "lapiz"; text: "Aspecto"; onClicked: runner.connectSource("setsid -f /usr/lib/apogeo/apogeo-ajustes aspecto") }
                    Mini { icono: "ajustes"; text: "Todos los ajustes"; onClicked: root.open("apogeo-ajustes") }
                    Mini { icono: "apagar"; text: "Apagar, reiniciar o cerrar sesión"; onClicked: root.act("apagar") }
                }
            }

            // --- Los pisos ---
            Rectangle {
                width: parent.width; height: 46
                radius: Tema.r(16)
                color: Tema.encima
                Row {
                    id: pisos
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4
                    Repeater {
                        model: desktops.desktopIds
                        delegate: AbstractButton {
                            id: piso
                            required property int index
                            readonly property bool on: index === root.floorIndex
                            width: (pisos.width - 8) / 3; height: pisos.height
                            hoverEnabled: true
                            onClicked: root.go(index)
                            background: Item {
                                RectangularShadow { anchors.fill: parent; visible: piso.on; radius: Tema.r(12); blur: 14; spread: -4; offset.y: 4; color: Tema.rosa }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Tema.r(12)
                                    color: piso.on ? Tema.rosa : piso.hovered ? Tema.pulsado : "transparent"
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                            }
                            contentItem: Item {
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 7
                                    Icono { anchors.verticalCenter: parent.verticalCenter; nombre: ["jugar", "navegar", "estudiar"][piso.index] || "pisos"; color: piso.on ? Tema.sobreRosa : Tema.apagado }
                                    Texto { anchors.verticalCenter: parent.verticalCenter; text: desktops.desktopNames[piso.index] || ""; font.pixelSize: 13; font.weight: piso.on ? Font.Bold : Font.Normal; color: piso.on ? Tema.sobreRosa : Tema.texto; wrapMode: Text.NoWrap }
                                }
                            }
                        }
                    }
                }
            }

            // --- La red, el sonido y el micro ---
            Row {
                id: pastillas
                width: parent.width
                spacing: 8
                readonly property real ancho: (width - 16) / 3
                Pastilla {
                    width: pastillas.ancho
                    text: "Red"
                    icono: root.st.red.on ? "wifi" : "sinred"
                    on: !!root.st.red.on
                    sub: root.st.red.texto || "…"
                    onClicked: root.act("red")
                }
                Pastilla {
                    width: pastillas.ancho
                    readonly property bool mudo: !root.sink || root.sink.muted
                    text: "Sonido"
                    icono: mudo ? "silencio" : "volumen"
                    on: !mudo
                    sub: mudo ? "Silencio" : (root.st.volumen || 0) + " %"
                    onClicked: if (root.sink) root.sink.muted = !root.sink.muted
                }
                Pastilla {
                    width: pastillas.ancho
                    readonly property bool mudo: !root.source || root.source.muted
                    enabled: !!root.source
                    text: "Micro"
                    icono: "micro"
                    on: !mudo
                    sub: !root.source ? "No hay" : mudo ? "Apagado" : "Encendido"
                    onClicked: root.source.muted = !root.source.muted
                }
            }

            // --- Lo de todos los días ---
            Row {
                id: redondos
                width: parent.width
                spacing: (width - 5 * 50) / 4
                Redondo {
                    text: !root.st.bt.hay ? "Bluetooth: este equipo no tiene" : "Bluetooth"
                    icono: "bluetooth"
                    enabled: !!root.st.bt.hay
                    on: !!root.st.bt.on
                    onClicked: root.act("bluetooth")
                }
                Redondo {
                    text: !root.st.grafica ? "Fondo animado (quieto: no hay gráfica)" : "Fondo animado"
                    icono: "foto"
                    on: !!root.st.animar
                    onClicked: root.act("animar")
                }
                Redondo {
                    text: "No molestar"
                    icono: "silencio"
                    on: !!root.st.silencio
                    onClicked: root.act("silencio")
                }
                Redondo {
                    text: "Ahorro de energía en " + root.floorName
                    icono: "energia"
                    on: root.st.energia[root.floorKey] === "power-saver"
                    onClicked: root.act("energia", root.floorKey)
                }
                Redondo {
                    text: "Luz nocturna"
                    icono: "luna"
                    on: !!root.st.luz
                    onClicked: root.act("luz")
                }
            }

            Level {
                icono: "volumen"
                value: root.st.volumen || 0
                onElegido: v => root.act("volumen", v)
            }
            Level { // (siempre está, aunque la pantalla no deje cambiar el brillo: así el panel no cambia de tamaño)
                enabled: (root.st.brillo !== undefined ? root.st.brillo : -1) >= 0
                opacity: enabled ? 1 : 0.45
                icono: "sol"
                value: Math.max(0, root.st.brillo || 0)
                onElegido: v => root.act("brillo", v)
            }
        }

        // --- Tus avisos (lo que sobra entre lo de arriba y el tiempo) ---
        Item {
            id: avisos
            x: 14
            y: arriba.y + arriba.height + 14
            width: parent.width - 28
            height: tiempo.y - y - 10
            Item {
                id: cabAvisos
                width: parent.width; height: 26
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7
                    Icono { nombre: "campana"; color: Tema.rosa; width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter }
                    Texto { text: "Avisos"; color: Tema.tenue; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.9; font.capitalization: Font.AllUppercase; anchors.verticalCenter: parent.verticalCenter }
                }
                AbstractButton {
                    id: clearAll
                    visible: notifs.count > 0
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: clearText.implicitWidth + 16; height: 24
                    hoverEnabled: true
                    onClicked: notifs.clear(NotificationManager.Notifications.ClearExpired)
                    background: Rectangle { radius: Tema.r(8); color: clearAll.hovered ? Tema.pulsado : "transparent" }
                    contentItem: Texto { id: clearText; text: "Borrar todo"; font.pixelSize: 12; color: Tema.apagado; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
            Column {
                visible: notifs.count === 0
                anchors.centerIn: parent
                spacing: 8
                Icono { anchors.horizontalCenter: parent.horizontalCenter; nombre: "campana"; width: 28; height: 28; color: Tema.tenue }
                Texto { anchors.horizontalCenter: parent.horizontalCenter; text: "Nada nuevo"; color: Tema.apagado }
            }
            ListView {
                id: listaAvisos
                y: cabAvisos.height + 6
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: notifs
                property int respondiendo: -1   // el aviso al que estás respondiendo (su índice)
                delegate: Loader {
                    id: fila
                    required property var model
                    required property int index
                    width: ListView.view.width
                    sourceComponent: model.isGroup ? grupo : aviso
                }
                // La cabeza de cada app: su icono, su nombre y cuántos; «Ver todos» si hay más de dos
                Component {
                    id: grupo
                    Item {
                        readonly property var m: parent ? parent.model : ({})
                        readonly property int i: parent ? parent.index : 0
                        height: 30
                        Kirigami.Icon { id: gIco; x: 4; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; source: m.applicationIconName || "apogeo" }
                        Texto {
                            x: gIco.x + gIco.width + 8; anchors.verticalCenter: parent.verticalCenter
                            text: (m.applicationName || "") + " · " + m.groupChildrenCount
                            font.pixelSize: 12; font.weight: Font.Bold; color: Tema.apagado; wrapMode: Text.NoWrap
                        }
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            AbstractButton {
                                id: verTodos
                                visible: m.groupChildrenCount > 2
                                width: vtTexto.implicitWidth + 14; height: 24
                                hoverEnabled: true
                                onClicked: m.isGroupExpanded = !m.isGroupExpanded
                                background: Rectangle { radius: Tema.r(8); color: verTodos.hovered ? Tema.pulsado : "transparent" }
                                contentItem: Texto { id: vtTexto; text: m.isGroupExpanded ? "Ver menos" : "Ver todos"; font.pixelSize: 12; color: Tema.rosa; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            AbstractButton {
                                id: cierraGrupo
                                width: 24; height: 24
                                hoverEnabled: true
                                onClicked: notifs.close(notifs.index(i, 0))
                                background: Rectangle { radius: Tema.r(8); color: cierraGrupo.hovered ? Tema.pulsado : "transparent" }
                                contentItem: Item { Icono { anchors.centerIn: parent; width: 11; height: 11; nombre: "cerrar"; color: Tema.apagado } }
                            }
                        }
                    }
                }
                // Un aviso: lo que dice, sus botones (los que trae la app) y responder, si deja
                Component {
                    id: aviso
                    AbstractButton {
                        id: nd
                        readonly property var m: parent ? parent.model : ({})
                        readonly property int i: parent ? parent.index : 0
                        readonly property var nombres: (m.actionNames || []).filter(n => n !== "default" && n !== "inline-reply")
                        readonly property var etiquetas: (m.actionLabels || []).filter((l, k) => (m.actionNames || [])[k] !== "default" && (m.actionNames || [])[k] !== "inline-reply")
                        readonly property bool botones: nombres.length > 0 || !!m.hasReplyAction
                        readonly property bool respondiendo: listaAvisos.respondiendo === i
                        height: contenido.implicitHeight + 22
                        hoverEnabled: true
                        onClicked: notifs.invokeDefaultAction(notifs.index(i, 0))
                        background: Rectangle { radius: Tema.r(14); color: nd.hovered ? Tema.pulsado : Tema.encima }
                        contentItem: Item {
                            Kirigami.Icon {
                                id: appIcon
                                x: 12; y: 11
                                width: 28; height: 28
                                visible: !nd.m.isInGroup
                                source: nd.m.applicationIconName || nd.m.iconName || "apogeo"
                            }
                            Column {
                                id: contenido
                                x: nd.m.isInGroup ? 14 : appIcon.x + appIcon.width + 11
                                y: 11
                                width: parent.width - x - 32
                                spacing: 2
                                Texto { width: parent.width; elide: Text.ElideRight; wrapMode: Text.NoWrap; font.weight: Font.Bold; font.pixelSize: 13; text: nd.m.summary || nd.m.applicationName || "" }
                                Texto {
                                    width: parent.width
                                    visible: text !== ""
                                    maximumLineCount: 2; elide: Text.ElideRight; wrapMode: Text.Wrap
                                    color: Tema.apagado; font.pixelSize: 12; textFormat: Text.PlainText
                                    text: nd.m.body ? String(nd.m.body).replace(/<[^>]*>/g, "").trim() : ""
                                }
                                Texto {
                                    width: parent.width
                                    color: Tema.tenue; font.pixelSize: 11; wrapMode: Text.NoWrap; elide: Text.ElideRight
                                    text: (nd.m.isInGroup ? "" : (nd.m.applicationName ? nd.m.applicationName + " · " : "")) + (root.ahora, root.ago(nd.m.created || new Date()))
                                }
                                // Los botones del aviso
                                Flow {
                                    visible: nd.botones && !nd.respondiendo
                                    width: parent.width
                                    topPadding: 6
                                    spacing: 6
                                    Repeater {
                                        model: nd.nombres
                                        delegate: Chico {
                                            required property int index
                                            text: nd.etiquetas[index] || ""
                                            onClicked: notifs.invokeAction(notifs.index(nd.i, 0), nd.nombres[index])
                                        }
                                    }
                                    Chico {
                                        visible: !!nd.m.hasReplyAction
                                        text: nd.m.replyActionLabel || "Responder"
                                        lleno: true
                                        onClicked: { listaAvisos.respondiendo = nd.i; root.escribiendo = true; }
                                    }
                                }
                                // Responder ahí mismo
                                Row {
                                    visible: nd.respondiendo
                                    topPadding: 6
                                    spacing: 6
                                    Campo {
                                        id: respuesta
                                        width: contenido.width - 40
                                        implicitHeight: 34
                                        font.pixelSize: 13
                                        placeholderText: nd.m.replyPlaceholderText || "Escribe tu respuesta"
                                        onVisibleChanged: if (visible) enfocar.restart()
                                        Timer { id: enfocar; interval: 120; onTriggered: respuesta.forceActiveFocus() }
                                        Keys.onEscapePressed: { text = ""; listaAvisos.respondiendo = -1; root.escribiendo = false; }
                                        onAccepted: enviar.clicked()
                                    }
                                    Chico {
                                        id: enviar
                                        width: 34; height: 34
                                        lleno: true
                                        icono: "enviar"
                                        onClicked: {
                                            if (respuesta.text.trim() === "") return;
                                            notifs.reply(notifs.index(nd.i, 0), respuesta.text.trim());
                                            respuesta.text = "";
                                            listaAvisos.respondiendo = -1;
                                            root.escribiendo = false;
                                        }
                                    }
                                }
                            }
                            AbstractButton {
                                id: close
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                y: 8
                                width: 26; height: 26
                                visible: nd.hovered
                                hoverEnabled: true
                                onClicked: notifs.close(notifs.index(nd.i, 0))
                                background: Rectangle { radius: Tema.r(8); color: close.hovered ? Tema.encima : "transparent" }
                                contentItem: Item { Icono { anchors.centerIn: parent; width: 12; height: 12; nombre: "cerrar"; color: Tema.apagado } }
                            }
                        }
                    }
                }
            }
        }

        // --- El tiempo: ahora, las próximas horas (en barras) y los próximos días ---
        Tarjeta {
            id: tiempo
            x: 14
            width: parent.width - 28
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            readonly property var w: root.tiempo
            readonly property bool hay: w.temp !== undefined
            // El color del cielo a esta hora (amanecer, día, atardecer o noche; más gris si está nublado o llueve)
            readonly property var cielo: Tema.colorCielo(root.ahora, w.salida, w.puesta, w.codigo || 0)
            readonly property color letra: hay ? "white" : Tema.texto
            readonly property color letraSuave: hay ? Qt.rgba(1, 1, 1, 0.75) : Tema.apagado
            gradient: hay ? degradadoCielo : null
            Gradient {
                id: degradadoCielo
                GradientStop { position: 0; color: tiempo.cielo[0] }
                GradientStop { position: 1; color: tiempo.cielo[1] }
            }
            readonly property var horas: w.horas || []
            readonly property real tmin: horas.length ? Math.min.apply(null, horas.map(h => h.t)) : 0
            readonly property real tmax: horas.length ? Math.max.apply(null, horas.map(h => h.t)) : 1
            Item {
                width: parent.width
                height: tiempo.w.temp === undefined ? 20 : 214
                Texto {
                    visible: tiempo.w.temp === undefined
                    width: parent.width
                    text: tiempo.w.sinCiudad ? "Elige tu ciudad en la agenda (Meta → Agenda) para ver el tiempo" : "Mirando el tiempo…"
                    color: Tema.apagado; font.pixelSize: 13
                }
                Item {
                    visible: tiempo.w.temp !== undefined
                    width: parent.width; height: parent.height
                    // Ahora
                    Icono { id: ahoraIco; width: 34; height: 34; nombre: root.cielo(tiempo.w.codigo, tiempo.w.dia); color: "white" }
                    Column {
                        x: ahoraIco.width + 12
                        Texto { text: tiempo.w.temp + "°"; color: tiempo.letra; font.pixelSize: 26; font.weight: Font.Black; lineHeight: 0.9 }
                        Texto { text: root.cieloTexto(tiempo.w.codigo) + " · " + (tiempo.w.ciudad || ""); color: tiempo.letraSuave; font.pixelSize: 12; wrapMode: Text.NoWrap }
                    }
                    Texto { anchors.right: parent.right; y: 6; text: tiempo.w.max + "° / " + tiempo.w.min + "°"; color: tiempo.letraSuave; font.pixelSize: 13 }
                    // Las próximas horas
                    Row {
                        id: barras
                        y: 54
                        width: parent.width
                        height: 82
                        Repeater {
                            model: tiempo.horas
                            delegate: Item {
                                id: hora
                                required property var modelData
                                required property int index
                                width: barras.width / Math.max(1, tiempo.horas.length); height: barras.height
                                readonly property real p: tiempo.tmax > tiempo.tmin ? (modelData.t - tiempo.tmin) / (tiempo.tmax - tiempo.tmin) : 0.5
                                Texto { anchors.horizontalCenter: parent.horizontalCenter; y: barra.y - 18; text: hora.modelData.t + "°"; color: tiempo.letra; font.pixelSize: 12; font.weight: Font.Bold }
                                Rectangle {
                                    id: barra
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                                    width: 14; radius: 7
                                    height: 14 + hora.p * 30
                                    color: hora.index === 0 ? "white" : Qt.rgba(1, 1, 1, 0.3)
                                }
                                Texto { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: hora.modelData.h + "h"; font.pixelSize: 11; color: tiempo.letraSuave }
                            }
                        }
                    }
                    // Los próximos días
                    Column {
                        id: dias
                        y: barras.y + barras.height + 8
                        width: parent.width
                        Repeater {
                            model: tiempo.w.dias || []
                            delegate: Item {
                                id: dia
                                required property var modelData
                                width: dias.width; height: 26
                                Texto { width: 22; anchors.verticalCenter: parent.verticalCenter; text: dia.modelData.dia; font.weight: Font.Bold; color: tiempo.letraSuave }
                                Icono { x: 26; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; nombre: root.cielo(dia.modelData.codigo, true); color: "white" }
                                Texto { x: 54; anchors.verticalCenter: parent.verticalCenter; text: root.cieloTexto(dia.modelData.codigo); font.pixelSize: 12; color: tiempo.letraSuave }
                                Texto { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: dia.modelData.max + "° / " + dia.modelData.min + "°"; color: tiempo.letra; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }
        }
    }
}
