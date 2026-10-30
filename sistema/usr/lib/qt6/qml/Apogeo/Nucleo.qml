import QtQuick

// El símbolo de Órbita («N1 · Una órbita por modo»): un núcleo sólido y tres órbitas abiertas, cada una del color de su
// modo (Navegar cian arriba, Estudiar ámbar, Jugar violeta). Se dibuja vectorial (nítido a cualquier tamaño). «disco»
// pinta el fondo grafito; «giro» mueve las órbitas; «pulso» late muy despacio; «trazo» (0-1) las dibuja poco a poco.
Item {
    id: n
    property color navegar: "#45d6ff"
    property color estudiar: "#ffb35c"
    property color jugar: "#b79cff"
    property color tinta: "#e9edf5"
    property bool disco: true
    property real giro: 0
    property real pulso: 0
    property real grosor: 1
    property real trazo: 1

    implicitWidth: 64
    implicitHeight: 64

    Canvas {
        id: lienzo
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const g = getContext("2d");
            const s = Math.min(width, height);
            const cx = width / 2, cy = height / 2;
            const R = s * 0.275;
            g.reset();
            g.translate(cx, cy);
            if (n.disco) {
                g.beginPath();
                g.arc(0, 0, s * 0.48, 0, 2 * Math.PI);
                g.fillStyle = "#0b0e14";
                g.fill();
                g.lineWidth = Math.max(1, s * 0.015);
                g.strokeStyle = "#1c2430";
                g.stroke();
            }
            const span = 82 * Math.PI / 180;
            const arcs = [[0.0, n.navegar, 1.0], [2 * Math.PI / 3, n.estudiar, 1.0], [4 * Math.PI / 3, n.jugar, 1.0]];
            g.lineWidth = Math.max(1.5, s * 0.026 * n.grosor);
            g.lineCap = "round";
            for (const [rot, color, alpha] of arcs) {
                const a0 = rot + n.giro - Math.PI / 2 - span / 2;
                const a1 = a0 + span * n.trazo;
                if (n.trazo <= 0) continue;
                g.globalAlpha = alpha;
                g.strokeStyle = color;
                g.beginPath();
                g.arc(0, 0, R, a0, a1);
                g.stroke();
                g.beginPath();
                g.arc(Math.cos(a1) * R, Math.sin(a1) * R, s * 0.029, 0, 2 * Math.PI);
                g.fillStyle = color;
                g.fill();
            }
            g.globalAlpha = 1;
            const r = s * (0.074 + n.pulso * 0.006);
            g.beginPath();
            g.arc(0, 0, r + s * 0.056, 0, 2 * Math.PI);
            g.fillStyle = n.tinta;
            g.globalAlpha = 0.07;
            g.fill();
            g.globalAlpha = 1;
            g.beginPath();
            g.arc(0, 0, r, 0, 2 * Math.PI);
            g.fillStyle = n.tinta;
            g.fill();
        }
    }
    onNavegarChanged: lienzo.requestPaint()
    onEstudiarChanged: lienzo.requestPaint()
    onJugarChanged: lienzo.requestPaint()
    onTrazoChanged: lienzo.requestPaint()
    onTintaChanged: lienzo.requestPaint()
    onDiscoChanged: lienzo.requestPaint()
    onGiroChanged: lienzo.requestPaint()
    onPulsoChanged: lienzo.requestPaint()
    onWidthChanged: lienzo.requestPaint()
    onHeightChanged: lienzo.requestPaint()
}
