import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Apogeo

// Resumen al volver («H3»): la tarjeta de cristal encima de la isla con lo que llegó mientras no salían los avisos. La
// coloca el script de KWin apogeo-ventanas (abajo, en el centro, encima de la isla). «resumen» es apogeo-resumen.
Window {
    id: win
    readonly property var d: resumen.data
    readonly property var avisos: d.avisos || []
    readonly property var pisos: d.pisos || []
    property bool todos: false
    readonly property int pocos: 3
    width: 560
    height: card.height + 36
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool | Qt.WindowDoesNotAcceptFocus
    title: "Resumen de avisos"
    visible: true

    function tiempo(s) {
        const h = Math.floor(s / 3600), m = Math.max(1, Math.round(s % 3600 / 60));
        return h ? h + " h" + (m ? " " + m + " min" : "") : m + " min";
    }
    readonly property string titulo: pisos.length === 1 && pisos[0] === "jugar" ? "Has jugado " + tiempo(d.segundos)
                                   : pisos.length === 1 && pisos[0] === "estudiar" ? "Has estudiado " + tiempo(d.segundos)
                                   : "Has vuelto"
    readonly property string sub: {
        const n = avisos.length;
        const llegaron = n === 1 ? "llegó 1 aviso" : "llegaron " + n + " avisos";
        if (titulo !== "Has vuelto") return "Mientras tanto " + llegaron + (n > pocos ? ". Lo importante:" : ":");
        return "En " + tiempo(d.segundos) + " sin avisos " + llegaron + (n > pocos ? ". Lo importante:" : ":");
    }
    // «y 2 más de Spotify y Discord»
    readonly property string resto: {
        if (todos || avisos.length <= pocos) return "";
        const apps = [];
        for (const a of avisos.slice(pocos)) if (a.app && apps.indexOf(a.app) < 0) apps.push(a.app);
        const n = avisos.length - pocos;
        return "y " + n + " más" + (apps.length ? " de " + (apps.length > 2 ? apps.slice(0, 2).join(", ") + "…" : apps.join(" y ")) : "");
    }

    // Se va sola al medio minuto (si no tienes el ratón encima)
    Timer { id: adios; interval: 30000; running: !zona.hovered; onTriggered: Qt.quit() }
    // Entra desde abajo
    property real entrada: 0
    NumberAnimation on entrada { from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }

    RectangularShadow {
        anchors.fill: card
        offset.y: 14; blur: 42; spread: -6
        radius: card.radius
        color: "#99000000"
        opacity: win.entrada
    }
    Rectangle {
        id: card
        x: 18
        y: 10 + (1 - win.entrada) * 24
        opacity: win.entrada
        width: win.width - 36
        height: col.implicitHeight + 44
        radius: 22
        color: Qt.rgba(30 / 255, 22 / 255, 33 / 255, 0.96)
        border.color: Tema.borde
        HoverHandler { id: zona }

        Column {
            id: col
            x: 22; y: 22
            width: parent.width - 44
            spacing: 14

            Row {
                spacing: 14
                Rectangle {
                    width: 46; height: 46; radius: 14
                    color: Tema.rosaSuave
                    Icono {
                        anchors.centerIn: parent
                        width: 20; height: 20
                        nombre: win.pisos.length === 1 && win.pisos[0] === "jugar" ? "jugar" : win.pisos.length === 1 && win.pisos[0] === "estudiar" ? "estudiar" : "campana"
                        color: Tema.rosa
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Texto { text: win.titulo; font.pixelSize: 20; font.weight: Font.Bold; wrapMode: Text.NoWrap }
                    Texto { text: win.sub; color: Tema.apagado; font.pixelSize: 13; width: col.width - 60 }
                }
            }

            ListView {
                id: lista
                width: parent.width
                height: Math.min(contentHeight, 330)
                spacing: 8
                clip: true
                interactive: contentHeight > height
                model: win.todos ? win.avisos : win.avisos.slice(0, win.pocos)
                ScrollBar.vertical: ScrollBar {
                    policy: lista.contentHeight > lista.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Tema.pulsado }
                }
                delegate: AbstractButton {
                    id: fila
                    required property var modelData
                    width: ListView.view.width
                    height: Math.max(56, cuerpo.implicitHeight + 20)
                    hoverEnabled: true
                    background: Rectangle {
                        radius: 14
                        color: fila.hovered && fila.modelData.desktop ? Tema.pulsado : Tema.encima
                        border.width: fila.modelData.urgencia >= 2 ? 1 : 0
                        border.color: Tema.rosa
                    }
                    contentItem: Item {
                        Image {
                            id: ico
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 32
                            source: "image://icono/" + fila.modelData.icono
                            sourceSize: Qt.size(64, 64)
                            asynchronous: true
                        }
                        Column {
                            id: cuerpo
                            x: 56
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - x - 64
                            spacing: 2
                            Texto {
                                width: parent.width
                                text: (fila.modelData.titulo || fila.modelData.app) + (fila.modelData.app && fila.modelData.titulo && fila.modelData.titulo !== fila.modelData.app ? " · " + fila.modelData.app : "")
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                            Texto {
                                visible: text !== ""
                                width: parent.width
                                text: fila.modelData.texto
                                textFormat: Text.PlainText
                                color: Tema.apagado
                                font.pixelSize: 13
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                        Texto {
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.top: parent.top; anchors.topMargin: 11
                            text: fila.modelData.hora
                            color: Tema.tenue
                            font.pixelSize: 12
                        }
                    }
                    onClicked: if (modelData.desktop) { resumen.open(modelData.desktop); Qt.quit(); }
                }
            }

            Texto { visible: win.resto !== ""; text: win.resto; color: Tema.apagado; font.pixelSize: 13 }

            Item {
                width: parent.width
                height: 34
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Boton {
                        visible: win.avisos.length > win.pocos
                        text: win.todos ? "Solo lo importante" : "Ver todos (" + win.avisos.length + ")"
                        onClicked: win.todos = !win.todos
                    }
                    Boton { tipo: "principal"; grande: false; text: "Vale"; onClicked: Qt.quit() }
                }
            }
        }
    }
}
