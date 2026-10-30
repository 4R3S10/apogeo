import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.volume as PulseAudio
import org.kde.plasma.private.brightnesscontrolplugin as Brillo
import Apogeo

// La barra fina de arriba de Órbita, en el centro de la pantalla («T1»): tus ventanas abiertas en el modo, solo sus
// iconos, con un punto debajo de la activa. Clic: ir a ella (o minimizarla si ya lo está); clic derecho: cerrar u otra
// ventana. Al cambiar el volumen o el brillo, un momento, su barrita en el mismo sitio (ya no hay pastilla encima del
// orbe). Ocupa el hueco entre el modo y la bandeja, y se coloca en el centro de la pantalla, no del hueco.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    readonly property string modo: Tema.modo || "navegar"
    readonly property color color: ({ jugar: "#b79cff", navegar: "#45d6ff", estudiar: "#ffb35c" })[modo] || Tema.acento

    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }
    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: true
        virtualDesktop: desktops.currentDesktop
        filterByActivity: true
        activity: activities.currentActivity
        filterByScreen: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
    }
    // La consola de Jugar y las ventanitas de Apogeo no van aquí (tienen su botón o se colocan solas)
    function oculta(id) { return /apogeo-(consola|musica|resumen|buscador)/.test(id || "") }

    // El volumen y el brillo, al cambiarlos (no al empezar ni al cambiar de altavoz)
    readonly property var sink: PulseAudio.PreferredDevice.sink
    property string osd: ""
    property int osdValor: 0
    property bool osdSilencio: false
    property bool osdListo: false
    Timer { interval: 3000; running: true; onTriggered: root.osdListo = true }
    onSinkChanged: { osdListo = false; osdArma.restart(); }
    Timer { id: osdArma; interval: 1500; onTriggered: root.osdListo = true }
    Timer { id: osdFin; interval: 1600; onTriggered: root.osd = "" }
    function enseña(tipo, valor, silencio) {
        if (!osdListo) return;
        osd = tipo; osdValor = valor; osdSilencio = !!silencio;
        osdFin.restart();
    }
    Connections {
        target: root.sink
        function onVolumeChanged() { root.enseña("volumen", Math.round(root.sink.volume / 65536 * 100), root.sink.muted) }
        function onMutedChanged() { root.enseña("volumen", Math.round(root.sink.volume / 65536 * 100), root.sink.muted) }
    }
    Brillo.ScreenBrightnessControl { id: brillo }
    Repeater {
        model: brillo.displays
        delegate: Item {
            required property var model
            readonly property int valor: model.maxBrightness > 0 ? Math.round(model.brightness / model.maxBrightness * 100) : -1
            onValorChanged: if (valor >= 0) root.enseña("brillo", valor, false)
        }
    }

    property var menuDe: null
    PlasmaExtras.Menu {
        id: menu
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
        PlasmaExtras.MenuItem {
            text: "Abrir otra ventana"
            icon: "window-new"
            onClicked: tasks.requestNewInstance(tasks.makeModelIndex(root.menuDe.index))
        }
        PlasmaExtras.MenuItem {
            text: "Cerrar"
            icon: "window-close"
            onClicked: tasks.requestClose(tasks.makeModelIndex(root.menuDe.index))
        }
    }

    fullRepresentation: Item {
        id: hueco
        // Jugar es solo la consola (a pantalla completa): aquí no se ve nada
        opacity: Tema.modo === "jugar" ? 0 : 1
        enabled: opacity > 0
        Layout.fillWidth: true
        Layout.minimumWidth: 40
        Layout.fillHeight: true

        // El centro de la pantalla, en las coordenadas del hueco (no se avisa al moverse: se mira al cambiar algo)
        property real centro: width / 2
        function recoloca() {
            const g = hueco.mapToGlobal(0, 0);
            const s = hueco.Window.window ? hueco.Window.window.screen : null;
            if (s) centro = s.virtualX + s.width / 2 - g.x;
        }
        onWidthChanged: Qt.callLater(recoloca)
        onXChanged: Qt.callLater(recoloca)
        Component.onCompleted: Qt.callLater(recoloca)
        Timer { interval: 2000; repeat: true; running: true; onTriggered: hueco.recoloca() }

        Row {
            id: fila
            visible: root.osd === ""
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            x: Math.max(0, Math.min(hueco.width - width, hueco.centro - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: tasks
                delegate: Item {
                    id: tarea
                    required property var model
                    required property int index
                    visible: !root.oculta(model.AppId) && !model.IsLauncher
                    width: visible ? 30 : 0
                    height: 30
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: 9
                        color: Qt.rgba(1, 1, 1, zona.pressed ? 0.14 : zona.containsMouse ? 0.09 : 0)
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        width: 20; height: 20
                        source: tarea.model.decoration
                        opacity: tarea.model.IsMinimized ? 0.45 : 1
                        scale: zona.pressed ? 0.88 : 1
                        Behavior on scale { NumberAnimation { duration: 110 } }
                    }
                    Rectangle {   // el punto de la activa
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -1
                        width: 4; height: 4; radius: 2
                        color: root.color
                        opacity: tarea.model.IsActive ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                    }
                    // Dónde está su icono (para que la ventana se minimice hacia él)
                    function publica() {
                        const g = tarea.mapToGlobal(0, 0);
                        tasks.requestPublishDelegateGeometry(tasks.makeModelIndex(tarea.index), Qt.rect(g.x, g.y, tarea.width, tarea.height), tarea);
                    }
                    Component.onCompleted: Qt.callLater(publica)
                    MouseArea {
                        id: zona
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onEntered: tarea.publica()
                        onClicked: mouse => {
                            const i = tasks.makeModelIndex(tarea.index);
                            if (mouse.button === Qt.RightButton) {
                                root.menuDe = { index: tarea.index };
                                menu.visualParent = tarea;
                                menu.openRelative();
                            } else if (mouse.button === Qt.MiddleButton) {
                                tasks.requestNewInstance(i);
                            } else if (tarea.model.IsActive) {
                                tasks.requestToggleMinimized(i);
                            } else {
                                tasks.requestActivate(i);
                            }
                        }
                    }
                    PlasmaCore.ToolTipArea {
                        anchors.fill: parent
                        location: PlasmaCore.Types.TopEdge
                        mainText: tarea.model.display || ""
                    }
                }
            }
        }

        // El volumen o el brillo, un momento, en el mismo sitio
        Row {
            id: osdFila
            visible: opacity > 0
            opacity: root.osd !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            x: Math.max(0, Math.min(hueco.width - width, hueco.centro - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Icono {
                anchors.verticalCenter: parent.verticalCenter
                width: 15; height: 15
                nombre: root.osd === "brillo" ? "sol" : root.osdSilencio || root.osdValor === 0 ? "silencio" : "volumen"
                color: "#eceef3"
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 140; height: 4; radius: 2
                color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle {
                    width: parent.width * Math.min(1, root.osdSilencio ? 0 : root.osdValor / 100); height: parent.height; radius: 2
                    color: root.color
                    Behavior on width { NumberAnimation { duration: 110 } }
                }
            }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: root.osdSilencio ? "Silencio" : root.osdValor
                color: "#eceef3"
                font { family: Tema.mono; pixelSize: 11 }
            }
        }
    }
}
