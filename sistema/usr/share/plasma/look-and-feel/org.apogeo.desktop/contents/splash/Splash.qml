import QtQuick
import QtQuick.Effects
import Apogeo

// Pantalla de carga al entrar en la sesión: la misma que al encender (el tema de Plymouth, con sus imágenes y medidas):
// el Núcleo de Órbita sobre la Tierra en penumbra (o el grafito, si aún no se ha bajado), con las órbitas girando
// despacio y el punto respirando, y la barra fina del acento, que avanza con cada etapa del arranque de Plasma. Así no
// se nota el paso de una a otra.
Rectangle {
    id: root
    color: Tema.fondo
    property int stage

    // La Tierra de Plymouth (la baja apogeo-tierra; no va en el paquete), recortada para llenar la pantalla
    Image {
        id: tierra
        anchors.fill: parent
        source: "file:///usr/share/plymouth/themes/apogeo/tierra.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
    }
    // Si no está: el brillo de detrás de siempre; con tu aspecto, del color de tu estilo
    Image { id: glow; anchors.fill: parent; source: "fondo.png"; fillMode: Image.Stretch; smooth: true; visible: tierra.status !== Image.Ready && !Tema.f.nombre }
    MultiEffect {
        anchors.fill: glow
        source: glow
        visible: tierra.status !== Image.Ready && !!Tema.f.nombre
        colorization: 0.9
        colorizationColor: Tema.wp[1]
    }

    // El Núcleo, igual que en Plymouth: las órbitas dan una vuelta cada 4 s y el punto respira cada 5 s (sube un poco
    // y brilla)
    property real ola
    SequentialAnimation on ola {
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 2500; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 2500; easing.type: Easing.InOutSine }
    }
    Item {
        id: nucleo
        x: (root.width - 150) / 2
        y: (root.height - 150) / 2 - 20 - 4 * root.ola
        width: 150; height: 150
        Image { anchors.fill: parent; source: "disco.png"; smooth: true }
        Image { anchors.fill: parent; source: "halo.png"; smooth: true; opacity: 0.35 + 0.65 * root.ola }
        Image {
            anchors.fill: parent
            source: "orbitas.png"
            smooth: true
            RotationAnimator on rotation { from: 0; to: 360; duration: 4000; loops: Animation.Infinite }
        }
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
