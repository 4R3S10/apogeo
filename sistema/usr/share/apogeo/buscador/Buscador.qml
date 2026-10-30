import QtQuick
import QtQuick.Shapes
import org.kde.milou as Milou
import org.kde.kirigami as Kirigami
import Apogeo

// La Órbita abierta («G3 · Constelación»): al pulsar el orbe o Meta. En el centro, unida al orbe por un haz de luz, la
// cubierta con tus apps fijadas del modo y el buscador; alrededor, unidos al orbe por hilos de luz, los satélites con lo
// que pasa ahora: lo que suena (con su portada y sus colores), los avisos, tu nota (con sus casillas), lo que queda hoy
// en tu calendario y, en Estudiar, tu estudio. Un clic en la nota, el calendario o el estudio los abre enteros (Esc
// vuelve). Las apps se fijan desde el buscador (la chincheta de cada una, o Ctrl+Intro) y se quitan con su chincheta o
// el clic derecho. Al escribir, encima del campo y en una sola lista: tus apps, la cuenta (Intro la copia), las órdenes
// (los modos, apagar, reiniciar, bloquear, ajustes…), lo que encuentran los buscadores de KDE (Milou), tus archivos por
// su nombre y al final «Buscar en la web con Ágape». Flechas elegir · Intro abrir (Mayús+Intro: la carpeta de un
// archivo) · Esc, un clic fuera o el orbe cerrar; las bolitas de los lados del orbe cambian de modo. La parte de dentro
// es apogeo-buscador («buscador»).
Window {
    id: win
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Órbita"
    visible: false

    // Las medidas van pensadas para 1280 × 720 y crecen con la pantalla
    readonly property real k: Math.min(1.4, Math.max(1, Math.min(width / 1280, height / 720)))
    function u(n) { return Math.round(n * k) }
    readonly property real margen: Math.max(u(40), width * 0.094)
    readonly property real techo: Math.max(u(56), height * 0.1)

    property string modo: "navegar"
    readonly property var colorModo: ({ jugar: "#b79cff", navegar: "#45d6ff", estudiar: "#ffb35c" })
    readonly property var nombreModo: ({ jugar: "Jugar", navegar: "Navegar", estudiar: "Estudiar" })
    readonly property string query: field.text.trim()
    property string detalle: ""                    // «», «agenda», «notas» o «estudios»: un satélite abierto entero
    readonly property bool verSatelites: query === "" && detalle === ""
    property real llegada: 0                       // 0 → 1 al abrir: todo sale del orbe
    property real encendido: 0                     // el orbe: 0 como el de la isla, 1 encendido
    property int sel: 0
    property bool pista: false                     // tras «+»: cómo se fija una app
    property var fijadas: []
    property var insp: ({ musica: {}, avisos: [], bajando: [], proximo: [] })
    property var avisos: []
    property var notas: []
    property var hoy: []
    property var estudio: ({})
    property real ahora: Date.now()

    // Sin escribir: tus fijadas y «+»
    readonly property var flat: fijadas.concat([{ id: "", nombre: "Fijar", icono: "" }])
    // Al escribir, en orden: tus apps, la cuenta (0 o 1), las órdenes, lo de KDE, tus archivos y la web
    readonly property var appsHalladas: query === "" ? [] : buscador.buscarApps(query)
    readonly property var nombresHallados: appsHalladas.map(a => a.nombre)
    readonly property var answer: query === "" ? ({}) : buscador.answer(query)
    readonly property int answerAt: appsHalladas.length
    readonly property int base: answerAt + (answer.valor ? 1 : 0)
    readonly property var ordenes: query === "" ? [] : buscador.ordenes(query)
    readonly property int kdeAt: base + ordenes.length
    property var files: []
    readonly property int filesAt: kdeAt + list.count
    readonly property int webAt: filesAt + files.length
    readonly property int total: query === "" ? flat.length : webAt + 1
    property bool copied: false
    // Lo de KDE que ya sale en «Apps» no se repite: qué filas se esconden y qué grupos quedan con algo
    property var kdeOcultas: []
    property var kdeGrupos: []

    function leer() {
        modo = buscador.modo();
        fijadas = buscador.fijadas(modo);
        leerAhora();
        leerLento();
    }
    function leerAhora() {
        try { insp = JSON.parse(buscador.inspector()); } catch (e) {}
        try { avisos = JSON.parse(buscador.avisos()); } catch (e) {}
        ahora = Date.now();
    }
    function leerLento() {
        datos.pedir("Notas", [], d => { if (d) win.notas = d; });
        datos.pedir("Agenda", [Qt.formatDate(new Date(), "yyyy-MM-dd")], d => { if (d) win.hoy = d.cosas || []; });
        if (modo === "estudiar") datos.pedir("Estudio", [], d => { if (d) win.estudio = d; });
    }
    // Dónde está el orbe de la isla (y sus bolitas), en esta ventana: la Órbita sale de él. Sin saberlo, abajo en el centro
    property point orbeEn: Qt.point(width / 2, height - 37)
    property var bolasEn: [Qt.point(width / 2 - 47, height - 44), Qt.point(width / 2 + 47, height - 44)]
    function leerOrbe() {
        const n = String(buscador.donde() || "").split(",").map(Number);
        const sx = win.screen ? win.screen.virtualX : 0, sy = win.screen ? win.screen.virtualY : 0;
        if (n.length === 6 && n.every(v => !isNaN(v)) && n[1] - sy > height / 2 && n[1] - sy < height) {
            orbeEn = Qt.point(n[0] - sx, n[1] - sy);
            bolasEn = [Qt.point(n[2] - sx, n[3] - sy), Qt.point(n[4] - sx, n[5] - sy)];
        } else {
            orbeEn = Qt.point(width / 2, height - 37);
            bolasEn = [Qt.point(width / 2 - 47, height - 44), Qt.point(width / 2 + 47, height - 44)];
        }
    }
    function open() {
        cierre.stop();
        buscador.refresh();
        field.text = "";
        detalle = "";
        pista = false;
        leer();
        sel = 0;
        showFullScreen();
        leerOrbe();
        requestActivate();
        field.forceActiveFocus();
        appear.restart();
    }
    // Se cierra al revés de como se abre (todo vuelve al orbe) y luego se esconde
    function close() {
        if (!visible || cierre.running) return;
        appear.stop();
        cierre.start();
    }
    function cerrado() {
        hide();
        field.text = "";
        detalle = "";
    }
    function abrir(que) {
        detalle = que;
        panel.forceActiveFocus();
    }
    function volver() {
        detalle = "";
        leerLento();
        field.forceActiveFocus();
    }
    function activate(i, folder, ctrl) {
        if (query === "") {
            const a = flat[i];
            if (!a) return;
            if (a.id === "") { pista = true; field.forceActiveFocus(); return; }   // «+»: se fija desde el buscador
            buscador.launch(a.id); close();
        } else if (i < answerAt) {
            const a = appsHalladas[i];
            if (ctrl) { pin(a.id, !pinned(a.id)); return; }
            buscador.launch(a.id); close();
        } else if (i < base) {
            buscador.copy(answer.valor.replace(/ [^\d]+$/, ""));   // (el número, sin la unidad)
            copied = true;
            copiedTimer.restart();
        } else if (i < kdeAt) {
            buscador.orden(ordenes[i - base].id);
            close();
        } else if (i < filesAt) {
            if (results.run(results.index(i - kdeAt, 0))) close();
        } else if (i < webAt) {
            buscador.openFile(files[i - filesAt].path, !!folder);
            close();
        } else {
            buscador.web(query);
            close();
        }
    }
    function oculta(i) { return query !== "" && i >= kdeAt && i < filesAt && kdeOcultas[i - kdeAt] === true }
    function move(d) {
        if (total === 0) return;
        let s = sel;
        for (let n = 0; n < total; n++) {
            s = (s + d + total) % total;
            if (!oculta(s)) break;
        }
        sel = s;
    }
    function recontar() {
        const o = [], g = [];
        for (let i = 0; i < kdeNombres.count; i++) {
            const r = kdeNombres.objectAt(i);
            const fuera = !!r && nombresHallados.indexOf(r.display) >= 0;
            o.push(fuera);
            if (r && !fuera && g.indexOf(r.category) < 0) g.push(r.category);
        }
        kdeOcultas = o;
        kdeGrupos = g;
        if (oculta(sel)) move(1);
    }
    // Que la fila elegida se vea (la lista de lo que encuentra se desliza)
    function asegura(item) {
        const p = item.mapToItem(res, 0, 0);
        if (p.y < resFlick.contentY) resFlick.contentY = p.y;
        else if (p.y + item.height > resFlick.contentY + resFlick.height) resFlick.contentY = p.y + item.height - resFlick.height;
    }
    function pinned(id) { return fijadas.some(a => a.id === id) }
    function pin(id, on) { buscador.fijar(modo, id, on); fijadas = buscador.fijadas(modo); }
    function hace(cuando) {
        const m = Math.floor((ahora / 1000 - cuando) / 60);
        return m < 1 ? "ahora" : m < 60 ? m + " min" : m < 1440 ? Math.floor(m / 60) + " h" : Math.floor(m / 1440) + " d";
    }
    function mmss(s) { s = Math.max(0, Math.round(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }

    Datos { id: datos }
    Timer { id: copiedTimer; interval: 700; onTriggered: { win.copied = false; win.close(); } }
    // Tus archivos: se buscan un momento después de dejar de escribir
    Timer { id: filesTimer; interval: 140; onTriggered: buscador.searchFiles(win.query) }
    onQueryChanged: { files = []; sel = 0; resFlick.contentY = 0; if (query.length >= 2) filesTimer.restart(); }
    onNombresHalladosChanged: Qt.callLater(recontar)
    Timer { interval: 2000; repeat: true; running: win.visible && win.verSatelites; onTriggered: win.leerAhora() }
    Timer { interval: 60000; repeat: true; running: win.visible && win.verSatelites; onTriggered: win.leerLento() }
    Timer {
        interval: 1000; repeat: true
        running: win.visible && win.verSatelites && win.modo === "estudiar"
        onTriggered: datos.pedir("Estudio", [], d => { if (d) win.estudio = d; })
    }
    Timer { id: refrescar; interval: 500; onTriggered: win.leerAhora() }

    Connections {
        target: buscador
        function onToggled() { win.visible ? win.close() : win.open() }
        function onFilesFound(q, found) { if (q === win.query) win.files = found; }
    }
    Component.onCompleted: if (showAtStart) open()
    onActiveChanged: if (!active && visible) close()

    Milou.ResultsModel {
        id: results
        queryString: win.query
        limit: 15
    }
    Instantiator {
        id: kdeNombres
        model: results
        delegate: QtObject {
            required property string display
            required property string category
        }
        onObjectAdded: Qt.callLater(win.recontar)
        onObjectRemoved: Qt.callLater(win.recontar)
    }
    Connections {
        target: results
        function onDataChanged() { Qt.callLater(win.recontar) }
        function onModelReset() { Qt.callLater(win.recontar) }
    }

    // ---------- El fondo: oscuro, con un resplandor del modo que sale del orbe ----------
    Rectangle {
        id: dim
        anchors.fill: parent
        color: Qt.rgba(5 / 255, 7 / 255, 11 / 255, 0.62)
        MouseArea { anchors.fill: parent; onClicked: win.detalle !== "" ? win.volver() : win.close() }
    }
    Shape {
        anchors.fill: parent
        opacity: dim.opacity
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: win.width / 2; centerY: orbe.y + orbe.height / 2
                centerRadius: win.u(460)
                focalX: centerX; focalY: centerY
                GradientStop { position: 0; color: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, 0.16) }
                GradientStop { position: 1; color: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: win.width; y: 0 }
            PathLine { x: win.width; y: win.height }
            PathLine { x: 0; y: win.height }
            PathLine { x: 0; y: 0 }
        }
    }
    ParallelAnimation {
        id: appear
        NumberAnimation { target: dim; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutQuad }
        NumberAnimation { target: win; property: "encendido"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { target: win; property: "llegada"; from: 0; to: 1; duration: 520; easing.type: Easing.OutQuint }
    }
    SequentialAnimation {
        id: cierre
        ParallelAnimation {
            NumberAnimation { target: win; property: "llegada"; to: 0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: dim; property: "opacity"; to: 0; duration: 240; easing.type: Easing.InQuad }
            NumberAnimation { target: win; property: "encendido"; to: 0; duration: 240; easing.type: Easing.InOutQuad }
        }
        ScriptAction { script: win.cerrado() }
    }

    // ---------- Los hilos de luz, del orbe a cada satélite (y el haz hasta la cubierta) ----------
    Hilo { b: Qt.point(musica.x + musica.width / 2, musica.y + musica.height); visible: musica.visible; opacity: musica.opacity; retraso: 0 }
    Hilo { b: Qt.point(avisosSat.x + avisosSat.width / 2, avisosSat.y + avisosSat.height); visible: avisosSat.visible; opacity: avisosSat.opacity; retraso: 600 }
    Hilo { b: Qt.point(nota.x + nota.width, nota.y + nota.height / 2); visible: nota.visible; opacity: nota.opacity; retraso: 300 }
    Hilo { b: Qt.point(calendario.x, calendario.y + calendario.height / 2); visible: calendario.visible; opacity: calendario.opacity; retraso: 900 }
    Hilo { b: Qt.point(estudioSat.x + estudioSat.width / 2, estudioSat.y + estudioSat.height); visible: estudioSat.visible; opacity: estudioSat.opacity; retraso: 1200 }
    Item {   // el haz
        visible: deck.visible
        opacity: deck.opacity
        x: win.width / 2 - width / 2
        y: deck.y + deck.height
        width: win.u(14)
        height: Math.max(0, orbe.y - y)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width; height: parent.height
            radius: width / 2
            opacity: 0.16
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Tema.acento }
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 2; height: parent.height
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, 0.15) }
                GradientStop { position: 1; color: Tema.acento }
            }
        }
    }

    // ---------- Los satélites ----------
    // (los colores de la portada de lo que suena; tiene que estar a la vista para mirarla)
    ColorDe { id: colores; fuente: musica.suena ? (musica.m.portada || "") : "" }
    // Lo que suena: la portada, sus colores y sus botones
    Satelite {
        id: musica
        readonly property var m: win.insp.musica || ({})
        readonly property bool suena: !!m.titulo
        x: win.margen; y: win.techo
        width: win.u(340)
        titulo: suena ? (m.sonando ? "Sonando" : "En pausa") : "Música"
        punto: suena && m.sonando ? "#3ddc84" : Tema.tenue
        derecha: suena ? (m.app || "") : ""
        clicable: false
        tinte: suena ? colores.oscuro : "transparent"
        Row {
            visible: musica.suena
            spacing: win.u(14)
            Rectangle {
                width: win.u(84); height: width
                radius: Tema.r(win.u(14))
                color: Qt.rgba(colores.vivo.r, colores.vivo.g, colores.vivo.b, 0.2)
                clip: true
                Icono { anchors.centerIn: parent; width: win.u(22); height: width; nombre: "musica"; color: colores.vivo; visible: art.status !== Image.Ready }
                Image {
                    id: art
                    anchors.fill: parent
                    source: musica.suena ? (musica.m.portada || "") : ""
                    sourceSize: Qt.size(width * 2, height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                width: musica.cuerpoAncho - win.u(84) - win.u(14)
                spacing: win.u(2)
                Texto { width: parent.width; text: musica.m.titulo || ""; font { pixelSize: win.u(17); weight: Font.DemiBold } elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText }
                Texto { width: parent.width; text: musica.m.artista || ""; color: Tema.apagado; font.pixelSize: win.u(13); elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText }
                Item { width: 1; height: win.u(8) }
                Row {
                    spacing: win.u(10)
                    Redondo { icono: "anterior"; anchors.verticalCenter: parent.verticalCenter; onClicked: { buscador.musica("Previous"); refrescar.restart(); } }
                    Redondo { icono: musica.m.sonando ? "pausa" : "reproducir"; lleno: true; anchors.verticalCenter: parent.verticalCenter; onClicked: { buscador.musica("PlayPause"); refrescar.restart(); } }
                    Redondo { icono: "siguiente"; anchors.verticalCenter: parent.verticalCenter; onClicked: { buscador.musica("Next"); refrescar.restart(); } }
                }
            }
        }
        Barritas {
            visible: musica.suena
            width: musica.cuerpoAncho
            height: win.u(26)
            grosor: win.u(3)
            cuantas: Math.floor((width + grosor) / (grosor * 2))
            color: colores.vivo
            sonando: !!musica.m.sonando && win.verSatelites
        }
        Texto { visible: !musica.suena; text: "Nada sonando"; color: Tema.apagado; font.pixelSize: win.u(14) }
        Texto { visible: !musica.suena; width: musica.cuerpoAncho; text: "Pon algo en Spotify o en tu navegador y aparecerá aquí."; color: Tema.tenue; font.pixelSize: win.u(12) }
    }

    // Tus avisos: los últimos, con su app; lo que se baja, arriba
    Satelite {
        id: avisosSat
        x: win.width - win.margen - width; y: win.techo
        width: win.u(360)
        titulo: "Avisos"
        derecha: win.avisos.length ? String(win.avisos.length) : ""
        clicable: false
        Repeater {
            model: win.insp.bajando || []
            delegate: Column {
                required property var modelData
                width: avisosSat.cuerpoAncho
                spacing: win.u(6)
                bottomPadding: win.u(6)
                Row {
                    spacing: win.u(10)
                    Kirigami.Icon { width: win.u(18); height: width; source: modelData.icono }
                    Texto { text: modelData.app + " · " + Math.round(modelData.progreso * 100) + " %"; font.pixelSize: win.u(13) }
                }
                Rectangle {
                    width: parent.width; height: 3; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.1)
                    Rectangle { width: parent.width * modelData.progreso; height: 3; radius: 1.5; color: Tema.acento }
                }
            }
        }
        Repeater {
            model: win.avisos.slice(0, 3)
            delegate: Item {
                id: av
                required property var modelData
                required property int index
                readonly property string cuerpo: (modelData.texto || "").replace(/<[^>]*>/g, "")
                readonly property string cabeza: modelData.titulo && av.cuerpo && modelData.titulo !== modelData.nombre ? modelData.titulo + " · " + modelData.nombre : modelData.nombre
                readonly property bool chips: index === 0 || avArea.containsMouse || quitar.encima || abrirChip.encima
                width: avisosSat.cuerpoAncho
                height: avCol.height + win.u(14)
                Rectangle {   // la línea de arriba (menos en el primero)
                    visible: av.index > 0
                    width: parent.width; height: 1
                    color: Qt.rgba(1, 1, 1, 0.07)
                }
                MouseArea { id: avArea; anchors.fill: parent; hoverEnabled: true }
                Rectangle {
                    id: cara
                    y: win.u(10)
                    width: win.u(32); height: width; radius: width / 2
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Kirigami.Icon {
                        id: avIcono
                        anchors.centerIn: parent
                        width: win.u(20); height: width
                        source: { const i = av.modelData.icono || ""; return i.startsWith("/") ? "file://" + i : i; }
                        fallback: "dialog-information"
                    }
                    Texto {   // (sin icono: su inicial)
                        anchors.centerIn: parent
                        visible: !avIcono.valid
                        text: (av.modelData.titulo || av.modelData.nombre || "?").charAt(0).toUpperCase()
                        font { pixelSize: win.u(14); weight: Font.DemiBold }
                    }
                }
                Column {
                    id: avCol
                    x: cara.width + win.u(12); y: win.u(8)
                    width: parent.width - x
                    spacing: win.u(3)
                    Item {
                        width: parent.width; height: avCab.height
                        Texto { id: avCab; width: parent.width - avHora.width - win.u(8); text: av.cabeza; color: Tema.apagado; font.pixelSize: win.u(12); elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText }
                        Texto { id: avHora; anchors.right: parent.right; text: win.hace(av.modelData.cuando); color: Tema.tenue; font.pixelSize: win.u(12) }
                    }
                    Texto {
                        width: parent.width
                        text: av.cuerpo || av.modelData.titulo || ""
                        font.pixelSize: win.u(14)
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    Row {
                        visible: av.chips
                        spacing: win.u(6)
                        topPadding: win.u(4)
                        Chip { id: abrirChip; visible: av.modelData.abrir !== ""; text: "Abrir"; onClicked: { buscador.launch(av.modelData.abrir); win.close(); } }
                        Chip { id: quitar; text: "Quitar"; onClicked: { buscador.quitarAviso(av.modelData.cuando); win.leerAhora(); } }
                    }
                }
            }
        }
        Texto { visible: !win.avisos.length && !(win.insp.bajando || []).length; text: "Todo tranquilo"; color: Tema.apagado; font.pixelSize: win.u(14) }
    }

    // Tu nota (la primera de este modo): sus casillas se marcan aquí mismo
    Satelite {
        id: nota
        readonly property var n: win.notas.find(x => x.piso === win.modo) || win.notas[0] || null
        readonly property var lineas: n ? (n.texto || "").split("\n") : []
        readonly property int cabeza: lineas.findIndex(l => l.trim() !== "")
        readonly property bool conTitulo: cabeza >= 0 && !/^\s*[-*]\s\[[ xX]\]/.test(lineas[cabeza])
        // (las líneas de debajo del título, sin las vacías: [número de línea, texto])
        readonly property var resto: lineas.map((l, i) => [i, l]).filter(p => p[1].trim() !== "" && !(conTitulo && p[0] === cabeza)).slice(0, 5)
        x: win.margen
        y: deck.y + deck.height - height - win.u(56)
        width: win.u(280)
        titulo: "Nota"
        punto: "#e9edf5"
        derecha: win.notas.length > 1 ? win.notas.length + " notas" : ""
        onPulsado: win.abrir("notas")
        function marcar(i) {
            const l = lineas.slice();
            l[i] = l[i].replace(/\[([ xX])\]/, (_, c) => c === " " ? "[x]" : "[ ]");
            const todas = win.notas.map(x => x.id === n.id ? Object.assign({}, x, { texto: l.join("\n") }) : x);
            win.notas = todas;
            datos.hacer("PonerNotas", [JSON.stringify(todas)]);
        }
        Texto {
            visible: nota.conTitulo
            width: nota.cuerpoAncho
            text: nota.conTitulo ? nota.lineas[nota.cabeza] : ""
            font { pixelSize: win.u(16); weight: Font.DemiBold }
            elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText
            bottomPadding: win.u(4)
        }
        Repeater {
            model: nota.resto
            delegate: Item {
                id: ln
                required property var modelData
                readonly property var casilla: /^\s*[-*]\s\[([ xX])\]\s?(.*)$/.exec(modelData[1])
                readonly property bool hecha: !!casilla && casilla[1] !== " "
                width: nota.cuerpoAncho
                height: win.u(25)
                Rectangle {
                    id: caja
                    visible: !!ln.casilla
                    anchors.verticalCenter: parent.verticalCenter
                    width: win.u(15); height: width; radius: win.u(4)
                    color: ln.hecha ? Tema.acento : "transparent"
                    border.width: ln.hecha ? 0 : 1.5
                    border.color: Qt.rgba(1, 1, 1, cajaArea.containsMouse ? 0.6 : 0.32)
                    Icono { anchors.centerIn: parent; width: win.u(11); height: width; nombre: "hecho"; color: Tema.sobreAcento; visible: ln.hecha }
                }
                Texto {
                    x: ln.casilla ? caja.width + win.u(10) : 0
                    width: parent.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    text: ln.casilla ? ln.casilla[2] : ln.modelData[1].replace(/^\s*[-*]\s/, "· ")
                    color: ln.hecha ? Tema.tenue : ln.casilla ? Tema.texto : Tema.apagado
                    font.pixelSize: win.u(14)
                    font.strikeout: ln.hecha
                    elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText
                }
                MouseArea {
                    id: cajaArea
                    enabled: !!ln.casilla
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: nota.marcar(ln.modelData[0])
                }
            }
        }
        Texto { visible: !nota.n; text: "Sin notas"; color: Tema.apagado; font.pixelSize: win.u(14) }
        Texto { visible: !nota.n; width: nota.cuerpoAncho; text: "Pulsa aquí para escribir una. Con «- [ ]» haces una casilla."; color: Tema.tenue; font.pixelSize: win.u(12) }
    }

    // Lo que queda hoy (y lo próximo) en tu calendario
    Satelite {
        id: calendario
        readonly property string hhmm: Qt.formatTime(new Date(win.ahora), "HH:mm")
        readonly property var cosas: {
            const o = [];
            for (const c of win.hoy)
                if (!c.hora || c.hora >= hhmm) o.push({ cuando: c.hora || "Hoy", texto: c.texto, sub: c.tipo === "recordatorio" ? "recordatorio" : "" });
            for (const p of (win.insp.proximo || []))
                if (p.dias > 0) o.push({ cuando: (p.dias === 1 ? "Mañana" : "En " + p.dias + " días") + (p.hora ? " " + p.hora : ""), texto: p.texto, sub: "" });
            return o.slice(0, 4);
        }
        x: win.width - win.margen - width
        y: deck.y + deck.height - height
        width: win.u(280)
        titulo: new Date(win.ahora).toLocaleDateString(Qt.locale("es_ES"), "dddd d")
        punto: "#ffb35c"
        derecha: cosas.length ? String(cosas.length) : ""
        onPulsado: win.abrir("agenda")
        Repeater {
            model: calendario.cosas
            delegate: Item {
                id: cosa
                required property var modelData
                required property int index
                width: calendario.cuerpoAncho
                height: cosaCol.height + win.u(12)
                Rectangle {   // la línea del tiempo
                    visible: cosa.index < calendario.cosas.length - 1
                    x: win.u(5); y: win.u(12)
                    width: 1; height: parent.height
                    color: Qt.rgba(1, 1, 1, 0.14)
                }
                Rectangle {
                    y: win.u(3)
                    width: win.u(11); height: width; radius: width / 2
                    color: cosa.index === 0 ? "#ffb35c" : "transparent"
                    border.width: 1.5; border.color: "#ffb35c"
                }
                Column {
                    id: cosaCol
                    x: win.u(22)
                    width: parent.width - x
                    Texto { text: cosa.modelData.cuando; color: "#ffb35c"; font { family: Tema.mono; pixelSize: win.u(11); capitalization: Font.AllUppercase } }
                    Texto { width: parent.width; text: cosa.modelData.texto; font.pixelSize: win.u(14); elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText }
                    Texto { visible: text !== ""; text: cosa.modelData.sub; color: Tema.tenue; font.pixelSize: win.u(12) }
                }
            }
        }
        Texto { visible: !calendario.cosas.length; text: "Nada más por hoy"; color: Tema.apagado; font.pixelSize: win.u(14) }
    }

    // Tu estudio (solo en Estudiar): el temporizador 25/5
    Satelite {
        id: estudioSat
        readonly property bool hay: win.modo === "estudiar"
        visible: hay && opacity > 0.01
        x: (win.width - width) / 2; y: win.techo
        width: win.u(240)
        titulo: win.estudio.fase === "largo" ? "Descanso largo" : win.estudio.fase === "descanso" ? "Descanso" : "Estudio"
        punto: win.estudio.corriendo ? "#ffb35c" : Tema.tenue
        derecha: win.estudio.asignatura || ""
        onPulsado: win.abrir("estudios")
        Item {
            width: estudioSat.cuerpoAncho
            height: win.u(46)
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: win.mmss(win.estudio.quedan !== undefined ? win.estudio.quedan : 1500)
                font { family: Tema.mono; pixelSize: win.u(34); weight: Font.Light }
            }
            Redondo {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icono: win.estudio.corriendo ? "pausa" : "reproducir"
                lleno: true
                onClicked: { datos.hacer("EstudioAccion", ["alternar", ""]); datos.pedir("Estudio", [], d => { if (d) win.estudio = d; }); }
            }
        }
        Rectangle {
            width: estudioSat.cuerpoAncho; height: 3; radius: 1.5
            color: Qt.rgba(1, 1, 1, 0.1)
            Rectangle {
                height: 3; radius: 1.5; color: "#ffb35c"
                width: parent.width * Math.max(0, Math.min(1, 1 - (win.estudio.quedan !== undefined ? win.estudio.quedan : 1500) / (win.estudio.total || 1500)))
            }
        }
    }

    // ---------- La cubierta: tus apps fijadas y el buscador (al escribir, lo que encuentra, encima del campo) ----------
    Rectangle {
        id: deck
        readonly property real pad: win.u(16)
        readonly property real tile: win.u(72)
        readonly property int porFila: Math.min(win.flat.length, 6)
        readonly property real maxRes: orbe.y - win.u(44) - win.techo - campo.height - 3 * pad
        visible: opacity > 0.01
        opacity: win.llegada * (win.detalle === "" ? 1 : 0)
        width: win.query !== "" ? Math.min(win.width - 2 * win.margen, win.u(640))
                                : Math.max(win.u(460), porFila * tile + 2 * pad)
        height: deckCol.height + 2 * pad
        x: (win.width - width) / 2
        y: orbe.y - win.u(44) - height + (1 - win.llegada) * win.u(20)
        radius: Tema.r(win.u(22))
        color: Qt.rgba(0.07, 0.08, 0.105, 0.86)
        border.color: Qt.rgba(1, 1, 1, 0.09)
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
        Brillo {}

        Column {
            id: deckCol
            x: deck.pad; y: deck.pad
            width: deck.width - 2 * deck.pad
            spacing: win.u(12)

            // Tus fijadas (y «+»)
            Flow {
                visible: win.query === ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: deck.porFila * deck.tile
                Repeater {
                    model: win.query === "" ? win.flat : []
                    delegate: Tile {
                        required property var modelData
                        required property int index
                        pos: index
                        app: modelData
                    }
                }
            }
            Texto {
                visible: win.query === "" && win.fijadas.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Fija aquí tus apps de " + win.nombreModo[win.modo] + ": búscalas abajo y pulsa su chincheta."
                color: Tema.apagado
                font.pixelSize: win.u(13)
            }

            // Lo que encuentra
            Flickable {
                id: resFlick
                visible: win.query !== ""
                width: parent.width
                height: visible ? Math.min(res.height, deck.maxRes) : 0
                contentHeight: res.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: res
                    width: resFlick.width

                    // Tus apps (con la chincheta para fijarlas en el modo)
                    Titulo { visible: win.appsHalladas.length > 0; text: "Apps" }
                    Repeater {
                        model: win.appsHalladas
                        delegate: Row_ {
                            required property var modelData
                            required property int index
                            width: res.width
                            pos: index
                            display: modelData.nombre
                            subtext: win.pinned(modelData.id) ? "Fijada en " + win.nombreModo[win.modo] : ""
                            decoration: modelData.icono
                            fijarId: modelData.id
                        }
                    }

                    // La cuenta, bien grande (Intro la copia)
                    Rectangle {
                        id: answerCard
                        visible: win.base > win.answerAt
                        width: parent.width
                        height: visible ? win.u(72) : 0
                        radius: Tema.r(win.u(14))
                        color: win.sel === win.answerAt ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
                        Rectangle {
                            id: eq
                            x: win.u(14); anchors.verticalCenter: parent.verticalCenter
                            width: win.u(40); height: width; radius: width / 2
                            color: Tema.rosaSuave
                            Texto { anchors.centerIn: parent; text: "="; color: Tema.acento; font.pixelSize: win.u(24); font.weight: Font.Bold }
                        }
                        Column {
                            x: eq.x + eq.width + win.u(14)
                            width: parent.width - x - copyHint.width - win.u(30)
                            anchors.verticalCenter: parent.verticalCenter
                            Texto {
                                width: parent.width
                                text: win.answer.valor || ""
                                font { family: Tema.mono; pixelSize: win.u(24); weight: Font.Bold }
                                elide: Text.ElideRight; wrapMode: Text.NoWrap
                            }
                            Texto {
                                width: parent.width
                                text: win.answer.detalle || ""
                                color: Tema.apagado; font.pixelSize: win.u(12)
                                elide: Text.ElideRight; wrapMode: Text.NoWrap
                            }
                        }
                        Texto {
                            id: copyHint
                            anchors.right: parent.right; anchors.rightMargin: win.u(18)
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.copied ? "Copiado ✓" : win.sel === win.answerAt ? "Intro para copiar" : ""
                            color: Tema.acento; font.pixelSize: win.u(12); font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: win.sel = win.answerAt
                            onClicked: win.activate(win.answerAt)
                        }
                    }

                    // Las órdenes
                    Titulo { visible: win.ordenes.length > 0; text: "Órdenes" }
                    Repeater {
                        model: win.ordenes
                        delegate: Row_ {
                            required property var modelData
                            required property int index
                            width: res.width
                            pos: win.base + index
                            display: modelData.nombre
                            subtext: modelData.detalle
                            iconName: modelData.icono
                        }
                    }

                    // Lo que encuentran los buscadores de KDE (sin las apps que ya salen arriba)
                    ListView {
                        id: list
                        width: parent.width
                        height: contentHeight
                        interactive: false
                        visible: count > 0
                        model: results
                        section.property: "category"
                        section.delegate: Titulo {
                            required property string section
                            visible: win.kdeGrupos.indexOf(section) >= 0
                            height: visible ? implicitHeight : 0
                            text: section
                        }
                        delegate: Row_ {
                            required property var model
                            pos: win.kdeAt + model.index
                            fuera: win.kdeOcultas[model.index] === true
                            display: model.display || ""
                            subtext: model.subtext || ""
                            decoration: model.decoration
                        }
                    }

                    // Tus archivos (por su nombre)
                    Titulo { visible: win.files.length > 0; text: "Tus archivos" }
                    Repeater {
                        model: win.files
                        delegate: Row_ {
                            required property var modelData
                            required property int index
                            width: res.width
                            pos: win.filesAt + index
                            display: modelData.nombre
                            subtext: modelData.ruta + (on && !modelData.carpeta ? "  ·  Mayús+Intro: abrir su carpeta" : "")
                            decoration: modelData.icono
                        }
                    }

                    // La web, siempre al final
                    Titulo { text: "En la web" }
                    Row_ {
                        width: parent.width
                        pos: win.webAt
                        display: "Buscar «" + win.query + "» en la web"
                        subtext: "Con Ágape"
                        iconName: "web"
                    }
                }
            }

            // El campo
            Rectangle {
                id: campo
                width: parent.width
                height: win.u(48)
                radius: Tema.r(win.u(14))
                color: Qt.rgba(0, 0, 0, 0.28)
                border.width: 1
                border.color: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, field.activeFocus ? 0.7 : 0.3)
                Rectangle {   // el brillo de alrededor
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: parent.radius + 3
                    color: "transparent"
                    border.width: 3
                    border.color: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, field.activeFocus ? 0.12 : 0)
                }
                Icono { x: win.u(16); anchors.verticalCenter: parent.verticalCenter; width: win.u(17); height: width; nombre: "buscar"; color: Tema.apagado }
                TextInput {
                    id: field
                    objectName: "campo"
                    x: win.u(44)
                    width: parent.width - x - teclas.width - win.u(28)
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tema.texto
                    selectionColor: Tema.acento
                    selectedTextColor: Tema.sobreAcento
                    font.family: Tema.letra
                    font.pixelSize: win.u(16)
                    clip: true
                    focus: true
                    Keys.onEscapePressed: { if (field.text !== "") field.text = ""; else win.close(); }
                    Keys.onDownPressed: event => { if (win.query !== "") win.move(1); }
                    Keys.onUpPressed: event => { if (win.query !== "") win.move(-1); }
                    Keys.onRightPressed: event => { if (win.query === "") win.move(1); else event.accepted = false; }
                    Keys.onLeftPressed: event => { if (win.query === "") win.move(-1); else event.accepted = false; }
                    Keys.onTabPressed: win.move(1)
                    Keys.onBacktabPressed: win.move(-1)
                    Keys.onReturnPressed: event => win.activate(win.sel, event.modifiers & Qt.ShiftModifier, event.modifiers & Qt.ControlModifier)
                    Keys.onEnterPressed: event => win.activate(win.sel, event.modifiers & Qt.ShiftModifier, event.modifiers & Qt.ControlModifier)
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        visible: field.text === ""
                        text: win.pista ? "Busca una app y pulsa su chincheta para fijarla" : "Busca apps, archivos, órdenes…"
                        color: win.pista ? Tema.acento : Tema.tenue
                        font.pixelSize: win.u(16)
                        elide: Text.ElideRight; wrapMode: Text.NoWrap
                    }
                }
                Texto {
                    id: teclas
                    anchors.right: parent.right
                    anchors.rightMargin: win.u(16)
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.query !== "" && win.sel < win.answerAt ? "↵ abrir · Ctrl+↵ fijar" : "↵ abrir · Esc"
                    color: Tema.tenue
                    font { family: Tema.mono; pixelSize: win.u(11) }
                }
            }
        }
    }

    // ---------- Un satélite abierto entero: tu agenda, tus notas o tu estudio ----------
    Rectangle {
        id: panel
        visible: opacity > 0.01
        opacity: win.detalle !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        width: Math.min(win.u(1000), win.width - 2 * win.margen)
        height: orbe.y - win.u(44) - win.techo
        x: (win.width - width) / 2
        y: win.techo + (1 - opacity) * win.u(16)
        radius: Tema.r(win.u(22))
        color: Qt.rgba(0.07, 0.08, 0.105, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.09)
        MouseArea { anchors.fill: parent }
        Keys.onEscapePressed: win.volver()
        Brillo {}
        Row {
            id: panelCab
            x: win.u(18); y: win.u(16)
            spacing: win.u(12)
            Redondo { icono: "flecha"; rotation: 180; anchors.verticalCenter: parent.verticalCenter; onClicked: win.volver() }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: ({ agenda: "Agenda", notas: "Notas", estudios: "Estudios" })[win.detalle] || ""
                font { pixelSize: win.u(20); weight: Font.DemiBold }
            }
        }
        Texto {
            anchors.right: parent.right; anchors.rightMargin: win.u(22)
            anchors.verticalCenter: panelCab.verticalCenter
            text: "Esc · volver"
            color: Tema.tenue
            font { family: Tema.mono; pixelSize: win.u(11) }
        }
        Loader {
            x: win.u(18); y: panelCab.y + panelCab.height + win.u(16)
            width: parent.width - 2 * x; height: parent.height - y - win.u(16)
            active: win.detalle !== ""
            sourceComponent: win.detalle === "agenda" ? cAgenda : win.detalle === "notas" ? cNotas : win.detalle === "estudios" ? cEstudios : null
        }
        Component { id: cAgenda; Agenda { Component.onCompleted: open() } }
        Component { id: cNotas; Notas { modo: win.modo } }
        Component { id: cEstudios; Estudios {} }
    }

    // ---------- El orbe: justo encima del de la isla e igual que él (que se aparta por debajo), y se enciende: el anillo
    // crece, el punto toma el color del modo y brilla. Un clic lo cierra; a sus lados, las bolitas de los otros modos,
    // también donde están las de la isla ----------
    Item {
        id: orbe
        width: 40; height: 40
        x: win.orbeEn.x - 20
        y: win.orbeEn.y - 20
        Rectangle {   // el brillo
            anchors.centerIn: parent
            width: 40 + 52 * win.encendido; height: width; radius: width / 2
            color: Tema.acento
            opacity: (orbeArea.containsMouse ? 0.2 : 0.13) * win.encendido
        }
        Rectangle {
            anchors.centerIn: parent
            width: 40; height: 40; radius: 20
            scale: (1 + 0.1 * win.encendido) * (orbeArea.pressed ? 0.92 : 1)
            color: Tema.claro ? Tema.superficie : "#0b0e14"
            border.width: 2
            border.color: Tema.acento
            Rectangle {
                anchors.centerIn: parent
                width: 11 + 3 * win.encendido; height: width; radius: width / 2
                color: Qt.tint(Tema.texto, Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, win.encendido))
            }
        }
        MouseArea { id: orbeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.close() }
    }
    Repeater {
        // (en el mismo orden que en la isla: el modo de antes a la izquierda y el de después a la derecha)
        model: { const m = ["jugar", "navegar", "estudiar"], i = Math.max(0, m.indexOf(win.modo)); return [m[(i + 2) % 3], m[(i + 1) % 3]]; }
        delegate: Item {
            id: bola
            required property string modelData
            required property int index
            readonly property color c: win.colorModo[modelData]
            width: 50; height: 48
            x: win.bolasEn[index].x - width / 2
            y: win.bolasEn[index].y - 17
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 5
                width: 24; height: 24; radius: 12
                color: bolaArea.containsMouse ? Qt.rgba(bola.c.r, bola.c.g, bola.c.b, 0.25) : (Tema.claro ? Tema.superficie : "#151b24")
                border.width: 1.5
                border.color: bola.c
                scale: bolaArea.pressed ? 0.88 : bolaArea.containsMouse ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: 140 } }
            }
            Texto {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 32
                text: win.nombreModo[bola.modelData]
                color: bola.c
                wrapMode: Text.NoWrap
                font { pixelSize: 10; weight: Font.DemiBold }
            }
            MouseArea {
                id: bolaArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { buscador.orden("modo:" + bola.modelData); win.close(); }
            }
        }
    }

    // ---------- Las piezas ----------
    // Un satélite: cristal grafito, su cabecera (un punto, el nombre y algo a la derecha) y lo de dentro
    component Satelite: Rectangle {
        id: s
        property string titulo
        property color punto: Tema.acento
        property string derecha: ""
        property bool clicable: true
        property color tinte: "transparent"
        readonly property real pad: win.u(16)
        readonly property real cuerpoAncho: width - 2 * pad
        default property alias contenido: cuerpo.data
        signal pulsado()
        property real ver: win.verSatelites ? 1 : 0
        Behavior on ver { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        visible: opacity > 0.01
        opacity: win.llegada * ver
        // (sale del orbe: crece un poco y sube hacia su sitio)
        scale: 0.92 + 0.08 * win.llegada
        transform: Translate { y: (1 - win.llegada) * win.u(24) }
        height: cuerpo.y + cuerpo.height + pad
        radius: Tema.r(win.u(18))
        color: Qt.rgba(0.07, 0.08, 0.105, 0.84)
        border.color: Qt.rgba(1, 1, 1, sArea.containsMouse && clicable ? 0.18 : 0.08)
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Rectangle {   // el color de lo que suena, desde arriba a la izquierda
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.55
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: s.tinte }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Brillo {}
        MouseArea {
            id: sArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: s.clicable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (s.clicable) s.pulsado()
        }
        Item {
            id: cab
            x: s.pad; y: s.pad
            width: s.cuerpoAncho
            height: cabTexto.height
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: win.u(6); height: width; radius: width / 2; color: s.punto }
            Texto {
                id: cabTexto
                x: win.u(14)
                width: parent.width - x - cabDer.width - win.u(8)
                text: s.titulo
                color: Tema.apagado
                font { family: Tema.mono; pixelSize: win.u(10); letterSpacing: 2; capitalization: Font.AllUppercase }
                elide: Text.ElideRight; wrapMode: Text.NoWrap
            }
            Texto {
                id: cabDer
                anchors.right: parent.right
                text: s.derecha
                color: Tema.tenue
                font { family: Tema.mono; pixelSize: win.u(10); letterSpacing: 1.5; capitalization: Font.AllUppercase }
            }
        }
        Column {
            id: cuerpo
            x: s.pad
            y: cab.y + cab.height + win.u(14)
            width: s.cuerpoAncho
            spacing: win.u(6)
        }
    }
    // La línea de luz de arriba de los cristales
    component Brillo: Rectangle {
        x: parent.radius; y: 0
        width: parent.width - 2 * parent.radius; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.16) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    // Un hilo de luz del orbe a un satélite, con una chispa que viaja por él
    component Hilo: Item {
        id: h
        property point b
        property int retraso: 0
        readonly property point a: Qt.point(win.width / 2, orbe.y)
        readonly property real dy: a.y - b.y
        anchors.fill: parent
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, 0.32)
                strokeWidth: 1.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: h.a.x; startY: h.a.y
                PathCubic { x: h.b.x; y: h.b.y; control1X: h.a.x; control1Y: h.a.y - h.dy * 0.5; control2X: h.b.x; control2Y: h.b.y + h.dy * 0.5 }
            }
        }
        PathInterpolator {
            id: viaje
            path: Path {
                startX: h.a.x; startY: h.a.y
                PathCubic { x: h.b.x; y: h.b.y; control1X: h.a.x; control1Y: h.a.y - h.dy * 0.5; control2X: h.b.x; control2Y: h.b.y + h.dy * 0.5 }
            }
            SequentialAnimation on progress {
                running: win.visible && h.visible
                loops: Animation.Infinite
                PauseAnimation { duration: h.retraso }
                NumberAnimation { from: 0; to: 1; duration: 2400; easing.type: Easing.InOutSine }
                PauseAnimation { duration: 1800 - h.retraso }
            }
        }
        Rectangle {   // la chispa
            x: viaje.x - width / 2; y: viaje.y - height / 2
            width: win.u(5); height: width; radius: width / 2
            color: Qt.lighter(Tema.acento, 1.35)
            opacity: Math.sin(viaje.progress * Math.PI) * 0.9
        }
        Rectangle {   // el nudo, donde llega
            x: h.b.x - width / 2; y: h.b.y - height / 2
            width: win.u(7); height: width; radius: width / 2
            color: Tema.acento
            Rectangle { anchors.centerIn: parent; width: parent.width * 3; height: width; radius: width / 2; color: Tema.acento; opacity: 0.18 }
        }
    }
    component Titulo: Texto {
        x: win.u(6)
        topPadding: win.u(10)
        bottomPadding: win.u(4)
        color: Tema.tenue
        font { family: Tema.mono; pixelSize: win.u(10); weight: Font.DemiBold; letterSpacing: 1.6; capitalization: Font.AllUppercase }
    }
    component Redondo: Rectangle {
        id: rd
        property string icono
        property bool lleno: false
        signal clicked()
        width: lleno ? win.u(40) : win.u(32); height: width; radius: width / 2
        color: lleno ? "#f4f5f8" : rm.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        scale: rm.pressed ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: 100 } }
        Icono { anchors.centerIn: parent; width: win.u(16); height: width; nombre: rd.icono; color: rd.lleno ? "#0b0e14" : Tema.texto }
        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rd.clicked() }
    }
    component Chip: Rectangle {
        id: ch
        property alias text: chT.text
        readonly property bool encima: chA.containsMouse
        signal clicked()
        width: chT.implicitWidth + win.u(20); height: win.u(24); radius: height / 2
        color: Qt.rgba(1, 1, 1, chA.containsMouse ? 0.16 : 0.08)
        Texto { id: chT; anchors.centerIn: parent; font.pixelSize: win.u(12) }
        MouseArea { id: chA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ch.clicked() }
    }
    // Una app fijada (o «+»): clic abrirla; su chincheta o el clic derecho la quitan del modo
    component Tile: Item {
        id: tile
        property int pos
        property var app
        readonly property bool on: win.sel === pos && win.query === ""
        readonly property bool mas: app.id === ""
        width: deck.tile; height: win.u(82)
        Rectangle {
            anchors.fill: parent
            anchors.margins: win.u(2)
            radius: Tema.r(win.u(14))
            color: Qt.rgba(1, 1, 1, tile.on ? 0.1 : area.containsMouse ? 0.06 : 0)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Rectangle {   // «+»
            visible: tile.mas
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.u(10); width: win.u(38); height: width; radius: width / 2
            color: "transparent"
            border.width: 1.5; border.color: Qt.rgba(1, 1, 1, area.containsMouse || tile.on ? 0.4 : 0.18)
            Icono { anchors.centerIn: parent; nombre: "mas"; color: Tema.apagado }
        }
        Kirigami.Icon {
            visible: !tile.mas
            anchors.horizontalCenter: parent.horizontalCenter
            y: win.u(10); width: win.u(38); height: width
            source: tile.app.icono
            scale: area.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
        Texto {
            y: win.u(56); width: parent.width - win.u(6); x: win.u(3)
            horizontalAlignment: Text.AlignHCenter
            text: tile.app.nombre
            color: tile.on ? Tema.texto : Tema.apagado
            font.pixelSize: win.u(12)
            elide: Text.ElideRight; wrapMode: Text.NoWrap
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onEntered: win.sel = tile.pos
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) { if (!tile.mas) win.pin(tile.app.id, false); }
                else win.activate(tile.pos);
            }
        }
        Rectangle {   // la chincheta: quitarla del modo
            visible: !tile.mas && (area.containsMouse || pinArea.containsMouse)
            anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: win.u(2)
            width: win.u(22); height: width; radius: width / 2
            color: pinArea.containsMouse ? Tema.acento : Qt.rgba(1, 1, 1, 0.14)
            Icono { anchors.centerIn: parent; width: win.u(12); height: width; nombre: "chincheta"; color: pinArea.containsMouse ? Tema.sobreAcento : Tema.texto }
            MouseArea {
                id: pinArea
                anchors.fill: parent; anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.pin(tile.app.id, false)
            }
        }
    }
    component Row_: Rectangle {
        id: r
        property int pos: 0
        property string display: ""
        property string subtext: ""
        property var decoration: undefined
        property string iconName: ""                // un icono de línea de Apogeo en vez del de la app
        property string fijarId: ""                 // una app: con su chincheta para fijarla en el modo
        property bool fuera: false                  // (ya sale en «Apps»)
        readonly property bool on: win.sel === pos
        readonly property bool fija: fijarId !== "" && win.pinned(fijarId)
        onOnChanged: if (on && !fuera) Qt.callLater(() => win.asegura(r))
        visible: !fuera
        width: ListView.view ? ListView.view.width : parent.width
        height: fuera ? 0 : win.u(46)
        radius: Tema.r(win.u(12))
        color: on ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
        Rectangle {
            id: badge
            x: win.u(10)
            anchors.verticalCenter: parent.verticalCenter
            width: win.u(30); height: width; radius: width / 2
            color: r.iconName ? Tema.rosaSuave : "transparent"
            Icono { visible: r.iconName !== ""; anchors.centerIn: parent; nombre: r.iconName; color: Tema.acento }
            Kirigami.Icon { visible: r.iconName === ""; anchors.fill: parent; source: r.decoration || "" }
        }
        Column {
            x: badge.x + badge.width + win.u(12)
            width: parent.width - x - (go.visible ? go.width + win.u(16) : 0) - (chin.visible ? chin.width + win.u(10) : win.u(12))
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Texto { width: parent.width; text: r.display; font.pixelSize: win.u(14); elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText }
            Texto { width: parent.width; visible: text !== ""; text: r.subtext; color: Tema.apagado; font.pixelSize: win.u(12); elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: win.sel = r.pos
            onClicked: win.activate(r.pos)
        }
        Row {
            id: go
            visible: r.on
            anchors.right: chin.visible ? chin.left : parent.right
            anchors.rightMargin: chin.visible ? win.u(10) : win.u(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: win.u(6)
            Texto { text: "Intro"; color: Tema.acento; font { family: Tema.mono; pixelSize: win.u(11) } anchors.verticalCenter: parent.verticalCenter }
            Icono { nombre: "flecha"; color: Tema.acento; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle {   // la chincheta de una app: fijarla en el modo (o quitarla)
            id: chin
            visible: r.fijarId !== ""
            anchors.right: parent.right
            anchors.rightMargin: win.u(10)
            anchors.verticalCenter: parent.verticalCenter
            width: win.u(28); height: width; radius: width / 2
            color: r.fija ? Tema.acento : chinArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
            Icono { anchors.centerIn: parent; width: win.u(13); height: width; nombre: "chincheta"; color: r.fija ? Tema.sobreAcento : Tema.texto }
            MouseArea {
                id: chinArea
                anchors.fill: parent; anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { win.pin(r.fijarId, !r.fija); field.forceActiveFocus(); }
            }
        }
    }
}
