import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Shapes
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.notificationmanager as NotificationManager
import org.kde.taskmanager as TaskManager
import org.kde.kirigami as Kirigami
import Apogeo

// El escritorio de Apogeo (sin iconos de apps), según el piso:
//  - Navegar («N13 · Una fila abajo»): la hora grande arriba con la fecha y el tiempo, y abajo, encima de la isla, una
//    fila de widgets: lo que suena, los avisos, lo próximo del calendario de Ágape y tu PC.
//  - Estudiar («E6 · La carpeta a la izquierda»): tu carpeta ~/Estudios (asignaturas con Temas, Trabajos y Ejercicios)
//    a la izquierda, el temporizador grande, los exámenes con lo que falta y las tareas de hoy.
//  - Jugar: nada (está la consola).
// Los datos los da apogeo-pisos (Datos, por D-Bus); solo se piden con el escritorio a la vista.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.VirtualDesktopInfo { id: desktops }
    readonly property int floorIndex: Math.max(0, desktops.desktopIds.indexOf(desktops.currentDesktop))
    readonly property string floor: ["jugar", "navegar", "estudiar"][floorIndex] || "navegar"

    Datos { id: datos }
    property var tiempo: ({})
    property var proximo: []
    property var pc: ({})
    property var estudio: ({})
    property var asignaturas: []
    property var tareas: []
    property var examenes: []
    property string abierta: ""         // la asignatura desplegada
    property string carpeta: ""         // la carpeta de la que se ven los archivos

    function cargar(lento) {
        if (root.floor === "navegar") {
            if (lento) { datos.pedir("Tiempo", [], d => { if (d) root.tiempo = d; }); datos.pedir("Proximo", [], d => { if (d) root.proximo = d; }); }
            datos.pedir("Pc", [], d => { if (d) root.pc = d; });
        } else if (root.floor === "estudiar") {
            datos.pedir("Estudio", [], d => { if (d) root.estudio = d; });
            if (lento) {
                datos.pedir("Asignaturas", [], d => {
                    if (!d) return;
                    root.asignaturas = d;
                    if (!root.abierta && d.length) root.abierta = d[0].nombre;
                });
                datos.pedir("Tareas", [], d => { if (d) root.tareas = d; });
                datos.pedir("Examenes", [], d => { if (d) root.examenes = d; });
            }
        }
    }
    property int vuelta: 0
    Timer {
        interval: root.floor === "estudiar" ? 1000 : 3000
        repeat: true
        running: root.floor !== "jugar"
        triggeredOnStart: true
        onTriggered: { root.cargar(root.vuelta % (root.floor === "estudiar" ? 10 : 20) === 0); root.vuelta++; }
    }
    onFloorChanged: { vuelta = 0; cargar(true); }

    property date ahora: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.ahora = new Date() }
    function hm(s) { s = Math.round(s || 0); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? h + " h " + m + " min" : m + " min"; }
    function mmss(s) { s = Math.max(0, Math.round(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
    function cielo(c) {
        if (c === 0) return "despejado";
        if (c <= 2) return "poco nuboso";
        if (c === 3) return "nublado";
        if (c === 45 || c === 48) return "niebla";
        if (c >= 51 && c <= 67 || c >= 80 && c <= 82) return "lluvia";
        if (c >= 71 && c <= 86) return "nieve";
        if (c >= 95) return "tormenta";
        return "";
    }
    function cuando(p) {
        const d = p.dias === 0 ? "Hoy" : p.dias === 1 ? "Mañana" : Qt.locale("es_ES").toString(new Date(p.fecha + "T00:00"), "ddd d");
        return d.charAt(0).toUpperCase() + d.slice(1) + (p.hora ? " " + p.hora : "");
    }
    function nuevoId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }

    // ---------- Piezas ----------

    component Tarjeta: Rectangle {
        default property alias contenido: caja.data
        property real relleno: 16
        radius: 22
        color: Qt.rgba(30 / 255, 22 / 255, 33 / 255, 0.62)
        border.color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.09)
        Rectangle { x: parent.radius; y: 1; width: parent.width - 2 * parent.radius; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }
        Item { id: caja; anchors.fill: parent; anchors.margins: parent.relleno }
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
        color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.14)
        Rectangle { height: parent.height; radius: 2; color: Tema.rosa; width: parent.width * Math.max(0, Math.min(1, parent.valor)) }
    }

    fullRepresentation: Item {
        id: lienzo
        // ======================= Navegar =======================
        Item {
            anchors.fill: parent
            visible: root.floor === "navegar"

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.14
                spacing: 6
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(root.ahora, "HH:mm")
                    font.pixelSize: Math.min(150, lienzo.height * 0.17)
                    font.weight: Font.ExtraBold
                    font.letterSpacing: -2
                    style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.15)
                }
                Texto {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Tema.apagado
                    font.pixelSize: 17
                    text: {
                        const d = Qt.locale("es_ES").toString(root.ahora, "dddd d 'de' MMMM");
                        const t = root.tiempo && root.tiempo.temp !== undefined ? " · " + root.tiempo.temp + "° " + root.cielo(root.tiempo.codigo) : "";
                        return d.charAt(0).toUpperCase() + d.slice(1) + t;
                    }
                }
            }

            Row {
                id: fila
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 92
                spacing: 12

                // --- Lo que suena ---
                Tarjeta {
                    id: musica
                    width: 300; height: 158
                    readonly property var p: mpris.currentPlayer
                    visible: !!p
                    Mpris.Mpris2Model { id: mpris }
                    clip: true
                    Image { // la portada, desenfocada, de fondo
                        anchors.fill: parent
                        source: musica.p ? musica.p.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        opacity: 0.32
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48 }
                    }
                    Row {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            width: 56; height: 56; radius: 13
                            color: Tema.rosaSuave
                            clip: true
                            Icono { anchors.centerIn: parent; nombre: "musica"; color: Tema.rosa }
                            Image { anchors.fill: parent; source: musica.p ? musica.p.artUrl : ""; fillMode: Image.PreserveAspectCrop }
                        }
                        Column {
                            width: parent.width - 68
                            anchors.verticalCenter: parent.verticalCenter
                            Texto { width: parent.width; text: musica.p ? musica.p.track : ""; font.weight: Font.Bold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                            Texto { width: parent.width; text: musica.p ? [musica.p.artist, musica.p.identity].filter(Boolean).join(" · ") : ""; color: Tema.apagado; font.pixelSize: 12; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                            Item { width: 1; height: 8 }
                            Barra { width: parent.width; valor: musica.p && musica.p.length > 0 ? musica.p.position / musica.p.length : 0 }
                        }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        spacing: 6
                        Boton { tipo: "plano"; icono: "anterior"; implicitHeight: 30; enabled: musica.p && musica.p.canGoPrevious; onClicked: musica.p.Previous() }
                        Boton { tipo: "principal"; icono: musica.p && musica.p.playbackStatus === Mpris.PlaybackStatus.Playing ? "pausa" : "reproducir"; implicitHeight: 30; implicitWidth: 42; onClicked: musica.p.PlayPause() }
                        Boton { tipo: "plano"; icono: "siguiente"; implicitHeight: 30; enabled: musica.p && musica.p.canGoNext; onClicked: musica.p.Next() }
                    }
                }

                // --- Avisos ---
                Tarjeta {
                    width: 300; height: 158
                    NotificationManager.Notifications {
                        id: avisos
                        showExpired: true
                        showDismissed: true
                        showJobs: false
                        limit: 3
                        sortMode: NotificationManager.Notifications.SortByDate
                        groupMode: NotificationManager.Notifications.GroupDisabled
                    }
                    Titulo { icono: "campana"; text: "Avisos" }
                    Column {
                        y: 22
                        width: parent.width
                        spacing: 4
                        Texto { visible: avisos.count === 0; text: "Nada nuevo"; color: Tema.apagado; topPadding: 20 }
                        Repeater {
                            model: avisos
                            delegate: Row {
                                required property string summary
                                required property string applicationName
                                required property string applicationIconName
                                required property var created
                                width: parent.width
                                spacing: 9
                                height: 36
                                Kirigami.Icon { width: 22; height: 22; source: parent.applicationIconName || "apogeo"; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    width: parent.width - 31
                                    anchors.verticalCenter: parent.verticalCenter
                                    Texto { width: parent.width; text: parent.parent.summary; font.pixelSize: 13; font.weight: Font.Bold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                    Texto { width: parent.width; text: parent.parent.applicationName; color: Tema.tenue; font.pixelSize: 11; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                }
                            }
                        }
                    }
                }

                // --- Lo próximo y tu PC ---
                Column {
                    spacing: 12
                    Tarjeta {
                        width: 240; height: 73
                        relleno: 14
                        Titulo { icono: "calendario"; text: "Próximo" }
                        Texto {
                            y: 20; width: parent.width
                            text: root.proximo.length ? root.proximo[0].texto : "Nada apuntado"
                            font.weight: Font.Bold; elide: Text.ElideRight; wrapMode: Text.NoWrap
                        }
                        Texto { y: 39; text: root.proximo.length ? root.cuando(root.proximo[0]) : "En el calendario de Ágape"; color: Tema.apagado; font.pixelSize: 12 }
                    }
                    Tarjeta {
                        width: 240; height: 73
                        relleno: 14
                        Titulo { icono: "temperatura"; text: "Tu PC" }
                        Row {
                            y: 24
                            width: parent.width
                            spacing: 14
                            Repeater {
                                model: [{ n: "Temp.", v: (root.pc.temp || 0) + "°", p: (root.pc.temp || 0) / 100 }, { n: "CPU", v: (root.pc.cpu || 0) + "%", p: (root.pc.cpu || 0) / 100 }]
                                delegate: Column {
                                    required property var modelData
                                    width: (parent.width - 14) / 2
                                    spacing: 5
                                    Item {
                                        width: parent.width; height: 16
                                        Texto { text: parent.parent.modelData.n; color: Tema.apagado; font.pixelSize: 12 }
                                        Texto { anchors.right: parent.right; text: parent.parent.modelData.v; font.pixelSize: 12; font.weight: Font.Bold }
                                    }
                                    Barra { width: parent.width; valor: parent.modelData.p }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ======================= Estudiar =======================
        Item {
            anchors.fill: parent
            anchors.margins: 50
            anchors.topMargin: 60
            anchors.bottomMargin: 90
            visible: root.floor === "estudiar"

            // --- Tu carpeta ---
            Tarjeta {
                id: arbol
                width: 330
                height: parent.height
                Titulo { icono: "carpeta"; text: "Estudios" }
                Flickable {
                    y: 26
                    width: parent.width
                    height: parent.height - 26 - nueva.height - 8
                    contentHeight: listaAsig.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: listaAsig
                        width: parent.width
                        spacing: 2
                        Texto {
                            visible: !root.asignaturas.length
                            width: parent.width
                            color: Tema.apagado
                            topPadding: 8
                            text: "Añade tus asignaturas abajo. Cada una tendrá sus carpetas de Temas, Trabajos y Ejercicios en ~/Estudios."
                        }
                        Repeater {
                            model: root.asignaturas
                            delegate: Column {
                                id: asig
                                required property var modelData
                                readonly property bool abierta: root.abierta === modelData.nombre
                                width: listaAsig.width
                                spacing: 2
                                Fila_ {
                                    texto: asig.modelData.nombre
                                    icono: "carpeta"
                                    on: asig.abierta
                                    onPulsado: root.abierta = asig.abierta ? "" : asig.modelData.nombre
                                    onDoble: Qt.openUrlExternally("file://" + asig.modelData.ruta)
                                }
                                Repeater {
                                    model: asig.abierta ? asig.modelData.carpetas : []
                                    delegate: Column {
                                        id: sub
                                        required property var modelData
                                        readonly property bool vista: root.carpeta === modelData.ruta
                                        width: listaAsig.width
                                        Fila_ {
                                            sangria: 22
                                            texto: sub.modelData.nombre
                                            extra: sub.modelData.cuantos ? String(sub.modelData.cuantos) : ""
                                            icono: "carpeta"
                                            on: sub.vista
                                            onPulsado: root.carpeta = sub.vista ? "" : sub.modelData.ruta
                                            onDoble: Qt.openUrlExternally("file://" + sub.modelData.ruta)
                                        }
                                        Repeater {
                                            model: sub.vista ? sub.modelData.archivos : []
                                            delegate: Fila_ {
                                                required property var modelData
                                                sangria: 44
                                                texto: modelData.nombre
                                                icono: "copia"
                                                tenue: true
                                                onPulsado: Qt.openUrlExternally("file://" + modelData.ruta)
                                            }
                                        }
                                        Fila_ {
                                            visible: sub.vista
                                            sangria: 44
                                            texto: sub.modelData.cuantos ? "Abrir la carpeta" : "Vacía · abrir la carpeta"
                                            icono: "flecha"
                                            tenue: true
                                            onPulsado: Qt.openUrlExternally("file://" + sub.modelData.ruta)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Campo {
                    id: nueva
                    anchors.bottom: parent.bottom
                    width: parent.width
                    implicitHeight: 36
                    font.pixelSize: 13
                    placeholderText: "+ Nueva asignatura"
                    onAccepted: {
                        if (!text.trim()) return;
                        datos.hacer("CrearAsignatura", [text.trim()]);
                        root.abierta = text.trim();
                        text = "";
                        refrescar.start();
                    }
                }
                Timer { id: refrescar; interval: 300; onTriggered: datos.pedir("Asignaturas", [], d => { if (d) root.asignaturas = d; }) }
            }

            // --- El temporizador ---
            Tarjeta {
                id: reloj
                x: arbol.width + 20
                width: parent.width - x - examenesT.width - 20
                height: parent.height * 0.6
                readonly property real total: root.estudio.total || 1500
                readonly property real quedan: root.estudio.quedan !== undefined ? root.estudio.quedan : 1500
                Titulo {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icono: "reloj"
                    text: root.estudio.fase === "estudio" || !root.estudio.fase ? "Estudio · " + ((root.estudio.ciclo - 1) % 4 + 1 || 1) + " de 4"
                        : root.estudio.fase === "largo" ? "Descanso largo" : "Descanso"
                }
                Item {
                    id: anillo
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -12
                    readonly property real lado: Math.min(parent.width, parent.height - 90)
                    width: lado; height: lado
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.12)
                            strokeWidth: 11; fillColor: "transparent"
                            PathAngleArc { centerX: anillo.lado / 2; centerY: anillo.lado / 2; radiusX: anillo.lado / 2 - 8; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                        }
                        ShapePath {
                            strokeColor: Tema.rosa
                            strokeWidth: 11; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                            PathAngleArc { centerX: anillo.lado / 2; centerY: anillo.lado / 2; radiusX: anillo.lado / 2 - 8; radiusY: radiusX; startAngle: -90; sweepAngle: 360 * (1 - reloj.quedan / reloj.total) }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        Texto { anchors.horizontalCenter: parent.horizontalCenter; text: root.mmss(reloj.quedan); font.pixelSize: anillo.lado * 0.22; font.weight: Font.ExtraBold; font.letterSpacing: -1 }
                        Texto {
                            id: asigReloj
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.estudio.asignatura || "Elige asignatura"
                            color: Tema.apagado; font.pixelSize: 15
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
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    spacing: 6
                    Boton { tipo: "principal"; text: root.estudio.corriendo ? "Pausa" : "Empezar"; icono: root.estudio.corriendo ? "pausa" : "reproducir"; onClicked: datos.hacer("EstudioAccion", ["alternar", ""]) }
                    Boton { text: "Saltar"; onClicked: datos.hacer("EstudioAccion", ["saltar", ""]) }
                    Boton { text: "Reiniciar"; onClicked: datos.hacer("EstudioAccion", ["reiniciar", ""]) }
                }
                Texto {
                    anchors.right: parent.right; anchors.top: parent.top
                    text: "Hoy " + root.hm(root.estudio.hoy)
                    color: Tema.apagado; font.pixelSize: 12
                }
            }

            // --- Exámenes ---
            Tarjeta {
                id: examenesT
                anchors.right: parent.right
                width: 290
                height: reloj.height
                Titulo { icono: "calendario"; text: "Exámenes" }
                Column {
                    y: 26
                    width: parent.width
                    spacing: 10
                    Texto { visible: !root.examenes.length; width: parent.width; text: "Apunta tus exámenes y verás cuánto falta."; color: Tema.apagado }
                    Repeater {
                        model: root.examenes.filter(e => new Date(e.fecha + "T23:59") >= root.ahora).slice(0, 5)
                        delegate: Column {
                            id: ex
                            required property var modelData
                            readonly property int dias: Math.ceil((new Date(modelData.fecha + "T00:00") - new Date(new Date(root.ahora).setHours(0, 0, 0, 0))) / 864e5)
                            width: parent.width
                            spacing: 4
                            Item {
                                width: parent.width; height: 18
                                Texto { text: ex.modelData.asignatura; font.weight: Font.Bold }
                                QQC2.AbstractButton {
                                    id: borrar
                                    anchors.right: parent.right
                                    width: 18; height: 18
                                    hoverEnabled: true
                                    contentItem: Icono { nombre: "cerrar"; width: 11; height: 11; color: borrar.hovered ? Tema.texto : Tema.tenue }
                                    onClicked: {
                                        const l = root.examenes.filter(e => e.id !== ex.modelData.id);
                                        root.examenes = l;
                                        datos.hacer("GuardarExamenes", [JSON.stringify(l)]);
                                    }
                                }
                            }
                            Texto {
                                text: Qt.locale("es_ES").toString(new Date(ex.modelData.fecha + "T00:00"), "dddd d") + " · " + (ex.dias === 0 ? "¡hoy!" : ex.dias === 1 ? "mañana" : "en " + ex.dias + " días")
                                color: Tema.apagado; font.pixelSize: 12
                            }
                            Barra { width: parent.width; valor: 1 - Math.min(ex.dias, 60) / 60 }
                        }
                    }
                }
                Row {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    spacing: 6
                    Campo { id: exAsig; width: parent.width - exFecha.width - 6; implicitHeight: 34; font.pixelSize: 12; placeholderText: "Asignatura" }
                    Campo {
                        id: exFecha
                        width: 88; implicitHeight: 34; font.pixelSize: 12
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
                            root.examenes = l;
                            datos.hacer("GuardarExamenes", [JSON.stringify(l)]);
                            exAsig.text = ""; text = "";
                        }
                    }
                }
            }

            // --- Hoy ---
            Tarjeta {
                x: reloj.x
                y: reloj.height + 20
                width: parent.width - x
                height: parent.height - y
                Titulo { icono: "hecho"; text: "Hoy" }
                Flickable {
                    y: 24
                    width: parent.width
                    height: parent.height - 24 - nuevaTarea.height - 6
                    contentHeight: listaT.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: listaT
                        width: parent.width
                        Repeater {
                            model: root.tareas
                            delegate: Item {
                                id: tarea
                                required property var modelData
                                required property int index
                                width: listaT.width
                                height: 36
                                Rectangle { width: parent.width; height: 1; color: Tema.linea; visible: tarea.index > 0 }
                                Rectangle {
                                    id: caja
                                    width: 20; height: 20; radius: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: tarea.modelData.hecha ? Tema.rosa : "transparent"
                                    border.width: tarea.modelData.hecha ? 0 : 1.5
                                    border.color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.3)
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
                                    id: marcar
                                    width: parent.width - 30; height: parent.height
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const l = root.tareas.map(t => t.id === tarea.modelData.id ? Object.assign({}, t, { hecha: !t.hecha }) : t);
                                        root.tareas = l;
                                        datos.hacer("GuardarTareas", [JSON.stringify(l)]);
                                    }
                                }
                                QQC2.AbstractButton {
                                    id: quitar
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22; height: 22
                                    hoverEnabled: true
                                    visible: marcar.containsMouse || hovered
                                    contentItem: Icono { nombre: "cerrar"; width: 11; height: 11; color: quitar.hovered ? Tema.texto : Tema.tenue }
                                    onClicked: {
                                        const l = root.tareas.filter(t => t.id !== tarea.modelData.id);
                                        root.tareas = l;
                                        datos.hacer("GuardarTareas", [JSON.stringify(l)]);
                                    }
                                }
                            }
                        }
                    }
                }
                Campo {
                    id: nuevaTarea
                    anchors.bottom: parent.bottom
                    width: parent.width
                    implicitHeight: 36
                    font.pixelSize: 13
                    placeholderText: "+ Añadir tarea"
                    onAccepted: {
                        if (!text.trim()) return;
                        const l = root.tareas.concat([{ id: root.nuevoId(), texto: text.trim(), hecha: false, asignatura: root.estudio.asignatura || "" }]);
                        root.tareas = l;
                        datos.hacer("GuardarTareas", [JSON.stringify(l)]);
                        text = "";
                    }
                }
            }
        }
    }

    component Fila_: Rectangle {
        id: f
        property string texto
        property string extra: ""
        property string icono
        property bool on: false
        property bool tenue: false
        property real sangria: 0
        signal pulsado()
        signal doble()
        width: parent ? parent.width : 0
        height: 32
        radius: 10
        color: on ? Tema.rosaSuave : zona.containsMouse ? Tema.encima : "transparent"
        Icono { x: 8 + f.sangria; anchors.verticalCenter: parent.verticalCenter; nombre: f.icono; color: Tema.rosa; width: 15; height: 15 }
        Texto {
            x: 31 + f.sangria
            width: parent.width - x - (f.extra ? 30 : 8)
            anchors.verticalCenter: parent.verticalCenter
            text: f.texto
            color: f.on ? Tema.texto : f.tenue ? Tema.apagado : Tema.texto
            font.pixelSize: f.tenue ? 12 : 14
            elide: Text.ElideMiddle; wrapMode: Text.NoWrap
        }
        Texto { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: f.extra; color: Tema.tenue; font.pixelSize: 12 }
        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: f.pulsado()
            onDoubleClicked: f.doble()
        }
    }
}
