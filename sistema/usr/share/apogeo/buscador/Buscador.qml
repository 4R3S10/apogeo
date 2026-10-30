import QtQuick
import org.kde.milou as Milou
import org.kde.kirigami as Kirigami
import Apogeo

// La Órbita abierta («C · Orbe central»): al pulsar el orbe o Meta. Arriba la paleta; debajo, a la izquierda, tus apps
// del modo (las que fijas tú; «Todas», con todas por tipo, y desde ahí la chincheta para fijarlas) y a la derecha el
// inspector, en pestañas: «Ahora» (lo que suena, los avisos de tus apps, lo que se baja y lo próximo), «Agenda» (el mes,
// el tiempo y tu ciudad, recordatorios y temporizadores), «Notas» y, en Estudiar (y la primera allí), «Estudios». Al escribir, en una sola lista: la
// cuenta, si es una (Intro la copia), las órdenes (los modos, apagar, reiniciar, bloquear, ajustes…), lo que encuentran
// los buscadores de KDE (Milou) agrupado, tus archivos por su nombre y al final «Buscar en la web con Ágape».
// Flechas elegir · Tab fijadas o todas · Intro abrir (Mayús+Intro: la carpeta de un archivo) · Esc, un clic fuera o el
// orbe de abajo cerrar. La parte de dentro es apogeo-buscador («buscador»).
Window {
    id: win
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Órbita"
    visible: false

    property string modo: "navegar"
    readonly property string nombreModo: ({ jugar: "Jugar", navegar: "Navegar", estudiar: "Estudiar" })[modo] || "Navegar"
    readonly property string query: field.text.trim()
    property int sel: 0
    property bool todas: false                     // la izquierda: tus apps fijadas o todas
    property var fijadas: []
    property var insp: ({ musica: {}, avisos: [], bajando: [], proximo: [] })
    // La pestaña de la derecha
    readonly property var pestanas: modo === "estudiar" ? ["ahora", "agenda", "notas", "estudios"] : ["ahora", "agenda", "notas"]
    property string pestana: "ahora"

    // Sin escribir: la rejilla de la izquierda (las fijadas y «Añadir», o todas por tipo)
    readonly property var flat: {
        if (!todas) return fijadas.concat([{ id: "", nombre: "Añadir", icono: "" }]);
        const o = [];
        for (const g of buscador.apps) for (const a of g.apps) o.push(a);
        return o;
    }
    readonly property int cols: Math.max(1, Math.floor((izq.width - 36) / 92))
    // Al escribir, en orden: la cuenta (0 o 1), las órdenes, lo de KDE, tus archivos y la web
    readonly property var answer: query === "" ? ({}) : buscador.answer(query)
    readonly property int base: answer.valor ? 1 : 0
    readonly property var ordenes: query === "" ? [] : buscador.ordenes(query)
    readonly property int kdeAt: base + ordenes.length
    property var files: []
    readonly property int filesAt: kdeAt + list.count
    readonly property int webAt: filesAt + files.length
    readonly property int total: query === "" ? flat.length : webAt + 1
    property bool copied: false

    function leer() {
        modo = buscador.modo();
        fijadas = buscador.fijadas(modo);
        try { insp = JSON.parse(buscador.inspector()); } catch (e) {}
    }
    function open() {
        buscador.refresh();
        field.text = "";
        todas = false;
        leer();
        pestana = modo === "estudiar" ? "estudios" : "ahora";
        sel = 0;
        showFullScreen();
        requestActivate();
        field.forceActiveFocus();
        appear.restart();
    }
    function close() {
        hide();
        field.text = "";
    }
    function activate(i, folder) {
        if (query === "") {
            const a = flat[i];
            if (!a) return;
            if (a.id === "") { todas = true; sel = 0; return; }      // «Añadir»: todas, para fijar con la chincheta
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
    function move(d) {
        if (total === 0) return;
        sel = (sel + d + total) % total;
        if (query !== "" && sel >= kdeAt && sel < filesAt) list.positionViewAtIndex(sel - kdeAt, ListView.Contain);
    }
    function pinned(id) { return fijadas.some(a => a.id === id) }
    function pin(id, on) { buscador.fijar(modo, id, on); fijadas = buscador.fijadas(modo); }
    Timer { id: copiedTimer; interval: 700; onTriggered: { win.copied = false; win.close(); } }
    // Tus archivos: se buscan un momento después de dejar de escribir
    Timer { id: filesTimer; interval: 140; onTriggered: buscador.searchFiles(win.query) }
    onQueryChanged: { files = []; sel = 0; if (query.length >= 2) filesTimer.restart(); }
    Timer { interval: 2000; repeat: true; running: win.visible && win.query === ""; onTriggered: { try { win.insp = JSON.parse(buscador.inspector()); } catch (e) {} } }

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

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Qt.rgba(8 / 255, 10 / 255, 15 / 255, 0.6)
        MouseArea { anchors.fill: parent; onClicked: win.close() }
    }
    ParallelAnimation {
        id: appear
        NumberAnimation { target: dim; property: "opacity"; from: 0; to: 1; duration: 160 }
        NumberAnimation { target: arriba; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: arriba; property: "anchors.topMargin"; from: win.height * 0.08 - 14; to: win.height * 0.08; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: abajo; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
    }

    // ---------- La paleta (y, al escribir, lo que encuentra) ----------
    Column {
        id: arriba
        anchors.top: parent.top
        anchors.topMargin: win.height * 0.08
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(860, win.width * 0.62, win.width - 40)
        spacing: 10

        Rectangle {
            width: parent.width
            height: 56
            radius: 28
            color: Qt.rgba(Tema.elevada.r, Tema.elevada.g, Tema.elevada.b, 0.97)
            border.width: 1
            border.color: Tema.acento
            MouseArea { anchors.fill: parent }
            Icono { x: 22; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; nombre: "buscar"; color: Tema.acento }
            TextInput {
                id: field
                objectName: "campo"
                x: 54
                width: parent.width - x - esc.width - 34
                anchors.verticalCenter: parent.verticalCenter
                color: Tema.texto
                selectionColor: Tema.acento
                selectedTextColor: Tema.sobreAcento
                font.family: Tema.letra
                font.pixelSize: 18
                clip: true
                focus: true
                Keys.onEscapePressed: win.close()
                Keys.onDownPressed: win.move(win.query === "" ? win.cols : 1)
                Keys.onUpPressed: win.move(win.query === "" ? -win.cols : -1)
                Keys.onRightPressed: event => { if (win.query === "") win.move(1); else event.accepted = false; }
                Keys.onLeftPressed: event => { if (win.query === "") win.move(-1); else event.accepted = false; }
                Keys.onTabPressed: { if (win.query === "") { win.todas = !win.todas; win.sel = 0; } else win.move(1); }
                Keys.onBacktabPressed: { if (win.query === "") { win.todas = !win.todas; win.sel = 0; } else win.move(-1); }
                Keys.onReturnPressed: event => win.activate(win.sel, event.modifiers & Qt.ShiftModifier)
                Keys.onEnterPressed: event => win.activate(win.sel, event.modifiers & Qt.ShiftModifier)
                Texto {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: "Escribe: apps, «estudiar», 15% de 80…"
                    color: Tema.tenue
                    font.pixelSize: 18
                }
            }
            Rectangle {
                id: esc
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: escText.implicitWidth + 14
                height: 24
                radius: 12
                color: Tema.encima
                Texto { id: escText; anchors.centerIn: parent; text: "Esc"; color: Tema.tenue; font { family: Tema.mono; pixelSize: 11; weight: Font.DemiBold } }
            }
        }

        // Lo que encuentra
        Rectangle {
            id: hallado
            visible: win.query !== ""
            width: parent.width
            height: Math.min(res.height, win.height * 0.62)
            radius: Tema.r(22)
            color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.97)
            border.color: Tema.borde
            clip: true
            MouseArea { anchors.fill: parent }
            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

            Column {
                id: res
                width: parent.width
                topPadding: 8
                bottomPadding: 8

                // La cuenta, bien grande (Intro la copia)
                Rectangle {
                    id: answerCard
                    visible: win.base > 0
                    x: 8
                    width: parent.width - 16
                    height: visible ? 72 : 0
                    radius: Tema.r(16)
                    color: win.sel === 0 ? Tema.rosaSuave : Tema.encima
                    Rectangle {
                        id: eq
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 40; radius: 20
                        color: Tema.rosaSuave
                        Texto { anchors.centerIn: parent; text: "="; color: Tema.acento; font.pixelSize: 24; font.weight: Font.Bold }
                    }
                    Column {
                        x: eq.x + eq.width + 14
                        width: parent.width - x - copyHint.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        Texto {
                            width: parent.width
                            text: win.answer.valor || ""
                            font { family: Tema.mono; pixelSize: 24; weight: Font.Bold }
                            elide: Text.ElideRight; wrapMode: Text.NoWrap
                        }
                        Texto {
                            width: parent.width
                            text: win.answer.detalle || ""
                            color: Tema.apagado; font.pixelSize: 12
                            elide: Text.ElideRight; wrapMode: Text.NoWrap
                        }
                    }
                    Texto {
                        id: copyHint
                        anchors.right: parent.right; anchors.rightMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.copied ? "Copiado ✓" : win.sel === 0 ? "Intro para copiar" : ""
                        color: Tema.acento; font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.sel = 0
                        onClicked: win.activate(0)
                    }
                }

                // Las órdenes
                Titulo { visible: win.ordenes.length > 0; text: "Órdenes" }
                Repeater {
                    model: win.ordenes
                    delegate: Row_ {
                        required property var modelData
                        required property int index
                        width: res.width - 16; x: 8
                        index: win.base + index
                        display: modelData.nombre
                        subtext: modelData.detalle
                        iconName: modelData.icono
                    }
                }

                // Lo que encuentran los buscadores de KDE
                ListView {
                    id: list
                    x: 8
                    width: parent.width - 16
                    height: Math.min(contentHeight, win.height * 0.4)
                    visible: count > 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: results
                    section.property: "category"
                    section.delegate: Titulo {
                        required property string section
                        x: 4
                        text: section
                    }
                    delegate: Row_ {
                        required property var model
                        index: win.kdeAt + model.index
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
                        width: res.width - 16; x: 8
                        index: win.filesAt + index
                        display: modelData.nombre
                        subtext: modelData.ruta + (on && !modelData.carpeta ? "  ·  Mayús+Intro: abrir su carpeta" : "")
                        decoration: modelData.icono
                    }
                }

                // La web, siempre al final
                Titulo { text: "En la web" }
                Row_ {
                    x: 8
                    width: parent.width - 16
                    index: win.webAt
                    display: "Buscar «" + win.query + "» en la web"
                    subtext: "Con Ágape"
                    iconName: "web"
                }
            }
        }
    }

    // ---------- Sin escribir: tus apps del modo (izquierda) y el inspector (derecha) ----------
    Item {
        id: abajo
        visible: win.query === ""
        anchors.top: arriba.bottom
        anchors.topMargin: 34
        anchors.bottom: orbe.top
        anchors.bottomMargin: 34
        x: win.width * 0.08
        width: win.width * 0.84

        Rectangle {
            id: izq
            width: (parent.width - 28) / 2
            height: Math.min(parent.height, izqCol.implicitHeight + 36)
            radius: Tema.r(22)
            color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.96)
            border.color: Tema.borde
            clip: true
            MouseArea { anchors.fill: parent }
            Column {
                id: izqCol
                x: 18; y: 16
                width: parent.width - 36
                spacing: 10
                Row {
                    spacing: 6
                    Pestana { text: "Tus apps de " + win.nombreModo; on: !win.todas; onClicked: { win.todas = false; win.sel = 0; } }
                    Pestana { text: "Todas"; on: win.todas; onClicked: { win.todas = true; win.sel = 0; } }
                }
                // Las fijadas (y «Añadir»)
                Flow {
                    visible: !win.todas
                    width: parent.width
                    Repeater {
                        model: win.flat.length && !win.todas ? win.flat : []
                        delegate: Tile {
                            required property var modelData
                            required property int index
                            pos: index
                            app: modelData
                        }
                    }
                }
                Texto {
                    visible: !win.todas && win.fijadas.length === 0
                    width: parent.width
                    text: "Aún no has fijado ninguna. En «Todas», la chincheta de una app la deja aquí."
                    color: Tema.apagado
                    font.pixelSize: 13
                }
                // Todas, por tipo (con la chincheta para fijarlas)
                Flickable {
                    id: cajon
                    visible: win.todas
                    width: parent.width
                    height: visible ? Math.min(grupos.height, abajo.height - 80) : 0
                    contentHeight: grupos.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: grupos
                        width: parent.width
                        Repeater {
                            model: win.todas ? buscador.apps : []
                            delegate: Column {
                                id: grupo
                                required property var modelData
                                required property int index
                                // dónde empieza este grupo en la lista de todas
                                readonly property int start: { let n = 0; for (let i = 0; i < index; i++) n += buscador.apps[i].apps.length; return n; }
                                width: grupos.width
                                Titulo { x: 4; text: grupo.modelData.grupo }
                                Flow {
                                    width: parent.width
                                    Repeater {
                                        model: grupo.modelData.apps
                                        delegate: Tile {
                                            required property var modelData
                                            required property int index
                                            pos: grupo.start + index
                                            app: modelData
                                            chincheta: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // El inspector, en pestañas: lo que pasa ahora, la agenda, tus notas y (en Estudiar) tus estudios
        Rectangle {
            id: der
            x: izq.width + 28
            width: izq.width
            height: win.pestana === "ahora" ? Math.min(parent.height, derTabs.height + 16 + derCol.implicitHeight + 36) : parent.height
            radius: Tema.r(22)
            color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.96)
            border.color: Tema.borde
            clip: true
            MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
            // (Esc en una nota, un campo vacío o la agenda sin nada a medias: se cierra la Órbita)
            Keys.onEscapePressed: win.close()
            readonly property bool suena: !!(win.insp.musica && win.insp.musica.titulo)
            Row {
                id: derTabs
                x: 18; y: 16
                spacing: 6
                Repeater {
                    model: win.pestanas
                    delegate: Pestana {
                        required property string modelData
                        text: ({ ahora: "Ahora", agenda: "Agenda", notas: "Notas", estudios: "Estudios" })[modelData]
                        on: win.pestana === modelData
                        onClicked: win.pestana = modelData
                    }
                }
            }
            Agenda {
                x: 18; y: derTabs.y + derTabs.height + 16
                width: parent.width - 36; height: parent.height - y - 16
                visible: win.pestana === "agenda" && win.visible
            }
            Notas {
                x: 18; y: derTabs.y + derTabs.height + 16
                width: parent.width - 36; height: parent.height - y - 16
                visible: win.pestana === "notas" && win.visible
                modo: win.modo
            }
            Estudios {
                x: 18; y: derTabs.y + derTabs.height + 16
                width: parent.width - 36; height: parent.height - y - 16
                visible: win.pestana === "estudios" && win.visible
            }
            Column {
                id: derCol
                visible: win.pestana === "ahora"
                x: 18; y: derTabs.y + derTabs.height + 16
                width: parent.width - 36
                spacing: 14
                Texto {
                    visible: !der.suena && !win.insp.avisos.length && !win.insp.bajando.length && !win.insp.proximo.length
                    text: "Todo tranquilo"
                    color: Tema.apagado
                    font.pixelSize: 14
                }
                // Lo que suena
                Row {
                    visible: der.suena
                    spacing: 14
                    Rectangle {
                        width: 56; height: 56; radius: 12
                        color: Tema.rosaSuave
                        clip: true
                        Icono { anchors.centerIn: parent; nombre: "musica"; color: Tema.acento; visible: art.status !== Image.Ready }
                        Image { id: art; anchors.fill: parent; source: der.suena ? (win.insp.musica.portada || "") : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: derCol.width - 56 - 14 - 130
                        Texto { width: parent.width; text: win.insp.musica.titulo || ""; font { pixelSize: 15; weight: Font.Bold } elide: Text.ElideRight; wrapMode: Text.NoWrap }
                        Texto { width: parent.width; text: win.insp.musica.artista || ""; color: Tema.apagado; font.pixelSize: 12; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Redondo { icono: "anterior"; onClicked: { buscador.musica("Previous"); refrescar.restart(); } }
                        Redondo { icono: win.insp.musica.sonando ? "pausa" : "reproducir"; lleno: true; onClicked: { buscador.musica("PlayPause"); refrescar.restart(); } }
                        Redondo { icono: "siguiente"; onClicked: { buscador.musica("Next"); refrescar.restart(); } }
                    }
                }
                // Los avisos de tus apps (el número que ponen en su icono)
                Repeater {
                    model: win.insp.avisos
                    delegate: Row {
                        required property var modelData
                        spacing: 12
                        Kirigami.Icon { width: 24; height: 24; source: modelData.icono; anchors.verticalCenter: parent.verticalCenter }
                        Texto { text: modelData.app; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: 14 }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(22, nn.implicitWidth + 12); height: 20; radius: 10
                            color: Tema.acento
                            Texto { id: nn; anchors.centerIn: parent; text: modelData.numero > 99 ? "99+" : modelData.numero; color: Tema.sobreAcento; font { pixelSize: 11; weight: Font.Bold } }
                        }
                    }
                }
                // Lo que se baja
                Repeater {
                    model: win.insp.bajando
                    delegate: Column {
                        required property var modelData
                        width: derCol.width
                        spacing: 6
                        Row {
                            spacing: 12
                            Kirigami.Icon { width: 20; height: 20; source: modelData.icono }
                            Texto { text: modelData.app + " · " + Math.round(modelData.progreso * 100) + " %"; font.pixelSize: 13 }
                        }
                        Rectangle {
                            width: parent.width; height: 4; radius: 2; color: Tema.encima
                            Rectangle { width: parent.width * modelData.progreso; height: 4; radius: 2; color: Tema.acento }
                        }
                    }
                }
                // Lo próximo de tu calendario
                Repeater {
                    model: win.insp.proximo
                    delegate: Row {
                        required property var modelData
                        spacing: 12
                        Icono { nombre: "calendario"; color: Tema.acento; anchors.verticalCenter: parent.verticalCenter }
                        Texto {
                            anchors.verticalCenter: parent.verticalCenter
                            width: derCol.width - 40
                            text: modelData.texto + "  ·  " + (modelData.dias === 0 ? "hoy" : modelData.dias === 1 ? "mañana" : "en " + modelData.dias + " días")
                                  + (modelData.hora ? " a las " + modelData.hora : "")
                            font.pixelSize: 13
                            elide: Text.ElideRight; wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }
    }
    Timer { id: refrescar; interval: 500; onTriggered: { try { win.insp = JSON.parse(buscador.inspector()); } catch (e) {} } }

    // ---------- El orbe, abierto (lleno del color del modo): un clic lo cierra ----------
    Rectangle {
        id: orbe
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: 52; height: 52; radius: 26
        color: Tema.acento
        Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: Tema.sobreAcento }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.close() }
    }

    // ---------- Las piezas ----------
    component Titulo: Texto {
        x: 12
        topPadding: 10
        bottomPadding: 4
        color: Tema.tenue
        font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.6; capitalization: Font.AllUppercase }
    }
    component Pestana: Rectangle {
        id: p
        property alias text: pt.text
        property bool on: false
        signal clicked()
        width: pt.implicitWidth + 24; height: 30; radius: 15
        color: on ? Tema.rosaSuave : pm.containsMouse ? Tema.encima : "transparent"
        Texto { id: pt; anchors.centerIn: parent; font { pixelSize: 13; weight: p.on ? Font.Bold : Font.Medium } color: p.on ? Tema.texto : Tema.apagado }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.clicked() }
    }
    component Redondo: Rectangle {
        id: rd
        property string icono
        property bool lleno: false
        signal clicked()
        width: 34; height: 34; radius: 17
        color: lleno ? Tema.acento : rm.containsMouse ? Tema.encima : "transparent"
        Icono { anchors.centerIn: parent; nombre: rd.icono; color: rd.lleno ? Tema.sobreAcento : Tema.texto }
        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rd.clicked() }
    }
    // Una app de la rejilla: con «chincheta», al pasar por ella, el botón para fijarla en el modo (o quitarla)
    component Tile: Rectangle {
        id: tile
        property int pos
        property var app
        property bool chincheta: false
        readonly property bool on: win.sel === pos
        readonly property bool fija: chincheta && win.pinned(app.id)
        width: 92; height: 88
        radius: Tema.r(16)
        color: on ? Tema.rosaSuave : area.containsMouse ? Tema.encima : "transparent"
        onOnChanged: if (on && win.todas) {
            const q = tile.mapToItem(grupos, 0, 0);
            if (q.y < cajon.contentY) cajon.contentY = q.y;
            else if (q.y + height > cajon.contentY + cajon.height) cajon.contentY = q.y + height - cajon.height;
        }
        Rectangle {   // «Añadir»
            visible: tile.app.id === ""
            anchors.horizontalCenter: parent.horizontalCenter
            y: 12; width: 40; height: 40; radius: 20
            color: "transparent"
            border.width: 1.5; border.color: Tema.borde
            Icono { anchors.centerIn: parent; nombre: "mas"; color: Tema.apagado }
        }
        Kirigami.Icon { visible: tile.app.id !== ""; anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 40; height: 40; source: tile.app.icono }
        Texto {
            y: 58; width: parent.width - 8; x: 4
            horizontalAlignment: Text.AlignHCenter
            text: tile.app.nombre
            color: tile.on ? Tema.texto : Tema.apagado
            font.pixelSize: 12
            elide: Text.ElideRight; wrapMode: Text.NoWrap
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: win.sel = tile.pos
            onClicked: win.activate(tile.pos)
        }
        Rectangle {
            visible: tile.chincheta && (area.containsMouse || pinArea.containsMouse || tile.fija)
            anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 4
            width: 24; height: 24; radius: 12
            color: tile.fija ? Tema.acento : pinArea.containsMouse ? Tema.pulsado : Tema.encima
            Icono { anchors.centerIn: parent; width: 13; height: 13; nombre: "chincheta"; color: tile.fija ? Tema.sobreAcento : Tema.texto }
            MouseArea {
                id: pinArea
                anchors.fill: parent; anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.pin(tile.app.id, !tile.fija)
            }
        }
    }
    component Row_: Rectangle {
        id: r
        property int index: 0
        property string display: ""
        property string subtext: ""
        property var decoration: undefined
        property string iconName: ""                // un icono de línea de Apogeo en vez del de la app
        readonly property bool on: win.sel === index
        width: ListView.view ? ListView.view.width : parent.width
        height: 48
        radius: Tema.r(12)
        color: on ? Tema.rosaSuave : "transparent"
        Rectangle {
            id: badge
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30; radius: 15
            color: r.iconName ? Tema.rosaSuave : "transparent"
            Icono { visible: r.iconName !== ""; anchors.centerIn: parent; nombre: r.iconName; color: Tema.acento }
            Kirigami.Icon { visible: r.iconName === ""; anchors.fill: parent; source: r.decoration || "" }
        }
        Column {
            x: badge.x + badge.width + 12
            width: parent.width - x - (go.visible ? go.width + 16 : 12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Texto { width: parent.width; text: r.display; elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText }
            Texto { width: parent.width; visible: text !== ""; text: r.subtext; color: Tema.apagado; font.pixelSize: 12; elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText }
        }
        Row {
            id: go
            visible: r.on
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Texto { text: "Intro"; color: Tema.acento; font { family: Tema.mono; pixelSize: 11 } anchors.verticalCenter: parent.verticalCenter }
            Icono { nombre: "flecha"; color: Tema.acento; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: win.sel = r.index
            onClicked: win.activate(r.index)
        }
    }
}
