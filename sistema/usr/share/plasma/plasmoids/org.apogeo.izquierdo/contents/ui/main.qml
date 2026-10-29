import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.taskmanager as TaskManager
import Apogeo

// El panel de widgets de Apogeo («2 · Dos paneles altos»), alto, a la izquierda: sale con Meta+A o empujando el ratón
// contra el borde (el script de KWin apogeo-bordes) y hace sitio. Arriba, tu foto y un saludo; debajo, tres pestañas:
//  - Widgets: lo que suena, la semana (abre la agenda a su lado), el tiempo, tu PC en anillos, los relojes del mundo y
//    tus fondos de Aura para este piso.
//  - Estudios (solo en Estudiar, y se abre sola al llegar): el temporizador, los exámenes, las tareas de hoy y tus
//    asignaturas.
//  - Notas: tus notas en tarjetas con su color; «Nueva» pone una, se escriben ahí mismo y se ordenan arrastrándolas.
// Los datos los da apogeo-pisos (Datos, por D-Bus) y solo se piden con el panel abierto («abierto», lo pone el script);
// abierto, el panel coge el teclado.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    toolTipMainText: ""
    toolTipSubText: ""
    readonly property bool abierto: !!Plasmoid.configuration.abierto
    // Abierto, coge el teclado (para escribir una nota o una tarea, como una ventana más); cerrado, lo devuelve
    Plasmoid.status: abierto ? PlasmaCore.Types.AcceptingInputStatus : PlasmaCore.Types.ActiveStatus

    TaskManager.VirtualDesktopInfo { id: desktops }
    readonly property int floorIndex: Math.max(0, desktops.desktopIds.indexOf(desktops.currentDesktop))
    readonly property string floor: ["jugar", "navegar", "estudiar"][floorIndex] || "navegar"
    readonly property string floorName: desktops.desktopNames[floorIndex] || "Navegar"

    // Las pestañas: Estudios solo en Estudiar (y al llegar allí, es la que se ve)
    readonly property var tabs: floor === "estudiar" ? ["widgets", "estudios", "notas"] : ["widgets", "notas"]
    property string tab: "widgets"
    onFloorChanged: {
        if (floor === "estudiar") tab = "estudios";
        else if (tab === "estudios") tab = "widgets";
        if (abierto) cargar(true);
    }

    Datos { id: datos }
    property var tiempo: ({})
    property var pc: ({})
    property var relojes: []
    property var fondos: null
    property var estudio: ({})
    property var asignaturas: []
    property var tareas: []
    property var examenes: []
    property var yo: ({})          // tu nombre y tu foto (apogeo-ajustes rapido)

    function cargar(lento) {
        if (tab === "widgets") {
            datos.pedir("Pc", [], d => { if (d) root.pc = d; });
            if (lento) {
                datos.pedir("Tiempo", [], d => { if (d) root.tiempo = d; });
                datos.pedir("Relojes", [], d => { if (d) root.relojes = d; });
                datos.pedir("Fondos", [], d => { if (d) root.fondos = d; });
            }
        } else if (tab === "estudios") {
            datos.pedir("Estudio", [], d => { if (d) root.estudio = d; });
            if (lento) {
                datos.pedir("Asignaturas", [], d => { if (d) root.asignaturas = d; });
                datos.pedir("Tareas", [], d => { if (d) root.tareas = d; });
                datos.pedir("Examenes", [], d => { if (d) root.examenes = d; });
            }
        }
    }
    property int vuelta: 0
    Timer {
        interval: root.tab === "estudios" ? 1000 : 2000
        repeat: true
        running: root.abierto && root.tab !== "notas"
        triggeredOnStart: true
        onTriggered: { root.cargar(root.vuelta % 10 === 0); root.vuelta++; }
    }
    onTabChanged: vuelta = 0
    onAbiertoChanged: {
        if (abierto) {
            vuelta = 0;
            ahora = new Date();
            runner.connectSource(tool);
        }
    }

    // Tu nombre y tu foto: los mismos que en el panel rápido
    readonly property string tool: "/usr/lib/apogeo/apogeo-ajustes rapido"
    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            try { root.yo = JSON.parse(data.stdout); } catch (e) {}
            disconnectSource(source);
        }
    }
    Component.onCompleted: runner.connectSource(tool)

    property date ahora: new Date()
    Timer { interval: 1000; repeat: true; running: root.abierto; onTriggered: root.ahora = new Date() }

    function saludo() {
        const h = ahora.getHours();
        return h >= 6 && h < 14 ? "Buenos días" : h >= 14 && h < 21 ? "Buenas tardes" : "Buenas noches";
    }
    function capital(s) { return s.charAt(0).toUpperCase() + s.slice(1) }
    function mmss(s) { s = Math.max(0, Math.round(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
    function hm(s) { s = Math.round(s || 0); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? h + " h " + m + " min" : m + " min"; }
    function nuevoId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }
    function cielo(c) {
        if (c === 0) return ahora.getHours() >= 7 && ahora.getHours() < 20 ? "sol" : "luna";
        if (c <= 2) return "nubes-sol";
        if (c === 3) return "nube";
        if (c === 45 || c === 48) return "niebla";
        if (c >= 95) return "tormenta";
        if (c >= 71 && c <= 77 || c === 85 || c === 86) return "nieve";
        return "lluvia";
    }

    // ---------- Piezas ----------

    // Una tarjeta del panel: un poco más clara que el fondo
    component Tarjeta: Rectangle {
        default property alias contenido: caja.data
        property real relleno: 14
        width: parent ? parent.width : 0
        height: caja.childrenRect.height + 2 * relleno
        radius: Tema.r(18)
        color: Tema.encima
        Item { id: caja; x: parent.relleno; y: parent.relleno; width: parent.width - 2 * parent.relleno }
    }
    component Titulo: Row {
        property string icono
        property alias text: t.text
        spacing: 7
        Icono { nombre: parent.icono; color: Tema.rosa; width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter }
        Texto { id: t; color: Tema.tenue; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.9; font.capitalization: Font.AllUppercase; wrapMode: Text.NoWrap; anchors.verticalCenter: parent.verticalCenter }
    }
    component Barra: Rectangle {
        property real valor: 0
        height: 4; radius: 2
        color: Tema.pulsado
        Rectangle { height: parent.height; radius: 2; color: Tema.rosa; width: parent.width * Math.max(0, Math.min(1, parent.valor)) }
    }
    // Un arco: el fondo apagado y, encima, lo lleno en el color del piso
    component Arco: Shape {
        id: arco
        property real valor: 0
        property real grosor: 6
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Tema.pulsado
            strokeWidth: arco.grosor; fillColor: "transparent"
            PathAngleArc { centerX: arco.width / 2; centerY: arco.height / 2; radiusX: arco.width / 2 - arco.grosor; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: Tema.rosa
            strokeWidth: arco.grosor; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: arco.width / 2; centerY: arco.height / 2; radiusX: arco.width / 2 - arco.grosor; radiusY: radiusX; startAngle: -90; sweepAngle: 360 * Math.max(0, Math.min(1, arco.valor)) }
        }
    }
    component Anillo: Column {
        id: an
        property real valor: 0
        property string valorTexto
        property string nombre
        spacing: 6
        Item {
            width: 62; height: 62
            anchors.horizontalCenter: an.horizontalCenter
            Arco { anchors.fill: parent; valor: an.valor }
            Texto { anchors.centerIn: parent; text: an.valorTexto; font.pixelSize: 14; font.weight: Font.Bold; wrapMode: Text.NoWrap }
        }
        Texto { anchors.horizontalCenter: an.horizontalCenter; text: an.nombre; color: Tema.apagado; font.pixelSize: 11; wrapMode: Text.NoWrap }
    }
    // Un campo del panel (Esc lo vacía y lo deja)
    component CampoPanel: Campo {
        implicitHeight: 36
        font.pixelSize: 13
        Keys.onEscapePressed: { text = ""; focus = false; }
    }
    component Quitar: QQC2.AbstractButton {
        id: q
        width: 22; height: 22
        hoverEnabled: true
        contentItem: Item { Icono { anchors.centerIn: parent; nombre: "cerrar"; width: 11; height: 11; color: q.hovered ? Tema.texto : Tema.tenue } }
    }

    fullRepresentation: Item {
        id: vista
        Layout.minimumWidth: 300
        Layout.preferredWidth: 360
        Layout.fillWidth: true
        Layout.fillHeight: true

        Agenda { id: agenda; panel: vista }
        Connections {
            target: root
            function onAbiertoChanged() {
                if (root.abierto) notas.cargar();
                else agenda.visible = false;
            }
        }

        // ---------- Tú: la foto y el saludo ----------
        Item {
            id: cabeza
            x: 16; y: 18
            width: parent.width - 32
            height: 60
            Foto {
                id: foto
                width: 52; height: 52
                anchors.verticalCenter: parent.verticalCenter
                letra: (root.yo.nombre || "").charAt(0).toUpperCase()
                fuente: root.yo.foto ? "file://" + root.yo.foto : ""
                anillo: true
            }
            Column {
                x: foto.width + 14
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Texto { width: parent.width; text: root.saludo(); font.pixelSize: 22; font.weight: Font.Black; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                Texto {
                    width: parent.width
                    text: [root.yo.nombre || "", root.floorName].filter(Boolean).join(" · ")
                    color: Tema.apagado; font.pixelSize: 13; elide: Text.ElideRight; wrapMode: Text.NoWrap
                }
            }
        }

        Segmentos {
            id: pestanas
            anchors.horizontalCenter: parent.horizontalCenter
            y: cabeza.y + cabeza.height + 16
            readonly property var nombres: ({ widgets: { texto: "Widgets", icono: "apps" }, estudios: { texto: "Estudios", icono: "estudiar" }, notas: { texto: "Notas", icono: "lapiz" } })
            opciones: root.tabs.map(t => nombres[t])
            actual: Math.max(0, root.tabs.indexOf(root.tab))
            onElegido: i => root.tab = root.tabs[i]
        }

        Item {
            id: cuerpo
            x: 12
            y: pestanas.y + pestanas.height + 14
            width: parent.width - 24
            height: parent.height - y - 12

            // ======================= Widgets =======================
            Flickable {
                anchors.fill: parent
                visible: root.tab === "widgets"
                contentHeight: widgets.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: widgets
                    width: parent.width
                    spacing: 10

                    // --- Lo que suena ---
                    Tarjeta {
                        id: musica
                        readonly property var p: mpris.currentPlayer
                        Mpris.Mpris2Model { id: mpris }
                        Item {
                            width: parent.width
                            height: musica.p ? 90 : 20
                            Texto { visible: !musica.p; text: "Nada sonando"; color: Tema.apagado }
                            Icono { visible: !musica.p; anchors.right: parent.right; nombre: "musica"; color: Tema.tenue }
                            Row {
                                visible: !!musica.p
                                width: parent.width
                                spacing: 12
                                Rectangle {
                                    width: 72; height: 72; radius: Tema.r(14)
                                    color: Tema.rosaSuave
                                    clip: true
                                    Icono { anchors.centerIn: parent; nombre: "musica"; color: Tema.rosa }
                                    Image { anchors.fill: parent; source: musica.p ? musica.p.artUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                }
                                Column {
                                    width: parent.width - 84
                                    spacing: 2
                                    Texto { width: parent.width; text: musica.p ? musica.p.track : ""; font.pixelSize: 15; font.weight: Font.Bold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                    Texto { width: parent.width; text: musica.p ? [musica.p.artist, musica.p.identity].filter(Boolean).join(" · ") : ""; color: Tema.apagado; font.pixelSize: 12; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                    Row {
                                        topPadding: 6
                                        spacing: 6
                                        Boton { tipo: "plano"; icono: "anterior"; implicitHeight: 30; enabled: musica.p && musica.p.canGoPrevious; onClicked: musica.p.Previous() }
                                        Boton { tipo: "principal"; icono: musica.p && musica.p.playbackStatus === Mpris.PlaybackStatus.Playing ? "pausa" : "reproducir"; implicitHeight: 30; implicitWidth: 42; onClicked: musica.p.PlayPause() }
                                        Boton { tipo: "plano"; icono: "siguiente"; implicitHeight: 30; enabled: musica.p && musica.p.canGoNext; onClicked: musica.p.Next() }
                                    }
                                }
                            }
                            Barra {
                                visible: !!musica.p
                                anchors.bottom: parent.bottom; width: parent.width
                                valor: musica.p && musica.p.length > 0 ? musica.p.position / musica.p.length : 0
                            }
                        }
                    }

                    // --- La semana (abre la agenda) y el tiempo ---
                    Tarjeta {
                        id: semana
                        Item {
                            width: parent.width; height: 18
                            Titulo { icono: "calendario"; text: root.capital(Qt.locale("es_ES").toString(root.ahora, "MMMM")) }
                            Texto { anchors.right: parent.right; text: "Agenda ›"; color: Tema.apagado; font.pixelSize: 12 }
                        }
                        Row {
                            id: dias
                            y: 28
                            width: parent.width
                            readonly property date lunes: { const d = new Date(root.ahora); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - (d.getDay() + 6) % 7); return d; }
                            Repeater {
                                model: 7
                                delegate: Rectangle {
                                    id: dia
                                    required property int index
                                    readonly property date fecha: { const d = new Date(dias.lunes); d.setDate(d.getDate() + index); return d; }
                                    readonly property bool hoy: fecha.toDateString() === root.ahora.toDateString()
                                    width: dias.width / 7; height: 52
                                    radius: Tema.r(14)
                                    color: hoy ? Tema.rosa : "transparent"
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        Texto { anchors.horizontalCenter: parent.horizontalCenter; text: "LMXJVSD"[dia.index]; font.pixelSize: 11; color: dia.hoy ? Tema.sobreRosa : Tema.tenue }
                                        Texto { anchors.horizontalCenter: parent.horizontalCenter; text: dia.fecha.getDate(); font.pixelSize: 15; font.weight: Font.Bold; color: dia.hoy ? Tema.sobreRosa : Tema.texto }
                                    }
                                }
                            }
                        }
                        // El tiempo de tu ciudad, en una línea
                        Item {
                            y: dias.y + dias.height + 10
                            width: parent.width
                            height: visible ? 34 : 0
                            visible: root.tiempo.temp !== undefined || !!root.tiempo.sinCiudad
                            Rectangle { width: parent.width; height: 1; color: Tema.linea }
                            Icono { y: 12; width: 20; height: 20; nombre: root.cielo(root.tiempo.codigo); color: Tema.rosa }
                            Texto {
                                x: 30; y: 12
                                width: parent.width - x - (minmax.visible ? minmax.width + 8 : 0)
                                text: root.tiempo.sinCiudad ? "Elige tu ciudad para ver el tiempo" : root.tiempo.temp + "° · " + (root.tiempo.ciudad || "")
                                font.weight: root.tiempo.sinCiudad ? Font.Normal : Font.Bold
                                color: root.tiempo.sinCiudad ? Tema.apagado : Tema.texto
                                elide: Text.ElideRight; wrapMode: Text.NoWrap
                            }
                            Texto { id: minmax; y: 12; anchors.right: parent.right; visible: root.tiempo.max !== undefined; text: root.tiempo.max + "° / " + root.tiempo.min + "°"; color: Tema.apagado; font.pixelSize: 13 }
                        }
                        MouseArea { // (toda la tarjeta: fuera de su contenido, que si no la estira)
                            parent: semana
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (agenda.visible) { agenda.visible = false; return; }
                                agenda.ancla = semana;
                                agenda.open();
                            }
                        }
                    }

                    // --- Tu PC ---
                    Tarjeta {
                        Titulo { icono: "temperatura"; text: "Tu PC" }
                        Row {
                            id: anillos
                            y: 28
                            width: parent.width
                            readonly property var cosas: [
                                { n: "CPU", v: (root.pc.cpu || 0) + "%", p: (root.pc.cpu || 0) / 100 },
                                { n: "RAM", v: (root.pc.mem || 0) + "%", p: (root.pc.mem || 0) / 100 },
                                { n: "Temp.", v: (root.pc.temp || 0) + "°", p: (root.pc.temp || 0) / 100 }
                            ].concat(root.pc.gpu >= 0 ? [{ n: "Gráfica", v: root.pc.gpu + "%", p: root.pc.gpu / 100 }] : [])
                            Repeater {
                                model: anillos.cosas
                                delegate: Item {
                                    id: cosa
                                    required property var modelData
                                    width: anillos.width / anillos.cosas.length; height: 88
                                    Anillo { anchors.horizontalCenter: cosa.horizontalCenter; valor: cosa.modelData.p; valorTexto: cosa.modelData.v; nombre: cosa.modelData.n }
                                }
                            }
                        }
                    }

                    // --- Relojes del mundo ---
                    Tarjeta {
                        Titulo { icono: "reloj"; text: "Relojes" }
                        Column {
                            id: listaRelojes
                            y: 26
                            width: parent.width
                            Repeater {
                                model: root.relojes
                                delegate: Item {
                                    id: rel
                                    required property var modelData
                                    required property int index
                                    width: listaRelojes.width; height: 44
                                    Rectangle { width: parent.width; height: 1; color: Tema.linea; visible: rel.index > 0 }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Texto { text: rel.modelData.nombre; font.weight: Font.Bold; wrapMode: Text.NoWrap }
                                        Texto {
                                            text: rel.modelData.dia + (rel.modelData.dif ? " · " + rel.modelData.dif : "")
                                            color: Tema.apagado; font.pixelSize: 11; wrapMode: Text.NoWrap
                                        }
                                    }
                                    Texto {
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        text: rel.modelData.hora
                                        font.pixelSize: 22; font.weight: Font.Black
                                        color: rel.modelData.aqui ? Tema.rosa : Tema.texto
                                    }
                                }
                            }
                        }
                    }

                    // --- Tus fondos, para este piso ---
                    Tarjeta {
                        id: aura
                        readonly property string actual: root.fondos && root.fondos.pisos ? root.fondos.pisos[root.floor] : ""
                        function poner(valor) {
                            datos.hacer("PonerFondo", [root.floor, valor]);
                            const l = Object.assign({}, root.fondos); l.pisos = Object.assign({}, l.pisos); l.pisos[root.floor] = valor;
                            root.fondos = l;
                        }
                        Item {
                            width: parent.width; height: 18
                            Titulo { icono: "imagen"; text: "Fondo de " + root.floorName }
                            Texto {
                                anchors.right: parent.right
                                text: "Aura ›"; color: Tema.apagado; font.pixelSize: 12
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: datos.hacer("Abrir", ["aura"]) }
                            }
                        }
                        Flickable {
                            y: 28
                            width: parent.width; height: 66
                            contentWidth: miniaturas.implicitWidth
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: miniaturas
                                y: 3
                                spacing: 10
                                leftPadding: 3; rightPadding: 3
                                Repeater {
                                    model: root.fondos ? (root.fondos.aura || []).concat(root.fondos.animados || []) : []
                                    delegate: Item {
                                        id: mini
                                        required property var modelData
                                        readonly property bool on: modelData.valor === aura.actual
                                        width: 106; height: 60
                                        Fondo { anchors.fill: parent; visible: mini.modelData.tipo === "animado"; tipo: mini.modelData.indice || 0; radio: 10 }
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: mini.modelData.tipo !== "animado"
                                            radius: Tema.r(10); color: Tema.pulsado; clip: true
                                            Image { anchors.fill: parent; source: mini.modelData.mini || ""; sourceSize: Qt.size(212, 120); fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                            Icono { anchors.centerIn: parent; visible: !!mini.modelData.video && !mini.modelData.mini; nombre: "video"; color: Tema.rosa }
                                        }
                                        Rectangle {
                                            anchors.fill: parent; anchors.margins: -3; radius: Tema.r(13); color: "transparent"; border.width: 2
                                            border.color: mini.on ? Tema.rosa : zonaMini.containsMouse ? Tema.borde : "transparent"
                                        }
                                        MouseArea { id: zonaMini; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: aura.poner(mini.modelData.valor) }
                                        QQC2.ToolTip.visible: zonaMini.containsMouse
                                        QQC2.ToolTip.text: modelData.nombre || ""
                                        QQC2.ToolTip.delay: 600
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ======================= Estudios =======================
            Flickable {
                anchors.fill: parent
                visible: root.tab === "estudios"
                contentHeight: estudios.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: estudios
                    width: parent.width
                    spacing: 10

                    // --- El temporizador ---
                    Tarjeta {
                        id: reloj
                        readonly property real total: root.estudio.total || 1500
                        readonly property real quedan: root.estudio.quedan !== undefined ? root.estudio.quedan : 1500
                        Item {
                            width: parent.width; height: 18
                            Titulo {
                                icono: "reloj"
                                text: root.estudio.fase === "estudio" || !root.estudio.fase ? "Estudio · " + ((root.estudio.ciclo - 1) % 4 + 1 || 1) + " de 4"
                                    : root.estudio.fase === "largo" ? "Descanso largo" : "Descanso"
                            }
                            Texto { anchors.right: parent.right; text: "Hoy " + root.hm(root.estudio.hoy); color: Tema.apagado; font.pixelSize: 12 }
                        }
                        Item {
                            id: anillo
                            y: 30
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 170; height: 170
                            Arco { anchors.fill: parent; grosor: 9; valor: 1 - reloj.quedan / reloj.total }
                            Column {
                                anchors.centerIn: parent
                                Texto { anchors.horizontalCenter: parent.horizontalCenter; text: root.mmss(reloj.quedan); font.pixelSize: 38; font.weight: Font.ExtraBold; font.letterSpacing: -1 }
                                Texto {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(implicitWidth, 120)
                                    text: root.estudio.asignatura || "Elige asignatura"
                                    color: Tema.apagado; font.pixelSize: 13; elide: Text.ElideRight; wrapMode: Text.NoWrap
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { // pasa a la siguiente asignatura
                                            const n = root.asignaturas.map(a => a.nombre);
                                            if (!n.length) return;
                                            const i = n.indexOf(root.estudio.asignatura);
                                            datos.hacer("EstudioAccion", ["asignatura", n[(i + 1) % n.length]]);
                                        }
                                    }
                                }
                            }
                        }
                        Row {
                            y: anillo.y + anillo.height + 14
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6
                            Boton { tipo: "principal"; text: root.estudio.corriendo ? "Pausa" : "Empezar"; onClicked: datos.hacer("EstudioAccion", ["alternar", ""]) }
                            Boton { text: "Saltar"; onClicked: datos.hacer("EstudioAccion", ["saltar", ""]) }
                            Boton { tipo: "plano"; icono: "deshacer"; onClicked: datos.hacer("EstudioAccion", ["reiniciar", ""]) }
                        }
                    }

                    // --- Exámenes ---
                    Tarjeta {
                        Titulo { icono: "calendario"; text: "Exámenes" }
                        Column {
                            id: listaEx
                            y: 26
                            width: parent.width
                            spacing: 10
                            Texto { visible: !root.examenes.length; width: parent.width; text: "Apunta tus exámenes y verás cuánto falta."; color: Tema.apagado; font.pixelSize: 13 }
                            Repeater {
                                model: root.examenes.filter(e => new Date(e.fecha + "T23:59") >= root.ahora).slice(0, 5)
                                delegate: Column {
                                    id: ex
                                    required property var modelData
                                    readonly property int dias: Math.ceil((new Date(modelData.fecha + "T00:00") - new Date(new Date(root.ahora).setHours(0, 0, 0, 0))) / 864e5)
                                    width: listaEx.width
                                    spacing: 4
                                    Item {
                                        width: parent.width; height: 20
                                        Texto { text: ex.modelData.asignatura; font.weight: Font.Bold; wrapMode: Text.NoWrap }
                                        Texto {
                                            anchors.right: borrarEx.left; anchors.rightMargin: 4
                                            text: ex.dias === 0 ? "¡hoy!" : ex.dias === 1 ? "mañana" : "en " + ex.dias + " días"
                                            color: ex.dias <= 3 ? Tema.rosa : Tema.apagado; font.pixelSize: 12; font.weight: Font.Bold
                                        }
                                        Quitar {
                                            id: borrarEx
                                            anchors.right: parent.right
                                            onClicked: {
                                                const l = root.examenes.filter(e => e.id !== ex.modelData.id);
                                                datos.hacer("GuardarExamenes", [JSON.stringify(l)]);  // (antes de cambiar la lista: al cambiarla, esta fila desaparece)
                                                root.examenes = l;
                                            }
                                        }
                                    }
                                    Barra { width: parent.width; valor: 1 - Math.min(ex.dias, 60) / 60 }
                                }
                            }
                            Row {
                                width: parent.width
                                spacing: 6
                                CampoPanel { id: exAsig; width: parent.width - exFecha.width - 6; placeholderText: "Asignatura" }
                                CampoPanel {
                                    id: exFecha
                                    width: 82
                                    placeholderText: "dd/mm"
                                    onAccepted: {
                                        const m = /^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?$/.exec(text.trim());
                                        if (!m || !exAsig.text.trim()) return;
                                        const hoy = new Date();
                                        let y = m[3] ? (m[3].length === 2 ? 2000 + +m[3] : +m[3]) : hoy.getFullYear();
                                        let d = new Date(y, +m[2] - 1, +m[1]);
                                        if (!m[3] && d < new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())) d = new Date(y + 1, +m[2] - 1, +m[1]);
                                        const f = d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
                                        const l = root.examenes.concat([{ id: root.nuevoId(), asignatura: exAsig.text.trim(), fecha: f }]).sort((a, b) => a.fecha.localeCompare(b.fecha));
                                        datos.hacer("GuardarExamenes", [JSON.stringify(l)]);
                                        root.examenes = l;
                                        exAsig.text = ""; text = "";
                                    }
                                }
                            }
                        }
                    }

                    // --- Hoy ---
                    Tarjeta {
                        Titulo { icono: "hecho"; text: "Hoy" }
                        Column {
                            id: listaT
                            y: 24
                            width: parent.width
                            Repeater {
                                model: root.tareas
                                delegate: Item {
                                    id: tarea
                                    required property var modelData
                                    required property int index
                                    width: listaT.width
                                    height: 36
                                    HoverHandler { id: sobreTarea }
                                    Rectangle { width: parent.width; height: 1; color: Tema.linea; visible: tarea.index > 0 }
                                    Rectangle {
                                        width: 20; height: 20; radius: Tema.r(7)
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: tarea.modelData.hecha ? Tema.rosa : "transparent"
                                        border.width: tarea.modelData.hecha ? 0 : 1.5
                                        border.color: Tema.tenue
                                        Icono { anchors.centerIn: parent; visible: tarea.modelData.hecha; nombre: "hecho"; width: 12; height: 12; color: Tema.sobreRosa }
                                    }
                                    Texto {
                                        x: 32
                                        width: parent.width - 60
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tarea.modelData.texto
                                        color: tarea.modelData.hecha ? Tema.tenue : Tema.texto
                                        font.strikeout: tarea.modelData.hecha
                                        elide: Text.ElideRight; wrapMode: Text.NoWrap
                                    }
                                    MouseArea {
                                        width: parent.width - 30; height: parent.height
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const l = root.tareas.map(t => t.id === tarea.modelData.id ? Object.assign({}, t, { hecha: !t.hecha }) : t);
                                            datos.hacer("GuardarTareas", [JSON.stringify(l)]);  // (antes de cambiar la lista: al cambiarla, esta fila desaparece)
                                            root.tareas = l;
                                        }
                                    }
                                    Quitar {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: sobreTarea.hovered
                                        onClicked: {
                                            const l = root.tareas.filter(t => t.id !== tarea.modelData.id);
                                            datos.hacer("GuardarTareas", [JSON.stringify(l)]);  // (antes de cambiar la lista: al cambiarla, esta fila desaparece)
                                            root.tareas = l;
                                        }
                                    }
                                }
                            }
                            Item { width: 1; height: 6 }
                            CampoPanel {
                                width: parent.width
                                placeholderText: "+ Añadir tarea"
                                onAccepted: {
                                    if (!text.trim()) return;
                                    const l = root.tareas.concat([{ id: root.nuevoId(), texto: text.trim(), hecha: false, asignatura: root.estudio.asignatura || "" }]);
                                    datos.hacer("GuardarTareas", [JSON.stringify(l)]);
                                    root.tareas = l;
                                    text = "";
                                }
                            }
                        }
                    }

                    // --- Tus asignaturas (~/Estudios): un clic abre su carpeta ---
                    Tarjeta {
                        Titulo { icono: "carpeta"; text: "Asignaturas" }
                        Column {
                            id: listaAsig
                            y: 24
                            width: parent.width
                            spacing: 2
                            Texto {
                                visible: !root.asignaturas.length
                                width: parent.width
                                color: Tema.apagado; font.pixelSize: 13
                                text: "Añade tus asignaturas: cada una tendrá sus carpetas de Temas, Trabajos y Ejercicios en ~/Estudios."
                            }
                            Repeater {
                                model: root.asignaturas
                                delegate: Rectangle {
                                    id: asig
                                    required property var modelData
                                    width: listaAsig.width; height: 34
                                    radius: Tema.r(10)
                                    color: zonaAsig.containsMouse ? Tema.pulsado : "transparent"
                                    Icono { x: 8; anchors.verticalCenter: parent.verticalCenter; nombre: "carpeta"; color: Tema.rosa; width: 15; height: 15 }
                                    Texto { x: 31; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter; text: asig.modelData.nombre; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                    MouseArea { id: zonaAsig; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally("file://" + asig.modelData.ruta) }
                                }
                            }
                            Item { width: 1; height: 6 }
                            CampoPanel {
                                width: parent.width
                                placeholderText: "+ Nueva asignatura"
                                onAccepted: {
                                    if (!text.trim()) return;
                                    datos.hacer("CrearAsignatura", [text.trim()]);
                                    text = "";
                                    refrescar.start();
                                }
                                Timer { id: refrescar; interval: 300; onTriggered: datos.pedir("Asignaturas", [], d => { if (d) root.asignaturas = d; }) }
                            }
                        }
                    }
                }
            }

            // ======================= Notas =======================
            Item {
                id: notas
                anchors.fill: parent
                visible: root.tab === "notas"
                // [papel, tinta] (los mismos tonos que tenían en el escritorio)
                readonly property var colores: [["#ffd1e6", "#3a1f30"], ["#e9d8f5", "#2e2140"], ["#f6e2c9", "#3a2a18"],
                                                ["#d3f0e0", "#1f3a2c"], ["#d6e6fb", "#1f2c3a"]]
                ListModel { id: modelo }
                function cargar() {
                    datos.pedir("Notas", [], d => {
                        if (!d) return;
                        modelo.clear();
                        for (const n of d) modelo.append({ nid: n.id, piso: n.piso, px: n.x, py: n.y, tono: n.color, giro: n.giro, texto: n.texto });
                    });
                }
                function guardar() {
                    const l = [];
                    for (let i = 0; i < modelo.count; i++) {
                        const n = modelo.get(i);
                        l.push({ id: n.nid, piso: n.piso, x: n.px, y: n.py, color: n.tono, giro: n.giro, texto: n.texto });
                    }
                    datos.hacer("PonerNotas", [JSON.stringify(l)]);
                }
                function poner() {
                    if (modelo.count >= 40) return;
                    const usados = Array.from({ length: modelo.count }, (_, i) => modelo.get(i).tono);
                    const tono = [0, 1, 2, 3, 4].find(c => usados.indexOf(c) < 0);
                    modelo.insert(0, { nid: root.nuevoId(), piso: root.floor, px: 0, py: 0, tono: tono !== undefined ? tono : modelo.count % 5, giro: 0, texto: "" });
                    lista.positionViewAtBeginning();
                    // La recién puesta empieza escribiéndose (cuando ya está en la lista)
                    Qt.callLater(() => { const n = lista.itemAtIndex(0); if (n) n.editor.forceActiveFocus(); });
                }
                function quitar(i) { modelo.remove(i); guardar(); }  // (desde aquí: la nota desaparece al quitarla)
                Timer { id: guardarLuego; interval: 700; onTriggered: notas.guardar() }

                Item {
                    id: barraNotas
                    width: parent.width; height: 36
                    Texto { anchors.verticalCenter: parent.verticalCenter; text: modelo.count === 1 ? "1 nota" : modelo.count + " notas"; color: Tema.apagado; font.pixelSize: 13 }
                    Boton { anchors.right: parent.right; tipo: "principal"; grande: false; text: "Nueva"; onClicked: notas.poner() }
                }
                Texto {
                    visible: modelo.count === 0
                    y: barraNotas.height + 16
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Tema.apagado; font.pixelSize: 13
                    text: "Sin notas. «Nueva» pone una; las ordenas arrastrándolas por los puntitos."
                }
                ListView {
                    id: lista
                    y: barraNotas.height + 10
                    width: parent.width
                    height: parent.height - y
                    model: modelo
                    spacing: 10
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: !arrastrando
                    property bool arrastrando: false
                    moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: 160; easing.type: Easing.OutCubic } }
                    delegate: Rectangle {
                        id: nota
                        required property int index
                        required property string nid
                        required property int tono
                        required property string texto
                        readonly property alias editor: area
                        readonly property color papel: notas.colores[tono][0]
                        readonly property color tinta: notas.colores[tono][1]
                        width: lista.width
                        height: Math.max(72, area.contentHeight + 26)
                        radius: Tema.r(16)
                        color: papel
                        // La raya de color a la izquierda (más oscura que el papel)
                        Rectangle { x: 0; width: 6; height: parent.height; radius: 3; color: Qt.darker(nota.papel, 1.35) }
                        // Arrastrar para ordenar
                        MouseArea {
                            id: asa
                            x: 10; width: 18; height: parent.height
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            preventStealing: true
                            onPressed: lista.arrastrando = true
                            onPositionChanged: mouse => {
                                const p = mapToItem(lista.contentItem, mouse.x, mouse.y);
                                const i = lista.indexAt(lista.width / 2, p.y);
                                if (i >= 0 && i !== nota.index) modelo.move(nota.index, i, 1);
                            }
                            onReleased: { lista.arrastrando = false; notas.guardar(); }
                            Grid {
                                anchors.centerIn: parent
                                columns: 2; spacing: 3
                                Repeater { model: 6; Rectangle { width: 3; height: 3; radius: 1.5; color: nota.tinta; opacity: 0.45 } }
                            }
                        }
                        QQC2.TextArea {
                            id: area
                            x: 30; y: 4
                            width: parent.width - x - 40
                            height: parent.height - 8
                            text: nota.texto
                            color: nota.tinta
                            placeholderText: "Escribe aquí…"
                            placeholderTextColor: Qt.rgba(nota.tinta.r, nota.tinta.g, nota.tinta.b, 0.45)
                            selectionColor: nota.tinta
                            selectedTextColor: nota.papel
                            font.family: Tema.letra
                            font.pixelSize: 14
                            wrapMode: TextEdit.Wrap
                            background: null
                            Keys.onEscapePressed: focus = false
                            onTextChanged: if (text !== nota.texto) { modelo.setProperty(nota.index, "texto", text); guardarLuego.restart(); }
                        }
                        // Arriba a la derecha, al pasar el ratón: el color y quitar
                        HoverHandler { id: encima }
                        Column {
                            anchors.right: parent.right; anchors.rightMargin: 8
                            y: 8
                            spacing: 6
                            visible: encima.hovered
                            QQC2.AbstractButton {
                                id: tonoB
                                width: 22; height: 22
                                hoverEnabled: true
                                onClicked: { modelo.setProperty(nota.index, "tono", (nota.tono + 1) % 5); notas.guardar(); }
                                contentItem: Item { Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: notas.colores[(nota.tono + 1) % 5][0]; border.width: 1.5; border.color: nota.tinta } }
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: "Otro color"
                            }
                            QQC2.AbstractButton {
                                id: quitarB
                                width: 22; height: 22
                                hoverEnabled: true
                                onClicked: notas.quitar(nota.index)
                                contentItem: Item { Icono { anchors.centerIn: parent; nombre: "cerrar"; width: 11; height: 11; color: nota.tinta } }
                                QQC2.ToolTip.visible: hovered
                                QQC2.ToolTip.text: "Quitar"
                            }
                        }
                    }
                }
                Component.onCompleted: cargar()
            }
        }
    }
}
