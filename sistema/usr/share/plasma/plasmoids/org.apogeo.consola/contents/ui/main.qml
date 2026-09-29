import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Consola del piso Jugar («Destacado»): el juego elegido en grande con su imagen de fondo y el botón de jugar; debajo,
// todos los demás en una fila (Steam, Epic/GOG con Heroic, Hydra y los que se abren en el Windows escondido).
// Teclado o mando (Steam lo convierte en teclado): ← → elegir · Intro jugar · Q / E cambiar de tienda · ↓ bajar al piso
// Navegar · Esc salir. La rueda del ratón en el borde derecho también cambia de piso (como la columna de pisos).
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    readonly property color pink: "#ff8fc6"
    readonly property color text: "#f1e6ea"
    readonly property color muted: "#a9949f"
    readonly property var filters: [
        { key: "", label: "Todo" }, { key: "steam", label: "Steam" }, { key: "epic", label: "Epic" },
        { key: "gog", label: "GOG" }, { key: "hydra", label: "Hydra" }, { key: "windows", label: "Windows" }
    ]
    readonly property var storeName: ({ steam: "Steam", epic: "Epic", gog: "GOG", hydra: "Hydra", windows: "Windows ⟳" })
    property var games: []
    property int filter: 0
    readonly property var shown: games.filter(g => !filters[filter].key || g.store === filters[filter].key)
    property int current: 0
    readonly property var game: shown[Math.min(current, shown.length - 1)] || null
    property string status: ""

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === root.listCmd) {
                try { root.games = JSON.parse(data.stdout); } catch (e) { root.games = []; }
            }
            disconnectSource(source);
        }
    }
    readonly property string listCmd: "/usr/lib/apogeo/apogeo-juegos lista"
    function reload() { runner.connectSource(listCmd) }
    Component.onCompleted: reload()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.reload() } // por si instalas algo nuevo

    function play(g) {
        if (!g) return;
        const q = s => "'" + String(s).replace(/'/g, "'\\''") + "'";
        runner.connectSource("/usr/lib/apogeo/apogeo-juegos jugar " + q(g.store) + " " + q(g.id));
        status = g.store === "windows" ? "Preparando Windows…" : "Abriendo " + g.name + "…";
        statusTimer.restart();
    }
    Timer { id: statusTimer; interval: 6000; onTriggered: root.status = "" }
    function floor(dir) { runner.connectSource("/usr/lib/apogeo/apogeo-pisos " + dir) }

    function when(ts) {
        if (!ts) return "";
        const d = (Date.now() / 1000 - ts) / 86400;
        return d < 1 ? "Jugado hoy" : d < 2 ? "Jugado ayer" : "Jugado hace " + Math.floor(d) + " días";
    }

    fullRepresentation: Item {
        id: screen
        Layout.preferredWidth: 1280
        Layout.preferredHeight: 800
        focus: true

        Keys.onLeftPressed: root.current = Math.max(0, root.current - 1)
        Keys.onRightPressed: root.current = Math.min(root.shown.length - 1, root.current + 1)
        Keys.onReturnPressed: root.play(root.game)
        Keys.onEnterPressed: root.play(root.game)
        Keys.onDownPressed: root.floor("bajar")
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Q || event.key === Qt.Key_PageUp) { root.filter = (root.filter + root.filters.length - 1) % root.filters.length; root.current = 0; }
            else if (event.key === Qt.Key_E || event.key === Qt.Key_PageDown) { root.filter = (root.filter + 1) % root.filters.length; root.current = 0; }
            else if (event.key === Qt.Key_Escape) Qt.quit();
        }

        Rectangle { anchors.fill: parent; color: "#2e0f24" }

        // Imagen de fondo del juego elegido y un degradado para que se lea el texto
        Image {
            id: heroImg
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.game ? root.game.hero : ""
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 350 } }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#f22e0f24" }
                GradientStop { position: 0.45; color: "#a02e0f24" }
                GradientStop { position: 1.0; color: "#202e0f24" }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.55; color: "#002e0f24" }
                GradientStop { position: 1.0; color: "#f02e0f24" }
            }
        }

        // Arriba: tiendas y hora
        RowLayout {
            x: 48; y: 32
            width: parent.width - 96
            spacing: 8
            QQC2.Label { text: "🎮  Jugar"; color: root.text; font.pixelSize: 24; font.weight: Font.ExtraBold; Layout.rightMargin: 18 }
            Repeater {
                model: root.filters
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool on: index === root.filter
                    Layout.preferredHeight: 36
                    Layout.preferredWidth: pillText.implicitWidth + 30
                    radius: 18
                    color: on ? root.pink : (pillArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                    QQC2.Label {
                        id: pillText
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.on ? "#2e0f24" : root.text
                        font.weight: Font.Bold
                    }
                    MouseArea { id: pillArea; anchors.fill: parent; hoverEnabled: true; onClicked: { root.filter = parent.index; root.current = 0; } }
                }
            }
            Item { Layout.fillWidth: true }
            QQC2.Label {
                id: clock
                color: root.muted
                font.pixelSize: 18
                font.weight: Font.Bold
                Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm") }
            }
        }

        Kirigami.Icon {
            visible: !!root.game && !!root.game.icon
            anchors.right: parent.right
            anchors.rightMargin: parent.width * 0.12
            y: parent.height * 0.14
            width: Math.min(parent.width * 0.26, 300)
            height: width
            source: root.game && root.game.icon ? root.game.icon : ""
            fallback: "input-gaming"
            opacity: 0.9
        }

        // El juego elegido
        ColumnLayout {
            x: 48
            y: parent.height * 0.2
            width: Math.min(640, parent.width * 0.5)
            spacing: 8
            visible: !!root.game
            QQC2.Label {
                text: root.game ? [root.storeName[root.game.store], root.when(root.game.last)].filter(Boolean).join(" · ") : ""
                color: root.muted
                font.pixelSize: 17
            }
            QQC2.Label {
                text: root.game ? root.game.name : ""
                color: root.text
                font.pixelSize: 58
                font.weight: Font.ExtraBold
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                lineHeight: 0.95
            }
            RowLayout {
                spacing: 10
                Layout.topMargin: 14
                Rectangle {
                    Layout.preferredHeight: 50
                    Layout.preferredWidth: playText.implicitWidth + 48
                    radius: 15
                    color: playArea.containsMouse ? "#ffa6d3" : root.pink
                    QQC2.Label {
                        id: playText
                        anchors.centerIn: parent
                        text: !root.game ? "" : root.game.app ? "▶  Abrir " + root.game.name : root.game.store === "windows" ? "▶  Jugar (en Windows)" : root.game.installed ? "▶  Jugar" : "⤓  Instalar"
                        color: "#2e0f24"
                        font.pixelSize: 18
                        font.weight: Font.ExtraBold
                    }
                    MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.play(root.game) }
                }
                QQC2.Label { text: root.status; color: root.text; font.pixelSize: 16; Layout.leftMargin: 8 }
            }
            QQC2.Label {
                visible: !root.games.some(g => g.store !== "windows" && !g.app)
                text: "Entra en Steam o en Heroic con tu cuenta y tus juegos aparecerán aquí solos."
                color: root.muted
                font.pixelSize: 16
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.topMargin: 18
            }
        }

        // Sin juegos todavía
        ColumnLayout {
            anchors.centerIn: parent
            visible: root.games.length === 0
            spacing: 10
            QQC2.Label { text: "Aún no hay juegos"; color: root.text; font.pixelSize: 34; font.weight: Font.ExtraBold; Layout.alignment: Qt.AlignHCenter }
            QQC2.Label { text: "Entra en Steam o en Heroic (Epic y GOG) con tu cuenta y aparecerán aquí solos"; color: root.muted; font.pixelSize: 17; Layout.alignment: Qt.AlignHCenter }
        }

        // Fila de juegos
        ListView {
            id: row
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: hints.top
            anchors.leftMargin: 48
            anchors.bottomMargin: 26
            height: 230
            orientation: ListView.Horizontal
            spacing: 16
            clip: false
            model: root.shown
            currentIndex: root.current
            highlightMoveDuration: 220
            preferredHighlightBegin: 0
            preferredHighlightEnd: width * 0.6
            highlightRangeMode: ListView.ApplyRange
            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool sel: index === root.current
                width: 156
                height: 230
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: tile.sel ? 156 : 138
                    height: tile.sel ? 222 : 196
                    radius: 14
                    clip: true
                    color: "#3a1a30"
                    border.color: tile.sel ? root.pink : "transparent"
                    border.width: 3
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Image {
                        id: cover
                        anchors.fill: parent
                        anchors.margins: 3
                        source: tile.modelData.cover || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    // Sin carátula: el nombre sobre un degradado
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 11
                        visible: cover.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop { position: 0; color: tile.modelData.store === "windows" ? "#8a1c3a" : "#5a3160" }
                            GradientStop { position: 1; color: "#241a28" }
                        }
                        Kirigami.Icon {
                            visible: !!tile.modelData.icon
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height * 0.22
                            width: parent.width * 0.5
                            height: width
                            source: tile.modelData.icon || ""
                            fallback: "input-gaming"
                        }
                        QQC2.Label {
                            anchors.fill: parent
                            anchors.margins: 12
                            text: tile.modelData.name
                            color: root.text
                            font.pixelSize: 16
                            font.weight: Font.ExtraBold
                            wrapMode: Text.Wrap
                            verticalAlignment: Text.AlignBottom
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        radius: 7
                        color: "#b0000000"
                        width: storeLabel.implicitWidth + 12
                        height: 20
                        QQC2.Label { id: storeLabel; anchors.centerIn: parent; text: root.storeName[tile.modelData.store] || ""; color: "white"; font.pixelSize: 11; font.weight: Font.Bold }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.current = tile.index
                    onDoubleClicked: root.play(tile.modelData)
                }
            }
        }

        // Rueda del ratón en el borde derecho: cambia de piso, como la columna de pisos (que la consola tapa)
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 24
            acceptedButtons: Qt.NoButton
            property real acc: 0
            onWheel: wheel => {
                acc += wheel.angleDelta.y;
                if (Math.abs(acc) >= 120) {
                    root.floor(acc < 0 ? "bajar" : "subir");
                    acc = 0;
                }
            }
        }

        RowLayout {
            id: hints
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 48
            anchors.bottomMargin: 26
            spacing: 24
            Repeater {
                model: [["←  →", "Elegir"], ["Intro · A", "Jugar"], ["Q  E", "Tienda"], ["↓", "Bajar a Navegar"], ["Esc", "Salir"]]
                delegate: QQC2.Label {
                    required property var modelData
                    text: "<b>" + modelData[0] + "</b>  " + modelData[1]
                    textFormat: Text.StyledText
                    color: root.muted
                    font.pixelSize: 14
                }
            }
        }
    }
}
