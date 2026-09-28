import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin

// Ventanas sin barra de título (V2): a todas las ventanas normales se les quita el borde. Al acercar el ratón a la
// esquina de arriba a la derecha de la ventana activa aparece una pastilla con mover, minimizar, maximizar y cerrar.
Item {
    id: root
    property var target: null

    function bare(w) {
        if (w && w.normalWindow && !w.noBorder) w.noBorder = true;
    }
    Component.onCompleted: Workspace.windows.forEach(bare)
    Connections {
        target: Workspace
        function onWindowAdded(w) { root.bare(w) }
    }

    // Dónde está el ratón: si está en la esquina de la ventana activa (o sobre la pastilla), se enseña
    Timer {
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            const w = Workspace.activeWindow;
            const p = Workspace.cursorPos;
            const onPill = pill.visible && p.x >= pill.x && p.x < pill.x + pill.width && p.y >= pill.y && p.y < pill.y + pill.height;
            if (onPill) return;
            if (!w || !w.normalWindow || w.fullScreen || w.minimized) { pill.visible = false; return; }
            const g = w.frameGeometry;
            const hot = p.x >= g.x + g.width - 190 && p.x < g.x + g.width && p.y >= g.y && p.y < g.y + 56;
            if (hot) {
                root.target = w;
                pill.x = g.x + g.width - pill.width - 10;
                pill.y = g.y + 8;
                pill.visible = true;
            } else {
                pill.visible = false;
            }
        }
    }

    PlasmaCore.Window {
        id: pill
        visible: false
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.BypassWindowManagerHint
        color: "transparent"
        width: row.implicitWidth + 12
        height: 38

        mainItem: Rectangle {
            radius: 13
            color: Qt.rgba(36 / 255, 26 / 255, 40 / 255, 0.97)
            border.color: Qt.rgba(1, 1, 1, 0.08)

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: [
                        { label: "✥", hot: false, run: () => Workspace.slotWindowMove() },
                        { label: "–", hot: false, run: () => { root.target.minimized = true } },
                        { label: "▢", hot: false, run: () => Workspace.slotWindowMaximize() },
                        { label: "✕", hot: true, run: () => root.target.closeWindow() }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 28
                        radius: 9
                        color: area.containsMouse ? (modelData.hot ? "#e5484d" : Qt.rgba(1, 1, 1, 0.12)) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: "#f1e6ea"
                            font.pixelSize: 15
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.target) Workspace.activeWindow = root.target;
                                parent.modelData.run();
                                pill.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
