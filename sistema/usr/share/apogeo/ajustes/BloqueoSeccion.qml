import QtQuick
import QtQuick.Controls
import Apogeo

// Ajustes → Bloqueo: «Tu símbolo» (D7). Lo dibujas tres veces igual y se guarda (pide tu contraseña); luego, en la
// pantalla de bloqueo, lo dibujas en cualquier parte y entras. Se puede probar aquí y quitar. La contraseña sigue
// sirviendo siempre (y es la que se pide al encender el equipo).
Seccion {
    id: sec
    property string palabras: "bloqueo desbloquear simbolo dibujo firma gesto contraseña pantalla"
    titulo: "Bloqueo"
    intro: "Desbloquea dibujando tu símbolo con el ratón, en cualquier parte de la pantalla. La contraseña sigue sirviendo siempre y es la que se pide al encender el equipo."

    property string modo: ""           // "" · crear · probar
    property var dibujos: []
    property string mensaje: ""
    property bool bien: false
    property bool guardando: false

    Connections {
        target: apogeo
        function onSymbolDone(what, ok, message) {
            sec.guardando = false;
            if (what === "probar") {
                sec.bien = ok;
                sec.mensaje = ok ? "¡Es tu símbolo! Así entrarás." : "No se parece a tu símbolo. Prueba otra vez.";
                pad.clear(ok ? "bien" : "mal");
                return;
            }
            sec.bien = ok;
            sec.mensaje = ok ? (what === "guardar" ? "Listo: ya puedes desbloquear con tu símbolo." : "Quitado: se desbloquea solo con la contraseña.") : message;
            if (ok || what === "guardar") { sec.modo = ""; sec.dibujos = []; }
        }
    }

    function empezar(m) { modo = m; dibujos = []; mensaje = ""; pad.clear(""); }
    function dibujado(pts) {
        if (modo === "probar") { apogeo.testSymbol(pts); return; }
        const d = dibujos.slice();
        d.push(pts);
        dibujos = d;
        if (d.length < 3) { mensaje = ""; pad.clear("bien"); return; }
        guardando = true;
        mensaje = "Guardando… (te pedirá tu contraseña)";
        apogeo.saveSymbol(d);
    }

    Fila {
        titulo: "Tu símbolo"
        detalle: apogeo.hasSymbol ? "Puesto: dibújalo en la pantalla de bloqueo para entrar" : "Sin símbolo: se desbloquea con la contraseña"
        linea: sec.modo === "" && sec.mensaje === ""
        Row {
            spacing: 8
            Boton {
                visible: sec.modo === "" && apogeo.hasSymbol
                text: "Probar"
                onClicked: sec.empezar("probar")
            }
            Boton {
                visible: sec.modo === ""
                tipo: apogeo.hasSymbol ? "normal" : "principal"
                text: apogeo.hasSymbol ? "Cambiar" : "Crear símbolo"
                onClicked: sec.empezar("crear")
            }
            Boton {
                visible: sec.modo === "" && apogeo.hasSymbol
                text: "Quitar"
                onClicked: { sec.guardando = true; apogeo.removeSymbol(); }
            }
            Boton {
                visible: sec.modo !== ""
                text: "Cancelar"
                onClicked: { sec.modo = ""; sec.mensaje = ""; }
            }
        }
    }

    // El papel para dibujar
    Item {
        visible: sec.modo !== ""
        width: parent.width
        height: 300
        Rectangle {
            id: paper
            width: parent.width
            height: 260
            radius: Tema.r(16)
            color: Tema.encima
            border.color: Tema.borde
            Canvas {
                id: pad
                anchors.fill: parent
                property var pts: []
                property string estado: ""      // bien · mal (el color del último trazo)
                function clear(e) { estado = e; fade.restart(); }
                Timer { id: fade; interval: 700; onTriggered: { pad.pts = []; pad.estado = ""; pad.requestPaint(); } }
                onPaint: {
                    const c = getContext("2d");
                    c.reset();
                    if (pts.length < 2) return;
                    const col = estado === "mal" ? Tema.error : Tema.acento;
                    c.lineCap = "round"; c.lineJoin = "round";
                    for (const [w, a] of [[14, 0.12], [7, 0.3], [3, 1]]) {
                        c.globalAlpha = a;
                        c.strokeStyle = col;
                        c.lineWidth = w;
                        c.beginPath();
                        c.moveTo(pts[0].x, pts[0].y);
                        for (let i = 1; i < pts.length; i++) c.lineTo(pts[i].x, pts[i].y);
                        c.stroke();
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !sec.guardando
                    cursorShape: Qt.CrossCursor
                    onPressed: mouse => { fade.stop(); pad.estado = ""; pad.pts = [{ x: mouse.x, y: mouse.y }]; pad.requestPaint(); }
                    onPositionChanged: mouse => {
                        const l = pad.pts[pad.pts.length - 1];
                        if (Math.hypot(mouse.x - l.x, mouse.y - l.y) < 3) return;
                        pad.pts.push({ x: mouse.x, y: mouse.y });
                        pad.requestPaint();
                    }
                    onReleased: if (pad.pts.length > 8) sec.dibujado(pad.pts.slice()); else pad.clear("");
                }
            }
            Texto {
                anchors.centerIn: parent
                visible: pad.pts.length === 0
                color: Tema.tenue
                horizontalAlignment: Text.AlignHCenter
                text: sec.modo === "probar" ? "Dibuja tu símbolo"
                    : ["Dibuja tu símbolo de un solo trazo", "Otra vez, igual", "Y una última vez"][Math.min(2, sec.dibujos.length)]
            }
            Row { // los tres dibujos
                visible: sec.modo === "crear"
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 14
                spacing: 6
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        width: 22; height: 6; radius: 3
                        color: index < sec.dibujos.length ? Tema.rosa : Tema.pulsado
                    }
                }
            }
        }
        Texto {
            y: paper.height + 10
            width: parent.width
            color: Tema.apagado
            font.pixelSize: 12
            text: "De un solo trazo, sin levantar el ratón. Mejor con alguna curva o esquina: una raya o un círculo se adivinan fácil."
        }
    }

    Texto {
        visible: sec.mensaje !== ""
        width: parent.width
        topPadding: 4
        color: sec.bien ? Tema.acento : Tema.error
        text: sec.mensaje
    }
}
