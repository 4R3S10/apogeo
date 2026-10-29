import QtQuick
import QtQuick.Window
import QtQuick.Effects

// «Cristal con tu fondo» (los paneles de los lados y la isla): el fondo de tu piso desenfocado y alineado con la
// pantalla, como si se viera a través; oscurecido con el color de fondo y, arriba, un brillo del color del piso.
// El desenfoque no gasta: apogeo-pisos hace una vez una copia pequeña ya desenfocada (Datos → Cristal). Con un fondo
// animado de Apogeo, su sombreador quieto. Solo para los widgets de Plasma (pide el fondo por Datos).
Item {
    id: c
    property real radio: Tema.r(18)
    property bool brillo: true      // el brillo del color del piso arriba
    property real oscuro: 0.52      // cuánto se oscurece (0 nada, 1 del todo)
    property bool activo: true      // cerrado (un panel escondido), no pide ni mira nada

    property string imagen: ""
    property int animado: -1
    property point en: Qt.point(0, 0)   // dónde está en la pantalla

    Datos { id: datos }
    function pedir() {
        if (!activo || Tema.piso === "") return;
        datos.pedir("Cristal", [Tema.piso], d => { if (d) { c.imagen = d.imagen || ""; c.animado = d.animado; } });
    }
    function alinear() {
        const g = c.mapToGlobal(0, 0);
        en = Qt.point(g.x - Screen.virtualX, g.y - Screen.virtualY);
    }
    onActivoChanged: { pedir(); alinear() }
    Connections { target: Tema; function onPisoChanged() { c.pedir() } }
    Component.onCompleted: { pedir(); alinear() }
    onWidthChanged: alinear()
    onHeightChanged: alinear()
    // (el panel entra deslizándose y el fondo puede cambiar: se mira de vez en cuando, solo con él a la vista)
    Timer { interval: 1500; repeat: true; running: c.activo; onTriggered: c.alinear() }
    Timer { interval: 20000; repeat: true; running: c.activo; onTriggered: c.pedir() }

    Item {
        id: dentro
        anchors.fill: parent
        visible: false
        layer.enabled: true
        clip: true
        Rectangle {   // sin fondo todavía: los colores del piso
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Tema.wp[1] }
                GradientStop { position: 1; color: Tema.wp[0] }
            }
        }
        Fondo {
            visible: c.imagen === "" && c.animado >= 0
            x: -c.en.x; y: -c.en.y
            width: Screen.width; height: Screen.height
            tipo: Math.max(0, c.animado)
        }
        Image {
            visible: c.imagen !== ""
            x: -c.en.x; y: -c.en.y
            width: Screen.width; height: Screen.height
            source: c.imagen
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
        Rectangle { anchors.fill: parent; color: Tema.fondo; opacity: c.oscuro }
        Rectangle {   // el brillo de arriba
            visible: c.brillo
            width: parent.width; height: Math.min(parent.height * 0.4, 320)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(Tema.rosa.r, Tema.rosa.g, Tema.rosa.b, 0.30) }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
    Rectangle { id: forma; anchors.fill: parent; radius: c.radio; visible: false; layer.enabled: true }
    MultiEffect { anchors.fill: parent; source: dentro; maskEnabled: true; maskSource: forma }
    Rectangle {   // el borde fino, más claro arriba
        anchors.fill: parent
        radius: c.radio
        color: "transparent"
        border.width: 1
        border.color: Tema.tinte(0.10)
    }
}
