import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Apogeo

// El instalador de Apogeo (en el USB): una tarjeta de cristal en el centro, como la bienvenida, sobre el fondo animado
// de Navegar, con puntos abajo que marcan por dónde vas: hola (y la red), tú, dónde va y la instalación. La parte de
// dentro es apogeo-instalador («instalador»).
ApplicationWindow {
    id: win
    visible: true
    visibility: Window.FullScreen
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Instalar Apogeo"
    color: Tema.fondo
    font.family: Tema.letra

    readonly property int steps: 4
    property int step: 0
    // Lo que eliges
    property string nombre: ""
    property string usuario: ""
    property bool usuarioTocado: false
    property string clave: ""
    property string clave2: ""
    property string disco: ""
    property bool conWindows: true
    readonly property int windowsGB: 200
    // La instalación
    property string paso: ""
    property string texto: ""
    property string detalle: ""
    property real progreso: 0
    property int estado: 0          // 0 aún no, 1 instalando, 2 listo, 3 ha fallado
    property string fallo: ""
    readonly property var pasos: [
        { clave: "disco", texto: "El disco, cifrado" },
        { clave: "apogeo", texto: "Apogeo y sus apps" },
        { clave: "sistema", texto: "Tu cuenta y el arranque" },
        { clave: "windows", texto: "Windows, de Microsoft" }
    ]

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
    function gb(b) { return Math.round(b / 1e9) }
    function elegido() { return instalador.discos.find(d => d.ruta === win.disco) || null }
    function cabe(d) { return d.tamano >= (4 + 60 + (win.conWindows ? win.windowsGB : 0)) * 1073741824 }

    Connections {
        target: instalador
        function onAvance(paso, texto, detalle, progreso) {
            win.paso = paso; win.texto = texto; win.detalle = detalle; win.progreso = progreso;
        }
        function onTerminado(bien, mensaje) {
            win.estado = bien ? 2 : 3;
            win.fallo = mensaje;
        }
    }
    Timer { interval: 3000; repeat: true; running: win.estado === 0; onTriggered: instalador.refrescar() }

    // ---------- Fondo: el de Navegar (Órbitas), oscuro alrededor ----------
    Binding { target: Tema; property: "animar"; value: win.active }
    Fondo { anchors.fill: parent; tipo: 0 }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.35) }
            GradientStop { position: 0.5; color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.15) }
            GradientStop { position: 1; color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.6) }
        }
    }
    // Arriba a la izquierda, la marca (como en la barra de Órbita)
    Row {
        x: 26; y: 22
        spacing: 8
        Rectangle { width: 7; height: 7; radius: 3.5; color: Tema.acento; anchors.verticalCenter: parent.verticalCenter }
        Texto {
            text: "APOGEO"
            font.family: Tema.mono
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.letterSpacing: 2.4
            color: Tema.acento
        }
    }
    Texto {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 22
        visible: win.estado === 0
        text: "paso " + (win.step + 1) + " de " + win.steps
        font.family: Tema.mono
        font.pixelSize: 12
        color: Tema.tenue
    }

    // ---------- Piezas ----------

    component Cabeza_: Column {
        property alias title: t.text
        property alias lead: l.text
        property bool logo: false
        width: parent ? parent.width : 0
        spacing: 6
        Image {
            visible: parent.logo
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76; height: 76
            source: "file:///usr/share/apogeo/logo.svg"
            sourceSize: Qt.size(152, 152)
        }
        Item { width: 1; height: parent.logo ? 2 : 0 }
        Texto {
            id: t
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 29
            font.weight: Font.Black
            font.letterSpacing: -0.3
        }
        Texto {
            id: l
            width: Math.min(480, parent.width)
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            color: Tema.apagado
            font.pixelSize: 15
            lineHeight: 1.25
            visible: text !== ""
        }
        Item { width: 1; height: 12 }
    }

    component Acciones_: Item {
        id: acts
        property string back: ""
        property string next: ""
        property bool nextEnabled: true
        property bool arrow: true
        property string nextTipo: "principal"
        signal backClicked()
        signal nextClicked()
        width: parent ? parent.width : 0
        height: 42 + 22
        Boton {
            visible: acts.back !== ""
            tipo: "plano"
            text: acts.back
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            onClicked: acts.backClicked()
        }
        Boton {
            tipo: acts.nextTipo
            grande: true
            text: acts.next
            icono: acts.arrow ? "flecha" : ""
            enabled: acts.nextEnabled
            anchors.bottom: parent.bottom
            anchors.right: acts.back !== "" ? parent.right : undefined
            anchors.horizontalCenter: acts.back === "" ? parent.horizontalCenter : undefined
            onClicked: acts.nextClicked()
        }
    }

    component Etiqueta_: Texto {
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: Tema.apagado
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
        width: 640
        height: page.implicitHeight + 56
        radius: 24
        color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.8)
        border.color: Tema.borde
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Rectangle {
            x: parent.radius; y: 1
            width: parent.width - 2 * parent.radius; height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }
        Loader {
            id: page
            x: 32; y: 30
            width: parent.width - 64
            sourceComponent: [pHola, pTu, pDisco, pInstalar][win.step]
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
                color: index === win.step ? Tema.acento : Tema.tenue
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ---------- Los pasos ----------

    Component {
        id: pHola
        Column {
            spacing: 0
            Cabeza_ {
                logo: true
                title: "Instalar Apogeo"
                lead: "En unos minutos tienes Apogeo en este PC y, al lado, el Windows escondido para los juegos que solo van en Windows."
            }
            // La red: hace falta (Apogeo y Windows se bajan al instalar)
            Item {
                width: parent.width
                height: 30
                visible: instalador.online
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Icono { nombre: "hecho"; color: Tema.acento; anchors.verticalCenter: parent.verticalCenter }
                    Texto { text: "Conectado a internet"; color: Tema.apagado; font.weight: Font.DemiBold }
                }
            }
            Column {
                width: parent.width
                visible: !instalador.online
                spacing: 6
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Icono { nombre: "sinred"; color: Tema.tenue; anchors.verticalCenter: parent.verticalCenter }
                    Texto { text: "Hace falta internet: conecta el cable o elige tu Wi-Fi"; color: Tema.apagado; font.weight: Font.DemiBold }
                }
                Item { width: 1; height: 6 }
                Repeater {
                    model: instalador.redes
                    delegate: Rectangle {
                        id: red
                        required property var modelData
                        property bool abierta: false
                        width: parent.width
                        height: abierta ? 104 : 46
                        radius: Tema.r(12)
                        color: zona.containsMouse || abierta ? Tema.encima : "transparent"
                        clip: true
                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        MouseArea {
                            id: zona
                            width: parent.width; height: 46
                            hoverEnabled: true
                            onClicked: {
                                if (!red.modelData.cerrada) instalador.conectar(red.modelData.nombre, "");
                                else red.abierta = !red.abierta;
                            }
                        }
                        Row {
                            x: 14; height: 46
                            spacing: 12
                            Icono { nombre: "wifi"; anchors.verticalCenter: parent.verticalCenter; opacity: 0.4 + 0.6 * red.modelData.senal / 100 }
                            Texto { text: red.modelData.nombre; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.DemiBold }
                            Icono { nombre: "llave"; visible: red.modelData.cerrada; color: Tema.tenue; width: 13; height: 13; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            x: 14; y: 52
                            spacing: 10
                            visible: red.abierta
                            Campo {
                                id: claveRed
                                width: 380
                                echoMode: TextInput.Password
                                placeholderText: "Contraseña de la Wi-Fi"
                                onAccepted: unir.clicked()
                            }
                            Boton {
                                id: unir
                                text: "Conectar"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    if (!instalador.conectar(red.modelData.nombre, claveRed.text)) mal.text = "No ha entrado: revisa la contraseña";
                                    claveRed.text = "";
                                }
                            }
                        }
                    }
                }
                Texto { id: mal; width: parent.width; horizontalAlignment: Text.AlignHCenter; color: Tema.error; visible: text !== "" }
            }
            Item { width: 1; height: 14 }
            Acciones_ { next: "Empezar"; nextEnabled: instalador.online; onNextClicked: win.go(1) }
        }
    }

    Component {
        id: pTu
        Column {
            spacing: 0
            readonly property bool usuarioBien: /^[a-z_][a-z0-9_-]{0,31}$/.test(win.usuario)
            readonly property bool claveBien: win.clave.length >= 4 && win.clave === win.clave2
            Cabeza_ {
                title: "Tú"
                lead: "Tu nombre y tu contraseña: con ella entras en Apogeo y, si un día el chip de seguridad no abre el disco solo, la pide para abrirlo."
            }
            Etiqueta_ { text: "Tu nombre" }
            Item { width: 1; height: 6 }
            Campo {
                width: parent.width
                text: win.nombre
                placeholderText: "Como quieras que te salude Apogeo"
                focus: true
                onTextChanged: {
                    win.nombre = text;
                    if (!win.usuarioTocado) win.usuario = instalador.usuarioDe(text);
                }
            }
            Item { width: 1; height: 14 }
            Etiqueta_ { text: "Nombre de usuario" }
            Item { width: 1; height: 6 }
            Campo {
                width: parent.width
                text: win.usuario
                font.family: Tema.mono
                placeholderText: "en minúsculas, sin espacios"
                onTextEdited: { win.usuario = text; win.usuarioTocado = true; }
            }
            Item { width: 1; height: 14 }
            Etiqueta_ { text: "Contraseña" }
            Item { width: 1; height: 6 }
            Row {
                width: parent.width
                spacing: 12
                Campo {
                    width: (parent.width - 12) / 2
                    echoMode: TextInput.Password
                    placeholderText: "Contraseña"
                    onTextChanged: win.clave = text
                }
                Campo {
                    width: (parent.width - 12) / 2
                    echoMode: TextInput.Password
                    placeholderText: "Otra vez"
                    onTextChanged: win.clave2 = text
                }
            }
            Item { width: 1; height: 8 }
            Texto {
                width: parent.width
                color: win.clave2 !== "" && win.clave !== win.clave2 ? Tema.error : Tema.tenue
                font.pixelSize: 12
                text: win.clave2 !== "" && win.clave !== win.clave2 ? "Las dos contraseñas no son iguales"
                    : "Apúntala en un sitio seguro: sin ella no se puede abrir el disco si el chip falla."
            }
            Item { width: 1; height: 18 }
            Acciones_ {
                back: "Atrás"
                next: "Seguir"
                nextEnabled: win.nombre.trim() !== "" && parent.usuarioBien && parent.claveBien
                onBackClicked: win.go(0)
                onNextClicked: win.go(2)
            }
        }
    }

    Component {
        id: pDisco
        Column {
            id: col
            spacing: 0
            property bool seguro: false
            Cabeza_ {
                title: "¿Dónde va Apogeo?"
                lead: "Se usa el disco entero: lo que haya en él se borra."
            }
            Repeater {
                model: instalador.discos
                delegate: Rectangle {
                    id: d
                    required property var modelData
                    readonly property bool sel: win.disco === modelData.ruta
                    readonly property bool vale: win.cabe(modelData)
                    width: col.width
                    height: 78
                    radius: Tema.r(14)
                    color: sel ? Tema.rosaSuave : zona.containsMouse && vale ? Tema.encima : "transparent"
                    border.color: sel ? Tema.acento : Tema.borde
                    opacity: vale ? 1 : 0.5
                    MouseArea {
                        id: zona
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: d.vale
                        onClicked: { win.disco = d.modelData.ruta; col.seguro = false; }
                    }
                    Column {
                        x: 16; y: 14
                        width: parent.width - 32
                        spacing: 8
                        Row {
                            spacing: 8
                            Texto { text: d.modelData.nombre; font.weight: Font.Bold }
                            Texto { text: win.gb(d.modelData.tamano) + " GB" + (d.modelData.tipo ? " · " + d.modelData.tipo : ""); color: Tema.apagado }
                            Texto { visible: !d.vale; text: "· no cabe"; color: Tema.error }
                        }
                        // Cómo queda: Apogeo y Windows
                        Row {
                            width: parent.width
                            spacing: 3
                            readonly property real total: Math.max(1, d.modelData.tamano / 1073741824)
                            readonly property real fw: win.conWindows ? Math.min(0.85, win.windowsGB / total) : 0
                            Rectangle {
                                width: (parent.width - (win.conWindows ? 3 : 0)) * (1 - parent.fw)
                                height: 22; radius: 6
                                color: Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, d.sel ? 0.85 : 0.35)
                                Texto {
                                    anchors.centerIn: parent
                                    visible: parent.width > 96
                                    text: "Apogeo · " + Math.max(0, win.gb(d.modelData.tamano) - (win.conWindows ? win.windowsGB : 0) - 4) + " GB"
                                    font.pixelSize: 11; font.weight: Font.Bold
                                    color: d.sel ? Tema.sobreAcento : Tema.texto
                                }
                            }
                            Rectangle {
                                visible: win.conWindows
                                width: (parent.width - 3) * parent.fw
                                height: 22; radius: 6
                                color: Qt.rgba(0.72, 0.61, 1, d.sel ? 0.75 : 0.3)   // (el violeta de Jugar)
                                Texto {
                                    anchors.centerIn: parent
                                    visible: parent.width > 96
                                    text: "Windows · " + win.windowsGB + " GB"
                                    font.pixelSize: 11; font.weight: Font.Bold
                                    color: d.sel ? Tema.sobreAcento : Tema.texto
                                }
                            }
                        }
                    }
                }
            }
            Texto {
                visible: instalador.discos.length === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                color: Tema.error
                text: "No se encuentra ningún disco donde instalar."
            }
            Item { width: 1; height: 14 }
            Row {
                width: parent.width
                spacing: 12
                Interruptor {
                    checked: win.conWindows
                    onToggled: win.conWindows = checked
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    width: parent.width - 54
                    Texto { text: "Windows escondido"; font.weight: Font.DemiBold }
                    Texto {
                        width: parent.width
                        color: Tema.apagado; font.pixelSize: 12
                        text: "Windows 11 de Microsoft, " + win.windowsGB + " GB, solo para los juegos con antitrampas. Se activa solo con la clave de tu PC."
                    }
                }
            }
            Item { width: 1; height: 14 }
            // Lo de borrar, con su casilla
            Rectangle {
                width: parent.width
                height: aviso.implicitHeight + 24
                radius: Tema.r(12)
                color: Qt.rgba(1, 0.42, 0.5, 0.1)
                visible: win.disco !== ""
                Row {
                    x: 14; y: 12
                    spacing: 12
                    width: parent.width - 28
                    Interruptor {
                        checked: col.seguro
                        onToggled: col.seguro = checked
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Texto {
                        id: aviso
                        width: parent.width - 54
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.elegido() ? "Sí, borrar todo lo que hay en «" + win.elegido().nombre + "» (" + win.gb(win.elegido().tamano) + " GB)" : ""
                        font.weight: Font.DemiBold
                    }
                }
            }
            Item { width: 1; height: 18 }
            Acciones_ {
                back: "Atrás"
                next: "Instalar"
                arrow: false
                nextEnabled: win.disco !== "" && col.seguro && !!win.elegido() && win.cabe(win.elegido())
                onBackClicked: win.go(1)
                onNextClicked: {
                    win.estado = 1;
                    win.go(3);
                    instalador.instalar({ disco: win.disco, nombre: win.nombre.trim(), usuario: win.usuario,
                                          clave: win.clave, windows: win.conWindows, windowsGB: win.windowsGB,
                                          zona: "Europe/Madrid", teclado: "es", equipo: "apogeo" });
                    win.clave = ""; win.clave2 = "";
                }
            }
        }
    }

    Component {
        id: pInstalar
        Column {
            spacing: 0
            Cabeza_ {
                logo: win.estado === 2
                title: win.estado === 2 ? "Apogeo está instalado" : win.estado === 3 ? "No se ha podido terminar" : "Instalando"
                lead: win.estado === 2
                    ? (win.conWindows ? "Quita el USB y reinicia. Primero se termina de preparar Windows: entra con tu cuenta Microsoft y, cuando lo pida, escribe su contraseña una vez (para que no la vuelva a pedir). Luego, «Volver a Apogeo»."
                                      : "Quita el USB y reinicia: entras en Apogeo.")
                    : win.estado === 3 ? win.fallo
                    : "Puedes dejarlo solo: tarda un rato (sobre todo bajar Windows). No apagues el PC."
            }
            // Los cuatro pasos de la instalación
            Column {
                width: parent.width
                spacing: 10
                visible: win.estado !== 3
                Repeater {
                    model: win.pasos.filter(p => p.clave !== "windows" || win.conWindows)
                    delegate: Row {
                        id: fila
                        required property var modelData
                        required property int index
                        readonly property int orden: ["disco", "apogeo", "sistema", "windows", "listo"].indexOf(win.paso)
                        readonly property int mio: ["disco", "apogeo", "sistema", "windows"].indexOf(modelData.clave)
                        readonly property bool hecho: win.estado === 2 || orden > mio
                        readonly property bool ahora: win.estado === 1 && orden === mio
                        spacing: 12
                        Item {
                            width: 22; height: 22
                            anchors.verticalCenter: parent.verticalCenter
                            Icono { anchors.centerIn: parent; nombre: "hecho"; color: Tema.acento; visible: fila.hecho }
                            Girando { anchors.centerIn: parent; visible: fila.ahora }
                            Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: Tema.tenue; visible: !fila.hecho && !fila.ahora }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Texto {
                                text: fila.modelData.texto
                                font.weight: fila.ahora ? Font.Bold : Font.Normal
                                color: fila.hecho || fila.ahora ? Tema.texto : Tema.tenue
                            }
                            Texto {
                                visible: fila.ahora && (win.texto !== "" || win.detalle !== "")
                                text: win.texto + (win.detalle ? " · " + win.detalle : "")
                                color: Tema.apagado
                                font.pixelSize: 12
                            }
                        }
                    }
                }
                Item { width: 1; height: 6 }
                // La barra
                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Tema.encima
                    visible: win.estado === 1
                    Rectangle {
                        width: parent.width * Math.max(0.02, win.progreso)
                        height: parent.height
                        radius: 3
                        color: Tema.acento
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }
            }
            // Si falla, lo último del registro
            Rectangle {
                width: parent.width
                height: 180
                radius: Tema.r(12)
                color: Tema.encima
                visible: win.estado === 3
                clip: true
                Flickable {
                    anchors.fill: parent
                    anchors.margins: 12
                    contentHeight: reg.implicitHeight
                    contentY: Math.max(0, contentHeight - height)
                    Texto {
                        id: reg
                        width: parent.width
                        font.family: Tema.mono
                        font.pixelSize: 11
                        color: Tema.apagado
                        text: win.estado === 3 ? instalador.registro() : ""
                    }
                }
            }
            Item { width: 1; height: 18 }
            Acciones_ {
                visible: win.estado === 2
                next: "Reiniciar"
                arrow: false
                onNextClicked: instalador.reiniciar()
            }
            Acciones_ {
                visible: win.estado === 3
                back: "Apagar"
                next: "Volver a empezar"
                arrow: false
                onBackClicked: instalador.apagar()
                onNextClicked: { win.estado = 0; win.progreso = 0; win.paso = ""; win.go(1); }
            }
        }
    }
}
