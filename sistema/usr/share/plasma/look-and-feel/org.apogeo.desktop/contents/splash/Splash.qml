import QtQuick

// Pantalla de carga al entrar en la sesión: la misma que al encender (el tema de Plymouth «A2 · Brillo y barra», con sus
// imágenes y medidas): el diamante de Apogeo sobre el brillo berenjena y la barra fina rosa, que avanza con cada etapa
// del arranque de Plasma. Así no se nota el paso de una a otra.
Rectangle {
    id: root
    color: "#120d14"
    property int stage

    Image { anchors.fill: parent; source: "fondo.png"; fillMode: Image.Stretch; smooth: true }
    Image {
        id: logo
        x: (root.width - 150) / 2
        y: (root.height - 150) / 2 - 20
        width: 150; height: 150
        source: "logo.png"
    }
    Rectangle {
        x: (root.width - 240) / 2
        y: root.height / 2 + 75 + 30
        width: 240; height: 4; radius: 2
        color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.14)
        Rectangle {
            height: parent.height; radius: 2
            color: "#e0a9b4"
            width: parent.width * Math.min(1, Math.max(0.1, root.stage / 6))
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
}
