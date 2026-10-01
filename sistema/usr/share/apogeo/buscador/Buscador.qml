import QtQuick
import org.kde.milou as Milou
import org.kde.kirigami as Kirigami
import Apogeo

// Buscador de Apogeo («B2 · Paleta en el centro»): la tarjeta del buscador de Ágape en el centro de la pantalla, con lo
// que encuentran los buscadores de KDE (Milou) agrupado por tipo, y al final «Buscar en la web con Ágape».
// ↑ ↓ (o Tab) elegir · Intro abrir · Esc o un clic fuera cerrar. La parte de dentro es apogeo-buscador («buscador»).
Window {
    id: win
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Buscador de Apogeo"
    visible: false

    readonly property string query: field.text.trim()
    property int sel: 0
    readonly property int total: list.count + (query !== "" ? 1 : 0) // + la de la web

    function open() {
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
    function activate(i) {
        if (i < list.count) {
            if (results.run(results.index(i, 0))) close();
        } else if (query !== "") {
            buscador.web(query);
            close();
        }
    }
    function move(d) {
        if (total === 0) return;
        sel = (sel + d + total) % total;
        if (sel < list.count) list.positionViewAtIndex(sel, ListView.Contain);
    }

    Connections {
        target: buscador
        function onToggled() { win.visible ? win.close() : win.open() }
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
        width: Math.min(640, win.width - 40)
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.height * 0.18)
        height: col.height
        radius: 24
        color: Qt.rgba(33 / 255, 25 / 255, 36 / 255, 0.96)
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
                    Keys.onDownPressed: win.move(1)
                    Keys.onUpPressed: win.move(-1)
                    Keys.onTabPressed: win.move(1)
                    Keys.onBacktabPressed: win.move(-1)
                    Keys.onReturnPressed: win.activate(win.sel)
                    Keys.onEnterPressed: win.activate(win.sel)
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "Busca apps, archivos, ajustes o en la web"
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
                    radius: 7
                    color: Tema.encima
                    Texto { id: escText; anchors.centerIn: parent; text: "Esc para cerrar"; color: Tema.tenue; font.pixelSize: 11; font.weight: Font.DemiBold }
                }
            }
            Rectangle { width: parent.width; height: 1; color: Tema.borde; visible: win.query !== "" }

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
                currentIndex: win.sel < count ? win.sel : -1
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
                    index: model.index
                    display: model.display || ""
                    subtext: model.subtext || ""
                    decoration: model.decoration
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
                    index: list.count
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
        radius: 12
        color: on ? Tema.rosaSuave : "transparent"
        Rectangle {
            id: badge
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30; radius: 9
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
