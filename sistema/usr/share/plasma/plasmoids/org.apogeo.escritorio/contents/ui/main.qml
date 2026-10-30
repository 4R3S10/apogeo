import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.taskmanager as TaskManager
import Apogeo

// El escritorio de Apogeo: limpio, solo el fondo («nivel pro»: lo que había aquí, la hora, tus widgets, lo de estudiar
// y las notas, está ahora en el panel de widgets de la izquierda, Meta+A). Con el botón derecho sale el carrusel de
// fondos de este piso.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.VirtualDesktopInfo { id: desktops }
    readonly property int floorIndex: Math.max(0, desktops.desktopIds.indexOf(desktops.currentDesktop))
    readonly property string floor: ["jugar", "navegar", "estudiar"][floorIndex] || "navegar"

    Datos { id: datos }

    fullRepresentation: Item {
      // Se dibuja siempre del tamaño de la pantalla: Plasma estrecha el widget cuando un panel se queda fijo y así el
      // escritorio no da saltos
      Item {
        id: lienzo
        width: Screen.width
        height: Screen.height
        readonly property real abajo: 96
        // Botón derecho en el escritorio: el carrusel de fondos («F2»)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: carrusel.abrir()
        }

        // ======================= Carrusel de fondos (botón derecho) =======================
        // Tu biblioteca de Aura y los animados: elige y se ve al momento; «Cancelar» deja el de antes. «Aura…» la abre
        // (lo que elijas en ella va a este piso).
        Item {
            id: carrusel
            anchors.fill: parent
            visible: false
            property var lib: null
            property string antes: ""
            readonly property string actual: lib && lib.pisos ? lib.pisos[root.floor] : ""
            function abrir() {
                datos.pedir("Fondos", [], d => {
                    if (!d) return;
                    carrusel.lib = d;
                    carrusel.antes = d.pisos[root.floor];
                    carrusel.visible = true;
                });
            }
            function poner(valor) {
                datos.hacer("PonerFondo", [root.floor, valor]);
                const l = Object.assign({}, carrusel.lib); l.pisos = Object.assign({}, l.pisos); l.pisos[root.floor] = valor;
                carrusel.lib = l;
            }
            function cerrar(cancelar) {
                if (cancelar && carrusel.antes && carrusel.antes !== carrusel.actual) datos.hacer("PonerFondo", [root.floor, carrusel.antes]);
                carrusel.visible = false;
            }
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: carrusel.cerrar(false) }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 320
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(10 / 255, 6 / 255, 12 / 255, 0.85) }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 40
                width: aviso.implicitWidth + 36; height: 40; radius: Tema.r(14)
                color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.88)
                border.color: Tema.borde
                Texto {
                    id: aviso
                    anchors.centerIn: parent
                    text: "Vista previa en directo · " + ({ jugar: "Jugar", navegar: "Navegar", estudiar: "Estudiar" })[root.floor]
                    font.weight: Font.DemiBold
                }
            }
            Rectangle {
                id: tarjeta
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: lienzo.abajo + 10
                width: Math.min(parent.width - 80, filaFondos.implicitWidth + botones.width + 48)
                height: 150
                radius: Tema.r(24)
                color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.9)
                border.color: Tema.borde
                MouseArea { anchors.fill: parent } // (que pulsar dentro no cierre)
                Flickable {
                    x: 16; y: 16
                    width: parent.width - botones.width - 48
                    height: parent.height - 32
                    contentWidth: filaFondos.implicitWidth
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: filaFondos
                        spacing: 12
                        Repeater {
                            model: carrusel.lib ? carrusel.lib.aura.concat(carrusel.lib.animados) : []
                            delegate: Column {
                                id: mini
                                required property var modelData
                                readonly property bool on: modelData.valor === carrusel.actual
                                spacing: 6
                                Item {
                                    width: 160; height: 90
                                    Fondo { anchors.fill: parent; visible: mini.modelData.tipo === "animado"; tipo: mini.modelData.indice || 0; radio: 12 }
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: mini.modelData.tipo !== "animado"
                                        radius: Tema.r(12); color: Tema.encima; clip: true
                                        Image { anchors.fill: parent; source: mini.modelData.mini || ""; sourceSize: Qt.size(320, 180); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                        Icono { anchors.centerIn: parent; visible: !!mini.modelData.video && !mini.modelData.mini; nombre: "video"; color: Tema.rosa }
                                        Rectangle {
                                            visible: !!mini.modelData.video && !!mini.modelData.mini
                                            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 6
                                            width: 22; height: 22; radius: Tema.r(7); color: "#cc080a0f"
                                            Icono { anchors.centerIn: parent; nombre: "reproducir"; width: 11; height: 11; color: Tema.texto }
                                        }
                                    }
                                    Rectangle {
                                        anchors.fill: parent; anchors.margins: -4; radius: Tema.r(15); color: "transparent"; border.width: 2
                                        border.color: mini.on ? Tema.rosa : zonaMini.containsMouse ? Tema.borde : "transparent"
                                    }
                                    MouseArea { id: zonaMini; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: carrusel.poner(mini.modelData.valor) }
                                }
                                Texto { width: 160; text: mini.modelData.nombre; font.pixelSize: 12; elide: Text.ElideRight; wrapMode: Text.NoWrap; color: mini.on ? Tema.texto : Tema.apagado }
                            }
                        }
                    }
                }
                Column {
                    id: botones
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: 170
                    spacing: 8
                    Boton { width: parent.width; tipo: "principal"; text: "Listo"; onClicked: carrusel.cerrar(false) }
                    Boton {
                        width: parent.width
                        readonly property bool solo: carrusel.lib && carrusel.lib.cambiar ? carrusel.lib.cambiar[root.floor].activo : false
                        text: solo ? "Cambia solo · sí" : "Que cambie solo"
                        icono: "actualizar"
                        onClicked: {
                            datos.hacer("CambiarSolo", [root.floor, solo ? "false" : "true"]);
                            const l = Object.assign({}, carrusel.lib); l.cambiar = JSON.parse(JSON.stringify(l.cambiar)); l.cambiar[root.floor].activo = !solo;
                            carrusel.lib = l;
                        }
                    }
                    Row {
                        spacing: 8
                        Boton { width: 81; tipo: "plano"; text: "Aura…"; onClicked: { carrusel.cerrar(false); datos.hacer("Abrir", ["aura"]); } }
                        Boton { width: 81; tipo: "plano"; text: "Cancelar"; onClicked: carrusel.cerrar(true) }
                    }
                }
            }
        }
      }
    }
}
