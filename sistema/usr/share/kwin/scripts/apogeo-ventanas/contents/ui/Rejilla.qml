import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kwin
import Apogeo

// La rejilla («V2 · Huecos en toda la pantalla»): al arrastrar una ventana hasta arriba, baja una pastilla con los
// esquemas (mitades, tercios, ⅔ + ⅓, cuartos; pasando el ratón por ella se cambia) y la pantalla enseña sus huecos en
// rosa. El hueco que queda bajo el ratón se ilumina y, al soltar, la ventana va ahí. «Suelta» la deja donde la sueltes.
// Si luego la sueltas fuera de su hueco, vuelve al tamaño que tenía antes.
Item {
    id: rejilla

    readonly property var layouts: [
        { nombre: "Mitades", huecos: [[0, 0, 1 / 2, 1], [1 / 2, 0, 1 / 2, 1]] },
        { nombre: "Tercios", huecos: [[0, 0, 1 / 3, 1], [1 / 3, 0, 1 / 3, 1], [2 / 3, 0, 1 / 3, 1]] },
        { nombre: "⅔ + ⅓", huecos: [[0, 0, 2 / 3, 1], [2 / 3, 0, 1 / 3, 1]] },
        { nombre: "Cuartos", huecos: [[0, 0, 1 / 2, 1 / 2], [1 / 2, 0, 1 / 2, 1 / 2], [0, 1 / 2, 1 / 2, 1 / 2], [1 / 2, 1 / 2, 1 / 2, 1 / 2]] }
    ]
    readonly property int gap: 8
    property int layout: 0          // el esquema elegido (se recuerda para la próxima)
    property bool loose: false      // «Suelta»: sin hueco
    property var win: null          // la ventana que se arrastra
    property bool active: false     // ya ha llegado arriba: se ven los huecos
    property rect area: Qt.rect(0, 0, 0, 0)
    property int hover: -1
    // Lo que medían antes de ponerlas en un hueco (para devolverlas al sacarlas)
    property var before: ({})
    property var restore: null      // el tamaño que recupera la que se está sacando de su hueco

    function eligible(w) {
        const cls = ((w.resourceClass || "") + " " + (w.desktopFileName || "")).toLowerCase();
        return w.normalWindow && w.moveable && w.resizeable && !w.fullScreen
            && cls.indexOf("apogeo-consola") < 0 && cls.indexOf("apogeo-musica") < 0;
    }
    function zoneRect(i) {
        const z = layouts[layout].huecos[i], a = area, g = gap;
        const x = Math.round(a.x + a.width * z[0]) + g, y = Math.round(a.y + a.height * z[1]) + g;
        const r = Math.round(a.x + a.width * (z[0] + z[2])) - g, b = Math.round(a.y + a.height * (z[1] + z[3])) - g;
        return Qt.rect(x, y, r - x, b - y);
    }

    function start(w) {
        if (!eligible(w) || !w.move) return;
        win = w;
        active = false;
        loose = false;
        hover = -1;
        // Estaba en un hueco: al soltarla fuera, su tamaño de antes (cambiarlo mientras la arrastras corta el arrastre)
        const key = w.internalId.toString();
        restore = before[key] || null;
        delete before[key];
    }
    function step() {
        if (!win) return;
        const p = Workspace.cursorPos;
        const out = Workspace.screenAt(p);
        area = Workspace.clientArea(KWin.MaximizeArea, out, Workspace.currentDesktop);
        // (arriba del todo: el ratón, o la ventana ya por encima del borde; pegada justo al borde no, que KWin la
        // imanta ahí al moverla cerca)
        if (!active && (p.y <= area.y + 6 || win.frameGeometry.y < area.y - 4)) active = true;
        if (!active) return;
        // En la pastilla: cambiar de esquema (o «Suelta»)
        const pg = pill.mapToItem(null, 0, 0);
        const lx = p.x - (area.x + pg.x), ly = p.y - (area.y + pg.y);
        if (ly >= -8 && ly <= pill.height + 4 && lx >= 0 && lx <= pill.width) {
            for (let i = 0; i < choices.count; i++) {
                const c = choices.itemAt(i);
                if (lx >= c.x && lx <= c.x + c.width) {
                    if (i < layouts.length) { layout = i; loose = false; } else loose = true;
                }
            }
            hover = -1;
            return;
        }
        hover = -1;
        if (loose) return;
        for (let i = 0; i < layouts[layout].huecos.length; i++) {
            const z = layouts[layout].huecos[i];
            const zx = area.x + area.width * z[0], zy = area.y + area.height * z[1];
            if (p.x >= zx && p.x < zx + area.width * z[2] && p.y >= zy && p.y < zy + area.height * z[3]) { hover = i; break; }
        }
    }
    function finish(w) {
        if (w !== win) return;
        const key = w.internalId.toString();
        if (active && !loose && hover >= 0) {
            before[key] = restore || { width: w.frameGeometry.width, height: w.frameGeometry.height };
            w.frameGeometry = zoneRect(hover);
        } else if (restore) { // (bajo el ratón, por donde la cogiste)
            const g = w.frameGeometry, p = Workspace.cursorPos, fx = (p.x - g.x) / g.width;
            w.frameGeometry = Qt.rect(Math.round(p.x - restore.width * fx), g.y, restore.width, restore.height);
        }
        win = null;
        restore = null;
        active = false;
        hover = -1;
    }

    Connections {
        target: Workspace
        enabled: rejilla.win !== null
        function onCursorPosChanged() { rejilla.step() }
    }

    // Los huecos y la pastilla, encima de todo (sin coger el ratón: el arrastre sigue siendo de KWin)
    PlasmaCore.Dialog {
        id: overlay
        visible: rejilla.active
        location: PlasmaCore.Types.Desktop
        type: PlasmaCore.Dialog.OnScreenDisplay
        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
        hideOnWindowDeactivate: false
        outputOnly: true
        x: rejilla.area.x; y: rejilla.area.y

        mainItem: Item {
            width: Math.max(1, rejilla.area.width); height: Math.max(1, rejilla.area.height)

            Repeater {
                model: rejilla.loose ? [] : rejilla.layouts[rejilla.layout].huecos
                delegate: Rectangle {
                    required property int index
                    readonly property rect r: rejilla.zoneRect(index)
                    x: r.x - rejilla.area.x; y: r.y - rejilla.area.y; width: r.width; height: r.height
                    radius: Tema.r(14)
                    color: Qt.rgba(Tema.rosa.r, Tema.rosa.g, Tema.rosa.b, rejilla.hover === index ? 0.32 : 0.1)
                    border.width: 2
                    border.color: Qt.rgba(Tema.rosa.r, Tema.rosa.g, Tema.rosa.b, rejilla.hover === index ? 1 : 0.5)
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: row.implicitWidth + 12
                height: row.implicitHeight + 12
                radius: Tema.r(16)
                color: Tema.cristal
                border.color: Tema.borde
                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        id: choices
                        model: rejilla.layouts.length + 1
                        delegate: Rectangle {
                            id: choice
                            required property int index
                            readonly property bool none: index === rejilla.layouts.length
                            readonly property bool on: none ? rejilla.loose : !rejilla.loose && rejilla.layout === index
                            width: Math.max(74, label.implicitWidth + 20)
                            height: 62
                            radius: Tema.r(12)
                            color: on ? Tema.rosa : "transparent"
                            // el esquema, en pequeño
                            Item {
                                id: mini
                                visible: !choice.none
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 9
                                width: 40; height: 25
                                Repeater {
                                    model: choice.none ? [] : rejilla.layouts[choice.index].huecos
                                    delegate: Rectangle {
                                        required property var modelData
                                        x: modelData[0] * mini.width + 1; y: modelData[1] * mini.height + 1
                                        width: modelData[2] * mini.width - 2; height: modelData[3] * mini.height - 2
                                        radius: 3
                                        color: choice.on ? Tema.sobreRosa : Tema.pulsado
                                        opacity: choice.on ? 0.55 : 1
                                    }
                                }
                            }
                            Icono {
                                visible: choice.none
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 12; width: 20; height: 20
                                nombre: "cerrar"
                                color: choice.on ? Tema.sobreRosa : Tema.apagado
                            }
                            Texto {
                                id: label
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 39
                                text: choice.none ? "Suelta" : rejilla.layouts[choice.index].nombre
                                font.pixelSize: 12; font.weight: Font.Bold
                                color: choice.on ? Tema.sobreRosa : Tema.texto
                            }
                        }
                    }
                }
            }
        }
    }
}
