import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin as KWin
import Apogeo

// Alt+Tab de Apogeo («6 · Alt+Tab de cristal»): una tarjeta de cristal en el centro con tus ventanas en vivo y en
// grande, una al lado de otra; la elegida, con el borde y el nombre en el color del piso. Con muchas, se hacen más
// pequeñas para caber (y si no caben, se desliza). Clic en una para ir; ✕ al pasar el ratón para cerrarla.
KWin.TabBoxSwitcher {
    id: tabBox

    Instantiator {
        active: tabBox.visible
        delegate: PlasmaCore.Dialog {
            location: PlasmaCore.Types.Floating
            visible: true
            flags: Qt.ToolTip | Qt.X11BypassWindowManagerHint
            x: tabBox.screenGeometry.x + (tabBox.screenGeometry.width - mainItem.width) / 2
            y: tabBox.screenGeometry.y + (tabBox.screenGeometry.height - mainItem.height) / 2

            mainItem: FocusScope {
                id: card
                focus: true
                readonly property real ratio: tabBox.screenGeometry.width / Math.max(1, tabBox.screenGeometry.height)
                readonly property real maxWidth: tabBox.screenGeometry.width * 0.86
                // Grandes (hasta 320 px de ancho), más pequeñas si hay muchas (no menos de 180)
                readonly property real thumbWidth: Math.max(180, Math.min(320, (maxWidth - 24) / Math.max(1, list.count) - 16))
                readonly property real thumbHeight: thumbWidth / ratio
                width: Math.min(maxWidth, list.count * (thumbWidth + 16) + 24)
                height: thumbHeight + 76

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: 12
                    orientation: ListView.Horizontal
                    spacing: 0
                    model: tabBox.model
                    currentIndex: tabBox.currentIndex
                    highlightMoveDuration: 160
                    highlightFollowsCurrentItem: true
                    keyNavigationWraps: true
                    clip: true
                    onCurrentIndexChanged: tabBox.currentIndex = currentIndex

                    highlight: Rectangle {
                        radius: Tema.r(18)
                        color: Qt.rgba(Tema.rosa.r, Tema.rosa.g, Tema.rosa.b, 0.16)
                        border.width: 2
                        border.color: Tema.rosa
                    }

                    delegate: MouseArea {
                        id: item
                        required property int index
                        required property var model
                        readonly property bool current: ListView.isCurrentItem
                        width: card.thumbWidth + 16
                        height: list.height
                        hoverEnabled: true
                        onClicked: tabBox.model.activate(index)

                        Item {
                            id: frame
                            x: 8; y: 8
                            width: card.thumbWidth
                            height: card.thumbHeight
                            scale: item.current ? 1 : 0.94
                            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            KWin.WindowThumbnail {
                                anchors.fill: parent
                                wId: item.model.windowId
                            }
                            Kirigami.Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.bottom
                                width: 40; height: 40
                                source: item.model.icon
                            }
                            Rectangle {
                                id: closeBtn
                                visible: item.model.closeable && item.containsMouse && typeof tabBox.model.close !== "undefined"
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 6
                                width: 28; height: 28; radius: 14
                                color: closeArea.containsMouse ? "#e5484d" : Qt.rgba(0, 0, 0, 0.55)
                                Icono { anchors.centerIn: parent; width: 12; height: 12; nombre: "cerrar"; color: "white" }
                                MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: tabBox.model.close(item.index) }
                            }
                        }
                        Texto {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: frame.y + frame.height + 24
                            width: parent.width - 20
                            horizontalAlignment: Text.AlignHCenter
                            text: item.model.caption
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            font.pixelSize: 13
                            font.weight: item.current ? Font.Bold : Font.Normal
                            color: item.current ? Tema.texto : Tema.apagado
                        }
                    }
                }

                Texto {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No hay ventanas abiertas"
                    color: Tema.apagado
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) list.decrementCurrentIndex();
                    else if (event.key === Qt.Key_Right) list.incrementCurrentIndex();
                    else return;
                    event.accepted = true;
                }
            }

            onSceneGraphError: () => {}   // (sin esto, un reinicio de la gráfica puede tirar KWin)
        }
    }
}
