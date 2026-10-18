import QtQuick
import QtQuick.Shapes
import "neuronas.js" as Dibujo

// Entrar con neuronas («E5», que no se pueda adivinar mirando). Tu código son 5 neuronas, que reconoces por su forma
// (sus dendritas). En cada toque las 20 neuronas cambian de sitio y de cables, y no tocas la tuya: tocas una de las que
// están conectadas a ella. Quien mira ve toques en neuronas distintas cada vez.
//
// Al acabar, se prueban las combinaciones posibles (las vecinas de cada neurona tocada) contra el verificador de
// /var/lib/apogeo/neuronas/USUARIO.json (sal y resumen; lo escribe apogeo-neuronas) y, si una cuadra, se emite
// «contrasena» con la contraseña de verdad de la cuenta (las letras de tus neuronas). Si ninguna cuadra, «fallo», sin
// gastar intentos de la cuenta.
//
// También dibuja una neurona suelta para elegirlas en Ajustes (forma(id) da su dibujo).
Item {
    id: red
    property string usuario: ""
    property var verificador: null          // { sal, resumen, n, vueltas }
    readonly property bool lista: !!verificador
    property int toques: 0
    readonly property int total: verificador ? verificador.n : 5
    property bool comprobando: false
    signal contrasena(string clave)
    signal fallo()

    readonly property int cuantas: 20
    readonly property string letras: Dibujo.letras   // la letra de cada neurona

    property var nodos: []        // [{ id, x, y }]
    property var cables: []       // [[i, j]] (posiciones en nodos)
    property var vecinas: []      // id → [ids conectadas]
    property var candidatas: []   // por toque: [ids posibles]
    property int destello: -1     // la neurona tocada (se ilumina un momento)

    function forma(id) { return Dibujo.forma(id) }

    // ---------- Cada toque: todo se recoloca y se recablea ----------
    function barajar() {
        const W = red.width, H = red.height, m = 50;
        const out = [];
        const ids = Array.from({ length: cuantas }, (_, i) => i);
        for (let i = ids.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [ids[i], ids[j]] = [ids[j], ids[i]]; }
        for (const id of ids) {
            let x = 0, y = 0;
            for (let t = 0; t < 200; t++) { // separadas entre sí
                x = m + Math.random() * (W - 2 * m); y = m + Math.random() * (H - 2 * m);
                if (out.every(o => Math.hypot(o.x - x, o.y - y) > 78)) break;
            }
            out.push({ id: id, x: x, y: y });
        }
        // Cada una, con sus 2 más cercanas (así tiene 2 o 3 vecinas y se resuelve rápido)
        const set = {}, cab = [], vec = {};
        out.forEach(o => vec[o.id] = []);
        out.forEach((o, i) => {
            const near = out.map((p, j) => [j, Math.hypot(p.x - o.x, p.y - o.y)]).filter(([j]) => j !== i).sort((a, b) => a[1] - b[1]).slice(0, 2);
            for (const [j] of near) {
                const k = Math.min(i, j) + "-" + Math.max(i, j);
                if (set[k]) continue;
                set[k] = true;
                cab.push([i, j]);
                vec[out[i].id].push(out[j].id);
                vec[out[j].id].push(out[i].id);
            }
        });
        nodos = out; cables = cab; vecinas = vec;
    }
    function empezar() { toques = 0; candidatas = []; barajar(); }
    onWidthChanged: if (width > 0 && height > 0) barajar()
    onHeightChanged: if (width > 0 && height > 0) barajar()

    function tocar(id) {
        if (comprobando || !lista) return;
        candidatas = candidatas.concat([vecinas[id].slice()]);
        destello = id;
        destelloTimer.restart();
        toques += 1;
        if (toques >= total) Qt.callLater(comprobar); else barajar();
    }
    Timer { id: destelloTimer; interval: 220; onTriggered: red.destello = -1 }

    // ---------- Comprobar: todas las combinaciones posibles contra el verificador ----------
    function resumen(seq) {
        const sal = verificador.sal;
        let h = Qt.md5(sal + ":" + seq);
        for (let i = 1; i < verificador.vueltas; i++) h = Qt.md5(h + sal);
        return h;
    }
    function comprobar() {
        comprobando = true;
        let hallada = null;
        const probar = (i, va) => {
            if (hallada) return;
            if (i === candidatas.length) {
                const seq = va.join("-");
                if (resumen(seq) === verificador.resumen) hallada = va.slice();
                return;
            }
            for (const c of candidatas[i]) if (va.indexOf(c) < 0) { va.push(c); probar(i + 1, va); va.pop(); }
        };
        probar(0, []);
        comprobando = false;
        if (hallada) red.contrasena(hallada.map(i => letras[i]).join(""));
        else { red.fallo(); empezar(); }
    }

    // ---------- El verificador de la cuenta ----------
    function cargar() {
        verificador = null;
        if (!usuario) return;
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            try {
                const v = JSON.parse(x.responseText);
                if (v && v.sal && v.resumen && v.n >= 3) { red.verificador = v; red.empezar(); }
            } catch (e) { red.verificador = null; }
        };
        x.open("GET", "file:///var/lib/apogeo/neuronas/" + encodeURIComponent(usuario) + ".json");
        x.send();
    }
    onUsuarioChanged: cargar()
    Component.onCompleted: cargar()

    // ---------- Dibujo ----------
    Canvas {
        id: lienzo
        anchors.fill: parent
        onPaint: {
            const g = getContext("2d");
            g.reset();
            g.lineWidth = 1.3;
            g.strokeStyle = "rgba(224,169,180,0.22)";
            for (const [i, j] of red.cables) {
                const a = red.nodos[i], b = red.nodos[j];
                if (!a || !b) continue;
                g.beginPath();
                g.moveTo(a.x, a.y);
                g.quadraticCurveTo((a.x + b.x) / 2 + 16, (a.y + b.y) / 2 - 16, b.x, b.y);
                g.stroke();
            }
        }
        Connections { target: red; function onCablesChanged() { lienzo.requestPaint() } }
    }
    Repeater {
        model: red.nodos
        delegate: Item {
            id: n
            required property var modelData
            readonly property bool encendida: red.destello === modelData.id
            x: modelData.x - 30; y: modelData.y - 30
            width: 60; height: 60
            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Shape {
                x: 30; y: 30
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: n.encendida ? "#ff8fc6" : zona.containsMouse ? "#f1e6ea" : "#bfe0a9b4"
                    strokeWidth: 1.7
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathSvg { path: red.forma(n.modelData.id) }
                }
            }
            Nucleo {
                anchors.centerIn: parent
                tamano: n.encendida ? 20 : 16
                tipo: Dibujo.nucleo(n.modelData.id)
                on: n.encendida
                tinta: n.encendida || zona.containsMouse ? "#ff8fc6" : "#e0a9b4"
            }
            MouseArea {
                id: zona
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: red.tocar(n.modelData.id)
            }
        }
    }
}
