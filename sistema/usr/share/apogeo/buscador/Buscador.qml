import QtQuick
import org.kde.milou as Milou
import org.kde.kirigami as Kirigami
import Apogeo

// Apps y buscador de Apogeo («A1»): el cajón de cristal encima de la isla. Sin escribir, todas tus apps por tipo; al
// escribir: arriba la cuenta, si es una (Intro la copia), lo que encuentran los buscadores de KDE (Milou) agrupado, tus
// archivos por su nombre y al final «Buscar en la web con Ágape».
// Flechas (o Tab) elegir · Intro abrir (Mayús+Intro: la carpeta de un archivo) · Esc o un clic fuera cerrar. La parte de
// dentro es apogeo-buscador («buscador»).
Window {
    id: win
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Buscador de Apogeo"
    visible: false

    readonly property string query: field.text.trim()
    property int sel: 0
    // Al escribir, en orden: la cuenta (0 o 1), lo de KDE, tus archivos y la web
    readonly property var answer: query === "" ? ({}) : buscador.answer(query)
    readonly property int base: answer.valor ? 1 : 0
    property var files: []
    readonly property int filesAt: base + list.count
    readonly property int webAt: filesAt + files.length
    readonly property int total: query === "" ? flat.length : webAt + 1
    property bool copied: false
    // Las apps del cajón, en una lista (para moverse con las flechas) y cuántas caben por fila
    readonly property var flat: { const o = []; for (const g of buscador.apps) for (const a of g.apps) o.push(a); return o; }
    readonly property int cols: Math.max(1, Math.floor((card.width - 36) / 92))

    function open() {
        buscador.refresh();
        field.text = "";
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
            if (flat[i]) { buscador.launch(flat[i].id); close(); }
        } else if (i < base) {
            buscador.copy(answer.valor.replace(/ [^\d]+$/, ""));   // (el número, sin la unidad)
            copied = true;
            copiedTimer.restart();
        } else if (i < filesAt) {
            if (results.run(results.index(i - base, 0))) close();
        } else if (i < webAt) {
            buscador.openFile(files[i - filesAt].path, !!folder);
            close();
        } else if (query !== "") {
            buscador.web(query);
            close();
        }
    }
    function move(d) {
        if (total === 0) return;
        sel = (sel + d + total) % total;
        if (query !== "" && sel >= base && sel < filesAt) list.positionViewAtIndex(sel - base, ListView.Contain);
    }
    Timer { id: copiedTimer; interval: 700; onTriggered: { win.copied = false; win.close(); } }
    // Tus archivos: se buscan un momento después de dejar de escribir
    Timer { id: filesTimer; interval: 140; onTriggered: buscador.searchFiles(win.query) }
    onQueryChanged: { files = []; if (query.length >= 2) filesTimer.restart(); }

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
        onQueryStringChanged: win.sel = 0
    }

    Rectangle {
        id: dim
        anchors.fill: parent
        color: Qt.rgba(10 / 255, 7 / 255, 11 / 255, 0.5)
        MouseArea { anchors.fill: parent; onClicked: win.close() }
    }

    Rectangle {
        id: card
        width: Math.min(760, win.width - 40)
        x: Math.round((win.width - width) / 2)
        // encima de la isla (o debajo, si la isla va arriba: Ajustes → Aspecto)
        y: Tema.posicion === "arriba-dcha" ? 84 : win.height - height - 84
        height: Math.min(col.height, win.height - 120)
        radius: Tema.r(24)
        color: Qt.rgba(Tema.cromo.r, Tema.cromo.g, Tema.cromo.b, 0.96)
        border.color: Tema.borde
        clip: true
        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        ParallelAnimation {
            id: appear
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: card; property: "scale"; from: 0.97; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: dim; property: "opacity"; from: 0; to: 1; duration: 160 }
        }
        MouseArea { anchors.fill: parent } // (los clics en la tarjeta no la cierran)

        Column {
            id: col
            width: parent.width

            // El campo
            Item {
                width: parent.width
                height: 62
                Icono { x: 22; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; nombre: "buscar"; color: Tema.rosa }
                TextInput {
                    id: field
                    x: 56
                    width: parent.width - x - esc.width - 36
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tema.texto
                    selectionColor: Tema.rosa
                    selectedTextColor: Tema.sobreRosa
                    font.family: Tema.letra
                    font.pixelSize: 19
                    clip: true
                    focus: true
                    Keys.onEscapePressed: win.close()
                    Keys.onDownPressed: win.move(win.query === "" ? win.cols : 1)
                    Keys.onUpPressed: win.move(win.query === "" ? -win.cols : -1)
                    Keys.onRightPressed: event => { if (win.query === "") win.move(1); else event.accepted = false; }
                    Keys.onLeftPressed: event => { if (win.query === "") win.move(-1); else event.accepted = false; }
                    Keys.onTabPressed: win.move(1)
                    Keys.onBacktabPressed: win.move(-1)
                    Keys.onReturnPressed: event => win.activate(win.sel, event.modifiers & Qt.ShiftModifier)
                    Keys.onEnterPressed: event => win.activate(win.sel, event.modifiers & Qt.ShiftModifier)
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "Busca apps, archivos, ajustes, haz cuentas o busca en la web"
                        color: Tema.tenue
                        font.pixelSize: 19
                    }
                }
                Rectangle {
                    id: esc
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: escText.implicitWidth + 14
                    height: 22
                    radius: Tema.r(7)
                    color: Tema.encima
                    Texto { id: escText; anchors.centerIn: parent; text: "Esc para cerrar"; color: Tema.tenue; font.pixelSize: 11; font.weight: Font.DemiBold }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Tema.borde }

            // Sin escribir: tus apps por tipo
            Flickable {
                id: cajon
                visible: win.query === ""
                width: parent.width
                height: visible ? Math.min(grupos.height + 12, win.height - 220) : 0
                contentHeight: grupos.height + 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: grupos
                    x: 18
                    width: parent.width - 36
                    Repeater {
                        model: buscador.apps
                        delegate: Column {
                            id: grupo
                            required property var modelData
                            required property int index
                            // dónde empieza este grupo en la lista de todas
                            readonly property int start: { let n = 0; for (let i = 0; i < index; i++) n += buscador.apps[i].apps.length; return n; }
                            width: grupos.width
                            Texto {
                                topPadding: 12; bottomPadding: 4; leftPadding: 4
                                text: grupo.modelData.grupo
                                color: Tema.tenue; font.pixelSize: 11; font.weight: Font.Bold
                                font.letterSpacing: 0.8; font.capitalization: Font.AllUppercase
                            }
                            Flow {
                                width: parent.width
                                Repeater {
                                    model: grupo.modelData.apps
                                    delegate: Rectangle {
                                        id: tile
                                        required property var modelData
                                        required property int index
                                        readonly property int pos: grupo.start + index
                                        readonly property bool on: win.sel === pos
                                        width: 92; height: 88
                                        radius: Tema.r(16)
                                        color: on ? Tema.rosaSuave : area.containsMouse ? Tema.encima : "transparent"
                                        onOnChanged: if (on) {
                                            const p = tile.mapToItem(grupos, 0, 0);
                                            if (p.y < cajon.contentY) cajon.contentY = p.y;
                                            else if (p.y + height > cajon.contentY + cajon.height) cajon.contentY = p.y + height - cajon.height;
                                        }
                                        Kirigami.Icon { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 40; height: 40; source: tile.modelData.icono }
                                        Texto {
                                            y: 58; width: parent.width - 8; x: 4
                                            horizontalAlignment: Text.AlignHCenter
                                            text: tile.modelData.nombre
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
                                            onClicked: { buscador.launch(tile.modelData.id); win.close(); }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // La cuenta, bien grande (Intro la copia)
            Rectangle {
                id: answerCard
                visible: win.base > 0
                x: 8
                width: parent.width - 16
                height: visible ? 76 : 0
                radius: Tema.r(16)
                color: win.sel === 0 ? Tema.rosaSuave : Tema.encima
                Rectangle {
                    id: eq
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: Tema.r(12)
                    color: Tema.rosaSuave
                    Texto { anchors.centerIn: parent; text: "="; color: Tema.rosa; font.pixelSize: 24; font.weight: Font.Bold }
                }
                Column {
                    x: eq.x + eq.width + 14
                    width: parent.width - x - copyHint.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    Texto {
                        width: parent.width
                        text: win.answer.valor || ""
                        color: Tema.texto
                        font.pixelSize: 26; font.weight: Font.ExtraBold
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
                    color: Tema.rosa; font.pixelSize: 12; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: win.sel = 0
                    onClicked: win.activate(0)
                }
            }
            Item { width: 1; height: answerCard.visible ? 6 : 0 }

            // Lo que encuentran los buscadores de KDE
            ListView {
                id: list
                x: 8
                width: parent.width - 16
                height: Math.min(contentHeight, win.height * 0.55)
                visible: count > 0 && win.query !== ""
                topMargin: 6
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: results
                currentIndex: win.sel >= win.base && win.sel < win.filesAt ? win.sel - win.base : -1
                highlightFollowsCurrentItem: false
                section.property: "category"
                section.delegate: Texto {
                    required property string section
                    width: ListView.view.width
                    leftPadding: 12
                    topPadding: 10
                    bottomPadding: 4
                    text: section
                    color: Tema.tenue
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    font.capitalization: Font.AllUppercase
                }
                delegate: Row_ {
                    required property var model
                    index: win.base + model.index
                    display: model.display || ""
                    subtext: model.subtext || ""
                    decoration: model.decoration
                }
            }

            // Tus archivos (por su nombre)
            Item {
                width: parent.width
                height: visible ? filesTitle.height + filesCol.height : 0
                visible: win.query !== "" && win.files.length > 0
                Texto {
                    id: filesTitle
                    x: 20
                    topPadding: 10
                    bottomPadding: 4
                    text: "Tus archivos"
                    color: Tema.tenue
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    font.capitalization: Font.AllUppercase
                }
                Column {
                    id: filesCol
                    y: filesTitle.height
                    x: 8
                    width: parent.width - 16
                    Repeater {
                        model: win.files
                        delegate: Row_ {
                            required property var model   // (la fila ya tiene su «index»: el de toda la lista)
                            width: filesCol.width
                            index: win.filesAt + model.index
                            display: model.modelData.nombre
                            subtext: model.modelData.ruta + (on && !model.modelData.carpeta ? "  ·  Mayús+Intro: abrir su carpeta" : "")
                            decoration: model.modelData.icono
                        }
                    }
                }
            }

            // La web, siempre al final
            Item {
                width: parent.width
                height: visible ? webRow.y + webRow.height + 6 : 0
                visible: win.query !== ""
                Texto {
                    id: webTitle
                    x: 20
                    topPadding: 10
                    bottomPadding: 4
                    text: "En la web"
                    color: Tema.tenue
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    font.capitalization: Font.AllUppercase
                }
                Row_ {
                    id: webRow
                    y: webTitle.height
                    x: 8
                    width: parent.width - 16
                    index: win.webAt
                    display: "Buscar «" + win.query + "» en la web"
                    subtext: "Con Ágape"
                    iconName: "web"
                }
            }
            Item { width: 1; height: win.query === "" ? 0 : 6 }
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
            width: 30; height: 30; radius: Tema.r(9)
            color: r.iconName ? Tema.rosaSuave : "transparent"
            Icono { visible: r.iconName !== ""; anchors.centerIn: parent; nombre: r.iconName; color: Tema.rosa }
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
            Texto { text: "Abrir"; color: Tema.rosa; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            Icono { nombre: "flecha"; color: Tema.rosa; anchors.verticalCenter: parent.verticalCenter }
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
