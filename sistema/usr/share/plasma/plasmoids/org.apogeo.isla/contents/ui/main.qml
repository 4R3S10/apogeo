import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.pipewire as PipeWire
import Apogeo

// La isla de Apogeo (abajo, se esconde sola), con los botones y chips de Ágape. Siempre: tus apps y el buscador en uno (el
// botón rosa, «A1»; también con la tecla Meta).
// En todos los pisos, tus apps: las fijadas de ese piso (aunque estén cerradas) y las ventanas abiertas en él; al pasar
// por una, su vista en vivo (y ✕ para cerrarla); clic derecho para fijarla en el piso o dejar de fijarla.
// Además, según el piso:
//  - Jugar: temperatura, el límite de FPS y un botón para ver el escritorio.
//  - Navegar: la música que suena.
//  - Estudiar: temporizador de concentración (25 min estudio / 5 descanso) y lo estudiado hoy.
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
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.floor === "Estudiar" && Plasmoid.configuration.extraEstudiar
        onTriggered: datos.pedir("Estudio", [], d => { if (d) root.estudio = d; })
    }
    function mmss(s) { return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
    function hm(s) { const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? h + " h " + m + " min" : m + " min" }

    // ---------- Música ----------
    Mpris.Mpris2Model { id: mpris }
    readonly property var player: mpris.currentPlayer

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

        // ----- Estudiar -----
        Chip {
            visible: root.floor === "Estudiar" && Plasmoid.configuration.extraEstudiar
            iconName: root.focusRunning ? "pausa" : "reloj"
            on: root.focusRunning
            text: root.mmss(root.focusLeft) + " · " + (root.focusBreak ? "descanso" : "estudio")
            onClicked: datos.hacer("EstudioAccion", ["alternar", ""])
            onRightClicked: datos.hacer("EstudioAccion", ["reiniciar", ""])
        }
        Chip {
            visible: root.floor === "Estudiar" && Plasmoid.configuration.extraEstudiar
            iconName: "libro"
            text: "Hoy " + root.hm(root.studied())
        }
        Separator { visible: tasks.count > 0 && (root.floor === "Jugar" || (root.floor === "Estudiar" && Plasmoid.configuration.extraEstudiar)) }

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
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 26; height: 26
                    source: task.model.decoration
                    opacity: task.launcher ? 0.82 : task.model.IsMinimized ? 0.5 : 1
                    scale: hoverTask.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: 120 } }
                }
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

        // ----- Música (Navegar): la del widget de música de Ágape -----
        Separator { visible: music.visible }
        Rectangle {
            id: music
            visible: root.floor === "Navegar" && Plasmoid.configuration.extraNavegar && !!root.player && (root.player.track || "") !== ""
            Layout.preferredHeight: 38
            Layout.preferredWidth: musicRow.implicitWidth + 12
            radius: Tema.r(13)
            color: "transparent"
            RowLayout {
                id: musicRow
                anchors.centerIn: parent
                spacing: 9
                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30
                    radius: Tema.r(8)
                    clip: true
                    color: root.accentSoft
                    Image {
                        anchors.fill: parent
                        source: root.player ? root.player.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }
                ColumnLayout {
                    spacing: 0
                    QQC2.Label {
                        text: root.player ? root.player.track : ""
                        font.family: root.font
                        font.weight: Font.DemiBold
                        font.pixelSize: 13
                        color: root.text
                        elide: Text.ElideRight
                        Layout.maximumWidth: 160
                    }
                    QQC2.Label {
                        visible: text !== ""
                        text: root.player ? (root.player.artist || "") : ""
                        font.family: root.font
                        font.pixelSize: 11
                        color: root.muted
                        elide: Text.ElideRight
                        Layout.maximumWidth: 160
                    }
                }
                AgapeButton {
                    implicitWidth: 28; implicitHeight: 28
                    iconName: root.player && root.player.playbackStatus === Mpris.PlaybackStatus.Playing ? "pausa" : "reproducir"
                    onClicked: root.player.PlayPause()
                }
                AgapeButton {
                    implicitWidth: 28; implicitHeight: 28
                    iconName: "siguiente"
                    onClicked: root.player.Next()
                }
            }
        }

        Separator {}
    }
}
