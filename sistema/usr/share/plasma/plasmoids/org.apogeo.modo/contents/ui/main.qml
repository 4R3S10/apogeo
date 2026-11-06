// Esquina izquierda de la barra superior: acceso rápido a escritorios
// Muestra los escritorios del mismo modo cuando hay varios (más de uno)
// Iconos para cambiar de escritorio

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import Apogeo

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    // Obtener información de escritorios
    TaskManager.VirtualDesktopInfo { id: desktops }
    TaskManager.ActivityInfo { id: activities }

    readonly property string floor: {
        const n = String(desktops.desktopNames[desktops.desktopIds.indexOf(desktops.currentDesktop)] || "").split(" ")[0].toLowerCase();
        return ["jugar", "navegar", "estudiar"].indexOf(n) >= 0 ? n : "navegar";
    }

    // Cuántos escritorios hay en este modo
    readonly property int escritoriosEnModo: desktops.desktopNames.length

    // El nombre del modo actual
    readonly property string modoActual: {
        const n = String(desktops.desktopNames[desktops.desktopIds.indexOf(desktops.currentDesktop)] || "").split(" ")[0];
        switch(n) {
            case "Jugar": return "jugar";
            case "Navegar": return "navegar";
            case "Estudiar": return "estudiar";
            default: return "navegar";
        }
    }

    fullRepresentation: Item {
        id: panel
        Layout.minimumWidth: root.escritoriosEnModo > 1 ? u(80) : 8
        Layout.preferredWidth: root.escritoriosEnModo > 1 ? u(100) : 8
        Layout.minimumHeight: u(40)
        implicitHeight: u(40)

        // Mostrar acceso a escritorios solo si hay más de uno en el mismo modo
        property bool mostrar: root.escritoriosEnModo > 1

        // Animación de entrada
        Behavior on panel.opacity {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on panel.scale {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        // El panel de acceso a escritorios
        Item {
            visible: panel.mostrar
            opacity: panel.opacity
            scale: panel.scale

            // Fondo del panel
            Rectangle {
                anchors.fill: parent
                radius: u(8)
                color: Tema.cromo
                border.color: Tema.borde
                border.width: 1

                // Título del modo
                Texto {
                    text: win.modoNombre
                    font.pixelSize: u(14)
                    font.weight: Font.ExtraBold
                    color: Tema.texto
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: [u(8), u(6), 0, 0]
                }

                // Lista de escritorios
                Flow {
                    id: flow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: u(8)
                    spacing: u(6)

                    // Scroll para escritorios múltiples
                    ScrollView {
                        width: parent.width
                        contentWidth: flow.width
                        contentHeight: flow.height

                        // Cada escritorio
                        Repeater {
                            model: desktops.desktopNames
                            delegate: MouseArea {
                                id: escritorioArea
                                property int index: desktops.desktopIds.indexOf(desktops.currentDesktop)
                                width: u(50)
                                height: u(50)
                                radius: u(25)
                                anchors.verticalCenter: parent.verticalCenter

                                // Calcular posición
                                property int pos: {
                                    var i = 0;
                                    for (var j = 0; j < desktops.desktopIds.length; j++) {
                                        if (desktops.desktopIds[j] === desktops.currentDesktop) return i;
                                        i++;
                                        if (desktops.desktopNames[j].split(" ")[0].toLowerCase() === root.modoActual) i++;
                                    }
                                    return i;
                                }

                                // Colores según el escritorio
                                readonly property color color: {
                                    const n = String(desktops.desktopNames[index]).split(" ")[0];
                                    return ["jugar", "navegar", "estudiar"].indexOf(n) >= 0
                                        ? Tema.acentoDe(n)
                                        : Tema.cromo;
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: u(25)
                                    color: escritorioArea.eq(0) ? color : "transparent"
                                    border.color: escritorioArea.eq(0) ? color : Tema.linea
                                    border.width: escritorioArea.eq(0) ? 2 : 1

                                    // Icono del escritorio
                                    Icono {
                                        anchors.centerIn: parent
                                        width: u(24)
                                        height: u(24)
                                        nombre: escritorioArea.eq(0) ? "laptop" : "desktop"
                                        color: escritorioArea.eq(0) ? "white" : Tema.texto
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: escritorioArea.pressed = true
                                    onExited: escritorioArea.pressed = false

                                    onClicked: {
                                        if (!escritorioArea.eq(0)) {
                                            // Cambiar de escritorio
                                            var targetIndex = desktops.desktopIds.indexOf(escritorioArea.id);
                                            if (targetIndex < 0) return;
                                            DBus.SessionBus.call(
                                                "org.kde.KWin", "/VirtualDesktop",
                                                "org.kde.KWin.VirtualDesktop",
                                                "goToDesktop", targetIndex, 0, "q"
                                            );
                                        } else {
                                            // Ir al escritorio activo
                                            tasks.requestActivate(index);
                                        }
                                    }

                                    function eq(i) { return i === desktops.desktopIds.indexOf(desktops.currentDesktop); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
