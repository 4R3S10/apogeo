import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Los botones de Ágape: «principal» (rosa con brillo), «plano» (sin fondo) o normal
AbstractButton {
    id: b
    property string tipo: "normal"
    property bool grande: tipo === "principal"
    property string icono: ""
    readonly property color tinta: tipo === "principal" ? Tema.sobreRosa : tipo === "plano" && !hovered ? Tema.apagado : Tema.texto
    implicitHeight: grande ? 42 : 34
    implicitWidth: fila.implicitWidth + (text ? (grande ? 44 : 28) : 18)
    opacity: enabled ? 1 : 0.45
    hoverEnabled: true
    background: Item {
        RectangularShadow {
            anchors.fill: parent
            visible: b.tipo === "principal" && b.enabled
            offset.y: 4; blur: 18; spread: -4
            radius: caja.radius
            color: Tema.rosa
            opacity: 0.8
        }
        Rectangle {
            id: caja
            anchors.fill: parent
            radius: b.grande ? 13 : 10
            color: b.tipo === "principal" ? (b.hovered ? Qt.lighter(Tema.rosa, 1.06) : Tema.rosa)
                 : b.tipo === "plano" ? (b.hovered ? Tema.encima : "transparent")
                 : (b.hovered || b.down ? Tema.pulsado : Tema.encima)
            border.width: b.tipo === "normal" ? 1 : 0
            border.color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.14)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    contentItem: Item {
        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 8
            Icono {
                visible: b.icono !== "" && b.tipo !== "principal"
                nombre: b.icono
                color: b.tinta
                anchors.verticalCenter: parent.verticalCenter
            }
            Texto {
                visible: b.text !== ""
                text: b.text
                color: b.tinta
                wrapMode: Text.NoWrap
                font.pixelSize: b.grande ? 14 : 13
                font.weight: b.tipo === "plano" ? Font.DemiBold : b.tipo === "principal" ? Font.ExtraBold : Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
            Icono { // en el principal la flecha va detrás, como en Ágape
                visible: b.icono !== "" && b.tipo === "principal"
                nombre: b.icono
                color: b.tinta
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
