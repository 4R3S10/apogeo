import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import Apogeo

// Las capturas de Apogeo («C1 + C3»). La pantalla congelada y oscurecida; arriba, cómo: Zona, Ventana, Pantalla o
// ⏱ 3 s. Debajo de lo elegido, sus botones: Copiar (Intro), Guardar como…, Dibujar y Sacar texto. Dibujando: flecha,
// recuadro, a mano y tapar, cuatro colores y deshacer (Ctrl+Z); Intro la da por hecha. Al acabar, la miniatura abajo a
// la derecha unos segundos (Editar, la carpeta, o arrastrarla a un chat). Esc: un paso atrás (o salir).
// La parte de dentro es apogeo-captura («captura»).
QtObject {
    id: root

    property Window pantalla: Window {
        id: win
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        color: "black"
        title: "Captura de Apogeo"
        visibility: Window.Hidden

        property string modo: "zona"          // zona · ventana · pantalla
        readonly property var modos: ["zona", "ventana", "pantalla"]
        property rect sel: Qt.rect(0, 0, 0, 0)
        property bool elegida: false
        property bool arrastrando: false
        property int sobre: -1                // la ventana bajo el ratón (modo ventana)
        property bool dibujando: false
        property string leyendo: ""           // «» · «leyendo» · el texto sacado
        property bool hayTexto: false
        // La imagen en pantalla: la pantalla entera o, al editar un archivo, centrada y que quepa
        readonly property bool archivo: captura.editada !== ""
        readonly property real fit: archivo ? Math.min(1, (width * 0.86) / captura.ancho, (height * 0.8) / captura.alto) : 1 / captura.escala
        readonly property rect zona: archivo ? Qt.rect(Math.round((width - captura.ancho * fit) / 2), Math.round((height - captura.alto * fit) / 2),
                                                       captura.ancho * fit, captura.alto * fit)
                                             : Qt.rect(0, 0, captura.ancho * fit, captura.alto * fit)
        readonly property real px: 1 / fit    // píxeles de la imagen por punto de la pantalla
        // (al editar, lo elegido es la imagen entera: la sigue mientras la ventana coge su tamaño)
        onZonaChanged: if (archivo && elegida) sel = zona

        function empezar() {
            modo = "zona"; elegida = false; dibujando = false; leyendo = ""; hayTexto = false; sobre = -1;
            sel = Qt.rect(0, 0, 0, 0);
            lienzo.formas = [];
            visibility = Window.FullScreen;
            requestActivate();
            teclas.forceActiveFocus();
        }
        function editar() {
            empezar();
            sel = zona;
            elegida = true;
            dibujando = true;
        }
        function cerrar() {
            visibility = Window.Hidden;
            if (!mini.visible) captura.salir();
        }
        function atras() {
            if (leyendo !== "") { cerrar(); return; }
            if (dibujando && !archivo) { dibujando = false; lienzo.formas = []; return; }
            if (elegida && !archivo && modo !== "pantalla") { elegida = false; sel = Qt.rect(0, 0, 0, 0); return; }
            cerrar();
        }
        // Lo elegido, en píxeles de la imagen
        function enImagen() {
            return [(sel.x - zona.x) * px, (sel.y - zona.y) * px, sel.width * px, sel.height * px];
        }
        function elegir(m) {
            modo = m;
            elegida = false;
            sobre = m === "ventana" && raton.containsMouse ? ventanaEn(raton.mouseX, raton.mouseY) : -1;
            if (m === "pantalla") { sel = zona; elegida = true; }
            else sel = Qt.rect(0, 0, 0, 0);
        }
        function copiar() {
            // (Intro sin elegir nada: la ventana activa en «Ventana», si no la pantalla entera)
            if (!elegida && !arrastrando) {
                const a = modo === "ventana" ? captura.ventanas.findIndex(v => v.activa) : -1;
                sel = a >= 0 ? rectVentana(a) : zona;
                elegida = true;
            }
            if (!elegida) return;
            if (dibujando) { hecho(""); return; }
            const r = enImagen();
            visibility = Window.Hidden;
            captura.guardar(r[0], r[1], r[2], r[3], "");
        }
        function hecho(ruta) {
            // Con lo dibujado: se pinta lo elegido con sus dibujos al tamaño de verdad
            const destino = ruta || (archivo ? captura.editada : captura.ruta());
            lienzo.grabToImage(res => {
                visibility = Window.Hidden;
                if (res.saveToFile(destino)) captura.lista(destino);
                else captura.salir();
            }, Qt.size(Math.round(sel.width * px), Math.round(sel.height * px)));
        }
        // Guardar como…: el diálogo de KDE (la captura se esconde mientras; si lo cancelas, vuelve)
        function guardarComo() {
            const r = enImagen();
            visibility = Window.Hidden;
            captura.guardarComo(r[0], r[1], r[2], r[3]);
        }
        function sacarTexto() {
            const r = enImagen();
            leyendo = "leyendo";
            captura.sacarTexto(r[0], r[1], r[2], r[3]);
        }
        function tresSegundos() {
            visibility = Window.Hidden;
            espera.restart();
        }
        Timer { id: espera; interval: 3000; onTriggered: captura.otraVez() }
        Timer { id: otraFoto; interval: 150; onTriggered: captura.otraVez() }

        Connections {
            target: captura
            function onNueva() { win.empezar() }
            function onSinGuardar() { win.visibility = Window.FullScreen; win.requestActivate(); teclas.forceActiveFocus(); }
            function onPedida() {
                if (win.visibility !== Window.Hidden || espera.running) return;
                mini.visible = false;   // (que no salga en la foto)
                otraFoto.restart();
            }
            function onEditar() { win.editar() }
            function onHecha(ruta) { mini.ensenar(ruta) }
            function onTexto(t) {
                win.hayTexto = t.trim() !== "";
                win.leyendo = win.hayTexto ? t : "nada";
                if (win.hayTexto) captura.copiarTexto(t);
            }
        }
        Component.onCompleted: editarAlEmpezar ? editar() : empezar()

        // La pantalla congelada
        Image {
            x: win.zona.x; y: win.zona.y; width: win.zona.width; height: win.zona.height
            source: "image://captura/" + captura.serial
            cache: false
            smooth: true
        }
        // Oscuro alrededor de lo elegido
        Item {
            anchors.fill: parent
            readonly property color sombra: Qt.rgba(10 / 255, 7 / 255, 11 / 255, win.archivo ? 0.8 : 0.5)
            readonly property bool hay: win.sel.width > 0
            Rectangle { x: 0; y: 0; width: parent.width; height: parent.hay ? win.sel.y : parent.height; color: parent.sombra }
            Rectangle { visible: parent.hay; x: 0; y: win.sel.y; width: win.sel.x; height: win.sel.height; color: parent.sombra }
            Rectangle { visible: parent.hay; x: win.sel.x + win.sel.width; y: win.sel.y; width: parent.width - x; height: win.sel.height; color: parent.sombra }
            Rectangle { visible: parent.hay; x: 0; y: win.sel.y + win.sel.height; width: parent.width; height: parent.height - y; color: parent.sombra }
        }

        // ---------- Elegir ----------
        MouseArea {
            id: raton
            anchors.fill: parent
            enabled: !win.dibujando && win.leyendo === "" && !win.archivo
            hoverEnabled: true
            cursorShape: win.modo === "ventana" ? Qt.PointingHandCursor : Qt.CrossCursor
            property point desde
            onPressed: m => {
                if (win.modo !== "zona") return;
                desde = Qt.point(m.x, m.y);
                win.arrastrando = true;
                win.elegida = false;
                win.sel = Qt.rect(m.x, m.y, 0, 0);
            }
            onPositionChanged: m => {
                if (win.modo === "ventana") { win.sobre = win.ventanaEn(m.x, m.y); return; }
                if (!win.arrastrando) return;
                win.sel = Qt.rect(Math.min(desde.x, m.x), Math.min(desde.y, m.y), Math.abs(m.x - desde.x), Math.abs(m.y - desde.y));
            }
            onReleased: {
                if (!win.arrastrando) return;
                win.arrastrando = false;
                if (win.sel.width >= 6 && win.sel.height >= 6) win.elegida = true;
                else win.sel = Qt.rect(0, 0, 0, 0);
            }
            onClicked: m => {
                if (win.modo !== "ventana") return;
                const i = win.ventanaEn(m.x, m.y);
                if (i < 0) return;
                win.sel = win.rectVentana(i);
                win.elegida = true;
            }
        }
        function rectVentana(i) {
            const v = captura.ventanas[i];
            const x = Math.max(0, v.x * width), y = Math.max(0, v.y * height);
            return Qt.rect(x, y, Math.min(width, (v.x + v.w) * width) - x, Math.min(height, (v.y + v.h) * height) - y);
        }
        // La de delante bajo el ratón (la activa, si está ahí; si no, la última de la lista)
        function ventanaEn(mx, my) {
            const vs = captura.ventanas;
            const dentro = i => { const r = rectVentana(i); return mx >= r.x && mx < r.x + r.width && my >= r.y && my < r.y + r.height; };
            for (let i = 0; i < vs.length; i++) if (vs[i].activa && dentro(i)) return i;
            for (let i = vs.length - 1; i >= 0; i--) if (dentro(i)) return i;
            return -1;
        }
        // La ventana bajo el ratón
        Rectangle {
            visible: win.modo === "ventana" && !win.elegida && win.sobre >= 0
            readonly property rect r: win.sobre >= 0 ? win.rectVentana(win.sobre) : Qt.rect(0, 0, 0, 0)
            x: r.x; y: r.y; width: r.width; height: r.height
            color: Qt.rgba(Tema.rosa.r, Tema.rosa.g, Tema.rosa.b, 0.14)
            border.width: 2
            border.color: Tema.rosa
            radius: Tema.r(10)
        }
        // Lo elegido
        Rectangle {
            visible: win.sel.width > 0
            x: win.sel.x - 1; y: win.sel.y - 1; width: win.sel.width + 2; height: win.sel.height + 2
            color: "transparent"
            border.width: 2
            border.color: Tema.rosa
        }
        Texto {
            visible: win.sel.width > 0 && !win.archivo
            x: Math.max(4, win.sel.x)
            y: win.sel.y >= 24 ? win.sel.y - 22 : win.sel.y + 6
            text: Math.round(win.sel.width * win.px) + " × " + Math.round(win.sel.height * win.px)
            color: Tema.rosa
            font.pixelSize: 12
            font.weight: Font.Bold
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.35)
        }

        // ---------- Dibujar ----------
        Item {
            id: lienzo
            visible: win.dibujando
            x: win.sel.x; y: win.sel.y; width: win.sel.width; height: win.sel.height
            clip: true
            property var formas: []
            property var actual: null
            property string herramienta: "trazo"
            property color tinta: colores[0]
            readonly property var colores: [Tema.vivo, "#ff5a5a", "#ffd84a", "#ffffff"]
            // (la imagen entera, corrida para que se vea lo elegido: el lienzo la recorta; así lo pintado sale con la
            // imagen al tamaño de verdad)
            Image {
                x: win.zona.x - win.sel.x; y: win.zona.y - win.sel.y
                width: win.zona.width; height: win.zona.height
                source: win.dibujando ? "image://captura/" + captura.serial : ""
                cache: false
                smooth: true
            }
            Canvas {
                id: papel
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const todas = lienzo.actual ? lienzo.formas.concat([lienzo.actual]) : lienzo.formas;
                    for (const f of todas) {
                        ctx.lineCap = "round"; ctx.lineJoin = "round";
                        ctx.strokeStyle = f.c; ctx.fillStyle = f.c; ctx.lineWidth = 4;
                        if (f.t === "trazo") {
                            const a = Math.atan2(f.y2 - f.y1, f.x2 - f.x1), l = 16;
                            ctx.beginPath(); ctx.moveTo(f.x1, f.y1); ctx.lineTo(f.x2 - 6 * Math.cos(a), f.y2 - 6 * Math.sin(a)); ctx.stroke();
                            ctx.beginPath(); ctx.moveTo(f.x2, f.y2);
                            ctx.lineTo(f.x2 - l * Math.cos(a - 0.45), f.y2 - l * Math.sin(a - 0.45));
                            ctx.lineTo(f.x2 - l * Math.cos(a + 0.45), f.y2 - l * Math.sin(a + 0.45));
                            ctx.closePath(); ctx.fill();
                        } else if (f.t === "recuadro") {
                            ctx.beginPath(); ctx.roundedRect(Math.min(f.x1, f.x2), Math.min(f.y1, f.y2), Math.abs(f.x2 - f.x1), Math.abs(f.y2 - f.y1), 6, 6); ctx.stroke();
                        } else if (f.t === "tapar") {
                            ctx.fillStyle = "#0b0e14";
                            ctx.beginPath(); ctx.roundedRect(Math.min(f.x1, f.x2), Math.min(f.y1, f.y2), Math.abs(f.x2 - f.x1), Math.abs(f.y2 - f.y1), 4, 4); ctx.fill();
                        } else if (f.t === "lapiz" && f.p.length > 1) {
                            ctx.beginPath(); ctx.moveTo(f.p[0].x, f.p[0].y);
                            for (let i = 1; i < f.p.length; i++) ctx.lineTo(f.p[i].x, f.p[i].y);
                            ctx.stroke();
                        }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                onPressed: m => {
                    const h = lienzo.herramienta;
                    lienzo.actual = h === "lapiz" ? { t: h, c: lienzo.tinta.toString(), p: [Qt.point(m.x, m.y)] }
                                                  : { t: h, c: lienzo.tinta.toString(), x1: m.x, y1: m.y, x2: m.x, y2: m.y };
                }
                onPositionChanged: m => {
                    const f = lienzo.actual;
                    if (!f) return;
                    if (f.t === "lapiz") f.p.push(Qt.point(m.x, m.y));
                    else { f.x2 = m.x; f.y2 = m.y; }
                    papel.requestPaint();
                }
                onReleased: {
                    const f = lienzo.actual;
                    lienzo.actual = null;
                    if (f && (f.t === "lapiz" ? f.p.length > 1 : Math.abs(f.x2 - f.x1) + Math.abs(f.y2 - f.y1) > 6))
                        lienzo.formas = lienzo.formas.concat([f]);
                    papel.requestPaint();
                }
            }
            onFormasChanged: papel.requestPaint()
        }

        // ---------- Las teclas ----------
        Item {
            id: teclas
            focus: true
            Keys.onEscapePressed: win.atras()
            Keys.onReturnPressed: win.leyendo === "" ? win.copiar() : win.cerrar()
            Keys.onEnterPressed: win.leyendo === "" ? win.copiar() : win.cerrar()
            // ← → cambian entre Zona, Ventana y Pantalla
            Keys.onLeftPressed: if (!win.dibujando && !win.archivo && win.leyendo === "") win.elegir(win.modos[(win.modos.indexOf(win.modo) + 2) % 3])
            Keys.onRightPressed: if (!win.dibujando && !win.archivo && win.leyendo === "") win.elegir(win.modos[(win.modos.indexOf(win.modo) + 1) % 3])
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Z && (e.modifiers & Qt.ControlModifier) && win.dibujando) {
                    lienzo.formas = lienzo.formas.slice(0, -1);
                    e.accepted = true;
                }
            }
        }

        // ---------- Arriba: cómo ----------
        Pastilla {
            visible: !win.archivo && !win.arrastrando && !win.dibujando && win.leyendo === ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: 16
            Opcion { icono: "zona"; texto: "Zona"; on: win.modo === "zona"; onPulsada: win.elegir("zona") }
            Opcion { icono: "ventana"; texto: "Ventana"; on: win.modo === "ventana"; onPulsada: win.elegir("ventana") }
            Opcion { icono: "pantalla"; texto: "Pantalla"; on: win.modo === "pantalla"; onPulsada: win.elegir("pantalla") }
            Opcion { icono: "reloj"; texto: "3 s"; onPulsada: win.tresSegundos() }
            Separador {}
            Opcion { icono: "cerrar"; onPulsada: win.cerrar() }
        }
        Texto {
            visible: !win.archivo && !win.elegida && !win.arrastrando && win.leyendo === ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: 76
            text: win.modo === "ventana" ? "Pulsa una ventana (Intro: la de delante) · Esc para salir" : "Arrastra para elegir (Intro: toda la pantalla) · Esc para salir"
            color: Tema.texto
            opacity: 0.8
            font.pixelSize: 12
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.3)
        }

        // ---------- Debajo de lo elegido: qué hacer ----------
        Pastilla {
            id: acciones
            visible: win.elegida && !win.arrastrando && win.leyendo === ""
            // debajo; si no cabe, encima; si tampoco, dentro abajo
            x: Math.max(12, Math.min(win.width - width - 12, win.sel.x))
            y: win.sel.y + win.sel.height + 12 + height <= win.height - 12 ? win.sel.y + win.sel.height + 12
             : win.sel.y - 12 - height >= 12 ? win.sel.y - 12 - height
             : win.sel.y + win.sel.height - height - 12
            // Sin dibujar
            Opcion { visible: !win.dibujando; icono: "copia"; texto: "Copiar"; on: true; onPulsada: win.copiar() }
            Opcion { visible: !win.dibujando; icono: "descargar"; texto: "Guardar"; onPulsada: win.guardarComo() }
            Opcion { visible: !win.dibujando; icono: "lapiz"; texto: "Dibujar"; onPulsada: { win.dibujando = true; lienzo.formas = []; } }
            Opcion { visible: !win.dibujando; icono: "texto"; texto: "Sacar texto"; onPulsada: win.sacarTexto() }
            // Dibujando
            Opcion { visible: win.dibujando; icono: "trazo"; on: lienzo.herramienta === "trazo"; ayuda: "Flecha"; onPulsada: lienzo.herramienta = "trazo" }
            Opcion { visible: win.dibujando; icono: "recuadro"; on: lienzo.herramienta === "recuadro"; ayuda: "Recuadro"; onPulsada: lienzo.herramienta = "recuadro" }
            Opcion { visible: win.dibujando; icono: "lapiz"; on: lienzo.herramienta === "lapiz"; ayuda: "A mano"; onPulsada: lienzo.herramienta = "lapiz" }
            Opcion { visible: win.dibujando; icono: "tapar"; on: lienzo.herramienta === "tapar"; ayuda: "Tapar"; onPulsada: lienzo.herramienta = "tapar" }
            Separador { visible: win.dibujando }
            Repeater {
                model: win.dibujando ? lienzo.colores : []
                delegate: Item {
                    id: punto
                    required property color modelData
                    width: 30; height: 36
                    Rectangle {
                        anchors.centerIn: parent
                        width: 18; height: 18; radius: 9
                        color: punto.modelData
                        border.width: Qt.colorEqual(lienzo.tinta, punto.modelData) ? 3 : 0
                        border.color: Tema.texto
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: lienzo.tinta = punto.modelData }
                }
            }
            Separador { visible: win.dibujando }
            Opcion { visible: win.dibujando; icono: "deshacer"; ayuda: "Deshacer (Ctrl+Z)"; activa: lienzo.formas.length > 0; onPulsada: lienzo.formas = lienzo.formas.slice(0, -1) }
            Opcion { visible: win.dibujando; icono: "hecho"; texto: "Hecho"; on: true; onPulsada: win.hecho("") }
            Separador {}
            Opcion { icono: "cerrar"; ayuda: win.dibujando && !win.archivo ? "Dejar de dibujar" : "Salir"; onPulsada: win.atras() }
        }

        // ---------- El texto sacado ----------
        Rectangle {
            visible: win.leyendo !== ""
            anchors.centerIn: parent
            width: Math.min(560, parent.width - 40)
            height: Math.min(cuerpo.implicitHeight + 32, parent.height - 80)
            radius: Tema.r(20)
            color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.97)
            border.color: Tema.borde
            Column {
                id: cuerpo
                x: 18; y: 16
                width: parent.width - 36
                spacing: 12
                Row {
                    spacing: 10
                    // (solo mientras lee: su animación no para nunca)
                    Loader { active: win.leyendo === "leyendo"; visible: active; anchors.verticalCenter: parent.verticalCenter; sourceComponent: Girando {} }
                    Icono { visible: win.hayTexto; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; nombre: "hecho"; color: Tema.rosa }
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.leyendo === "leyendo" ? "Leyendo el texto…" : win.hayTexto ? "Texto copiado" : "No he encontrado texto"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                }
                QQC2.ScrollView {
                    visible: win.hayTexto
                    width: parent.width
                    height: Math.min(texto.implicitHeight, 320)
                    QQC2.TextArea {
                        id: texto
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        text: win.hayTexto ? win.leyendo : ""
                        color: Tema.texto
                        selectionColor: Tema.rosa
                        selectedTextColor: Tema.sobreRosa
                        font.family: Tema.letra
                        font.pixelSize: 14
                        background: Rectangle { radius: Tema.r(12); color: Tema.encima }
                        padding: 12
                    }
                }
                Row {
                    visible: win.leyendo !== "leyendo"
                    anchors.right: parent.right
                    spacing: 8
                    Boton { text: "Volver"; visible: !win.hayTexto; onClicked: { win.leyendo = ""; teclas.forceActiveFocus(); } }
                    Boton { text: "Listo"; tipo: "principal"; grande: false; onClicked: win.cerrar() }
                }
            }
        }
    }

    // ---------- La miniatura (abajo a la derecha: la pone ahí apogeo-ventanas) ----------
    property Window miniatura: Window {
        id: mini
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        color: "transparent"
        title: "Miniatura de la captura"
        visible: false
        width: tarjeta.width + 40
        height: tarjeta.height + 40
        property string ruta: ""
        readonly property url url: ruta ? "file://" + ruta.split("/").map(encodeURIComponent).join("/") : ""

        function ensenar(r) {
            ruta = r;
            foto.source = "";
            foto.source = url;
            visible = true;
            vida.restart();
            entra.restart();
        }
        function irse() {
            visible = false;
            if (win.visibility === Window.Hidden) captura.salir();
        }
        Timer { id: vida; interval: 7000; running: false; onTriggered: if (!encima.hovered && !arrastre.active) mini.irse(); else restart() }

        RectangularShadow { anchors.fill: tarjeta; radius: tarjeta.radius; offset.y: 8; blur: 24; spread: -4; color: Qt.rgba(0, 0, 0, 0.45) }
        Rectangle {
            id: tarjeta
            x: 20; y: 20
            width: 300
            height: col.height + 20
            radius: Tema.r(18)
            color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.97)
            border.color: Tema.borde
            HoverHandler { id: encima }
            NumberAnimation { id: entra; target: tarjeta; property: "x"; from: 60; to: 20; duration: 220; easing.type: Easing.OutCubic }
            Column {
                id: col
                x: 10; y: 10
                width: parent.width - 20
                spacing: 8
                // La foto (se puede arrastrar a un chat o a una carpeta)
                Rectangle {
                    id: marco
                    width: parent.width
                    height: Math.round(width * 9 / 16)
                    radius: Tema.r(12)
                    color: Tema.encima
                    clip: true
                    Image {
                        id: foto
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(560, 316)
                        asynchronous: true
                        cache: false
                    }
                    Item {
                        id: arrastrable
                        anchors.fill: parent
                        Drag.active: arrastre.active
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.mimeData: { "text/uri-list": mini.url.toString() }
                        DragHandler { id: arrastre; target: null }
                    }
                }
                Texto {
                    width: parent.width
                    text: mini.ruta.indexOf("/Capturas/") >= 0 ? "Copiada y guardada en Capturas" : "Copiada y guardada"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
                Row {
                    width: parent.width
                    spacing: 6
                    Boton { text: "Editar"; icono: "lapiz"; width: parent.width - 2 * 40 - 12; onClicked: { mini.visible = false; captura.editarArchivo(mini.ruta); } }
                    Boton { icono: "carpeta"; width: 40; onClicked: { captura.carpeta(mini.ruta); mini.irse(); } }
                    Boton { icono: "cerrar"; width: 40; onClicked: mini.irse() }
                }
            }
        }
    }

    // ---------- Piezas ----------
    component Pastilla: Rectangle {
        default property alias contenido: fila.data
        width: fila.implicitWidth + 12
        height: 48
        radius: Tema.r(16)
        color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.96)
        border.color: Tema.borde
        RectangularShadow { anchors.fill: parent; z: -1; radius: parent.radius; offset.y: 6; blur: 20; spread: -4; color: Qt.rgba(0, 0, 0, 0.4) }
        Row { id: fila; anchors.centerIn: parent; spacing: 2 }
    }
    component Opcion: Rectangle {
        id: o
        property string icono
        property string texto
        property string ayuda
        property bool on: false
        property bool activa: true
        signal pulsada()
        width: (texto ? etiqueta.implicitWidth + 44 : 36)
        height: 36
        radius: Tema.r(11)
        opacity: activa ? 1 : 0.4
        color: on ? Tema.rosa : toque.containsMouse ? Tema.pulsado : "transparent"
        Icono {
            x: o.texto ? 12 : (o.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            nombre: o.icono
            color: o.on ? Tema.sobreRosa : Tema.texto
        }
        Texto {
            id: etiqueta
            visible: !!o.texto
            x: 34
            anchors.verticalCenter: parent.verticalCenter
            text: o.texto
            font.pixelSize: 13
            font.weight: Font.Bold
            color: o.on ? Tema.sobreRosa : Tema.texto
        }
        MouseArea {
            id: toque
            anchors.fill: parent
            hoverEnabled: true
            enabled: o.activa
            cursorShape: Qt.PointingHandCursor
            onClicked: o.pulsada()
        }
        QQC2.ToolTip.visible: !!o.ayuda && toque.containsMouse
        QQC2.ToolTip.text: o.ayuda
        QQC2.ToolTip.delay: 400
    }
    component Separador: Rectangle { width: 1; height: 22; anchors.verticalCenter: parent ? parent.verticalCenter : undefined; color: Tema.linea }
}
