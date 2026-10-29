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
// luz nocturna); el volumen y el brillo; tus avisos y, abajo, el tiempo de las próximas horas y días. Lo de los botones
// lo lee y lo cambia «apogeo-ajustes rapido», solo con el panel abierto («abierto», lo pone el script).
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    Plasmoid.status: PlasmaCore.Types.ActiveStatus

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
        groupMode: NotificationManager.Notifications.GroupDisabled
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
    onAbiertoChanged: if (abierto) vuelta = 0

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
            color: pa.on ? (pa.hovered ? Qt.lighter(Tema.rosa, 1.06) : Tema.rosa) : (pa.hovered ? Tema.pulsado : Tema.encima)
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        contentItem: Item {
            Icono { id: pIco; x: 14; anchors.verticalCenter: parent.verticalCenter; nombre: pa.icono; color: pa.on ? Tema.sobreRosa : Tema.texto }
            Column {
                x: pIco.x + pIco.width + 9
                width: parent.width - x - 10
                anchors.verticalCenter: parent.verticalCenter
                Texto { width: parent.width; text: pa.text; font.pixelSize: 13; font.weight: Font.Bold; color: pa.on ? Tema.sobreRosa : Tema.texto; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                Texto { width: parent.width; text: pa.sub; font.pixelSize: 11; color: pa.on ? Qt.rgba(Tema.sobreRosa.r, Tema.sobreRosa.g, Tema.sobreRosa.b, 0.7) : Tema.apagado; elide: Text.ElideRight; wrapMode: Text.NoWrap }
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
            RectangularShadow { anchors.fill: parent; visible: re.on; radius: width / 2; blur: 14; spread: -4; offset.y: 4; color: Tema.rosa }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: re.on ? Tema.rosa : re.hovered ? Tema.pulsado : Tema.encima
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
        contentItem: Item { Icono { anchors.centerIn: parent; width: 18; height: 18; nombre: re.icono; color: re.on ? Tema.sobreRosa : Tema.texto } }
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
                y: cabAvisos.height + 6
                width: parent.width
                height: parent.height - y
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds
                model: notifs
                delegate: AbstractButton {
                    id: nd
                    required property var model
                    required property int index
                    width: ListView.view.width
                    height: 60
                    hoverEnabled: true
                    onClicked: notifs.invokeDefaultAction(notifs.index(index, 0))
                    background: Rectangle { radius: Tema.r(14); color: nd.hovered ? Tema.pulsado : Tema.encima }
                    contentItem: Item {
                        Kirigami.Icon {
                            id: appIcon
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28; height: 28
                            source: nd.model.applicationIconName || nd.model.iconName || "apogeo"
                        }
                        Column {
                            x: appIcon.x + appIcon.width + 11
                            width: parent.width - x - 36
                            anchors.verticalCenter: parent.verticalCenter
                            Texto { width: parent.width; elide: Text.ElideRight; wrapMode: Text.NoWrap; font.weight: Font.Bold; font.pixelSize: 13; text: nd.model.summary || nd.model.applicationName || "" }
                            Texto { width: parent.width; elide: Text.ElideRight; wrapMode: Text.NoWrap; color: Tema.apagado; font.pixelSize: 12; textFormat: Text.PlainText
                                    text: (nd.model.applicationName ? nd.model.applicationName + " · " : "") + root.ago(nd.model.created || new Date()) + (nd.model.body ? " · " + String(nd.model.body).replace(/<[^>]*>/g, "") : "") }
                        }
                        AbstractButton {
                            id: close
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 26
                            visible: nd.hovered
                            hoverEnabled: true
                            onClicked: notifs.close(notifs.index(nd.index, 0))
                            background: Rectangle { radius: Tema.r(8); color: close.hovered ? Tema.encima : "transparent" }
                            contentItem: Item { Icono { anchors.centerIn: parent; width: 12; height: 12; nombre: "cerrar"; color: Tema.apagado } }
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
            readonly property var horas: w.horas || []
            readonly property real tmin: horas.length ? Math.min.apply(null, horas.map(h => h.t)) : 0
            readonly property real tmax: horas.length ? Math.max.apply(null, horas.map(h => h.t)) : 1
            Item {
                width: parent.width
                height: tiempo.w.temp === undefined ? 20 : 214
                Texto {
                    visible: tiempo.w.temp === undefined
                    width: parent.width
                    text: tiempo.w.sinCiudad ? "Elige tu ciudad en la agenda (panel de widgets) para ver el tiempo" : "Mirando el tiempo…"
                    color: Tema.apagado; font.pixelSize: 13
                }
                Item {
                    visible: tiempo.w.temp !== undefined
                    width: parent.width; height: parent.height
                    // Ahora
                    Icono { id: ahoraIco; width: 34; height: 34; nombre: root.cielo(tiempo.w.codigo, tiempo.w.dia); color: Tema.rosa }
                    Column {
                        x: ahoraIco.width + 12
                        Texto { text: tiempo.w.temp + "°"; font.pixelSize: 26; font.weight: Font.Black; lineHeight: 0.9 }
                        Texto { text: root.cieloTexto(tiempo.w.codigo) + " · " + (tiempo.w.ciudad || ""); color: Tema.apagado; font.pixelSize: 12; wrapMode: Text.NoWrap }
                    }
                    Texto { anchors.right: parent.right; y: 6; text: tiempo.w.max + "° / " + tiempo.w.min + "°"; color: Tema.apagado; font.pixelSize: 13 }
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
                                Texto { anchors.horizontalCenter: parent.horizontalCenter; y: barra.y - 18; text: hora.modelData.t + "°"; font.pixelSize: 12; font.weight: Font.Bold }
                                Rectangle {
                                    id: barra
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 18
                                    width: 14; radius: 7
                                    height: 14 + hora.p * 30
                                    color: hora.index === 0 ? Tema.rosa : Tema.rosaSuave
                                }
                                Texto { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: hora.modelData.h + "h"; font.pixelSize: 11; color: Tema.tenue }
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
                                Texto { width: 22; anchors.verticalCenter: parent.verticalCenter; text: dia.modelData.dia; font.weight: Font.Bold; color: Tema.apagado }
                                Icono { x: 26; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; nombre: root.cielo(dia.modelData.codigo, true) }
                                Texto { x: 54; anchors.verticalCenter: parent.verticalCenter; text: root.cieloTexto(dia.modelData.codigo); font.pixelSize: 12; color: Tema.apagado }
                                Texto { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: dia.modelData.max + "° / " + dia.modelData.min + "°"; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }
        }
    }
}
