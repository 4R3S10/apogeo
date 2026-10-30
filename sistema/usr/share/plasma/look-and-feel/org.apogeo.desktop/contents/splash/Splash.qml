import QtQuick
import QtQuick.Effects
import Apogeo

// Pantalla de carga al entrar en la sesión: la misma que al encender (el tema de Plymouth, con sus imágenes y medidas):
// el Núcleo de Órbita girando sobre el grafito y la barra fina del acento, que avanza con cada etapa del arranque de
// Plasma. Así no se nota el paso de una a otra.
Rectangle {
    id: root
    color: Tema.fondo
    property int stage

    // El brillo de detrás (el de Plymouth); con tu aspecto, del color de tu estilo
    Image { id: glow; anchors.fill: parent; source: "fondo.png"; fillMode: Image.Stretch; smooth: true; visible: !Tema.f.nombre }
    MultiEffect {
        anchors.fill: glow
        source: glow
        visible: !!Tema.f.nombre
        colorization: 0.9
        colorizationColor: Tema.wp[1]
    }
    // El aleteo, igual que en Plymouth: 24 fotogramas a unos 16 por segundo, subiendo y bajando un poco
    property int frame: 0
    Timer { interval: 62; running: true; repeat: true; onTriggered: root.frame = (root.frame + 1) % 24 }
    Image {
        id: logo
        x: (root.width - 150) / 2
        y: (root.height - 150) / 2 - 20 + Math.cos(2 * Math.PI * root.frame / 24) * 5
        width: 150; height: 150
        source: "aleteo-" + String(root.frame).padStart(2, "0") + ".png"
        cache: true
    }
    Rectangle {
        x: (root.width - 240) / 2
        y: root.height / 2 + 75 + 30
        width: 240; height: 4; radius: 2
        color: Tema.tinte(0.14)
        Rectangle {
            height: parent.height; radius: 2
            color: Tema.rosa
            width: parent.width * Math.min(1, Math.max(0.1, root.stage / 6))
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
    }
}
