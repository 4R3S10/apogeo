import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.pipewire as PipeWire
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.volume as PulseAudio
import org.kde.plasma.private.brightnesscontrolplugin as Brillo
import Apogeo

// La isla de Apogeo (abajo, se esconde sola), con los botones y chips de Ágape. Siempre: tus apps y el buscador en uno (el
// botón rosa, «A1»; también con la tecla Meta).
// En todos los pisos, tus apps: las fijadas de ese piso (aunque estén cerradas) y las ventanas abiertas en él; al pasar
// por una, su vista en vivo (y ✕ para cerrarla); clic derecho para fijarla en el piso o dejar de fijarla. Encima de
// cada icono, sus avisos sin mirar (o el número que pone la app, como Discord) y, si está bajando algo, su barrita.
// En Jugar, además: temperatura, el límite de FPS, MangoHud, la consola y ver el escritorio.
// «Isla dinámica» (A · Cristal como los paneles): al final, lo que pasa ahora, y la isla se estira con ello. De más a
// menos importante:
//  - el volumen o el brillo al cambiarlos (en vez de la ventanita de KDE), un momento;
//  - un aviso que llega: unos segundos, con sus botones (no mientras lo miras; en silencio no sale);
//  - lo que se está copiando o bajando (copias de archivos y la barrita que pone una app, como Ágape);
//  - el temporizador de concentración (en Estudiar, o en marcha en cualquier piso);
//  - la música: portada con sus colores, barritas y la barra para avanzar (al pasar el ratón, sus botones).
// El volumen, el brillo y los avisos sacan la isla aunque estuviera escondida (se lo pide al script de KWin).
// Lo de cada piso se puede quitar en Ajustes de Apogeo → Isla (apogeo-pisos lo escribe en la configuración de este widget).
// La hora, el sonido, la red y los avisos son los widgets de Plasma que van a su lado en el mismo panel.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    // Colores de Ágape (tema Berenjena oscuro)
    readonly property color accent: Tema.rosa
    readonly property color accentText: Tema.sobreRosa
    readonly property color accentSoft: Tema.rosaSuave
    readonly property color text: Tema.texto
    readonly property color muted: Tema.apagado
    readonly property color hover: Tema.encima
    readonly property color press: Tema.pulsado
    readonly property color border: Tema.borde
    readonly property color warn: "#ff8f9a"
    readonly property string font: Tema.letra

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    readonly property int floorIndex: Math.max(0, desktops.desktopIds.indexOf(desktops.currentDesktop))
    readonly property string floor: desktops.desktopNames[floorIndex] || "Navegar"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.tempCmd) root.temp = parseInt(data.stdout) / 1000 || 0;
            disconnectSource(source);
        }
    }
    function run(cmd) { runner.connectSource(cmd) }

    // ---------- Temperatura (piso Jugar) ----------
    readonly property string tempCmd: "sh -c 'for d in /sys/class/hwmon/hwmon*; do case $(cat $d/name) in k10temp|zenpower|coretemp|amdgpu) cat $d/temp1_input;; esac; done 2>/dev/null | sort -n | tail -1'"
    property real temp: 0
    Timer {
        interval: 4000; repeat: true; triggeredOnStart: true
        running: root.floor === "Jugar"
        onTriggered: root.run(root.tempCmd)
    }

    // ---------- Temporizador de concentración (piso Estudiar): el mismo que el del escritorio (apogeo-pisos) ----------
    Datos { id: datos }
    property var estudio: ({})
    readonly property bool focusRunning: !!estudio.corriendo
    readonly property bool focusBreak: !!estudio.fase && estudio.fase !== "estudio"
    readonly property int focusLeft: estudio.quedan !== undefined ? estudio.quedan : 25 * 60
    function studied() { return estudio.hoy || 0 }
    // (cada segundo en Estudiar o con él en marcha; en otro piso, de vez en cuando, por si lo pones en marcha)
    Timer {
        interval: root.floor === "Estudiar" || root.focusRunning ? 1000 : 10000
        repeat: true; triggeredOnStart: true
        running: Plasmoid.configuration.extraEstudiar
        onTriggered: datos.pedir("Estudio", [], d => { if (d) root.estudio = d; })
    }
    function mmss(s) { return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
    function hm(s) { const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? h + " h " + m + " min" : m + " min" }

    // ---------- Música ----------
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer
    readonly property bool playing: !!player && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string art: player && player.artUrl ? player.artUrl.toString() : ""
    Timer { interval: 1000; repeat: true; running: root.playing && root.moment === "musica"; onTriggered: root.player.updatePosition() }

    // ---------- Isla dinámica: lo que pasa ahora ----------
    // Que la isla salga aunque esté escondida (y que vuelva a esconderse después): se lo pide al script de KWin
    property var reasons: ({})
    function reveal(why, on) {
        const r = Object.assign({}, reasons);
        if (on) r[why] = true; else delete r[why];
        const before = Object.keys(reasons).length > 0, after = Object.keys(r).length > 0;
        reasons = r;
        if (before !== after)
            run("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/kwin "
                + "org.kde.kglobalaccel.Component.invokeShortcut string:" + (after ? "apogeo-isla-mostrar" : "apogeo-isla-soltar"));
    }

    // El volumen y el brillo, al cambiarlos (no al empezar ni al cambiar de altavoz)
    readonly property var sink: PulseAudio.PreferredDevice.sink
    property string osd: ""             // "volumen" o "brillo"
    property int osdValue: 0
    property bool osdMuted: false
    property bool osdReady: false
    Timer { interval: 3000; running: true; onTriggered: root.osdReady = true }
    onSinkChanged: { osdReady = false; osdArm.restart(); }
    Timer { id: osdArm; interval: 1500; onTriggered: root.osdReady = true }
    function showOsd(kind, value, muted) {
        if (!osdReady) return;
        osd = kind; osdValue = value; osdMuted = !!muted;
        osdEnd.restart();
        reveal("osd", true);
    }
    Timer { id: osdEnd; interval: 1800; onTriggered: { root.osd = ""; root.reveal("osd", false); } }
    Connections {
        target: root.sink
        function onVolumeChanged() { root.showOsd("volumen", Math.round(root.sink.volume / 65536 * 100), root.sink.muted) }
        function onMutedChanged() { root.showOsd("volumen", Math.round(root.sink.volume / 65536 * 100), root.sink.muted) }
    }
    Brillo.ScreenBrightnessControl { id: brightness }
    Repeater {
        model: brightness.displays
        delegate: Item {
            required property var model
            readonly property int value: model.maxBrightness > 0 ? Math.round(model.brightness / model.maxBrightness * 100) : -1
            onValueChanged: if (value >= 0) root.showOsd("brillo", value, false)
        }
    }

    // Los avisos que llegan (los urgentes salen además en su ventanita, Avisos de la isla, por encima de todo)
    readonly property bool quiet: NotificationManager.Server.inhibited
    NotificationManager.Notifications {
        id: arriving
        limit: 1
        showExpired: true
        showDismissed: false
        showJobs: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
    }
    property var notice: null           // {id, titulo, texto, app, icono, acciones: [[nombre, etiqueta]], responder, abrir}
    property bool noticeHover: false
    property var seenNotice: -1
    Repeater {
        model: arriving
        delegate: Item {
            id: arrived
            required property var model
            required property int index
            readonly property var nid: model.notificationId
            function take() {
                const m = model;
                root.arrivedId = nid;
                if (nid === root.seenNotice) return;
                root.seenNotice = nid;
                // (los que ya estaban al empezar, los urgentes, en silencio y los de hace rato, no)
                if (!root.osdReady || m.urgency === NotificationManager.Notifications.CriticalUrgency || root.quiet
                    || m.wasAddedDuringInhibition || !m.created || Date.now() - m.created.getTime() > 15000) return;
                const names = m.actionNames || [], labels = m.actionLabels || [];
                root.notice = {
                    id: nid, titulo: m.summary || m.applicationName || "",
                    texto: m.body ? String(m.body).replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim() : "",
                    app: m.applicationName || "", icono: m.applicationIconName || m.iconName || "apogeo",
                    acciones: names.map((n, k) => [n, labels[k] || ""]).filter(a => a[0] !== "default" && a[0] !== "inline-reply").slice(0, 2),
                    responder: !!m.hasReplyAction, abrir: !!m.hasDefaultAction
                };
                arriving.playSoundHint(arriving.index(index, 0));
                noticeEnd.restart();
                root.reveal("aviso", true);
            }
            Component.onCompleted: take()
            onNidChanged: take()
        }
    }
    Timer {
        id: noticeEnd
        interval: 6000
        running: !!root.notice && !root.noticeHover
        onTriggered: root.noticeDone(true)
    }
    // (el aviso que se ve, si sigue siendo el último)
    function noticeIndex() { return notice && arriving.count > 0 && arrivedId === notice.id ? arriving.index(0, 0) : null }
    property var arrivedId: -1
    // Se acabó de enseñar: pasa al historial (mientras se ve, sus botones funcionan; luego la app ya no los escucha)
    function noticeDone(expire) {
        const i = noticeIndex();
        if (expire && i) arriving.expire(i);
        notice = null;
        reveal("aviso", false);
    }
    function noticeAction(name) {
        const i = noticeIndex();
        if (i) {
            if (name === "") arriving.invokeDefaultAction(i); else arriving.invokeAction(i, name);
        }
        noticeDone(false);
    }

    // Lo que se copia o se baja: las copias de archivos de KDE y la barrita que ponen las apps en su icono
    NotificationManager.Notifications {
        id: jobs
        showNotifications: false
        showJobs: true
        showExpired: false
    }
    property var badges: ({})           // app → {numero, progreso} (Datos → Insignias)
    Timer { interval: 3000; repeat: true; running: true; triggeredOnStart: true; onTriggered: datos.pedir("Insignias", [], d => { if (d) root.badges = d; }) }
    readonly property var download: {
        if (jobs.activeJobsCount > 0)
            return { texto: jobs.activeJobsCount === 1 ? "Copiando" : jobs.activeJobsCount + " copias", valor: jobs.jobsPercentage / 100 };
        for (const app in badges)
            if (badges[app].progreso !== undefined) return { texto: appName(app), valor: badges[app].progreso };
        return null;
    }
    function appName(app) { return ({ ares: "Ágape", "org.kde.dolphin": "Dolphin", discord: "Discord", steam: "Steam" })[app] || app }

    // Los números de los iconos: los de la app o, si no pone, sus avisos desde la última vez que miraste
    NotificationManager.Notifications {
        id: history
        showExpired: true
        showDismissed: true
        showJobs: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        limit: 40
    }
    readonly property date lastSeen: Plasmoid.configuration.leidos ? new Date(Plasmoid.configuration.leidos) : new Date(0)
    property var unread: ({})
    Instantiator {
        id: historyRows
        model: history
        delegate: QtObject {
            required property var model
            readonly property string app: root.appKey(model.desktopEntry || "")
            readonly property bool fresh: !!model.created && model.created > root.lastSeen
        }
        onObjectAdded: countLater.restart()
        onObjectRemoved: countLater.restart()
    }
    onLastSeenChanged: countLater.restart()
    Timer {
        id: countLater
        interval: 300
        onTriggered: {
            const u = {};
            for (let i = 0; i < historyRows.count; i++) {
                const o = historyRows.objectAt(i);
                if (o && o.fresh && o.app) u[o.app] = (u[o.app] || 0) + 1;
            }
            root.unread = u;
        }
    }
    function appKey(id) { return String(id || "").toLowerCase().replace(/\.desktop$/, "").replace(/^applications:/, "") }
    function badgeOf(id) {
        const k = appKey(id), b = badges[k] || {};
        return { numero: b.numero || unread[k] || 0, progreso: b.progreso !== undefined ? b.progreso : -1 };
    }

    // Lo que se ve ahora, de más a menos importante
    readonly property bool timerShown: Plasmoid.configuration.extraEstudiar && (focusRunning || floor === "Estudiar")
    readonly property bool musicShown: !!player && (player.track || "") !== "" && (playing || (floor === "Navegar" && Plasmoid.configuration.extraNavegar))
    readonly property string moment: osd !== "" ? "osd" : notice ? "aviso" : download ? "descarga" : timerShown ? "temporizador" : musicShown ? "musica" : ""

    // ---------- Tus apps del piso: las fijadas y las ventanas abiertas ----------
    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: true
        virtualDesktop: desktops.currentDesktop
        filterByActivity: true
        activity: activities.currentActivity
        groupMode: TaskManager.TasksModel.GroupDisabled
        separateLaunchers: false
        launchInPlace: true
        // Fijar o dejar de fijar (requestAddLauncher…) cambia la lista: se guarda en la del piso
        onLauncherListChanged: if (!root.loadingPins) Plasmoid.configuration["fijadas" + root.floor] = launcherList
    }
    property bool loadingPins: false
    function loadPins() {
        loadingPins = true;
        tasks.launcherList = Plasmoid.configuration["fijadas" + floor] || [];
        loadingPins = false;
    }
    onFloorChanged: loadPins()
    Component.onCompleted: loadPins()
    // La consola de Jugar y las ventanitas de Apogeo no van en la isla (tienen su botón o se colocan solas)
    function hiddenApp(id) { return /apogeo-(consola|musica|resumen|buscador)/.test(id || "") }

    // El menú de una app (clic derecho)
    property var menuTask: null
    PlasmaExtras.Menu {
        id: taskMenu
        placement: Tema.posicion === "arriba-dcha" ? PlasmaExtras.Menu.BottomPosedLeftAlignedPopup : PlasmaExtras.Menu.TopPosedLeftAlignedPopup
        PlasmaExtras.MenuItem {
            visible: !!root.menuTask && !root.menuTask.pinned
            text: "Fijar en " + root.floor
            icon: "window-pin"
            onClicked: tasks.requestAddLauncher(root.menuTask.url)
        }
        PlasmaExtras.MenuItem {
            visible: !!root.menuTask && root.menuTask.pinned
            text: "Dejar de fijar en " + root.floor
            icon: "window-unpin"
            onClicked: tasks.requestRemoveLauncher(root.menuTask.url)
        }
        PlasmaExtras.MenuItem {
            visible: !!root.menuTask && root.menuTask.window
            text: "Abrir otra ventana"
            icon: "window-new"
            onClicked: tasks.requestNewInstance(tasks.makeModelIndex(root.menuTask.index))
        }
        PlasmaExtras.MenuItem {
            visible: !!root.menuTask && root.menuTask.window
            text: "Cerrar"
            icon: "window-close"
            onClicked: tasks.requestClose(tasks.makeModelIndex(root.menuTask.index))
        }
    }

    function icon(name) { return Qt.resolvedUrl("../icons/" + name + ".svg") }

    // Botón de Ágape (38 × 38, radio 13): sin fondo; al pasar el ratón, el fondo suave. «on» = la pastilla rosa con brillo
    component AgapeButton: Item {
        id: btn
        property string iconName
        property bool on: false
        property string tip
        signal clicked()
        implicitWidth: 38
        implicitHeight: 38
        RectangularShadow {
            anchors.fill: bg
            visible: btn.on
            offset.y: 4; blur: 18; spread: -4
            radius: bg.radius
            color: root.accent
            opacity: 0.85
        }
        Rectangle {
            id: bg
            anchors.fill: parent
            radius: Tema.r(13)
            color: btn.on ? root.accent : (area.pressed ? root.press : area.containsMouse ? root.hover : "transparent")
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        Kirigami.Icon {
            anchors.centerIn: parent
            width: 18; height: 18
            source: root.icon(btn.iconName)
            isMask: true
            color: btn.on ? root.accentText : (area.containsMouse ? root.text : root.muted)
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
        QQC2.ToolTip.visible: tip !== "" && area.containsMouse
        QQC2.ToolTip.text: tip
        QQC2.ToolTip.delay: 500
    }

    // Chip de Ágape: icono + texto sobre el cristal (el fondo suave solo al pasar el ratón); «on» = rosa
    component Chip: Item {
        id: chip
        property string iconName
        property alias text: label.text
        property color fg: root.text
        property bool on: false
        signal clicked()
        signal rightClicked()
        implicitWidth: row.implicitWidth + 20
        implicitHeight: 38
        RectangularShadow {
            anchors.fill: chipBg
            visible: chip.on
            offset.y: 4; blur: 18; spread: -4
            radius: chipBg.radius
            color: root.accent
            opacity: 0.85
        }
        Rectangle {
            id: chipBg
            anchors.fill: parent
            radius: Tema.r(13)
            color: chip.on ? root.accent : (chipArea.containsMouse ? root.hover : "transparent")
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 7
            Kirigami.Icon {
                visible: chip.iconName !== ""
                Layout.preferredWidth: 15; Layout.preferredHeight: 15
                source: chip.iconName ? root.icon(chip.iconName) : ""
                isMask: true
                color: chip.on ? root.accentText : root.muted
            }
            QQC2.Label {
                id: label
                color: chip.on ? root.accentText : chip.fg
                font.family: root.font
                font.weight: chip.on ? Font.Bold : Font.DemiBold
                font.pixelSize: 14
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? chip.rightClicked() : chip.clicked()
        }
    }

    // Un estado de la isla dinámica: entra fundiéndose y creciendo un poco; «tint», con el fondo de los colores de la
    // portada
    component MomentView: Item {
        id: mv
        property bool on: false
        property bool tint: false
        property color tintFrom: "transparent"
        property color tintTo: "transparent"
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: 36
        visible: opacity > 0
        opacity: on ? 1 : 0
        scale: on ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Rectangle {
            visible: mv.tint
            anchors.fill: parent
            radius: Tema.r(13)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: mv.tintFrom; Behavior on color { ColorAnimation { duration: 600 } } }
                GradientStop { position: 1; color: mv.tintTo; Behavior on color { ColorAnimation { duration: 600 } } }
            }
        }
    }
    // Un botón de un aviso en la isla
    component MomentChip: QQC2.AbstractButton {
        id: mc
        property bool filled: false
        implicitHeight: 26
        implicitWidth: mcText.implicitWidth + 18
        hoverEnabled: true
        background: Rectangle {
            radius: height / 2
            color: mc.filled ? (mc.hovered ? Qt.lighter(root.accent, 1.08) : root.accent) : (mc.hovered ? root.press : root.hover)
        }
        contentItem: QQC2.Label { id: mcText; text: mc.text; font.family: root.font; font.weight: Font.Bold; font.pixelSize: 12; color: mc.filled ? root.accentText : root.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
    }

    component Separator: Rectangle {
        implicitWidth: 1
        implicitHeight: 24
        color: root.border
        Layout.leftMargin: 6
        Layout.rightMargin: 6
    }

    fullRepresentation: RowLayout {
        spacing: 6
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth

        // Tus apps por tipo y, al escribir, el buscador (apps, archivos, calculadora, la web…): la pastilla rosa
        AgapeButton {
            iconName: "apps"
            on: true
            tip: "Apps y buscar (Meta)"
            onClicked: root.run("dbus-send --session --type=method_call --dest=org.apogeo.Buscador /Buscador org.apogeo.Buscador.Toggle")
        }

        Separator {}

        // ----- Jugar -----
        Chip {
            visible: root.floor === "Jugar" && root.temp > 0 && Plasmoid.configuration.extraJugar
            iconName: "temperatura"
            text: Math.round(root.temp) + " °C"
            fg: root.temp >= Plasmoid.configuration.limite ? root.warn : root.text
        }
        Chip {
            visible: root.floor === "Jugar" && Plasmoid.configuration.extraJugar
            iconName: "fps"
            text: Plasmoid.configuration.fps + " FPS"
        }
        AgapeButton {
            visible: root.floor === "Jugar"
            iconName: "hud"
            tip: "MangoHud en el juego: enseñar o esconder (también Mayús derecha+F12)"
            onClicked: root.run("mangohudctl toggle no_display")
        }
        AgapeButton {
            visible: root.floor === "Jugar"
            iconName: "consola"
            tip: "Consola de juegos"
            onClicked: root.run("/usr/lib/apogeo/apogeo-juegos consola")
        }
        AgapeButton {
            visible: root.floor === "Jugar"
            iconName: "escritorio"
            tip: "Ver el escritorio"
            onClicked: root.run("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'string:Show Desktop'")
        }

        Separator { visible: tasks.count > 0 && root.floor === "Jugar" }

        // ----- Tus apps del piso: fijadas y abiertas -----
        Repeater {
            model: tasks
            delegate: Item {
                id: task
                required property var model
                required property int index
                readonly property bool launcher: !!model.IsLauncher
                readonly property string url: model.LauncherUrlWithoutIcon ? model.LauncherUrlWithoutIcon.toString() : ""
                readonly property bool pinned: Plasmoid.configuration["fijadas" + root.floor].indexOf(url) >= 0
                visible: !root.hiddenApp(model.AppId)
                Layout.preferredWidth: visible ? 40 : 0
                Layout.preferredHeight: 40
                Rectangle {
                    anchors.fill: parent
                    radius: Tema.r(13)
                    color: hoverTask.pressed ? root.press : hoverTask.containsMouse || task.model.IsActive ? root.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                // Todas iguales: cada icono en su baldosa redondeada, con un toque del color de tu estilo
                Rectangle {
                    id: tile
                    anchors.centerIn: parent
                    width: 32; height: 32
                    radius: Tema.r(10)
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                    border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                    border.width: 1
                    opacity: task.launcher ? 0.82 : task.model.IsMinimized ? 0.5 : 1
                    scale: hoverTask.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Kirigami.Icon {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 22; height: 22
                        source: task.model.decoration
                        layer.enabled: true
                        layer.effect: MultiEffect { colorization: 0.14; colorizationColor: root.accent }
                    }
                }
                // Sus avisos sin mirar (o el número que pone la app) y, si baja algo, su barrita
                readonly property var badge: root.badgeOf(model.AppId || url.replace(/^.*\//, ""))
                Rectangle {
                    visible: task.badge.numero > 0
                    z: 2
                    x: tile.x + tile.width - width / 2 - 2
                    y: tile.y - 5
                    width: Math.max(17, badgeText.implicitWidth + 8); height: 17
                    radius: height / 2
                    color: Tema.rosa
                    border.width: 2
                    border.color: Tema.cromo
                    Texto { id: badgeText; anchors.centerIn: parent; text: task.badge.numero > 99 ? "99+" : task.badge.numero; font.pixelSize: 10; font.weight: Font.Black; color: Tema.sobreRosa }
                    scale: visible ? 1 : 0.4
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                }
                Rectangle {
                    visible: task.badge.progreso >= 0
                    z: 2
                    anchors.horizontalCenter: tile.horizontalCenter
                    y: tile.y + tile.height - 5
                    width: tile.width - 8; height: 4; radius: 2
                    color: Qt.rgba(0, 0, 0, 0.5)
                    Rectangle { width: parent.width * Math.max(0, task.badge.progreso); height: parent.height; radius: 2; color: "#7fd4ff" }
                }
                // Dónde está su icono (para que la ventana se minimice hacia él)
                function publish() {
                    if (task.launcher) return;
                    const g = task.mapToGlobal(0, 0);
                    tasks.requestPublishDelegateGeometry(tasks.makeModelIndex(task.index), Qt.rect(g.x, g.y, task.width, task.height), task);
                }
                Component.onCompleted: Qt.callLater(publish)
                Rectangle { // el puntito rosa de cada ventana abierta (en la activa, una rayita); las fijadas cerradas, sin él
                    visible: !task.launcher
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -3
                    width: task.model.IsActive ? 14 : 5
                    height: 4; radius: 2
                    color: root.accent
                    opacity: task.model.IsMinimized ? 0.35 : 1
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: hoverTask
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: task.publish()
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        const idx = tasks.makeModelIndex(task.index);
                        if (mouse.button === Qt.RightButton) {
                            root.menuTask = { index: task.index, url: task.url, pinned: task.pinned, window: !task.launcher };
                            taskMenu.visualParent = task;
                            taskMenu.openRelative();
                        } else if (mouse.button === Qt.MiddleButton) {
                            task.launcher ? tasks.requestActivate(idx) : tasks.requestNewInstance(idx);
                        } else if (task.launcher) {
                            tasks.requestActivate(idx);   // (en un lanzador, abre la app)
                        } else if (task.model.IsActive) {
                            tasks.requestToggleMinimized(idx);
                        } else {
                            tasks.requestActivate(idx);
                        }
                    }
                }
                // Al pasar el ratón: la vista en vivo de la ventana (o el nombre, si está cerrada)
                PlasmaCore.ToolTipArea {
                    anchors.fill: parent
                    interactive: !task.launcher
                    location: Tema.posicion === "arriba-dcha" ? PlasmaCore.Types.TopEdge : PlasmaCore.Types.BottomEdge
                    mainText: task.launcher ? (task.model.display || "") : ""
                    subText: task.launcher ? "Abrir" : ""
                    mainItem: task.launcher ? null : preview
                    Item {
                        id: preview
                        visible: false
                        width: 260
                        height: 190
                        TaskManager.ScreencastingRequest {
                            id: cast
                            // solo mientras se ve la vista (no gasta nada si no)
                            uuid: preview.visible && task.model.WinIdList && task.model.WinIdList.length ? task.model.WinIdList[0] : ""
                        }
                        Rectangle {
                            x: 0; y: 0
                            width: parent.width; height: 146
                            radius: Tema.r(12)
                            color: Qt.rgba(0, 0, 0, 0.25)
                            clip: true
                            Kirigami.Icon { anchors.centerIn: parent; width: 48; height: 48; source: task.model.decoration; visible: !thumb.visible }
                            PipeWire.PipeWireSourceItem {
                                id: thumb
                                anchors.fill: parent
                                anchors.margins: 4
                                nodeId: cast.nodeId
                                visible: nodeId > 0 && ready
                            }
                        }
                        Texto {
                            x: 4; y: 154
                            width: parent.width - 40
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.weight: Font.Bold
                            font.pixelSize: 13
                            text: task.model.display || ""
                        }
                        Texto {
                            x: 4; y: 172
                            width: parent.width - 40
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            color: Tema.apagado
                            font.pixelSize: 11
                            text: task.model.AppName || ""
                        }
                        Rectangle {
                            id: closeBtn
                            anchors.right: parent.right
                            y: 156
                            width: 28; height: 28; radius: Tema.r(9)
                            color: closeArea.containsMouse ? "#e5484d" : "transparent"
                            Icono { anchors.centerIn: parent; width: 12; height: 12; nombre: "cerrar"; color: closeArea.containsMouse ? "#ffffff" : Tema.apagado }
                            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: tasks.requestClose(tasks.makeModelIndex(task.index)) }
                        }
                    }
                }
            }
        }

        // ----- Isla dinámica: lo que pasa ahora (la isla se estira con ello) -----
        Separator { visible: moment.Layout.preferredWidth > 1 }
        Item {
            id: moment
            readonly property string kind: root.moment
            readonly property Item current: ({ osd: osdView, aviso: noticeView, descarga: downloadView, temporizador: timerView, musica: musicView })[kind] || null
            Layout.preferredHeight: 40
            Layout.preferredWidth: current ? current.implicitWidth : 0
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
            visible: Layout.preferredWidth > 1
            clip: true
            HoverHandler { id: momentHover; onHoveredChanged: root.noticeHover = hovered }

            // --- El volumen o el brillo ---
            MomentView {
                id: osdView
                on: moment.kind === "osd"
                implicitWidth: osdRow.implicitWidth + 24
                RowLayout {
                    id: osdRow
                    anchors.centerIn: parent
                    spacing: 10
                    Icono {
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        nombre: root.osd === "brillo" ? "sol" : root.osdMuted || root.osdValue === 0 ? "silencio" : "volumen"
                        color: root.text
                    }
                    Rectangle {
                        Layout.preferredWidth: 150; Layout.preferredHeight: 6
                        radius: 3
                        color: root.press
                        Rectangle {
                            width: parent.width * Math.min(1, root.osdMuted ? 0 : root.osdValue / 100); height: parent.height; radius: 3
                            color: root.accent
                            Behavior on width { NumberAnimation { duration: 120 } }
                        }
                    }
                    QQC2.Label { text: root.osdMuted ? "Silencio" : root.osdValue; font.family: root.font; font.weight: Font.Bold; font.pixelSize: 13; color: root.text; Layout.minimumWidth: 26 }
                }
            }

            // --- Un aviso que llega ---
            MomentView {
                id: noticeView
                on: moment.kind === "aviso"
                implicitWidth: Math.min(470, noticeRow.implicitWidth + 20)
                RowLayout {
                    id: noticeRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10
                    width: Math.min(implicitWidth, 450)
                    spacing: 10
                    Kirigami.Icon { Layout.preferredWidth: 26; Layout.preferredHeight: 26; source: root.notice ? root.notice.icono : "" }
                    ColumnLayout {
                        spacing: 0
                        Layout.maximumWidth: 230
                        QQC2.Label {
                            text: root.notice ? root.notice.titulo : ""
                            font.family: root.font; font.weight: Font.Bold; font.pixelSize: 13; color: root.text
                            elide: Text.ElideRight; Layout.maximumWidth: 230
                        }
                        QQC2.Label {
                            visible: text !== ""
                            text: root.notice ? (root.notice.texto || root.notice.app) : ""
                            font.family: root.font; font.pixelSize: 11; color: root.muted
                            elide: Text.ElideRight; Layout.maximumWidth: 230
                        }
                    }
                    Repeater {
                        model: root.notice ? root.notice.acciones : []
                        delegate: MomentChip { required property var modelData; text: modelData[1]; onClicked: root.noticeAction(modelData[0]) }
                    }
                    MomentChip {
                        visible: !!root.notice && root.notice.responder
                        text: "Responder"
                        filled: true
                        onClicked: { root.noticeDone(false); root.run("dbus-send --session --type=method_call --dest=org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut string:apogeo-panel-derecho"); }
                    }
                    MomentChip {
                        visible: !!root.notice && root.notice.abrir && !root.notice.responder
                        text: "Abrir"
                        filled: true
                        onClicked: root.noticeAction("")
                    }
                    AgapeButton {
                        implicitWidth: 26; implicitHeight: 26
                        iconName: "cerrar"
                        onClicked: root.noticeDone(true)
                    }
                }
            }

            // --- Lo que se copia o se baja ---
            MomentView {
                id: downloadView
                on: moment.kind === "descarga"
                implicitWidth: downloadRow.implicitWidth + 24
                RowLayout {
                    id: downloadRow
                    anchors.centerIn: parent
                    spacing: 9
                    Icono { Layout.preferredWidth: 16; Layout.preferredHeight: 16; nombre: "descargar"; color: "#7fd4ff" }
                    QQC2.Label { text: root.download ? root.download.texto : ""; font.family: root.font; font.weight: Font.DemiBold; font.pixelSize: 13; color: root.text; elide: Text.ElideRight; Layout.maximumWidth: 140 }
                    Rectangle {
                        Layout.preferredWidth: 90; Layout.preferredHeight: 5
                        radius: 2.5
                        color: root.press
                        Rectangle { width: parent.width * (root.download ? Math.max(0, Math.min(1, root.download.valor)) : 0); height: parent.height; radius: 2.5; color: "#7fd4ff"; Behavior on width { NumberAnimation { duration: 300 } } }
                    }
                    QQC2.Label { text: root.download ? Math.round(root.download.valor * 100) + "%" : ""; font.family: root.font; font.pixelSize: 12; color: root.muted }
                }
            }

            // --- El temporizador de concentración (clic: en marcha o en pausa; clic derecho: volver a empezar) ---
            MomentView {
                id: timerView
                on: moment.kind === "temporizador"
                implicitWidth: timerRow.implicitWidth + 24
                RowLayout {
                    id: timerRow
                    anchors.centerIn: parent
                    spacing: 9
                    Item {
                        id: ring
                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                        readonly property real total: root.estudio.total || (root.focusBreak ? 5 * 60 : 25 * 60)
                        readonly property real done: Math.max(0, Math.min(1, 1 - root.focusLeft / total))
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeColor: root.press; strokeWidth: 3; fillColor: "transparent"
                                PathAngleArc { centerX: 12; centerY: 12; radiusX: 10; radiusY: 10; startAngle: 0; sweepAngle: 360 }
                            }
                            ShapePath {
                                strokeColor: root.focusBreak ? Tema.vivo : root.accent; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                                PathAngleArc { centerX: 12; centerY: 12; radiusX: 10; radiusY: 10; startAngle: -90; sweepAngle: 360 * ring.done }
                            }
                        }
                    }
                    QQC2.Label { text: root.mmss(root.focusLeft); font.family: root.font; font.weight: Font.Bold; font.pixelSize: 14; color: root.text; font.features: { "tnum": 1 } }
                    QQC2.Label { text: (root.focusBreak ? "descanso" : "estudio") + " · hoy " + root.hm(root.studied()); font.family: root.font; font.pixelSize: 12; color: root.muted }
                    Icono { Layout.preferredWidth: 14; Layout.preferredHeight: 14; nombre: root.focusRunning ? "pausa" : "reproducir"; color: root.muted }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => datos.hacer("EstudioAccion", [mouse.button === Qt.RightButton ? "reiniciar" : "alternar", ""])
                }
            }

            // --- La música: portada, sus colores y la barra para avanzar; al pasar el ratón, sus botones ---
            MomentView {
                id: musicView
                on: moment.kind === "musica"
                tint: true
                implicitWidth: musicRow.implicitWidth + 16
                ColorDe { id: cover; fuente: root.art }
                RowLayout {
                    id: musicRow
                    anchors.verticalCenter: parent.verticalCenter
                    x: 5
                    spacing: 9
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30
                        radius: Tema.r(8)
                        color: Qt.rgba(1, 1, 1, 0.1)
                        Image { id: coverImage; anchors.fill: parent; source: root.art; sourceSize: Qt.size(60, 60); fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
                        Rectangle { id: coverShape; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
                        MultiEffect { anchors.fill: parent; source: coverImage; maskEnabled: true; maskSource: coverShape; visible: coverImage.status === Image.Ready }
                        Icono { anchors.centerIn: parent; width: 14; height: 14; nombre: "musica"; color: cover.vivo; visible: coverImage.status !== Image.Ready }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player.canRaise) root.player.Raise() }
                    }
                    ColumnLayout {
                        spacing: 1
                        Layout.preferredWidth: 150
                        QQC2.Label { text: root.player ? root.player.track : ""; font.family: root.font; font.weight: Font.DemiBold; font.pixelSize: 13; color: "white"; elide: Text.ElideRight; Layout.preferredWidth: 150 }
                        QQC2.Label { visible: text !== ""; text: root.player ? (root.player.artist || "") : ""; font.family: root.font; font.pixelSize: 11; color: Qt.rgba(1, 1, 1, 0.65); elide: Text.ElideRight; Layout.preferredWidth: 150 }
                        // La barra para avanzar (arrastrando)
                        Item {
                            id: seek
                            Layout.preferredWidth: 150; Layout.preferredHeight: 6
                            readonly property real len: root.player ? root.player.length : 0
                            readonly property real pos: seekArea.pressed ? seekArea.v : (len > 0 && root.player ? Math.min(1, root.player.position / len) : 0)
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: seekArea.containsMouse ? 4 : 2; radius: height / 2
                                color: Qt.rgba(1, 1, 1, 0.2)
                                Rectangle { width: parent.width * seek.pos; height: parent.height; radius: parent.radius; color: cover.vivo }
                            }
                            MouseArea {
                                id: seekArea
                                anchors.fill: parent; anchors.margins: -4
                                enabled: !!root.player && root.player.canSeek && seek.len > 0
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                property real v: 0
                                function at(x) { v = Math.max(0, Math.min(1, (x - 4) / seek.width)); }
                                onPressed: m => at(m.x)
                                onPositionChanged: m => { if (pressed) at(m.x); }
                                onReleased: root.player.position = Math.round(v * seek.len)
                            }
                        }
                    }
                    Barritas {
                        visible: !momentHover.hovered
                        Layout.preferredHeight: 16
                        Layout.preferredWidth: implicitWidth
                        cuantas: 4; grosor: 3
                        sonando: root.playing
                        color: cover.vivo
                    }
                    Row {
                        visible: momentHover.hovered
                        spacing: 0
                        AgapeButton { implicitWidth: 28; implicitHeight: 28; iconName: "anterior"; onClicked: root.player.Previous() }
                        AgapeButton { implicitWidth: 28; implicitHeight: 28; iconName: root.playing ? "pausa" : "reproducir"; onClicked: root.player.PlayPause() }
                        AgapeButton { implicitWidth: 28; implicitHeight: 28; iconName: "siguiente"; onClicked: root.player.Next() }
                    }
                }
                tintFrom: cover.oscuro
                tintTo: Qt.darker(cover.vivo, 2.4)
            }
        }

        Separator {}
    }
}
