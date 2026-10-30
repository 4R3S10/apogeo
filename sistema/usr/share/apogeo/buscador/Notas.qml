import QtQuick
import QtQuick.Controls as QQC2
import Apogeo

// Tus notas, en la Órbita abierta (pestaña «Notas»): en tarjetas con su color; «Nueva» pone una, se escriben ahí mismo
// y se ordenan arrastrándolas por los puntitos. Las guarda apogeo-pisos (Datos, por D-Bus).
Item {
    id: notas
    property string modo: "navegar"
    Datos { id: datos }
    function nuevoId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }
    // [papel, tinta] (los mismos tonos que tenían en el escritorio)
    readonly property var colores: [["#ffd1e6", "#3a1f30"], ["#e9d8f5", "#2e2140"], ["#f6e2c9", "#3a2a18"],
                                    ["#d3f0e0", "#1f3a2c"], ["#d6e6fb", "#1f2c3a"]]
    ListModel { id: modelo }
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
        if (modelo.count >= 40) return;
        const usados = Array.from({ length: modelo.count }, (_, i) => modelo.get(i).tono);
        const tono = [0, 1, 2, 3, 4].find(c => usados.indexOf(c) < 0);
        modelo.insert(0, { nid: notas.nuevoId(), piso: notas.modo, px: 0, py: 0, tono: tono !== undefined ? tono : modelo.count % 5, giro: 0, texto: "" });
        lista.positionViewAtBeginning();
        // La recién puesta empieza escribiéndose (cuando ya está en la lista)
        Qt.callLater(() => { const n = lista.itemAtIndex(0); if (n) n.editor.forceActiveFocus(); });
    }
    function quitar(i) { modelo.remove(i); guardar(); }  // (desde aquí: la nota desaparece al quitarla)
    Timer { id: guardarLuego; interval: 700; onTriggered: notas.guardar() }

    Item {
        id: barraNotas
        width: parent.width; height: 36
        Texto { anchors.verticalCenter: parent.verticalCenter; text: modelo.count === 1 ? "1 nota" : modelo.count + " notas"; color: Tema.apagado; font.pixelSize: 13 }
        Boton { anchors.right: parent.right; tipo: "principal"; grande: false; text: "Nueva"; onClicked: notas.poner() }
    }
    Texto {
        visible: modelo.count === 0
        y: barraNotas.height + 16
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        color: Tema.apagado; font.pixelSize: 13
        text: "Sin notas. «Nueva» pone una; las ordenas arrastrándolas por los puntitos."
    }
    ListView {
        id: lista
        y: barraNotas.height + 10
        width: parent.width
        height: parent.height - y
        model: modelo
        spacing: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !arrastrando
        property bool arrastrando: false
        moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: 160; easing.type: Easing.OutCubic } }
        delegate: Rectangle {
            id: nota
            required property int index
            required property string nid
            required property int tono
            required property string texto
            readonly property alias editor: area
            readonly property color papel: notas.colores[tono][0]
            readonly property color tinta: notas.colores[tono][1]
            width: lista.width
            height: Math.max(72, area.contentHeight + 26)
            radius: Tema.r(16)
            color: papel
            // La raya de color a la izquierda (más oscura que el papel)
            Rectangle { x: 0; width: 6; height: parent.height; radius: 3; color: Qt.darker(nota.papel, 1.35) }
            // Arrastrar para ordenar
            MouseArea {
                id: asa
                x: 10; width: 18; height: parent.height
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                preventStealing: true
                onPressed: lista.arrastrando = true
                onPositionChanged: mouse => {
                    const p = mapToItem(lista.contentItem, mouse.x, mouse.y);
                    const i = lista.indexAt(lista.width / 2, p.y);
                    if (i >= 0 && i !== nota.index) modelo.move(nota.index, i, 1);
                }
                onReleased: { lista.arrastrando = false; notas.guardar(); }
                Grid {
                    anchors.centerIn: parent
                    columns: 2; spacing: 3
                    Repeater { model: 6; Rectangle { width: 3; height: 3; radius: 1.5; color: nota.tinta; opacity: 0.45 } }
                }
            }
            QQC2.TextArea {
                id: area
                x: 30; y: 4
                width: parent.width - x - 40
                height: parent.height - 8
                text: nota.texto
                color: nota.tinta
                placeholderText: "Escribe aquí…"
                placeholderTextColor: Qt.rgba(nota.tinta.r, nota.tinta.g, nota.tinta.b, 0.45)
                selectionColor: nota.tinta
                selectedTextColor: nota.papel
                font.family: Tema.serif   // (los apuntes, en Source Serif 4)
                font.pixelSize: 15
                wrapMode: TextEdit.Wrap
                background: null
                Keys.onEscapePressed: event => event.accepted = false   // (sigue: vuelve a la Órbita)
                onTextChanged: if (text !== nota.texto) { modelo.setProperty(nota.index, "texto", text); guardarLuego.restart(); }
            }
            // Arriba a la derecha, al pasar el ratón: el color y quitar
            HoverHandler { id: encima }
            Column {
                anchors.right: parent.right; anchors.rightMargin: 8
                y: 8
                spacing: 6
                visible: encima.hovered
                QQC2.AbstractButton {
                    id: tonoB
                    width: 22; height: 22
                    hoverEnabled: true
                    onClicked: { modelo.setProperty(nota.index, "tono", (nota.tono + 1) % 5); notas.guardar(); }
                    contentItem: Item { Rectangle { anchors.centerIn: parent; width: 14; height: 14; radius: 7; color: notas.colores[(nota.tono + 1) % 5][0]; border.width: 1.5; border.color: nota.tinta } }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: "Otro color"
                }
                QQC2.AbstractButton {
                    id: quitarB
                    width: 22; height: 22
                    hoverEnabled: true
                    onClicked: notas.quitar(nota.index)
                    contentItem: Item { Icono { anchors.centerIn: parent; nombre: "cerrar"; width: 11; height: 11; color: nota.tinta } }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: "Quitar"
                }
            }
        }
    }
    onVisibleChanged: if (visible) cargar()
    Component.onCompleted: cargar()
}
