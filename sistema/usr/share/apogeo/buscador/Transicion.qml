import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import org.kde.layershell as LayerShell
import Apogeo

// La transición entre modos («El orbe se expande»): al cambiar de modo, el orbe del modo nuevo crece desde donde está
// el orbe de la isla (abajo en el centro) hasta llenar la pantalla con su color y su nombre; debajo, KWin cambia de
// escritorio; luego se abre desde el mismo sitio, como un iris, y deja ver el modo nuevo. Unos 800 ms en total.
// La pide apogeo-escritorios (el script de KWin que cambia de modo) por D-Bus: Transicion(modo) de apogeo-buscador.
// Va en la capa de encima de todo (también encima de la consola de Jugar) y no coge ni el ratón ni el teclado.
Window {
    id: t
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "Transición de modo"
    LayerShell.Window.scope: "apogeo-transicion"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.wantsToBeOnActiveScreen: true
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.activateOnShow: false
    width: Screen.width
    height: Screen.height
    visible: false

    // Lo que tarda cada parte (el script de KWin cambia de escritorio al acabar «tapar»: TAPAR en su main.js)
    readonly property int tapar: 260
    readonly property int quieto: 240      // (debajo, el efecto Deslizar de KWin)
    readonly property int abrir: 360

    property string modo: "navegar"
    readonly property var nombres: ({ jugar: "Jugar", navegar: "Navegar", estudiar: "Estudiar" })
    readonly property color c: Tema.acentoDe(modo)   // (el de su fondo de pantalla, con «Del fondo»)
    // El relleno: el grafito de Órbita teñido del modo; el borde que avanza, de su color
    readonly property color relleno: Qt.tint("#0b0e14", Qt.rgba(c.r, c.g, c.b, 0.2))
    readonly property color borde: Qt.rgba(c.r, c.g, c.b, 0.9)
    readonly property color nada: Qt.rgba(relleno.r, relleno.g, relleno.b, 0)

    property real crece: 0     // 0 → 1: el orbe llena la pantalla
    property real hueco: 0     // 0 → 1: el iris se abre y deja ver el modo nuevo
    // Desde el orbe de la isla (lo que dice ella: «x,y,…» en la pantalla) o, sin saberlo, abajo en el centro
    property point centro: Qt.point(width / 2, height - 37)
    readonly property real radio: Math.max(Math.hypot(centro.x, centro.y), Math.hypot(width - centro.x, centro.y),
                                           Math.hypot(centro.x, height - centro.y), Math.hypot(width - centro.x, height - centro.y)) + 4
    readonly property real filo: 22 / radio   // el ancho del borde de luz, en la escala del degradado
    // (un poco más allá del borde: al acabar, el borde de luz ya ha salido de las esquinas)
    readonly property real cr: crece * (1 + 3 * filo)
    readonly property real hr: hueco * (1 + 3 * filo)

    function empezar(m) {
        modo = m in nombres ? m : "navegar";
        const n = String(buscador.donde() || "").split(",").map(Number);
        const p = t.screen;
        const sx = p ? p.virtualX : 0, sy = p ? p.virtualY : 0;
        centro = n.length === 6 && n.every(v => !isNaN(v)) && n[1] - sy > height / 2 && n[1] - sy < height
                 ? Qt.point(n[0] - sx, n[1] - sy) : Qt.point(width / 2, height - 37);
        anim.stop();
        crece = 0;
        hueco = 0;
        visible = true;
        anim.start();
    }

    Connections {
        target: buscador
        function onTransicion(m) { t.empezar(m) }
    }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: t; property: "crece"; from: 0; to: 1; duration: t.tapar; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: t.quieto }
        NumberAnimation { target: t; property: "hueco"; from: 0; to: 1; duration: t.abrir; easing.type: Easing.OutCubic }
        ScriptAction { script: { t.visible = false; t.crece = 0; t.hueco = 0; } }
    }

    // El orbe que crece (un disco con su borde de luz)
    Shape {
        anchors.fill: parent
        visible: t.hueco === 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: t.centro.x; centerY: t.centro.y; centerRadius: t.radio
                focalX: t.centro.x; focalY: t.centro.y
                GradientStop { position: 0; color: t.relleno }
                GradientStop { position: Math.max(0, Math.min(1, t.cr - 2 * t.filo)); color: t.relleno }
                GradientStop { position: Math.max(0, Math.min(1, t.cr - t.filo * 0.6)); color: t.borde }
                GradientStop { position: Math.min(1, t.cr); color: t.nada }
                GradientStop { position: 1; color: t.nada }
            }
            startX: 0; startY: 0
            PathLine { x: t.width; y: 0 }
            PathLine { x: t.width; y: t.height }
            PathLine { x: 0; y: t.height }
            PathLine { x: 0; y: 0 }
        }
    }
    // El iris que se abre (el mismo color, con el hueco creciendo desde el orbe)
    Shape {
        anchors.fill: parent
        visible: t.hueco > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: t.centro.x; centerY: t.centro.y; centerRadius: t.radio
                focalX: t.centro.x; focalY: t.centro.y
                GradientStop { position: 0; color: t.nada }
                GradientStop { position: Math.min(1, t.hr); color: t.nada }
                GradientStop { position: Math.min(1, t.hr + t.filo * 0.6); color: t.borde }
                GradientStop { position: Math.min(1, t.hr + 2 * t.filo); color: t.relleno }
                GradientStop { position: 1; color: t.relleno }
            }
            startX: 0; startY: 0
            PathLine { x: t.width; y: 0 }
            PathLine { x: t.width; y: t.height }
            PathLine { x: 0; y: t.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // El modo nuevo, en el centro mientras la pantalla está tapada
    Column {
        anchors.centerIn: parent
        spacing: 14
        opacity: Math.max(0, Math.min(1, (t.crece - 0.55) / 0.35)) * (1 - Math.min(1, t.hueco * 2.2))
        scale: 0.94 + 0.06 * t.crece + 0.04 * t.hueco
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64; height: 64; radius: 32
            color: "transparent"
            border.width: 2; border.color: t.c
            Icono { anchors.centerIn: parent; width: 26; height: 26; nombre: t.modo; color: t.c }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (t.nombres[t.modo] || "").toUpperCase()
            color: "#eef0f4"
            font { family: Tema.letra; pixelSize: 34; weight: Font.DemiBold; letterSpacing: 10 }
        }
    }
}
