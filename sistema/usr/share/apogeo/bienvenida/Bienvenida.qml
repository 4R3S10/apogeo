import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Dialogs

// Bienvenida de Apogeo («A · Tarjeta central»): como la bienvenida de Ágape, una tarjeta de cristal en el centro sobre el
// fondo animado del piso Navegar, con puntos abajo que marcan por dónde vas. La parte de dentro (red, cuentas, descarga
// de Ágape, copia) es apogeo-bienvenida, que se ve aquí como «apogeo».
ApplicationWindow {
    id: win
    visible: true
    visibility: Window.FullScreen
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Bienvenida de Apogeo"
    color: bg

    // Colores y letra de Ágape (tema Berenjena oscuro)
    readonly property color bg: "#120d14"
    readonly property color text: "#f1e6ea"
    readonly property color muted: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.62)
    readonly property color faint: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.38)
    readonly property color hover: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.07)
    readonly property color press: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.13)
    readonly property color border: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.1)
    readonly property color accent: "#e0a9b4"
    readonly property color accentSoft: Qt.rgba(224 / 255, 169 / 255, 180 / 255, 0.2)
    readonly property color accentText: "#2a1c26"
    readonly property color chrome: "#211924"
    readonly property string fontName: "Bricolage Grotesque"
    font.family: fontName

    readonly property int steps: 7
    property int step: firstStep
    property string name: apogeo.realName
    property int face: 0                  // 0 inicial, 1 corazón, 2 mando, 3 música, 4 tu foto
    property url photo: ""
    property string profileError: ""
    property bool profileSaved: false
    property bool installing: false
    property real downloaded: 0
    property string agapeError: ""
    property var copy: ({})
    property bool restoring: false
    property bool restored: false

    function go(i) {
        if (i === step || fade.running) return;
        fade.target = i;
        fade.restart();
    }
    SequentialAnimation {
        id: fade
        property int target: 0
        NumberAnimation { target: page; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
        ScriptAction { script: win.step = fade.target }
        NumberAnimation { target: page; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    Connections {
        target: apogeo
        function onProgress(p) { win.downloaded = p }
        function onInstalled(ok, msg) {
            win.installing = false;
            win.agapeError = ok ? "" : msg;
        }
        function onRestored() {
            win.restoring = false;
            win.restored = true;
        }
    }

    // ---------- Fondo: el animado de Ágape del piso Navegar («Tinta»), a un tercio de resolución y 30 imágenes/s ----------

    property real time: 40
    ShaderEffect {
        id: fx
        width: Math.max(2, Math.round(win.width / 3))
        height: Math.max(2, Math.round(win.height / 3))
        visible: false
        property real t: win.time
        property real kind: 0
        property real light: 0
        property size res: Qt.size(win.width, win.height)
        property color base: "#120d14"
        property color c1: "#4a2c4f"
        property color c2: "#7a4458"
        property color c3: "#e0a9b4"
        fragmentShader: "file:///usr/share/plasma/wallpapers/org.apogeo.fondo/contents/shaders/fondo.frag.qsb"
    }
    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: fx
        textureSize: Qt.size(fx.width, fx.height)
        smooth: true
    }
    Timer {
        interval: 33
        repeat: true
        // Sin gráfica de verdad se queda quieto: primero la salud del equipo
        running: apogeo.animate && GraphicsInfo.api !== GraphicsInfo.Software && win.active
        onTriggered: win.time += 0.033
    }
    Rectangle { anchors.fill: parent; color: win.bg; opacity: 0.45 }

    // ---------- Piezas ----------

    component Label_: Text {
        color: win.text
        font.family: win.fontName
        font.pixelSize: 14
        wrapMode: Text.Wrap
    }

    component Icon_: Item {
        id: icon
        property string name
        property color color: win.text
        width: 16; height: 16
        Image {
            id: iconImg
            anchors.fill: parent
            source: icon.name ? Qt.resolvedUrl("iconos/" + icon.name + ".svg") : ""
            sourceSize: Qt.size(icon.width * 2, icon.height * 2)
            visible: false
        }
        // (la transparencia del color no la aplica el coloreado: va aparte)
        MultiEffect { anchors.fill: parent; source: iconImg; colorization: 1; colorizationColor: icon.color; opacity: icon.color.a }
    }

    component Button_: AbstractButton {
        id: b
        property string kind: "normal"      // primary · ghost · normal
        property bool big: kind === "primary"
        property string iconName: ""
        readonly property color fg: kind === "primary" ? win.accentText : kind === "ghost" && !hovered ? win.muted : win.text
        implicitHeight: big ? 42 : 34
        implicitWidth: row.implicitWidth + (big ? 44 : 28)
        opacity: enabled ? 1 : 0.45
        hoverEnabled: true
        font.family: win.fontName
        background: Item {
            RectangularShadow {
                anchors.fill: parent
                visible: b.kind === "primary" && b.enabled
                offset.y: 4; blur: 18; spread: -4
                radius: bgRect.radius
                color: win.accent
                opacity: 0.8
            }
            Rectangle {
                id: bgRect
                anchors.fill: parent
                radius: b.big ? 13 : 10
                color: b.kind === "primary" ? (b.hovered ? Qt.lighter(win.accent, 1.06) : win.accent)
                     : b.kind === "ghost" ? (b.hovered ? win.hover : "transparent")
                     : (b.hovered ? win.press : win.hover)
                border.width: b.kind === "normal" ? 1 : 0
                border.color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.14)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
        contentItem: Item {
            Row {
                id: row
                anchors.centerIn: parent
                spacing: 8
                Label_ {
                    text: b.text
                    color: b.fg
                    wrapMode: Text.NoWrap
                    font.pixelSize: b.big ? 14 : 13
                    font.weight: b.kind === "ghost" ? Font.DemiBold : Font.ExtraBold
                    anchors.verticalCenter: parent.verticalCenter
                }
                Icon_ {
                    visible: b.iconName !== ""
                    name: b.iconName
                    color: b.fg
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    component Field_: TextField {
        id: f
        width: Math.min(360, parent ? parent.width : 360)
        height: 44
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        horizontalAlignment: TextInput.AlignHCenter
        color: win.text
        placeholderTextColor: win.faint
        selectionColor: win.accent
        selectedTextColor: win.accentText
        font.family: win.fontName
        font.pixelSize: 15
        background: Rectangle {
            radius: 12
            color: win.hover
            border.width: 1
            border.color: f.activeFocus ? win.accent : Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.12)
            Rectangle { // el anillo de foco de Ágape
                anchors.fill: parent
                anchors.margins: -3
                radius: 15
                color: "transparent"
                border.width: 3
                border.color: win.accentSoft
                visible: f.activeFocus
            }
        }
    }

    component Header_: Column {
        property alias title: t.text
        property alias lead: l.text
        width: parent ? parent.width : 0
        spacing: 6
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76; height: 76
            source: "file:///usr/share/apogeo/logo.svg"
            sourceSize: Qt.size(152, 152)
        }
        Item { width: 1; height: 2 }
        Label_ {
            id: t
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 29
            font.weight: Font.Black
            font.letterSpacing: -0.3
        }
        Label_ {
            id: l
            width: Math.min(470, parent.width)
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            color: win.muted
            font.pixelSize: 15
            lineHeight: 1.25
            visible: text !== ""
        }
        Item { width: 1; height: 12 }
    }

    component Actions_: Item {
        id: acts
        property string back: ""          // el botón de la izquierda («» = sin él)
        property string next: ""
        property bool backEnabled: true
        property bool nextEnabled: true
        property bool arrow: true
        signal backClicked()
        signal nextClicked()
        width: parent ? parent.width : 0
        height: 42 + 22
        Button_ {
            visible: acts.back !== ""
            kind: "ghost"
            text: acts.back
            enabled: acts.backEnabled
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            onClicked: acts.backClicked()
        }
        Button_ {
            kind: "primary"
            text: acts.next
            iconName: acts.arrow ? "flecha" : ""
            enabled: acts.nextEnabled
            anchors.bottom: parent.bottom
            anchors.right: acts.back !== "" ? parent.right : undefined
            anchors.horizontalCenter: acts.back === "" ? parent.horizontalCenter : undefined
            onClicked: acts.nextClicked()
        }
    }

    component Warn_: Rectangle {
        property alias text: w.text
        width: Math.min(470, parent ? parent.width : 470)
        anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
        height: w.implicitHeight + 20
        radius: 12
        color: Qt.rgba(245 / 255, 158 / 255, 11 / 255, 0.14)
        visible: w.text !== ""
        Label_ { id: w; anchors.fill: parent; anchors.margins: 10; anchors.leftMargin: 14; anchors.rightMargin: 14; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 14 }
    }

    component Check_: Row {
        property alias text: c.text
        property bool ok: true
        property color tone: win.text
        spacing: 10
        Icon_ { name: parent.ok ? "hecho" : "aviso"; color: parent.ok ? win.accent : win.faint; anchors.verticalCenter: parent.verticalCenter }
        Label_ { id: c; color: parent.tone; wrapMode: Text.NoWrap; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
    }

    component Spinner_: Item {
        width: 22; height: 22
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2.5
            border.color: win.faint
        }
        Rectangle { // el trozo rosa que gira
            width: 7; height: 7; radius: 3.5
            color: win.accent
            x: parent.width / 2 - 3.5 + 8 * Math.cos(angle)
            y: parent.height / 2 - 3.5 + 8 * Math.sin(angle)
            property real angle: 0
            NumberAnimation on angle { from: 0; to: 2 * Math.PI; duration: 800; loops: Animation.Infinite }
        }
    }

    // Una cara para la foto: tu inicial, un icono o tu foto, sobre un degradado del tema
    component Face_: Rectangle {
        id: fc
        property int kind: 0
        property url photo: ""
        property string letter: ""
        readonly property var tones: [["#e0a9b4", "#7a4458"], ["#8e2e66", "#4a2c4f"], ["#ff8fc6", "#7a4458"], ["#5b3445", "#2a1830"]]
        gradient: Gradient {
            GradientStop { position: 0; color: fc.tones[Math.min(fc.kind, 3)][0] }
            GradientStop { position: 1; color: fc.tones[Math.min(fc.kind, 3)][1] }
        }
        Label_ {
            anchors.centerIn: parent
            visible: fc.kind === 0
            text: fc.letter
            color: "#ffffff"
            font.pixelSize: fc.height * 0.42
            font.weight: Font.Black
        }
        Icon_ {
            anchors.centerIn: parent
            visible: fc.kind >= 1 && fc.kind <= 3
            width: fc.height * 0.46; height: width
            name: ["", "navegar", "jugar", "musica"][Math.min(fc.kind, 3)]
            color: "#ffffff"
        }
        Image {
            anchors.fill: parent
            visible: fc.kind === 4
            source: fc.kind === 4 ? fc.photo : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(512, 512)
            asynchronous: true
        }
    }

    component Round_: Item {
        id: rd
        property int kind: 0
        property bool selected: false
        property bool ring: false
        Face_ { id: rface; anchors.fill: parent; kind: rd.kind; photo: win.photo; letter: win.name.trim().charAt(0).toUpperCase(); visible: false }
        Rectangle { id: rmask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        RectangularShadow {
            anchors.fill: parent
            visible: rd.ring
            radius: width / 2
            blur: 30; spread: -6; offset.y: 8
            color: win.accent
        }
        MultiEffect { anchors.fill: parent; source: rface; maskEnabled: true; maskSource: rmask }
        Rectangle {
            anchors.fill: parent
            anchors.margins: rd.ring ? -3 : rd.selected ? -4 : 0
            radius: width / 2
            color: "transparent"
            border.width: rd.ring ? 3 : 2
            border.color: win.accent
            visible: rd.ring || rd.selected
        }
    }

    // La foto que se guarda (256 × 256, cuadrada: el inicio de sesión y el bloqueo la recortan en círculo)
    Face_ {
        id: faceOut
        x: -1000
        width: 256; height: 256
        kind: win.face
        photo: win.photo
        letter: win.name.trim().charAt(0).toUpperCase()
    }

    FileDialog {
        id: photoDialog
        title: "Elige tu foto"
        nameFilters: ["Imágenes (*.png *.jpg *.jpeg *.webp *.svg)"]
        onAccepted: { win.photo = selectedFile; win.face = 4; }
    }
    FileDialog {
        id: copyDialog
        title: "Elige tu copia de Ágape"
        currentFolder: apogeo.mediaFolder
        nameFilters: ["Copias de Ágape (*.agape)"]
        onAccepted: win.copy = apogeo.copyInfo(selectedFile.toString())
    }

    // ---------- La tarjeta ----------

    RectangularShadow {
        anchors.fill: card
        offset.y: 18
        blur: 50
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.45)
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 620
        height: page.implicitHeight + 56
        radius: 24
        color: Qt.rgba(30 / 255, 22 / 255, 33 / 255, 0.74)
        border.color: win.border
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Rectangle { // el brillo de 1 px de arriba
            x: parent.radius; y: 1
            width: parent.width - 2 * parent.radius; height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }
        Loader {
            id: page
            x: 32; y: 30
            width: parent.width - 64
            sourceComponent: [pHello, pProfile, pAgape, pCopy, pFloors, pIsland, pDone][win.step]
        }
    }

    // Por dónde vas
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        spacing: 8
        Repeater {
            model: win.steps
            delegate: Rectangle {
                required property int index
                width: index === win.step ? 26 : 8
                height: 8
                radius: 4
                color: index === win.step ? win.accent : win.faint
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
        }
    }

    // Saltar: por ahora (vuelve en el próximo inicio) o para siempre
    Button_ {
        id: skip
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 22
        kind: "ghost"
        text: "Saltar"
        visible: win.step < win.steps - 1
        onClicked: skipMenu.open()
    }
    Popup {
        id: skipMenu
        x: win.width - width - 22
        y: skip.y + skip.height + 8
        width: 260
        padding: 6
        background: Rectangle { radius: 16; color: win.chrome; border.color: win.border }
        contentItem: Column {
            spacing: 2
            Repeater {
                model: [
                    { title: "Saltar por ahora", sub: "Vuelve a salir en el próximo inicio", done: false },
                    { title: "No volver a mostrar", sub: "La tienes en el buscador («Bienvenida»)", done: true }
                ]
                delegate: AbstractButton {
                    id: opt
                    required property var modelData
                    width: 248
                    height: 52
                    hoverEnabled: true
                    background: Rectangle { radius: 11; color: opt.hovered ? win.hover : "transparent" }
                    contentItem: Column {
                        leftPadding: 10
                        topPadding: 8
                        spacing: 1
                        Label_ { text: opt.modelData.title; font.weight: Font.Bold }
                        Label_ { text: opt.modelData.sub; color: win.muted; font.pixelSize: 12 }
                    }
                    onClicked: apogeo.finish(opt.modelData.done)
                }
            }
        }
    }

    // ---------- Los pasos ----------

    Component {
        id: pHello
        Column {
            spacing: 0
            Header_ {
                title: "Te damos la bienvenida a Apogeo"
                lead: "En un par de minutos lo tienes todo listo: tu perfil, tu Ágape con todas tus cosas y cómo moverte por los pisos."
            }
            Item {
                width: parent.width
                height: 30
                Check_ {
                    anchors.centerIn: parent
                    visible: apogeo.online
                    text: "Conectado a internet"
                    tone: win.muted
                }
                Row {
                    anchors.centerIn: parent
                    visible: !apogeo.online
                    spacing: 12
                    Check_ { ok: false; text: "Sin conexión a internet"; anchors.verticalCenter: parent.verticalCenter }
                    Button_ { text: "Conectar a una red…"; iconName: "wifi"; onClicked: apogeo.openNetwork() }
                }
                Timer { interval: 2000; repeat: true; running: true; onTriggered: apogeo.check_online() }
            }
            Actions_ { next: "Empezar"; onNextClicked: win.go(1) }
        }
    }

    Component {
        id: pProfile
        Column {
            id: prof
            spacing: 0
            function save() {
                win.profileError = "";
                faceOut.grabToImage(r => {
                    if (!r.saveToFile(apogeo.avatarPath)) { win.profileError = "No se ha podido guardar la foto."; return; }
                    win.profileError = apogeo.saveProfile(win.name);
                    if (win.profileError === "") { win.profileSaved = true; win.go(2); }
                }, Qt.size(256, 256));
            }
            Header_ {
                title: "¿Cómo te llamas?"
                lead: "Tu nombre y tu foto salen al iniciar sesión y en la pantalla de bloqueo."
            }
            Round_ {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 88; height: 88
                kind: win.face
                ring: true
            }
            Item { width: 1; height: 14 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Repeater {
                    model: 4
                    delegate: Round_ {
                        required property int index
                        width: 40; height: 40
                        kind: index
                        selected: win.face === index
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.face = parent.index }
                    }
                }
                Item {
                    width: 40; height: 40
                    Round_ { anchors.fill: parent; kind: 4; selected: win.face === 4; visible: win.photo.toString() !== "" }
                    Rectangle {
                        anchors.fill: parent
                        visible: win.photo.toString() === ""
                        radius: 20
                        color: pick.containsMouse ? win.press : win.hover
                        border.width: 1.5
                        border.color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.2)
                        Icon_ { anchors.centerIn: parent; name: "foto"; color: win.muted }
                    }
                    MouseArea {
                        id: pick
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (win.photo.toString() !== "" && win.face !== 4) ? (win.face = 4) : photoDialog.open()
                    }
                    ToolTip.visible: pick.containsMouse
                    ToolTip.text: "Elegir una foto…"
                }
            }
            Item { width: 1; height: 16 }
            Field_ {
                id: nameField
                text: win.name
                placeholderText: "Tu nombre"
                maximumLength: 40
                onTextEdited: win.name = text
                onAccepted: prof.save()
                Component.onCompleted: forceActiveFocus()
            }
            Item { width: 1; height: win.profileError ? 12 : 0 }
            Warn_ { text: win.profileError }
            Actions_ {
                back: "Atrás"; next: "Siguiente"
                nextEnabled: win.name.trim() !== ""
                onBackClicked: win.go(0)
                onNextClicked: prof.save()
            }
        }
    }

    Component {
        id: pAgape
        Column {
            id: ag
            spacing: 0
            function download() {
                if (!token.text.trim()) return;
                win.agapeError = "";
                win.downloaded = 0;
                win.installing = true;
                apogeo.installAgape(token.text);
                token.text = "";
            }
            Header_ {
                title: apogeo.agapeInstalled ? "Ágape está listo" : win.installing ? "Instalando Ágape" : "Instala Ágape"
                lead: apogeo.agapeInstalled ? "Ya es tu navegador y se actualiza solo. Ahora puedes traer tus cosas."
                    : win.installing ? "Un momento: lo estoy descargando."
                    : "Escribe tu llave de Ágape para descargarlo. Solo se pide esta vez; luego se actualiza solo."
            }
            // Pedir la llave
            Column {
                width: parent.width
                visible: !apogeo.agapeInstalled && !win.installing
                spacing: 12
                Field_ {
                    id: token
                    echoMode: TextInput.Password
                    placeholderText: "Llave de Ágape"
                    onAccepted: ag.download()
                    Component.onCompleted: if (visible) forceActiveFocus()
                }
                Warn_ { text: win.agapeError || (apogeo.online ? "" : "Sin conexión a internet: conéctate para descargar Ágape.") }
                Label_ {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "La llave se guarda solo en este equipo."
                    color: win.muted
                    font.pixelSize: 13
                }
            }
            // Descargando
            Column {
                width: parent.width
                visible: win.installing
                spacing: 10
                Rectangle {
                    width: 360; height: 8; radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: win.hover
                    Rectangle {
                        height: parent.height; radius: 4
                        width: win.downloaded > 0 ? parent.width * win.downloaded : 0
                        color: win.accent
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                }
                Label_ {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: win.muted
                    font.pixelSize: 13
                    text: win.downloaded > 0 ? Math.round(win.downloaded * 100) + " %" : "Preparando…"
                }
            }
            // Hecho
            Check_ {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: apogeo.agapeInstalled
                text: "Ágape instalado"
            }
            Actions_ {
                back: apogeo.agapeInstalled ? "Atrás" : "Más tarde"
                next: apogeo.agapeInstalled ? "Siguiente" : "Descargar"
                backEnabled: !win.installing
                nextEnabled: apogeo.agapeInstalled || (!win.installing && apogeo.online)
                onBackClicked: win.go(apogeo.agapeInstalled ? 1 : 3)
                onNextClicked: apogeo.agapeInstalled ? win.go(3) : ag.download()
            }
        }
    }

    Component {
        id: pCopy
        Column {
            spacing: 0
            Header_ {
                title: win.restored ? "¡Tus cosas ya están aquí!" : win.restoring ? "Sigue en Ágape" : "Trae tu Ágape"
                lead: !apogeo.agapeInstalled ? "Cuando instales Ágape (el paso anterior) podrás traer aquí la copia de tu otro equipo."
                    : win.restored ? "Ágape se reinicia para terminar de ponerlo todo en su sitio."
                    : win.restoring ? "Escribe en Ágape la contraseña de la copia. Cuando acabe, vuelve aquí."
                    : "Elige la copia que hiciste en tu otro equipo. Ágape te pedirá su contraseña y volverán tus marcadores, contraseñas, sesiones, historial y tema."
            }
            // La copia elegida (o el botón para elegirla)
            Rectangle {
                visible: apogeo.agapeInstalled && !win.restored && !win.restoring
                width: 440; height: 70
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 16
                color: dropArea.containsMouse && !win.copy.name ? win.hover : "transparent"
                border.width: 1.5
                border.color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.22)
                Rectangle {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 42; radius: 12
                    color: win.accentSoft
                    Icon_ { anchors.centerIn: parent; width: 20; height: 20; name: "copia"; color: win.accent }
                }
                Column {
                    x: 70; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 70 - (change.visible ? change.width + 28 : 16)
                    spacing: 2
                    Label_ { width: parent.width; elide: Text.ElideMiddle; wrapMode: Text.NoWrap; font.weight: Font.ExtraBold; text: win.copy.name || "Elegir la copia…" }
                    Label_ { width: parent.width; elide: Text.ElideRight; wrapMode: Text.NoWrap; color: win.muted; font.pixelSize: 13; text: win.copy.where || "Un archivo .agape (en un USB, otro disco o la nube)" }
                }
                MouseArea { id: dropArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: copyDialog.open() }
                Button_ {
                    id: change
                    visible: !!win.copy.name
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    text: "Cambiar…"
                    onClicked: copyDialog.open()
                }
            }
            Spinner_ { visible: win.restoring; anchors.horizontalCenter: parent.horizontalCenter }
            Check_ { visible: win.restored; anchors.horizontalCenter: parent.horizontalCenter; text: "Copia restaurada" }
            Actions_ {
                readonly property bool choosing: apogeo.agapeInstalled && !win.restored && !win.restoring
                back: !apogeo.agapeInstalled || win.restored ? "Atrás" : win.restoring ? "Elegir otra copia" : "Empezar de cero"
                next: choosing ? "Restaurar" : "Siguiente"
                nextEnabled: !choosing || !!win.copy.path
                onBackClicked: {
                    if (!apogeo.agapeInstalled || win.restored) win.go(2);
                    else if (win.restoring) { win.restoring = false; copyDialog.open(); }
                    else win.go(4);
                }
                onNextClicked: {
                    if (choosing) {
                        win.restoring = true;
                        apogeo.restoreCopy(win.copy.path);
                    } else win.go(4);
                }
            }
        }
    }

    Component {
        id: pFloors
        Column {
            spacing: 0
            Header_ {
                title: "Tres pisos"
                lead: "Cada piso tiene sus apps y sus ventanas. Cambia con la barra de la derecha o con la rueda del ratón en el borde derecho."
            }
            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: [
                        { key: "jugar", name: "Jugar", kind: 5, text: "La consola con todos tus juegos. Sin avisos y a 60 FPS." },
                        { key: "navegar", name: "Navegar", kind: 0, text: "Ágape, música y tus cosas. Aquí llegan los avisos." },
                        { key: "estudiar", name: "Estudiar", kind: 2, text: "Temporizador de estudio y nada que distraiga." }
                    ]
                    delegate: Rectangle {
                        id: fl
                        required property var modelData
                        width: 178; height: 190
                        radius: 16
                        color: Qt.rgba(241 / 255, 230 / 255, 234 / 255, 0.04)
                        border.color: win.border
                        clip: true
                        // El fondo de verdad de ese piso, en pequeño
                        ShaderEffect {
                            id: mini
                            width: 178; height: 84
                            property real t: win.time
                            property real kind: fl.modelData.kind
                            property real light: 0
                            property size res: Qt.size(356, 168)
                            property color base: "#120d14"
                            property color c1: "#4a2c4f"
                            property color c2: "#7a4458"
                            property color c3: "#e0a9b4"
                            fragmentShader: "file:///usr/share/plasma/wallpapers/org.apogeo.fondo/contents/shaders/fondo.frag.qsb"
                            layer.enabled: true
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: miniMask }
                        }
                        Item { // solo las esquinas de arriba redondeadas
                            id: miniMask
                            width: 178; height: 84
                            visible: false
                            layer.enabled: true
                            Rectangle { width: parent.width; height: parent.height + 16; radius: 16 }
                        }
                        RectangularShadow {
                            x: 10; y: 42; width: 32; height: 32
                            radius: 11; blur: 18; spread: -4; offset.y: 4
                            color: win.accent
                        }
                        Rectangle {
                            x: 10; y: 42; width: 32; height: 32
                            radius: 11
                            color: win.accent
                            Icon_ { anchors.centerIn: parent; name: fl.modelData.key; color: win.accentText }
                        }
                        Column {
                            x: 12; y: 94
                            width: parent.width - 24
                            spacing: 3
                            Label_ { text: fl.modelData.name; font.pixelSize: 15; font.weight: Font.ExtraBold }
                            Label_ { width: parent.width; text: fl.modelData.text; color: win.muted; font.pixelSize: 13; lineHeight: 1.15 }
                        }
                    }
                }
            }
            Actions_ { back: "Atrás"; next: "Siguiente"; onBackClicked: win.go(3); onNextClicked: win.go(5) }
        }
    }

    Component {
        id: pIsland
        Column {
            spacing: 0
            Header_ {
                title: "La isla"
                lead: "Tu barra, abajo en el centro. Cambia en cada piso y se esconde sola."
            }
            // Una isla de muestra
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: islandRow.implicitWidth + 16
                height: 46
                radius: 20
                color: Qt.rgba(30 / 255, 22 / 255, 33 / 255, 0.7)
                border.color: win.border
                Row {
                    id: islandRow
                    anchors.centerIn: parent
                    spacing: 4
                    Item {
                        width: 34; height: 34
                        RectangularShadow { anchors.fill: parent; radius: 12; blur: 18; spread: -4; offset.y: 4; color: win.accent }
                        Rectangle { anchors.fill: parent; radius: 12; color: win.accent; Icon_ { anchors.centerIn: parent; name: "buscar"; color: win.accentText } }
                    }
                    Rectangle { width: 1; height: 22; color: win.border; anchors.verticalCenter: parent.verticalCenter }
                    Repeater {
                        model: ["carpeta", "web", "musica"]
                        delegate: Item { required property string modelData; width: 34; height: 34; Icon_ { anchors.centerIn: parent; name: parent.modelData; color: win.muted } }
                    }
                    Rectangle { width: 1; height: 22; color: win.border; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: 34; height: 34; Icon_ { anchors.centerIn: parent; name: "volumen"; color: win.muted } }
                    Label_ {
                        id: islandClock
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: 8
                        leftPadding: 4
                        font.weight: Font.Bold
                        text: Qt.formatTime(new Date(), "HH:mm")
                        Timer { interval: 10000; repeat: true; running: true; onTriggered: islandClock.text = Qt.formatTime(new Date(), "HH:mm") }
                    }
                }
            }
            Item { width: 1; height: 18 }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Repeater {
                    model: [
                        { icon: "buscar", text: "Busca apps, archivos o en la web" },
                        { icon: "carpeta", text: "Tus apps abiertas, a un clic" },
                        { icon: "esconder", text: "Acerca el ratón abajo para que aparezca" }
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: 10
                        Icon_ { name: parent.modelData.icon; color: win.accent; anchors.verticalCenter: parent.verticalCenter }
                        Label_ { text: parent.modelData.text; wrapMode: Text.NoWrap; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            Actions_ { back: "Atrás"; next: "Siguiente"; onBackClicked: win.go(4); onNextClicked: win.go(6) }
        }
    }

    Component {
        id: pDone
        Column {
            spacing: 0
            Header_ {
                title: "¡Todo listo!"
                lead: "Si algo lo dejaste para luego, vuelve a abrir la bienvenida desde el buscador de la isla («Bienvenida»)."
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Check_ { ok: win.profileSaved; text: win.profileSaved ? "Tu nombre y tu foto puestos" : "Tu nombre y tu foto: para luego" }
                Check_ { ok: apogeo.agapeInstalled; text: apogeo.agapeInstalled ? "Ágape instalado" : "Ágape: para luego" }
                Check_ { visible: apogeo.agapeInstalled; ok: win.restored; text: win.restored ? "Tus cosas de Ágape, traídas" : "Ágape empieza de cero" }
                Check_ { text: "Ya sabes moverte por los pisos" }
            }
            Actions_ { back: "Atrás"; next: "Empezar a usar Apogeo"; arrow: false; onBackClicked: win.go(5); onNextClicked: apogeo.finish(true) }
        }
    }
}
