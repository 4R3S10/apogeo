import QtQuick
import QtQuick.Window
import org.kde.layershell as LayerShell
import Apogeo

// El escritorio vivo («como en COSMIC»): un reloj grande de bloques (como tty-clock) con la fecha debajo y, mientras
// suena algo, un visualizador de audio de barras de cuadraditos (como cava, que es quien lo escucha). Va en la capa de
// justo encima del fondo de pantalla (layer-shell «bottom»): tus ventanas lo tapan y no coge ni el ratón ni el teclado,
// así que el botón derecho del escritorio y escribir siguen yendo al escritorio. En Jugar no sale (es la consola).
// «musica» es apogeo-musica: barras (de 0 a 1) y si suena algo.
Window {
    id: vivo
    flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "Escritorio de Apogeo"
    LayerShell.Window.scope: "apogeo-escritorio-vivo"
    LayerShell.Window.layer: LayerShell.Window.LayerBottom
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom
                               | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityNone
    LayerShell.Window.activateOnShow: false
    width: Screen.width
    height: Screen.height
    visible: musica.escritorioVivo && Tema.modo !== "jugar"

    // Los bloques: un poco más anchos que altos, como los caracteres de una terminal
    readonly property real k: Math.max(0.7, Math.min(1.6, height / 1080))
    readonly property real bw: Math.round(26 * k)    // ancho de un bloque
    readonly property real bh: Math.round(22 * k)    // alto
    readonly property real gap: Math.max(2, Math.round(3 * k))
    readonly property color tinta: Qt.rgba(Tema.texto.r, Tema.texto.g, Tema.texto.b, 0.88)

    // Las cifras en 5 filas de 3 bloques (como tty-clock)
    readonly property var cifras: ({
        "0": "111101101101111", "1": "001001001001001", "2": "111001111100111", "3": "111001111001111",
        "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001",
        "8": "111101111101111", "9": "111101111001111", ":": "010"
    })
    property date ahora: new Date()
    Timer { interval: 1000; repeat: true; running: vivo.visible; triggeredOnStart: true; onTriggered: vivo.ahora = new Date() }
    readonly property string hora: Qt.formatTime(ahora, "HH:mm:ss")

    component Cifra: Grid {
        property string c: "0"
        readonly property string mapa: vivo.cifras[c] || ""
        readonly property bool puntos: c === ":"
        columns: puntos ? 1 : 3
        rows: 5
        columnSpacing: vivo.gap; rowSpacing: vivo.gap
        Repeater {
            model: parent.puntos ? [0, 1, 0, 1, 0] : parent.mapa.split("").map(Number)
            delegate: Rectangle {
                required property int modelData
                width: vivo.bw; height: vivo.bh
                radius: Math.round(2 * vivo.k)
                color: modelData ? vivo.tinta : "transparent"
            }
        }
    }

    Column {
        id: bloque
        // En el centro de la pantalla (un poco por encima: abajo está el orbe)
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2 - parent.height * 0.04)
        spacing: Math.round(14 * vivo.k)

        // El reloj
        Row {
            id: reloj
            spacing: Math.round(vivo.bw * 0.9)
            Repeater {
                model: vivo.hora.split("")
                delegate: Cifra { required property string modelData; c: modelData }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(vivo.ahora, "yyyy-MM-dd")
            color: Qt.rgba(Tema.texto.r, Tema.texto.g, Tema.texto.b, 0.62)
            font { family: Tema.mono; pixelSize: Math.round(15 * vivo.k); letterSpacing: 2 }
        }

        // El visualizador (solo mientras suena algo): barras de cuadraditos, del color del modo arriba
        Item { width: 1; height: Math.round(26 * vivo.k) }
        Canvas {
            id: barras
            anchors.horizontalCenter: parent.horizontalCenter
            width: reloj.width   // (tan ancho como el reloj)
            height: Math.round(170 * vivo.k)
            opacity: musica.suena ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 400 } }
            readonly property var datos: musica.barras
            onDatosChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const n = datos.length;
                if (!n) return;
                const cell = Math.max(4, Math.round(8 * vivo.k)), sep = Math.max(2, Math.round(2 * vivo.k));
                const filas = Math.floor(height / (cell + sep));
                const ancho = (width - (n - 1) * sep) / n;
                const t = vivo.tinta, a = Tema.acento;
                for (let i = 0; i < n; i++) {
                    const alto = Math.round(Math.max(0, Math.min(1, datos[i])) * filas);
                    for (let f = 0; f < alto; f++) {
                        // (los cuadraditos de arriba de cada barra, del color del modo)
                        g.fillStyle = f >= filas * 0.72 ? Qt.rgba(a.r, a.g, a.b, 0.95) : t;
                        g.fillRect(i * (ancho + sep), height - (f + 1) * (cell + sep) + sep, ancho, cell);
                    }
                }
            }
        }
    }
}
