import QtQuick

// Un aviso en amarillo suave (como .ob-warn de Ágape); no se ve si no tiene texto
Rectangle {
    property alias text: t.text
    implicitWidth: 470
    implicitHeight: t.implicitHeight + 20
    radius: 12
    color: Tema.aviso
    visible: t.text !== ""
    Texto {
        id: t
        anchors.fill: parent
        anchors.margins: 10
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
