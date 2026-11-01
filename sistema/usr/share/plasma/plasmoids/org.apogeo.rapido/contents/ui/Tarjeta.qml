import QtQuick
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.volume as PulseAudio
import Apogeo

// La tarjeta rápida: cuelga de la hora (debajo; encima si la barra está abajo) y flota sobre las ventanas, sin moverlas.
// Solo lo de un momento: el Wi-Fi, el bluetooth y el silencio en botones redondos; el volumen y el brillo en barras (se
// arrastran o se pulsan); luz nocturna y no molestar; y abajo bloquear, reposo, cerrar sesión, reiniciar y apagar
// (los tres últimos piden un segundo toque: el botón se pone rojo, «¿Seguro?»). Se va al pulsar fuera, con Esc o con
// otro clic en la hora (o Meta+N). La música, los avisos y el tiempo están en la Órbita.
// Lo de los botones lo lee y lo cambia «apogeo-ajustes rapido», solo con la tarjeta abierta.
PlasmaCore.Dialog {
    id: tarjeta
    type: PlasmaCore.Dialog.AppletPopup
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: true
    visible: false

    // Abrir o cerrar (un clic en la hora con la tarjeta abierta: el clic ya la ha cerrado al pulsar fuera, no se reabre)
    property double cerrada: 0
    function alternar() {
        if (visible) { visible = false; return; }
        if (Date.now() - cerrada < 300) return;
        visible = true;
        requestActivate();
        caja.forceActiveFocus();
    }
    onVisibleChanged: {
        if (visible) { refresh(); return; }
        cerrada = Date.now();
        armado = "";
    }

    readonly property var sink: PulseAudio.PreferredDevice.sink   // (el altavoz que se usa ahora)
    readonly property bool mudo: !sink || sink.muted
    readonly property int volumen: sink ? Math.round(Math.min(1, sink.volume / 65536) * 100) : 0

    property var st: ({ red: {}, wifi: {}, bt: {} })
    readonly property string tool: "/usr/lib/apogeo/apogeo-ajustes rapido"
    // (Dialog solo admite su contenido como hijo: lo demás va en propiedades)
    property P5Support.DataSource runner: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            if (source === tarjeta.tool) {
                try { tarjeta.st = Object.assign({ red: {}, wifi: {}, bt: {} }, JSON.parse(data.stdout)); } catch (e) {}
            }
            tarjeta.runner.disconnectSource(source);
        }
    }
    function refresh() { tarjeta.runner.connectSource(tool) }
    function act(what, value) {
        tarjeta.runner.connectSource(tool + " " + what + (value !== undefined ? " " + value : ""));
        tarjeta.luego.restart();
    }
    property Timer luego: Timer { interval: 450; onTriggered: tarjeta.refresh() }
    property Timer vigila: Timer { interval: 2500; repeat: true; running: tarjeta.visible; onTriggered: tarjeta.refresh() }

    // Apagar y los suyos: los que cierran lo que tienes abierto piden un segundo toque
    property string armado: ""
    property Timer desarmar: Timer { interval: 3000; onTriggered: tarjeta.armado = "" }
    function energia(clave, preguntar) {
        if (preguntar && armado !== clave) { armado = clave; tarjeta.desarmar.restart(); return; }
        armado = "";
        visible = false;
        act(clave);
    }

    // ---------- Piezas ----------

    // Un botón redondo con su nombre debajo (encendido, en blanco)
    component Redondo: AbstractButton {
        id: re
        property string icono
        property string nombre
        property bool on: false
        width: 92; height: 80
        hoverEnabled: true
        opacity: enabled ? 1 : 0.45
        background: Item {}
        contentItem: Item {
            Rectangle {
                id: bola
                anchors.horizontalCenter: parent.horizontalCenter
                width: 52; height: 52; radius: width / 2
                color: re.on ? (re.hovered ? Qt.darker(Tema.encendido, 1.06) : Tema.encendido) : re.hovered ? Tema.pulsado : Tema.encima
                Behavior on color { ColorAnimation { duration: 160 } }
                Icono { anchors.centerIn: parent; width: 20; height: 20; nombre: re.icono; color: re.on ? Tema.sobreEncendido : Tema.texto }
            }
            Texto {
                anchors.top: bola.bottom; anchors.topMargin: 7
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: re.nombre
                font.pixelSize: 11; font.weight: Font.DemiBold
                color: re.on ? Tema.texto : Tema.apagado
                elide: Text.ElideRight; wrapMode: Text.NoWrap; textFormat: Text.PlainText
            }
        }
    }
    // El volumen o el brillo: una barra que se llena desde la izquierda y se arrastra (o se pulsa, o con la rueda)
    component Barra: Item {
        id: ba
        property string icono
        property int value: 0
        signal elegido(int value)
        property real ahora: value
        Binding on ahora { value: ba.value; when: !zonaBa.pressed }
        height: 44
        Rectangle { anchors.fill: parent; radius: Tema.r(14); color: Tema.encima }
        Item {
            anchors.fill: parent
            clip: true
            Rectangle {
                width: Math.max(0, Math.min(1, ba.ahora / 100)) * parent.width
                height: parent.height
                radius: Tema.r(14)
                color: Tema.encendido
                Behavior on width { enabled: !zonaBa.pressed; NumberAnimation { duration: 140 } }
            }
        }
        Icono {
            x: 15; anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18
            nombre: ba.icono
            color: ba.ahora / 100 * ba.width > 36 ? Tema.sobreEncendido : Tema.texto
        }
        Texto {
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(ba.ahora) + " %"
            font { family: Tema.mono; pixelSize: 11; weight: Font.DemiBold }
            color: ba.ahora / 100 * ba.width > ba.width - 50 ? Tema.sobreEncendido : Tema.apagado
        }
        MouseArea {
            id: zonaBa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function lee(x) { ba.ahora = Math.round(Math.max(0, Math.min(1, x / width)) * 100); seguido.restart(); }
            onPressed: m => lee(m.x)
            onPositionChanged: m => { if (pressed) lee(m.x); }
            onReleased: ba.elegido(ba.ahora)
            onWheel: w => { ba.ahora = Math.max(0, Math.min(100, ba.ahora + (w.angleDelta.y > 0 ? 5 : -5))); ba.elegido(ba.ahora); }
        }
        Timer { id: seguido; interval: 120; onTriggered: ba.elegido(ba.ahora) }
    }
    // Luz nocturna y no molestar: medio ancho cada una, su icono, su nombre y cómo está
    component Pastilla: AbstractButton {
        id: pa
        property string icono
        property bool on: false
        height: 50
        hoverEnabled: true
        background: Rectangle {
            radius: Tema.r(16)
            color: pa.on ? (pa.hovered ? Qt.darker(Tema.encendido, 1.06) : Tema.encendido) : pa.hovered ? Tema.pulsado : Tema.encima
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        contentItem: Item {
            Icono { id: paIco; x: 13; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; nombre: pa.icono; color: pa.on ? Tema.sobreEncendido : Tema.texto }
            Column {
                x: paIco.x + paIco.width + 10
                width: parent.width - x - 8
                anchors.verticalCenter: parent.verticalCenter
                Texto { width: parent.width; text: pa.text; font.pixelSize: 12; font.weight: Font.DemiBold; color: pa.on ? Tema.sobreEncendido : Tema.texto; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                Texto { width: parent.width; text: pa.on ? "Encendido" : "Apagado"; font.pixelSize: 11; color: pa.on ? Qt.rgba(Tema.sobreEncendido.r, Tema.sobreEncendido.g, Tema.sobreEncendido.b, 0.65) : Tema.apagado; elide: Text.ElideRight; wrapMode: Text.NoWrap }
            }
        }
    }
    // Un botón de la fila de apagar (armado: rojo y «¿Seguro?»)
    component Energia: AbstractButton {
        id: en
        property string icono
        property string clave
        property bool preguntar: false
        readonly property bool armado: tarjeta.armado === clave
        width: 60; height: 66
        hoverEnabled: true
        onClicked: tarjeta.energia(clave, preguntar)
        background: Item {}
        contentItem: Item {
            Rectangle {
                id: circulo
                anchors.horizontalCenter: parent.horizontalCenter
                width: 42; height: 42; radius: width / 2
                color: en.armado ? Tema.error : en.hovered ? Tema.pulsado : Tema.encima
                Behavior on color { ColorAnimation { duration: 160 } }
                Icono { anchors.centerIn: parent; width: 17; height: 17; nombre: en.icono; color: en.armado ? "#ffffff" : Tema.texto }
            }
            Texto {
                anchors.top: circulo.bottom; anchors.topMargin: 6
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: en.armado ? "¿Seguro?" : en.text
                font.pixelSize: 11; font.weight: en.armado ? Font.Bold : Font.Normal
                color: en.armado ? Tema.error : Tema.apagado
                wrapMode: Text.NoWrap
            }
        }
    }

    // ---------- La tarjeta ----------

    mainItem: Item {
        id: caja
        // (un poco separada de la barra y del borde de la pantalla)
        readonly property bool abajo: tarjeta.location === PlasmaCore.Types.BottomEdge
        width: tarjeta_.width + 8
        height: tarjeta_.height + 8
        focus: true
        Keys.onEscapePressed: tarjeta.visible = false

        Item {
            id: tarjeta_
            width: 332
            height: col.implicitHeight + 28
            y: caja.abajo ? 0 : 8
            // Al abrirse, entra de la barra
            opacity: tarjeta.visible ? 1 : 0
            transform: Translate { y: tarjeta.visible ? 0 : (caja.abajo ? 8 : -8); Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } } }
            Behavior on opacity { NumberAnimation { duration: 160 } }

            Cristal { anchors.fill: parent; activo: tarjeta.visible; brillo: false; oscuro: Tema._orbita ? 0.7 : 0.58; radio: Tema.r(22) }
            Rectangle { anchors.fill: parent; radius: Tema.r(22); color: "transparent"; border.width: 1; border.color: Tema.borde }

            Column {
                id: col
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12

                // El Wi-Fi (o el cable), el bluetooth y el sonido
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6
                    Redondo {
                        readonly property bool hay: !!tarjeta.st.wifi.hay
                        icono: hay ? (tarjeta.st.wifi.on ? "wifi" : "sinred") : tarjeta.st.red.on ? "cable" : "sinred"
                        on: hay ? !!tarjeta.st.wifi.on : !!tarjeta.st.red.on
                        nombre: tarjeta.st.red.on ? tarjeta.st.red.texto : hay && !tarjeta.st.wifi.on ? "Wi-Fi apagado" : "Sin conexión"
                        // (sin Wi-Fi, abre los ajustes de la red)
                        onClicked: tarjeta.act("wifi")
                    }
                    Redondo {
                        icono: "bluetooth"
                        enabled: !!tarjeta.st.bt.hay
                        on: !!tarjeta.st.bt.on
                        nombre: !tarjeta.st.bt.hay ? "Sin bluetooth" : "Bluetooth"
                        onClicked: tarjeta.act("bluetooth")
                    }
                    Redondo {
                        icono: tarjeta.mudo ? "silencio" : "volumen"
                        enabled: !!tarjeta.sink
                        on: !tarjeta.mudo
                        nombre: tarjeta.mudo ? "Silencio" : "Sonido"
                        onClicked: tarjeta.sink.muted = !tarjeta.sink.muted
                    }
                }

                // El volumen y el brillo (si la pantalla deja)
                Barra {
                    width: parent.width
                    icono: tarjeta.mudo ? "silencio" : "volumen"
                    value: tarjeta.volumen
                    onElegido: v => { if (!tarjeta.sink) return; tarjeta.sink.muted = false; tarjeta.sink.volume = Math.round(v / 100 * 65536); }
                }
                Barra {
                    width: parent.width
                    visible: (tarjeta.st.brillo !== undefined ? tarjeta.st.brillo : -1) >= 0
                    icono: "sol"
                    value: Math.max(0, tarjeta.st.brillo || 0)
                    onElegido: v => tarjeta.act("brillo", v)
                }

                // Luz nocturna · no molestar
                Row {
                    width: parent.width
                    spacing: 8
                    Pastilla { width: (parent.width - 8) / 2; text: "Luz nocturna"; icono: "luna"; on: !!tarjeta.st.luz; onClicked: tarjeta.act("luz") }
                    Pastilla { width: (parent.width - 8) / 2; text: "No molestar"; icono: "campana"; on: !!tarjeta.st.silencio; onClicked: tarjeta.act("silencio") }
                }

                Rectangle { width: parent.width; height: 1; color: Tema.linea }

                // Bloquear · reposo · cerrar sesión · reiniciar · apagar
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 1
                    Energia { text: "Bloquear"; icono: "llave"; clave: "bloquear" }
                    Energia { text: "Reposo"; icono: "luna"; clave: "reposo" }
                    Energia { text: "Salir"; icono: "salir"; clave: "salir"; preguntar: true }
                    Energia { text: "Reiniciar"; icono: "actualizar"; clave: "reiniciar"; preguntar: true }
                    Energia { text: "Apagar"; icono: "apagar"; clave: "apagar"; preguntar: true }
                }
            }
        }
    }
}
