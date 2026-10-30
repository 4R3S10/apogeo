import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Shapes
import Apogeo

// Estudios, en la Órbita abierta (pestaña «Estudios», solo en Estudiar y la primera al llegar): el temporizador 25/5,
// los exámenes con lo que falta, las tareas de hoy y tus asignaturas de ~/Estudios (un clic abre su carpeta). Lo de
// dentro lo da apogeo-pisos (Datos, por D-Bus) y solo se pide mientras se ve.
Item {
    id: root
    Datos { id: datos }
    property var estudio: ({})
    property var asignaturas: []
    property var tareas: []
    property var examenes: []
    property date ahora: new Date()
    function mmss(s) { s = Math.max(0, Math.round(s || 0)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0"); }
    function hm(s) { s = Math.round(s || 0); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60); return h ? h + " h " + m + " min" : m + " min"; }
    function nuevoId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }
    function cargar(lento) {
        datos.pedir("Estudio", [], d => { if (d) root.estudio = d; });
        if (lento) {
            datos.pedir("Asignaturas", [], d => { if (d) root.asignaturas = d; });
            datos.pedir("Tareas", [], d => { if (d) root.tareas = d; });
            datos.pedir("Examenes", [], d => { if (d) root.examenes = d; });
        }
    }
    property int vuelta: 0
    onVisibleChanged: vuelta = 0
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.Window.window && root.Window.window.visible
        triggeredOnStart: true
        onTriggered: { root.ahora = new Date(); root.cargar(root.vuelta % 10 === 0); root.vuelta++; }
    }

    Flickable {
        anchors.fill: parent
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

    // ---------- Piezas ----------
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
    // Un arco: el fondo apagado y, encima, lo lleno con un degradado de los colores del piso (un anillo relleno, para
    // poder pintarlo con degradado; las puntas, redondas)
    component Arco: Shape {
        id: arco
        property real valor: 0
        property real grosor: 6
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real medio: width / 2 - grosor           // el radio por el centro del trazo
        readonly property real giro: 360 * Math.max(0.001, Math.min(0.999, valor))
        readonly property real fin: (giro - 90) * Math.PI / 180
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Tema.pulsado
            strokeWidth: arco.grosor; fillColor: "transparent"
            PathAngleArc { centerX: arco.cx; centerY: arco.cy; radiusX: arco.medio; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: ConicalGradient {
                centerX: arco.cx; centerY: arco.cy; angle: 90
                GradientStop { position: 0; color: Tema.vivo }
                GradientStop { position: 1; color: Tema.rosa }
            }
            PathAngleArc { centerX: arco.cx; centerY: arco.cy; radiusX: arco.medio + arco.grosor / 2; radiusY: radiusX; startAngle: -90; sweepAngle: arco.giro }
            PathAngleArc { centerX: arco.cx; centerY: arco.cy; radiusX: arco.medio - arco.grosor / 2; radiusY: radiusX; startAngle: arco.giro - 90; sweepAngle: -arco.giro; moveToStart: false }
        }
        Rectangle { // las puntas
            visible: arco.valor > 0.005
            x: arco.cx - width / 2; y: arco.cy - arco.medio - height / 2
            width: arco.grosor; height: width; radius: width / 2; color: Tema.rosa
        }
        Rectangle {
            visible: arco.valor > 0.005
            x: arco.cx + arco.medio * Math.cos(arco.fin) - width / 2; y: arco.cy + arco.medio * Math.sin(arco.fin) - height / 2
            width: arco.grosor; height: width; radius: width / 2
            color: Qt.tint(Tema.rosa, Qt.rgba(Tema.vivo.r, Tema.vivo.g, Tema.vivo.b, Math.min(1, arco.valor)))
        }
    }
    component CampoPanel: Campo {
        implicitHeight: 36
        font.pixelSize: 13
        // Esc lo vacía; vacío, sigue (cierra la Órbita)
        Keys.onEscapePressed: event => { if (text) text = ""; else event.accepted = false; }
    }
    // Un botón de la música: redondo; el de en medio, lleno con el color de la portada
    component Quitar: QQC2.AbstractButton {
        id: q
        width: 22; height: 22
        hoverEnabled: true
        contentItem: Item { Icono { anchors.centerIn: parent; nombre: "cerrar"; width: 11; height: 11; color: q.hovered ? Tema.texto : Tema.tenue } }
    }
}
