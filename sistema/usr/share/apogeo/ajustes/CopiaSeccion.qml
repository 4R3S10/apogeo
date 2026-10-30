import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Apogeo

// Ajustes → Copia: lo tuyo en un archivo cerrado con contraseña (apogeo-copia). Sola cada semana al conectar el USB o
// disco elegido, y con «Hacer copia ahora». «Recuperar…» abre una copia y lo pone todo en su sitio.
Seccion {
    id: sec
    property string palabras: "copia seguridad backup usb disco contraseña recuperar restaurar guardar"
    titulo: "Copia de Apogeo"
    intro: "Lo tuyo en un archivo cerrado con contraseña. Si cambias de PC o reinstalas, lo abres y todo vuelve a estar como lo dejaste."

    readonly property var cfg: apogeo.settings.copia
    readonly property var est: apogeo.copyState
    readonly property bool listo: !!est.clave && cfg.destino.uuid !== ""
    property string trabajando: ""    // clave · hacer · donde · recuperar
    property string mensaje: ""
    property bool fallo: false

    function fecha(t) {
        const d = new Date(t * 1000), hoy = new Date();
        const hm = d.toLocaleTimeString(Qt.locale("es_ES"), "HH:mm");
        if (d.toDateString() === hoy.toDateString()) return "hoy, " + hm;
        const ayer = new Date(hoy.getTime() - 86400000);
        if (d.toDateString() === ayer.toDateString()) return "ayer, " + hm;
        return d.toLocaleDateString(Qt.locale("es_ES"), "d 'de' MMMM");
    }

    Connections {
        target: apogeo
        function onCopyDone(what, ok, message) {
            if (what === "clave") { clave.guardando = false; clave.mensaje = ok ? "" : message; if (ok) clave.close(); }
            if (what === "recuperar") { abrir.abriendo = false; abrir.mensaje = ok ? "Listo: todo está otra vez en su sitio." : message; abrir.bien = ok; }
            if (what === "hacer" || what === "donde") { sec.mensaje = ok ? (what === "hacer" ? "Copia hecha" : "") : message; sec.fallo = !ok; }
            sec.trabajando = "";
        }
    }

    // La última copia y los dos botones
    Rectangle {
        width: parent.width
        height: 78
        radius: Tema.r(16)
        color: Tema.encima
        Rectangle {
            x: 16; anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 46; radius: Tema.r(14)
            color: Tema.rosaSuave
            Icono { anchors.centerIn: parent; width: 20; height: 20; nombre: "copia"; color: Tema.rosa }
        }
        Column {
            x: 76; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - botones.width - 32
            spacing: 2
            Texto {
                width: parent.width
                text: sec.trabajando === "hacer" ? "Haciendo la copia…"
                    : sec.est.fecha ? "Última copia: " + sec.fecha(sec.est.fecha) + " · " + sec.est.tamanoTexto
                    : "Todavía no hay ninguna copia"
                font.pixelSize: 16; font.weight: Font.Bold
                elide: Text.ElideRight; wrapMode: Text.NoWrap
            }
            Texto {
                width: parent.width
                text: sec.mensaje !== "" ? sec.mensaje
                    : sec.est.fecha ? "En «" + sec.est.donde + "» · " + sec.est.archivo
                    : !sec.est.clave ? "Pon una contraseña y elige dónde guardarla"
                    : sec.cfg.destino.uuid === "" ? "Elige dónde guardarla" : "Pulsa «Hacer copia ahora» (luego se hace sola)"
                color: sec.fallo && sec.mensaje !== "" ? Tema.error : Tema.apagado
                font.pixelSize: 13
                elide: Text.ElideRight; wrapMode: Text.NoWrap
            }
        }
        Row {
            id: botones
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Girando { visible: sec.trabajando === "hacer"; anchors.verticalCenter: parent.verticalCenter }
            Boton { text: "Recuperar…"; onClicked: abrirDialogo.open() }
            Boton {
                tipo: "principal"; grande: false
                text: "Hacer copia ahora"
                enabled: sec.listo && sec.trabajando === ""
                onClicked: { sec.mensaje = ""; sec.trabajando = "hacer"; apogeo.makeCopy(); }
            }
        }
    }

    Fila {
        titulo: "Qué se guarda"
        detalle: "Ágape tiene su propia copia (Personalizar → Avanzado)"
        ancha: true
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: [
                    { clave: "ajustes", texto: "Ajustes y modos" }, { clave: "fondos", texto: "Tus fondos" },
                    { clave: "estudios", texto: "~/Estudios" }, { clave: "tareas", texto: "Tareas y exámenes" },
                    { clave: "documentos", texto: "Documentos" }
                ]
                delegate: AbstractButton {
                    id: chip
                    required property var modelData
                    readonly property bool on: sec.cfg.que.indexOf(modelData.clave) >= 0
                    height: 32
                    width: fila.implicitWidth + 24
                    leftPadding: 12; rightPadding: 12; topPadding: 0; bottomPadding: 0
                    hoverEnabled: true
                    background: Rectangle { radius: Tema.r(16); color: chip.on ? Tema.rosaSuave : chip.hovered ? Tema.pulsado : Tema.encima }
                    contentItem: Row {
                        id: fila
                        spacing: 6
                        Icono { visible: chip.on; width: 13; height: 13; nombre: "hecho"; color: Tema.rosa; anchors.verticalCenter: parent.verticalCenter }
                        Texto { text: chip.modelData.texto; font.pixelSize: 13; color: chip.on ? Tema.texto : Tema.apagado; wrapMode: Text.NoWrap; anchors.verticalCenter: parent.verticalCenter }
                    }
                    onClicked: {
                        const q = sec.cfg.que.filter(x => x !== modelData.clave);
                        if (!on) q.push(modelData.clave);
                        apogeo.set("copia.que", q);
                    }
                }
            }
        }
    }
    Fila {
        titulo: "Copia sola"
        detalle: sec.cfg.sola ? "Al conectar «" + (sec.cfg.destino.nombre || "tu USB") + "», si la última tiene más de una semana"
                              : "Solo cuando pulses «Hacer copia ahora»"
        Interruptor { checked: sec.cfg.sola; onToggled: apogeo.set("copia.sola", checked) }
    }
    Fila {
        titulo: "Dónde"
        detalle: "Un USB, un disco o una carpeta (no en este mismo disco)"
        Row {
            spacing: 8
            Girando { visible: sec.trabajando === "donde"; anchors.verticalCenter: parent.verticalCenter }
            Texto {
                visible: sec.cfg.destino.uuid !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: sec.cfg.destino.nombre + (sec.cfg.destino.carpeta && sec.cfg.destino.carpeta !== "." ? " / " + sec.cfg.destino.carpeta : "")
                font.weight: Font.DemiBold
                wrapMode: Text.NoWrap
            }
            Boton {
                text: sec.cfg.destino.uuid === "" ? "Elegir…" : "Cambiar…"
                icono: sec.cfg.destino.uuid === "" ? "carpeta" : ""
                onClicked: dondeDialogo.open()
            }
        }
    }
    Fila {
        titulo: "Cuántas guardar"
        detalle: "Las más viejas se borran solas"
        Segmentos {
            readonly property var valores: [1, 4, 8]
            opciones: [{ texto: "1" }, { texto: "4" }, { texto: "8" }]
            actual: Math.max(0, valores.indexOf(sec.cfg.guardar))
            onElegido: i => apogeo.set("copia.guardar", valores[i])
        }
    }
    Fila {
        titulo: "Contraseña de la copia"
        detalle: sec.est.clave ? "Sin ella no se puede abrir (ni tú): apúntala en KeePassXC" : "Hace falta para cerrar tus copias"
        Boton {
            text: sec.est.clave ? "Cambiar…" : "Poner…"
            tipo: sec.est.clave ? "normal" : "principal"
            grande: false
            icono: "llave"
            onClicked: clave.open()
        }
    }

    // ---------- Poner la contraseña ----------
    Popup {
        id: clave
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 480
        modal: true
        padding: 26
        property bool guardando: false
        property string mensaje: ""
        onOpened: { uno.text = ""; dos.text = ""; mensaje = ""; guardando = false; uno.forceActiveFocus(); }
        background: Rectangle { radius: Tema.r(22); color: Tema.cromo; border.color: Tema.borde }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 14
            Texto { text: sec.est.clave ? "Nueva contraseña de la copia" : "Contraseña de la copia"; font.pixelSize: 20; font.weight: Font.Bold }
            Texto {
                width: parent.width
                color: Tema.apagado
                text: "Al menos 8 letras o números. No se guarda en ningún sitio: si la olvidas, las copias no se pueden abrir."
                    + (sec.est.clave ? " Las copias de antes siguen con la contraseña de antes." : "")
            }
            Campo { id: uno; width: parent.width; implicitHeight: 38; echoMode: TextInput.Password; placeholderText: "Contraseña"; onAccepted: dos.forceActiveFocus() }
            Campo { id: dos; width: parent.width; implicitHeight: 38; echoMode: TextInput.Password; placeholderText: "Otra vez"; onAccepted: guardar.clicked() }
            Texto {
                width: parent.width
                visible: text !== ""
                color: Tema.error
                font.weight: Font.DemiBold
                text: clave.mensaje !== "" ? clave.mensaje
                    : dos.text !== "" && uno.text !== dos.text ? "No son iguales"
                    : uno.text !== "" && uno.text.length < 8 ? "Pon al menos 8" : ""
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Boton { text: "Cancelar"; tipo: "plano"; onClicked: clave.close() }
                Boton {
                    id: guardar
                    tipo: "principal"
                    text: clave.guardando ? "Guardando…" : "Guardar"
                    enabled: uno.text.length >= 8 && uno.text === dos.text && !clave.guardando
                    onClicked: { clave.guardando = true; clave.mensaje = ""; apogeo.setCopyPassword(uno.text, dos.text); uno.text = ""; dos.text = ""; }
                }
            }
        }
    }

    // ---------- Recuperar una copia ----------
    Popup {
        id: abrir
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 500
        modal: true
        padding: 26
        property var info: ({})
        property bool abriendo: false
        property bool bien: false
        property string mensaje: ""
        onOpened: { pass.text = ""; mensaje = ""; bien = false; abriendo = false; pass.forceActiveFocus(); }
        background: Rectangle { radius: Tema.r(22); color: Tema.cromo; border.color: Tema.borde }
        Overlay.modal: Rectangle { color: "#99000000" }
        readonly property var nombres: ({ ajustes: "tus ajustes y modos", fondos: "tus fondos", estudios: "~/Estudios", tareas: "tus tareas y exámenes", documentos: "tus Documentos" })
        contentItem: Column {
            spacing: 14
            Texto { text: "Recuperar la copia"; font.pixelSize: 20; font.weight: Font.Bold }
            Texto {
                width: parent.width
                color: Tema.apagado
                text: abrir.info.error ? abrir.info.error
                    : "Copia del " + (abrir.info.fecha ? sec.fecha(abrir.info.fecha) : "?") + " con " + (abrir.info.que || []).map(k => abrir.nombres[k] || k).join(", ")
                      + ". Lo que tenga el mismo nombre se cambia por lo de la copia; lo demás se queda."
            }
            Campo {
                id: pass
                visible: !abrir.info.error && !abrir.bien
                width: parent.width; implicitHeight: 38
                echoMode: TextInput.Password
                placeholderText: "Contraseña de la copia"
                onAccepted: recuperar.clicked()
            }
            Texto {
                width: parent.width
                visible: abrir.mensaje !== ""
                text: abrir.mensaje
                color: abrir.bien ? Tema.acento : Tema.error
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                Girando { visible: abrir.abriendo; anchors.verticalCenter: parent.verticalCenter }
                Boton { text: abrir.bien ? "Cerrar" : "Cancelar"; tipo: abrir.bien ? "principal" : "plano"; grande: false; onClicked: abrir.close() }
                Boton {
                    id: recuperar
                    visible: !abrir.info.error && !abrir.bien
                    tipo: "principal"
                    text: abrir.abriendo ? "Abriendo…" : "Recuperar"
                    enabled: pass.text !== "" && !abrir.abriendo
                    onClicked: { abrir.abriendo = true; abrir.mensaje = ""; apogeo.restoreApogeo(abrir.info.ruta, pass.text); pass.text = ""; }
                }
            }
        }
    }

    FileDialog {
        id: abrirDialogo
        title: "Elige tu copia de Apogeo"
        nameFilters: ["Copias de Apogeo (*.apogeo)"]
        onAccepted: { abrir.info = apogeo.copyHeader(selectedFile); abrir.open(); }
    }
    FolderDialog {
        id: dondeDialogo
        title: "Elige dónde guardar las copias (un USB o un disco)"
        onAccepted: { sec.mensaje = ""; sec.trabajando = "donde"; apogeo.setCopyFolder(selectedFolder); }
    }
}
