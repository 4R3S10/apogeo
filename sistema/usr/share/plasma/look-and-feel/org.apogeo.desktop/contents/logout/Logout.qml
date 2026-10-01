import QtQuick
import QtQuick.Controls as QQC2
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.sessions
import Apogeo

// Pantalla de apagar de Apogeo («A1 · Tarjeta en el centro», como la bienvenida): tu foto, «¿Hasta luego?» y cuatro
// botones (Apagar, Reiniciar, Reposo, Cerrar sesión). Si se ha pedido algo concreto (apagar, reiniciar o salir), solo
// sale eso con su cuenta atrás de 30 segundos. Esc o un clic fuera cancelan. Las señales y lo que da ksmserver
// (sdtype, maysd, canLogout, spdMethods, softwareUpdatePending…) son los de la pantalla de Breeze.
Item {
    id: root
    height: screenGeometry.height
    width: screenGeometry.width

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

    Rectangle { anchors.fill: parent; color: Tema.fondo; opacity: 0.82 }
    MouseArea { anchors.fill: parent; onClicked: root.cancelRequested() }

    readonly property var actions: [
        { key: "halt", texto: softwareUpdatePending ? "Actualizar y apagar" : "Apagar", icono: "apagar",
          ver: maysd && (showAllOptions || sdtype === ShutdownType.ShutdownTypeHalt), run: () => root.halt() },
        { key: "reboot", texto: softwareUpdatePending ? "Actualizar y reiniciar" : "Reiniciar", icono: "actualizar",
          ver: maysd && (showAllOptions || sdtype === ShutdownType.ShutdownTypeReboot), run: () => root.reboot() },
        { key: "sleep", texto: "Reposo", icono: "luna",
          ver: showAllOptions && spdMethods.SuspendState, run: () => root.suspendRequested(2) },
        { key: "logout", texto: "Cerrar sesión", icono: "salir",
          ver: canLogout && (showAllOptions || sdtype === ShutdownType.ShutdownTypeNone), run: () => root.logoutRequested() }
    ].filter(a => a.ver)
    property int current: 0

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.max(380, buttons.implicitWidth + 60)
        height: col.implicitHeight + 56
        radius: 24
        color: Qt.rgba(33 / 255, 25 / 255, 36 / 255, 0.96)
        border.color: Tema.borde
        MouseArea { anchors.fill: parent } // (los clics dentro no cancelan)
        Column {
            id: col
            x: 30; y: 30
            width: card.width - 60
            spacing: 0
            Foto {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72; height: 72
                anillo: true
                letra: root.firstName.charAt(0).toUpperCase()
                fuente: kuser.faceIconUrl.toString().indexOf("file:") === 0 ? kuser.faceIconUrl : ""
            }
            Item { width: 1; height: 16 }
            Texto {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 26
                font.weight: Font.Black
                text: root.showAllOptions ? "¿Hasta luego, " + root.firstName + "?"
                    : sdtype === ShutdownType.ShutdownTypeReboot ? "Reiniciando"
                    : sdtype === ShutdownType.ShutdownTypeHalt ? "Apagando" : "Cerrando la sesión"
            }
            Item { width: 1; height: 4 }
            Texto {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Tema.apagado
                text: root.showAllOptions ? "Elige qué hacer"
                    : "En " + root.remaining + (root.remaining === 1 ? " segundo" : " segundos") + (softwareUpdatePending ? ", con las actualizaciones" : "")
            }
            Texto {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Tema.apagado
                font.pixelSize: 12
                topPadding: 6
                visible: rebootToFirmwareSetup || rebootToBootLoaderMenu
                text: rebootToFirmwareSetup ? "Al reiniciar entrará en la configuración del equipo (UEFI)." : "Al reiniciar saldrá el menú de arranque."
            }
            Item { width: 1; height: 20 }
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
                        width: 112; height: 104
                        hoverEnabled: true
                        focus: on
                        onHoveredChanged: if (hovered) root.current = index
                        onClicked: modelData.run()
                        Keys.onReturnPressed: modelData.run()
                        Keys.onEnterPressed: modelData.run()
                        Keys.onLeftPressed: root.current = Math.max(0, root.current - 1)
                        Keys.onRightPressed: root.current = Math.min(root.actions.length - 1, root.current + 1)
                        background: Rectangle {
                            radius: 18
                            color: b.on ? Tema.rosaSuave : Tema.encima
                            border.width: b.on ? 1.5 : 0
                            border.color: Tema.rosa
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        contentItem: Item {
                            Rectangle {
                                id: badge
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 16
                                width: 46; height: 46; radius: 14
                                color: b.on ? Tema.rosa : Tema.pulsado
                                Icono { anchors.centerIn: parent; width: 20; height: 20; nombre: b.modelData.icono; color: b.on ? Tema.sobreRosa : Tema.texto }
                            }
                            Texto {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: badge.y + badge.height + 10
                                width: parent.width - 8
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                font.weight: Font.Bold
                                font.pixelSize: 13
                                text: b.modelData.texto
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: 18 }
            QQC2.AbstractButton {
                id: cancel
                anchors.horizontalCenter: parent.horizontalCenter
                width: cancelRow.implicitWidth + 20
                height: 30
                hoverEnabled: true
                onClicked: root.cancelRequested()
                background: Rectangle { radius: 9; color: cancel.hovered ? Tema.encima : "transparent" }
                contentItem: Item {
                    Row {
                        id: cancelRow
                        anchors.centerIn: parent
                        spacing: 6
                        Texto { text: "Cancelar"; color: cancel.hovered ? Tema.texto : Tema.apagado; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: esc.implicitWidth + 12; height: 20; radius: 6
                            color: Tema.encima
                            anchors.verticalCenter: parent.verticalCenter
                            Texto { id: esc; anchors.centerIn: parent; text: "Esc"; font.pixelSize: 11; font.weight: Font.DemiBold; color: Tema.tenue }
                        }
                    }
                }
            }
        }
    }
}
