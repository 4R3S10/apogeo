import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.notificationmanager as NotificationManager
import Apogeo

// Los avisos que salen en pantalla, con el estilo de Apogeo (en lugar de la campana de KDE, que ya no está en la
// bandeja): abajo a la derecha, uno encima de otro (3 como mucho), con el icono y el nombre de la app, el título, el
// texto y sus botones. Se van solos a los pocos segundos (no mientras el ratón está encima; los urgentes se quedan) y
// pasan al historial del panel rápido. Con «No molestar» o en Jugar y Estudiar no salen (Plasma los guarda igual:
// el resumen de al volver los enseña).
Item {
    id: avisos

    NotificationManager.Notifications {
        id: popups
        limit: 3
        showExpired: false
        showDismissed: false
        showJobs: false
        showAddedDuringInhibition: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
    }

    readonly property bool inhibited: NotificationManager.Server.inhibited
    // (la pantalla de la isla)
    readonly property rect screen: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)
    // Apilados: cada uno, encima de los que van por debajo (con su altura de verdad)
    property int layoutRev: 0
    function bottomOf(i, rev) {
        let y = screen.y + screen.height - 18;
        for (let k = 0; k < i; k++) {
            const o = list.objectAt(k);
            y -= (o ? o.height : 0) + 10;
        }
        return y;
    }

    Instantiator {
        id: list
        model: avisos.inhibited ? null : popups
        onObjectAdded: avisos.layoutRev++
        onObjectRemoved: avisos.layoutRev++
        delegate: PlasmaCore.Dialog {
            id: pop
            required property var model
            required property int index
            readonly property bool urgent: model.urgency === NotificationManager.Notifications.CriticalUrgency
            readonly property int timeout: urgent || model.resident ? 0 : (model.timeout > 0 ? model.timeout : 6000)
            location: PlasmaCore.Types.Floating
            type: PlasmaCore.Dialog.Notification
            flags: Qt.WindowDoesNotAcceptFocus
            visible: true
            x: avisos.screen.x + avisos.screen.width - width - 18
            y: avisos.bottomOf(index, avisos.layoutRev) - height
            onHeightChanged: avisos.layoutRev++

            function idx() { return popups.index(pop.index, 0) }

            mainItem: Item {
                width: 360
                height: col.implicitHeight + 4
                HoverHandler { id: hover }
                Timer { // se va solo (no mientras lo miras)
                    id: life
                    interval: pop.timeout
                    running: pop.timeout > 0 && !hover.hovered
                    onTriggered: popups.expire(pop.idx())
                }
                TapHandler {
                    enabled: pop.model.hasDefaultAction
                    onTapped: popups.invokeDefaultAction(pop.idx())
                }
                Column {
                    id: col
                    width: parent.width
                    spacing: 6
                    // La app, cuándo y cerrar
                    Item {
                        width: parent.width
                        height: 24
                        Kirigami.Icon {
                            id: appIcon
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18
                            source: pop.model.applicationIconName || pop.model.iconName || "apogeo"
                        }
                        Texto {
                            anchors.left: appIcon.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 70
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            color: Tema.apagado
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            text: (pop.model.applicationName || "Aviso") + (pop.model.originName ? " · " + pop.model.originName : "")
                        }
                        AbstractButton {
                            id: closeX
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24
                            hoverEnabled: true
                            onClicked: popups.close(pop.idx())
                            background: Rectangle { radius: 8; color: closeX.hovered ? Tema.pulsado : "transparent" }
                            contentItem: Item { Icono { anchors.centerIn: parent; width: 11; height: 11; nombre: "cerrar"; color: Tema.apagado } }
                        }
                    }
                    // Título, texto e imagen
                    Row {
                        width: parent.width
                        spacing: 12
                        Column {
                            width: parent.width - (pic.visible ? pic.width + 12 : 0)
                            spacing: 3
                            Texto {
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                font.weight: Font.Bold
                                font.pixelSize: 15
                                text: pop.model.summary || ""
                            }
                            Texto {
                                visible: text !== ""
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                color: Tema.apagado
                                font.pixelSize: 13
                                textFormat: Text.StyledText
                                linkColor: Tema.rosa
                                onLinkActivated: link => Qt.openUrlExternally(link)
                                text: pop.model.body || ""
                            }
                        }
                        Rectangle {
                            id: pic
                            visible: !!pop.model.image || (!!pop.model.iconName && !!pop.model.applicationIconName && pop.model.iconName !== pop.model.applicationIconName)
                            width: 52; height: 52; radius: 12
                            color: Tema.encima
                            clip: true
                            Image { anchors.fill: parent; source: pop.model.image || ""; fillMode: Image.PreserveAspectCrop; visible: !!pop.model.image }
                            Kirigami.Icon { anchors.centerIn: parent; width: 34; height: 34; source: pop.model.iconName || ""; visible: !pop.model.image }
                        }
                    }
                    // Sus botones
                    Row {
                        visible: (pop.model.actionLabels || []).length > 0
                        spacing: 6
                        topPadding: 4
                        Repeater {
                            model: pop.model.actionLabels || []
                            delegate: Boton {
                                required property string modelData
                                required property int index
                                text: modelData
                                onClicked: popups.invokeAction(pop.idx(), pop.model.actionNames[index])
                            }
                        }
                    }
                    // Lo que le queda (una rayita rosa que se acaba)
                    Rectangle {
                        visible: pop.timeout > 0
                        width: parent.width
                        height: 2; radius: 1
                        color: Tema.encima
                        Rectangle {
                            id: bar
                            height: parent.height; radius: 1
                            color: Tema.rosa
                            width: parent.width
                            NumberAnimation on width {
                                from: col.width; to: 0
                                duration: pop.timeout
                                running: pop.timeout > 0
                                paused: hover.hovered
                            }
                        }
                    }
                }
            }
        }
    }
}
