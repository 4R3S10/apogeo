import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import Apogeo

// La tienda de Apogeo: arriba el buscador y «Instalados»; a la izquierda Inicio y los grupos (como el cajón de apps);
// a la derecha las apps en tarjetas. Al pulsar una, su ficha: capturas, descripción, de dónde se instala (Sistema o
// Flathub) e Instalar / Abrir / Quitar. La parte de dentro es apogeo-tienda («apogeo»).
ApplicationWindow {
    id: win
    visible: true
    width: 1120
    height: 760
    minimumWidth: 880
    minimumHeight: 560
    title: "Tienda de Apogeo"
    color: Tema.superficie
    font.family: Tema.letra

    property string page: "inicio"     // inicio · jugar, estudiar… · buscar · instalados
    property var ficha: null           // la app abierta (su ficha) o null
    property string query: ""
    property int version: 0            // sube cada vez que cambia lo instalado (para volver a mirar)
    property string aviso: ""

    readonly property var nav: [{ clave: "inicio", texto: "Inicio", icono: "apps" },
        { clave: "jugar", texto: "Jugar", icono: "jugar" }, { clave: "estudiar", texto: "Estudiar", icono: "estudiar" },
        { clave: "internet", texto: "Internet y chat", icono: "web" }, { clave: "crear", texto: "Ver y crear", icono: "foto" },
        { clave: "sistema", texto: "Sistema", icono: "ajustes" }]

    function go(p) { ficha = null; page = p; if (p !== "buscar") { field.text = ""; query = ""; } pages.contentY = 0 }
    function abrir(id) { const f = apogeo.ficha(id); if (f.id) { ficha = f; fichaFlick.contentY = 0; shots.contentX = 0 } }
    function estado(id) { win.version; return apogeo.estado(id) }

    Connections {
        target: apogeo
        function onInstalledChanged() { win.version++ }
        function onHecho(id, ok, msg) {
            if (!ok) { const a = apogeo.estado(id); win.aviso = "No se ha podido con " + (a.nombre || id) + (msg ? ": " + msg : ""); avisoTimer.restart() }
        }
        function onMostrar(id) { win.raise(); win.requestActivate(); if (id) win.abrir(id) }
        function onLoadedChanged() { if (abrirFicha) win.abrir(abrirFicha) }
    }
    Timer { id: avisoTimer; interval: 7000; onTriggered: win.aviso = "" }

    // ---------- Izquierda ----------

    Column {
        id: side
        x: 22; y: 18
        width: 210
        spacing: 2
        Row {
            spacing: 10
            leftPadding: 8
            bottomPadding: 14
            Kirigami.Icon { source: "apogeo"; width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter }
            Texto { text: "Tienda"; font.pixelSize: 19; font.weight: Font.ExtraBold; anchors.verticalCenter: parent.verticalCenter }
        }
        Repeater {
            model: win.nav
            delegate: NavItem {
                required property var modelData
                text: modelData.texto
                icono: modelData.icono
                on: win.page === modelData.clave && !win.ficha
                onClicked: win.go(modelData.clave)
            }
        }
        Rectangle { width: parent.width - 24; x: 12; height: 1; color: Tema.borde }
        Item { width: 1; height: 4 }
        NavItem { text: "Instalados"; icono: "hecho"; on: win.page === "instalados" && !win.ficha; onClicked: win.go("instalados") }
        NavItem { text: "Actualizaciones"; icono: "actualizar"; onClicked: apogeo.actualizaciones() }
    }

    component NavItem: AbstractButton {
        id: ni
        property string icono
        property bool on: false
        width: side.width
        height: 38
        hoverEnabled: true
        background: Rectangle {
            radius: Tema.r(11)
            color: ni.on ? Tema.rosaSuave : ni.hovered ? Tema.encima : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Row {
            leftPadding: 12
            spacing: 10
            Icono { nombre: ni.icono; color: ni.on ? Tema.rosa : ni.hovered ? Tema.texto : Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
            Texto { text: ni.text; color: ni.on || ni.hovered ? Tema.texto : Tema.apagado; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---------- Arriba: el buscador ----------

    Item {
        id: top
        x: side.x + side.width + 24
        y: 18
        width: win.width - x - 24
        height: 42
        Campo {
            id: field
            width: parent.width - instalados.width - 12
            implicitHeight: 42
            font.pixelSize: 14
            leftPadding: 40
            placeholderText: "Buscar programas…"
            onTextEdited: searchTimer.restart()
            Keys.onEscapePressed: { text = ""; win.go("inicio") }
            Icono { x: 14; anchors.verticalCenter: parent.verticalCenter; nombre: "buscar"; color: Tema.tenue }
        }
        Boton {
            id: instalados
            anchors.right: parent.right
            height: 42
            text: "Instalados"
            icono: "hecho"
            onClicked: win.go("instalados")
        }
        Timer {
            id: searchTimer
            interval: 220
            onTriggered: {
                win.query = field.text.trim();
                win.ficha = null;
                if (win.query) { win.page = "buscar"; pages.contentY = 0 } else if (win.page === "buscar") win.page = "inicio";
            }
        }
    }

    // ---------- Las páginas ----------

    Flickable {
        id: pages
        visible: !win.ficha
        x: top.x
        y: top.y + top.height + 18
        width: top.width + 12
        height: win.height - y
        contentHeight: body.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Tema.pulsado } }

        Column {
            id: body
            width: top.width
            spacing: 26

            Column {
                visible: !apogeo.loaded
                width: parent.width
                topPadding: 120
                spacing: 14
                Loader { active: !apogeo.loaded; anchors.horizontalCenter: parent.horizontalCenter; sourceComponent: Girando {} }
                Texto { anchors.horizontalCenter: parent.horizontalCenter; text: "Mirando el catálogo…"; color: Tema.apagado }
            }

            // Inicio
            Column {
                visible: apogeo.loaded && win.page === "inicio"
                width: parent.width
                spacing: 26
                Titulo { text: "Destacados" }
                Rejilla { items: apogeo.loaded ? apogeo.destacados() : []; grande: true }
                Titulo { text: "Lo más usado"; visible: masUsados.items.length > 0 }
                Rejilla { id: masUsados; items: apogeo.loaded ? apogeo.masUsados() : [] }
                Repeater {
                    model: apogeo.loaded ? apogeo.grupos : []
                    delegate: Column {
                        required property var modelData
                        width: body.width
                        spacing: 12
                        Item {
                            width: parent.width; height: 30
                            Titulo { text: "Para " + (modelData.texto === "Sistema" ? "el sistema" : modelData.texto.toLowerCase()); anchors.verticalCenter: parent.verticalCenter }
                            Boton { anchors.right: parent.right; tipo: "plano"; text: "Ver todo"; onClicked: win.go(modelData.clave) }
                        }
                        Rejilla { items: apogeo.grupo(modelData.clave, 6) }
                    }
                }
            }

            // Un grupo, lo que buscas o lo instalado
            Column {
                visible: apogeo.loaded && win.page !== "inicio"
                width: parent.width
                spacing: 16
                Titulo {
                    text: win.page === "buscar" ? "«" + win.query + "»" : win.page === "instalados" ? "Instalados"
                          : (win.nav.find(n => n.clave === win.page) || { texto: "" }).texto
                }
                Texto {
                    visible: lista.items.length === 0
                    color: Tema.apagado
                    text: win.page === "buscar" ? "No hay programas con eso. Prueba con otra palabra (en español o en inglés)."
                                               : "Aquí no hay nada todavía."
                }
                Rejilla {
                    id: lista
                    // (se vuelve a pedir al cambiar de página o de lo instalado)
                    items: !apogeo.loaded ? [] : win.page === "buscar" ? apogeo.buscar(win.query)
                         : win.page === "instalados" ? (win.version, apogeo.instalados()) : apogeo.grupo(win.page, 0)
                    limite: 120
                }
                Boton {
                    visible: lista.items.length > lista.limite && lista.mostrados < lista.items.length
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Ver más"
                    onClicked: lista.mostrados += 120
                }
            }
        }
    }

    component Titulo: Texto { font.pixelSize: 18; font.weight: Font.ExtraBold }

    // Las tarjetas: grandes (destacados) o normales, las que quepan por fila
    component Rejilla: Flow {
        id: rj
        property var items: []
        property bool grande: false
        property int limite: 0
        property int mostrados: limite
        onItemsChanged: mostrados = limite
        readonly property int cols: Math.max(2, Math.floor((width + spacing) / (grande ? 270 : 230)))
        readonly property real side: Math.floor((width - (cols - 1) * spacing) / cols)
        width: body.width
        spacing: 12
        Repeater {
            model: rj.limite ? rj.items.slice(0, rj.mostrados) : rj.items
            delegate: Tarjeta { required property var modelData; app: modelData; width: rj.side; grande: rj.grande }
        }
    }

    component Tarjeta: Rectangle {
        id: t
        property var app
        property bool grande: false
        readonly property var st: win.estado(app.id)
        height: grande ? 150 : 96
        radius: Tema.r(16)
        color: zona.containsMouse ? Tema.pulsado : Tema.encima
        border.color: Tema.borde
        Behavior on color { ColorAnimation { duration: 140 } }
        MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.abrir(t.app.id) }
        Kirigami.Icon {
            id: ico
            x: 16; y: 16
            width: t.grande ? 56 : 44; height: width
            source: t.app.icono
            fallback: "application-x-executable"
        }
        Column {
            x: ico.x + ico.width + 14
            y: 16
            width: t.width - x - 14
            spacing: 3
            Texto { width: parent.width; text: t.app.nombre; font.pixelSize: t.grande ? 15 : 14; font.weight: Font.Bold; elide: Text.ElideRight; wrapMode: Text.NoWrap }
            Texto {
                width: parent.width
                text: t.app.resumen
                color: Tema.apagado
                font.pixelSize: 12
                maximumLineCount: t.grande ? 3 : 2
                elide: Text.ElideRight
            }
        }
        Accion { app: t.st; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12; visible: t.grande }
        Texto {
            visible: !t.grande && !!t.st.instalado
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
            text: "✓ Instalado"; color: Tema.rosa; font.pixelSize: 11; font.weight: Font.Bold
        }
        Texto {
            visible: !t.grande && apogeo.busy === t.app.id
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
            text: "…"; color: Tema.rosa; font.pixelSize: 14; font.weight: Font.Bold
        }
    }

    // Instalar · Abrir (con lo que va haciendo mientras)
    component Accion: Row {
        id: ac
        property var app: ({})
        property string origen: ""
        property string paso: ""
        readonly property bool working: apogeo.busy !== "" && apogeo.busy === app.id
        spacing: 8
        Connections { target: apogeo; function onProgreso(id, texto) { if (id === ac.app.id) ac.paso = texto } }
        Boton {
            visible: !ac.app.instalado || ac.working
            tipo: "principal"
            enabled: !ac.working && apogeo.busy === ""
            text: ac.working ? (ac.paso || "Un momento…") : "Instalar"
            onClicked: apogeo.instalar(ac.app.id, ac.origen || (ac.app.paquete ? "sistema" : "flathub"))
        }
        Boton {
            visible: !!ac.app.instalado && !ac.working
            tipo: "principal"
            text: "Abrir"
            onClicked: apogeo.abrir(ac.app.id)
        }
    }

    // ---------- La ficha ----------

    Flickable {
        id: fichaFlick
        visible: !!win.ficha
        x: top.x
        y: top.y + top.height + 18
        width: top.width + 12
        height: win.height - y
        contentHeight: fc.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Tema.pulsado } }

        readonly property var f: win.ficha || ({})
        readonly property var st: win.ficha ? win.estado(win.ficha.id) : ({})
        readonly property bool both: !!f.paquete && !!f.ref
        property int origen: 0   // 0 Sistema · 1 Flathub (si está en los dos)

        Column {
            id: fc
            width: top.width
            spacing: 22

            Boton { tipo: "plano"; text: "Volver"; icono: "anterior"; onClicked: win.ficha = null }

            Row {
                width: parent.width
                spacing: 20
                Kirigami.Icon { width: 96; height: 96; source: fichaFlick.f.icono || ""; fallback: "application-x-executable" }
                Column {
                    width: parent.width - 116
                    spacing: 5
                    anchors.verticalCenter: parent.verticalCenter
                    Texto { text: fichaFlick.f.nombre || ""; font.pixelSize: 26; font.weight: Font.ExtraBold }
                    Texto { visible: !!fichaFlick.f.desarrollador; text: fichaFlick.f.desarrollador || ""; color: Tema.rosa; font.pixelSize: 13 }
                    Texto { width: parent.width; text: fichaFlick.f.resumen || ""; color: Tema.apagado; font.pixelSize: 14 }
                    Item { width: 1; height: 8 }
                    Row {
                        spacing: 10
                        Accion {
                            app: fichaFlick.st
                            origen: fichaFlick.both ? (fichaFlick.origen === 0 ? "sistema" : "flathub") : ""
                        }
                        Boton {
                            visible: !!fichaFlick.st.instalado && apogeo.busy !== fichaFlick.f.id
                            text: "Quitar"
                            enabled: apogeo.busy === ""
                            onClicked: apogeo.quitar(fichaFlick.f.id)
                        }
                        Segmentos {
                            visible: fichaFlick.both && !fichaFlick.st.instalado
                            anchors.verticalCenter: parent.verticalCenter
                            opciones: [{ texto: "Del sistema" }, { texto: "Flathub" }]
                            actual: fichaFlick.origen
                            onElegido: i => fichaFlick.origen = i
                        }
                    }
                    Texto {
                        width: parent.width
                        color: Tema.tenue
                        font.pixelSize: 12
                        text: fichaFlick.st.instalado === "flathub" ? "Instalado de Flathub"
                            : fichaFlick.st.instalado === "sistema" ? "Instalado del sistema (se pone al día con Apogeo)"
                            : fichaFlick.both ? (fichaFlick.origen === 0 ? "Del sistema: se pone al día con Apogeo. Pide tu contraseña."
                                                                         : "De Flathub: va en su propia caja, aparte del sistema.")
                            : fichaFlick.f.paquete ? "Del sistema: se pone al día con Apogeo. Pide tu contraseña."
                            : "De Flathub: va en su propia caja, aparte del sistema."
                    }
                }
            }

            // Las capturas
            ListView {
                id: shots
                visible: count > 0
                width: parent.width
                height: 280
                orientation: ListView.Horizontal
                spacing: 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: fichaFlick.f.capturas || []
                delegate: Rectangle {
                    required property var modelData
                    height: shots.height
                    // (del tamaño de la imagen, no de lo pintado: si no, el ancho depende de sí mismo)
                    width: Math.max(200, img.status === Image.Ready && img.implicitHeight > 0
                                         ? height * img.implicitWidth / img.implicitHeight : height * 16 / 9)
                    radius: Tema.r(14)
                    color: Tema.encima
                    clip: true
                    Image {
                        id: img
                        anchors.fill: parent
                        source: modelData
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.height: 560
                    }
                    Loader { anchors.centerIn: parent; active: img.status === Image.Loading; sourceComponent: Girando {} }
                }
                ScrollBar.horizontal: ScrollBar { contentItem: Rectangle { implicitHeight: 4; radius: 2; color: Tema.pulsado } }
            }

            Texto {
                width: parent.width
                textFormat: Text.RichText
                text: fichaFlick.f.descripcion || ""
                color: Tema.texto
                font.pixelSize: 14
                lineHeight: 1.25
                onLinkActivated: link => apogeo.web(link)
            }

            Row {
                spacing: 28
                Column {
                    visible: !!fichaFlick.f.licencia
                    spacing: 3
                    Texto { text: "Licencia"; color: Tema.tenue; font.pixelSize: 12 }
                    Texto { text: fichaFlick.f.licencia || ""; font.pixelSize: 13 }
                }
                Column {
                    spacing: 3
                    Texto { text: "Dónde está"; color: Tema.tenue; font.pixelSize: 12 }
                    Texto {
                        font.pixelSize: 13
                        text: fichaFlick.both ? "Sistema (" + fichaFlick.f.paquete + ") y Flathub"
                            : fichaFlick.f.paquete ? "Sistema (" + fichaFlick.f.paquete + ")" : "Flathub"
                    }
                }
                Boton { visible: !!fichaFlick.f.web; tipo: "plano"; text: "Su web"; icono: "web"; onClicked: apogeo.web(fichaFlick.f.web) }
            }
        }
    }

    // Lo que no ha salido bien
    Rectangle {
        visible: win.aviso !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: Math.min(parent.width - 80, avisoText.implicitWidth + 40)
        height: avisoText.implicitHeight + 24
        radius: Tema.r(16)
        color: Tema.cromo
        border.color: Tema.borde
        Texto { id: avisoText; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.parent.width - 120); text: win.aviso; wrapMode: Text.Wrap }
    }
}
