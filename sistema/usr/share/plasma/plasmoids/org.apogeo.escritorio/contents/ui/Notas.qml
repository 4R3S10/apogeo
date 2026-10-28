import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import Apogeo

// Las notas del escritorio («R1 · Post-its de colores»): papelitos en tonos pastel, un poco torcidos, en el piso donde
// los pones. El «+» de arriba a la derecha pone uno nuevo; un clic en el texto lo escribe (Esc o un clic fuera lo deja);
// se mueven arrastrándolos. Las líneas que empiezan por ☐ son una lista (un clic en la cajita la marca ☑; Intro sigue
// la lista). Arriba de cada nota, al pasar el ratón: lista, color y quitar. Se guardan solas (apogeo_datos.py, Notas).
Item {
    id: notas
    required property string piso
    Datos { id: datos }

    // [papel, tinta]
    readonly property var colores: [["#ffd1e6", "#3a1f30"], ["#e9d8f5", "#2e2140"], ["#f6e2c9", "#3a2a18"],
                                    ["#d3f0e0", "#1f3a2c"], ["#d6e6fb", "#1f2c3a"]]
    ListModel { id: modelo }
    property string nueva: ""   // la recién puesta: empieza escribiéndose

    function cargar() {
        datos.pedir("Notas", [], d => {
            if (!d) return;
            modelo.clear();
            for (const n of d) modelo.append({ nid: n.id, piso: n.piso, px: n.x, py: n.y, tono: n.color, giro: n.giro, texto: n.texto });
        });
    }
    function guardar() {
        const l = [];
        for (let i = 0; i < modelo.count; i++) {
            const n = modelo.get(i);
            l.push({ id: n.nid, piso: n.piso, x: n.px, y: n.py, color: n.tono, giro: n.giro, texto: n.texto });
        }
        datos.hacer("PonerNotas", [JSON.stringify(l)]);
    }
    function poner() {
        const id = Date.now().toString(36);
        const mias = Array.from({ length: modelo.count }, (_, i) => modelo.get(i)).filter(n => n.piso === piso);
        // El primer hueco libre bajo el «+» (de derecha a izquierda y de arriba abajo) y un color que no esté ya
        const w = 236, h = 150, top = Tema.posicion === "arriba-dcha" ? 128 : 84;
        let sitio = null;
        for (let col = 0; col < 4 && !sitio; col++) {
            for (let row = 0; row < 3 && !sitio; row++) {
                const x = width - 80 - w - col * (w + 18), y = top + row * (h + 18);
                if (!mias.some(n => Math.abs(n.px * width - x) < w && Math.abs(n.py * height - y) < h)) sitio = { x: x, y: y };
            }
        }
        sitio = sitio || { x: width - 80 - w - (mias.length % 5) * 24, y: top + (mias.length % 5) * 24 };
        const usados = mias.map(n => n.tono);
        const tono = [0, 1, 2, 3, 4].find(c => usados.indexOf(c) < 0);
        nueva = id;
        modelo.append({ nid: id, piso: piso, px: sitio.x / width, py: sitio.y / height,
                        tono: tono !== undefined ? tono : mias.length % colores.length,
                        giro: Math.round((Math.random() * 4 - 2) * 10) / 10, texto: "" });
    }
    function quitar(i) { modelo.remove(i); guardar(); }
    Component.onCompleted: cargar()

    Repeater {
        model: modelo
        delegate: Item {
            id: nota
            required property int index
            required property string nid
            required property string piso
            required property real px
            required property real py
            required property int tono
            required property real giro
            required property string texto
            readonly property color papel: notas.colores[tono][0]
            readonly property color tinta: notas.colores[tono][1]
            property bool editing: false
            readonly property var lineas: texto.split("\n")

            visible: piso === notas.piso
            x: px * notas.width
            y: py * notas.height
            width: 236
            height: Math.max(96, (editing ? area.contentHeight + 16 : vista.implicitHeight) + 40)
            z: editing || mover.active || tirador.active ? 2 : 1
            rotation: editing || mover.active || tirador.active ? 0 : giro
            Behavior on rotation { NumberAnimation { duration: 160 } }

            function set(campos) {
                for (const k in campos) modelo.setProperty(index, k, campos[k]);
                notas.guardar();
            }
            function escribir() {
                editing = true;
                area.text = texto;
                area.forceActiveFocus();
                area.cursorPosition = area.length;
            }
            function dejar() {
                if (!editing) return;
                editing = false;
                const t = area.text.replace(/\s+$/, "");
                if (!t.trim()) { notas.quitar(index); return; }
                if (t !== texto) set({ texto: t });
            }
            function soltar() {
                const nx = Math.max(0, Math.min(notas.width - width, x)), ny = Math.max(0, Math.min(notas.height - height, y));
                x = nx; y = ny;
                set({ px: nx / notas.width, py: ny / notas.height });
            }
            // ☐ ↔ ☑ en una línea
            function marcar(i) {
                const l = lineas.slice();
                l[i] = (l[i].startsWith("☑") ? "☐" : "☑") + l[i].slice(1);
                set({ texto: l.join("\n") });
            }
            Component.onCompleted: if (nid === notas.nueva) { notas.nueva = ""; escribir(); }

            HoverHandler { id: encima }
            DragHandler { id: mover; enabled: !nota.editing; onActiveChanged: if (!active) nota.soltar() }

            RectangularShadow { anchors.fill: papelito; radius: papelito.radius; offset.y: 6; blur: 18; spread: -2; color: Qt.rgba(0, 0, 0, 0.35) }
            Rectangle {
                id: papelito
                anchors.fill: parent
                radius: Tema.r(10)
                color: nota.papel
            }
            // Para arrastrarla también mientras se escribe: la franja de arriba
            Item {
                width: parent.width; height: 26
                DragHandler { id: tirador; target: nota; onActiveChanged: if (!active) nota.soltar() }
            }
            // Lista · color · quitar
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 6
                y: 5
                spacing: 2
                opacity: encima.hovered || nota.editing ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Herramienta {
                    tinta: nota.tinta
                    texto: "☐"
                    onPulsada: {
                        if (!nota.editing) { nota.escribir(); area.insert(area.length, (area.text ? "\n" : "") + "☐ "); return; }
                        const s = area.text.lastIndexOf("\n", area.cursorPosition - 1) + 1;
                        const c = area.text.charAt(s);
                        if (c === "☐" || c === "☑") area.remove(s, s + (area.text.charAt(s + 1) === " " ? 2 : 1));
                        else area.insert(s, "☐ ");
                    }
                }
                Herramienta {
                    tinta: nota.tinta
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12; height: 12; radius: 6
                        color: notas.colores[(nota.tono + 1) % notas.colores.length][0]
                        border.color: Qt.rgba(nota.tinta.r, nota.tinta.g, nota.tinta.b, 0.4)
                    }
                    onPulsada: nota.set({ tono: (nota.tono + 1) % notas.colores.length })
                }
                Herramienta { tinta: nota.tinta; texto: "✕"; onPulsada: notas.quitar(nota.index) }
            }

            // Leyendo: las líneas, con sus cajitas
            Column {
                id: vista
                visible: !nota.editing
                x: 14; y: 26
                width: parent.width - 28
                spacing: 3
                Repeater {
                    model: nota.lineas
                    delegate: Item {
                        id: linea
                        required property string modelData
                        required property int index
                        readonly property bool caja: modelData.startsWith("☐") || modelData.startsWith("☑")
                        readonly property bool hecha: modelData.startsWith("☑")
                        width: vista.width
                        height: Math.max(caja ? 20 : 0, escrito.implicitHeight)
                        Rectangle {
                            id: cajita
                            visible: linea.caja
                            y: 2
                            width: 15; height: 15; radius: 4
                            color: linea.hecha ? nota.tinta : "transparent"
                            border.width: 1.5
                            border.color: nota.tinta
                            Text { anchors.centerIn: parent; visible: linea.hecha; text: "✓"; color: nota.papel; font.pixelSize: 11; font.bold: true }
                            TapHandler { onTapped: nota.marcar(linea.index) }
                        }
                        Text {
                            id: escrito
                            x: linea.caja ? 22 : 0
                            width: parent.width - x
                            wrapMode: Text.Wrap
                            text: linea.caja ? linea.modelData.slice(1).replace(/^ /, "") : (linea.modelData || " ")
                            color: nota.tinta
                            opacity: linea.hecha ? 0.55 : 1
                            font.family: Tema.letra
                            font.pixelSize: 14
                            // (la primera línea, de título, si hay más)
                            font.weight: linea.index === 0 && !linea.caja && nota.lineas.length > 1 ? Font.Bold : Font.Normal
                            font.strikeout: linea.hecha
                            TapHandler { onTapped: nota.escribir() }
                        }
                    }
                }
            }
            // Escribiendo
            QQC2.TextArea {
                id: area
                visible: nota.editing
                x: 6; y: 20
                width: parent.width - 12
                wrapMode: TextEdit.Wrap
                color: nota.tinta
                selectionColor: Qt.rgba(nota.tinta.r, nota.tinta.g, nota.tinta.b, 0.25)
                selectedTextColor: nota.tinta
                font.family: Tema.letra
                font.pixelSize: 14
                placeholderText: "Escribe aquí…"
                placeholderTextColor: Qt.rgba(nota.tinta.r, nota.tinta.g, nota.tinta.b, 0.45)
                background: null
                onActiveFocusChanged: if (!activeFocus) nota.dejar()
                Keys.onEscapePressed: nota.dejar()
                // Intro en una línea de la lista sigue la lista (y en una vacía, la acaba)
                Keys.onReturnPressed: event => {
                    const s = text.lastIndexOf("\n", cursorPosition - 1) + 1;
                    const c = text.charAt(s);
                    if (c !== "☐" && c !== "☑") { event.accepted = false; return; }
                    if (text.slice(s, cursorPosition).replace(/^[☐☑] ?/, "").trim() === "") remove(s, cursorPosition);
                    else insert(cursorPosition, "\n☐ ");
                }
            }
        }
    }

    // El «+»: una nota nueva en este piso
    QQC2.AbstractButton {
        id: mas
        visible: notas.piso !== "jugar"
        x: notas.width - 80 - width
        y: Tema.posicion === "arriba-dcha" ? 76 : 28
        width: 40; height: 40
        hoverEnabled: true
        onClicked: notas.poner()
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.text: "Nueva nota"
        background: Rectangle {
            radius: 20
            color: mas.hovered ? Qt.lighter(Tema.rosa, 1.06) : Tema.rosa
            RectangularShadow { anchors.fill: parent; z: -1; radius: 20; offset.y: 4; blur: 16; spread: -4; color: Tema.rosa; opacity: mas.hovered ? 0.9 : 0.5 }
        }
        contentItem: Item { Icono { anchors.centerIn: parent; width: 18; height: 18; nombre: "mas"; color: Tema.sobreRosa } }
    }

    component Herramienta: QQC2.AbstractButton {
        id: h
        property string texto
        property color tinta: "#3a2a30"
        signal pulsada()
        width: 24; height: 22
        hoverEnabled: true
        focusPolicy: Qt.NoFocus   // (no le quita el foco al texto)
        onClicked: h.pulsada()
        background: Rectangle { radius: 6; color: h.hovered ? Qt.rgba(0, 0, 0, 0.08) : "transparent" }
        contentItem: Text {
            text: h.texto
            color: h.tinta
            opacity: 0.75
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }
}
