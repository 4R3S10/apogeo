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
// texto y sus botones (y, si la app deja, contestar ahí mismo). Se van solos a los pocos segundos (no mientras el
// ratón está encima ni mientras contestas; los urgentes se quedan) y pasan al historial del panel rápido. Con «No
// molestar» o en Jugar y Estudiar no salen (pasan directos al historial: el resumen de al volver los enseña), salvo los
// urgentes, como los recordatorios y los temporizadores.
Item {
    id: avisos

    NotificationManager.Notifications {
        id: popups
        limit: 3
        showExpired: false
        showDismissed: false
        showJobs: false
        showAddedDuringInhibition: true  // (para los urgentes; los demás se esconden abajo)
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
            if (o && o.shown) y -= o.height + 10;
        }
        return y;
    }

    Instantiator {
        id: list
        model: popups
        onObjectAdded: avisos.layoutRev++
        onObjectRemoved: avisos.layoutRev++
        delegate: PlasmaCore.Dialog {
            id: pop
            required property var model
            required property int index
            readonly property bool urgent: model.urgency === NotificationManager.Notifications.CriticalUrgency
            readonly property int timeout: urgent || model.resident ? 0 : (model.timeout > 0 ? model.timeout : 6000)
            // En silencio solo salen los urgentes; los demás se van directos al historial
            readonly property bool shown: urgent || (!avisos.inhibited && !model.wasAddedDuringInhibition)
            onShownChanged: avisos.layoutRev++
            // Su sonido, si lo trae (como hace Plasma; en silencio no suena)
            Component.onCompleted: if (shown) popups.playSoundHint(popups.index(index, 0))
            location: PlasmaCore.Types.Floating
            // (los urgentes, por encima de todo: también de un juego a pantalla completa)
            type: urgent ? PlasmaCore.Dialog.CriticalNotification : PlasmaCore.Dialog.Notification
            // (no se lleva el teclado, salvo al contestar)
            flags: replying ? 0 : Qt.WindowDoesNotAcceptFocus
            visible: shown
            x: avisos.screen.x + avisos.screen.width - width - 18
            y: avisos.bottomOf(index, avisos.layoutRev) - height
            onHeightChanged: avisos.layoutRev++

            function idx() { return popups.index(pop.index, 0) }
            property bool replying: false
            function startReply() {
                replying = true;
                pop.requestActivate();
                replyField.forceActiveFocus();
            }
            function sendReply() {
                const t = replyField.text.trim();
                if (t === "") return;
                popups.reply(pop.idx(), t, NotificationManager.Notifications.Close);
            }

            mainItem: Item {
                width: 360
                height: col.implicitHeight + 4
                HoverHandler { id: hover }
                Timer { // se va solo (no mientras lo miras)
                    id: life
                    interval: pop.shown ? pop.timeout : 1
                    running: !pop.shown || (pop.timeout > 0 && !hover.hovered && !pop.replying)
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
                            background: Rectangle { radius: Tema.r(8); color: closeX.hovered ? Tema.pulsado : "transparent" }
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
                            width: 52; height: 52; radius: Tema.r(12)
                            color: Tema.encima
                            clip: true
                            Image { anchors.fill: parent; source: pop.model.image || ""; fillMode: Image.PreserveAspectCrop; visible: !!pop.model.image }
                            Kirigami.Icon { anchors.centerIn: parent; width: 34; height: 34; source: pop.model.iconName || ""; visible: !pop.model.image }
                        }
                    }
                    // Sus botones (y «Responder», si la app deja contestar desde el aviso: Discord, mensajes…)
                    Row {
                        visible: !pop.replying && ((pop.model.actionLabels || []).length > 0 || pop.model.hasReplyAction)
                        spacing: 6
                        topPadding: 4
                        Boton {
                            visible: !!pop.model.hasReplyAction
                            tipo: "principal"
                            text: pop.model.replyActionLabel || "Responder"
                            onClicked: pop.startReply()
                        }
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
                    // Contestar aquí mismo: Intro lo envía
                    Row {
                        visible: pop.replying
                        width: parent.width
                        spacing: 6
                        topPadding: 4
                        TextField {
                            id: replyField
                            width: parent.width - sendReply.width - 6
                            height: 34
                            placeholderText: pop.model.replyPlaceholderText || "Escribe una respuesta…"
                            placeholderTextColor: Tema.tenue
                            color: Tema.texto
                            font.family: Tema.letra
                            font.pixelSize: 13
                            leftPadding: 10
                            background: Rectangle {
                                radius: Tema.r(10)
                                color: Tema.encima
                                border.color: replyField.activeFocus ? Tema.rosa : Tema.borde
                            }
                            onAccepted: pop.sendReply()
                            Keys.onEscapePressed: pop.replying = false
                        }
                        AbstractButton {
                            id: sendReply
                            width: 34; height: 34
                            enabled: replyField.text.trim() !== ""
                            opacity: enabled ? 1 : 0.5
                            onClicked: pop.sendReply()
                            background: Rectangle { radius: Tema.r(10); color: Tema.rosa }
                            contentItem: Item { Icono { anchors.centerIn: parent; width: 15; height: 15; nombre: "enviar"; color: Tema.sobreRosa } }
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
                                paused: hover.hovered || pop.replying
                            }
                        }
                    }
                }
            }
        }
    }
}
