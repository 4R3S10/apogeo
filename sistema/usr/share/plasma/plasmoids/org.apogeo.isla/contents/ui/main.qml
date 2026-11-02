import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus
import Apogeo

// El orbe de Apogeo («C · Orbe central»), abajo en el centro: el orbe del color del modo en el que estás (un clic, o
// Meta, abre la Órbita: tus apps, el buscador y lo que pasa ahora) y a sus lados los otros dos modos en bolitas (un clic
// te lleva; el tuyo siempre va en el centro). Tus ventanas, el volumen y el brillo van arriba, en la barra fina
// (org.apogeo.ventanas), y la hora, la red y los avisos a su derecha (org.apogeo.rapido).
// Escondido (Ajustes → Orbe, lo de serie): no se ve nada abajo. Al tocar el borde de abajo con el ratón, el script de KWin
// apogeo-bordes saca la barra y pone «asomado» en la configuración de este widget: el orbe sube desde abajo y se
// enciende (su anillo brilla un momento) y las bolitas le siguen; al alejar el ratón baja y se apaga, y luego el script
// vuelve a esconder la barra.
PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation

    TaskManager.VirtualDesktopInfo { id: desktops }
    // (el modo: el nombre del escritorio sin su número, «Navegar 2» → Navegar)
    readonly property string floor: String(desktops.desktopNames[desktops.desktopIds.indexOf(desktops.currentDesktop)] || "Navegar").split(" ")[0]
    readonly property var modos: ["jugar", "navegar", "estudiar"]
    readonly property string modo: modos.indexOf(floor.toLowerCase()) >= 0 ? floor.toLowerCase() : "navegar"
    readonly property color accent: Tema.rosa
    function colorModo(m) { return Tema.acentoDe(m) }
    function nombreModo(m) { return ({ jugar: "Jugar", navegar: "Navegar", estudiar: "Estudiar" })[m] }

    // ---------- Asomarse: subir y encenderse ----------
    readonly property bool asomado: !Plasmoid.configuration.esconder || Plasmoid.configuration.asomado
    // De 0 (abajo, apagado) a 1 (arriba, encendido). Sube despacio y baja deprisa (con «Animaciones: sin», de golpe)
    readonly property real ritmo: Tema.f.animaciones !== undefined ? Tema.f.animaciones : 1
    property real vista: asomado ? 1 : 0
    Behavior on vista {
        enabled: root.ritmo > 0
        NumberAnimation { duration: (root.asomado ? 460 : 190) * root.ritmo; easing.type: root.asomado ? Easing.OutCubic : Easing.InCubic }
    }
    // Lo de cada pieza: empieza un poco después que el orbe («retraso», de 0 a 1)
    function paso(retraso) { return Math.max(0, Math.min(1, (vista - retraso) / (1 - retraso))) }

    // ---------- La Órbita ----------
    readonly property string toggleCmd: "dbus-send --session --type=method_call --dest=org.apogeo.Buscador /Buscador org.apogeo.Buscador.Toggle"
    P5Support.DataSource { id: runner; engine: "executable"; onNewData: source => disconnectSource(source) }
    function run(cmd) { runner.connectSource(cmd) }
    function irA(m) {
        run("dbus-send --session --type=method_call --dest=org.apogeo.Modos /Modos org.apogeo.Modos1.Cambiar string:" + m);
    }
    // La Órbita abierta sale de este mismo orbe: se le dice dónde está (y sus bolitas) para que dibuje el suyo justo
    // encima, igual, y lo encienda (sin verse dos)
    function abrirOrbita() {
        if (orbeItem) { llamar("AbrirDesde", dondeOrbe(), () => run(toggleCmd)); return; }
        run(toggleCmd);
    }
    // (al empezar, dónde está el orbe, para cuando la Órbita se abra con Meta)
    Timer { interval: 4000; running: true; onTriggered: if (root.orbeItem) root.llamar("Orbe", root.dondeOrbe(), null) }
    property Item orbeItem: null
    property Item bolitaAntes: null
    property Item bolitaDespues: null
    function dondeOrbe() {
        // (donde queda asomado, aunque ahora esté abajo)
        const sube = (1 - vista) * 30;
        const c = orbeItem.mapToGlobal(orbeItem.width / 2, orbeItem.height / 2 - sube);
        const a = bolitaAntes ? bolitaAntes.mapToGlobal(bolitaAntes.width / 2, 17 - sube) : c;
        const d = bolitaDespues ? bolitaDespues.mapToGlobal(bolitaDespues.width / 2, 17 - sube) : c;
        return [c.x, c.y, a.x, a.y, d.x, d.y].map(Math.round).join(",");
    }
    function llamar(metodo, texto, mal) {
        DBus.SessionBus.asyncCall({
            service: "org.apogeo.Buscador", path: "/Buscador", iface: "org.apogeo.Buscador", member: metodo,
            arguments: [new DBus.string(texto)], signature: "(s)"
        }, () => {}, () => { if (mal) mal(); });
    }
    onVistaChanged: if (vista === 1 && orbeItem) llamar("Orbe", dondeOrbe(), null)

    fullRepresentation: Item {
        // Jugar es solo la consola (a pantalla completa): aquí no se ve nada
        opacity: Tema.modo === "jugar" ? 0 : 1
        enabled: opacity > 0 && root.vista > 0.5
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Layout.minimumWidth: fila.implicitWidth
        Layout.preferredWidth: fila.implicitWidth
        Row {
            id: fila
            anchors.centerIn: parent
            spacing: 6
            Bolita { id: antes; m: root.modos[(root.modos.indexOf(root.modo) + 2) % 3]; Component.onCompleted: root.bolitaAntes = antes }
            Item {
                id: orbe
                Component.onCompleted: root.orbeItem = orbe
                readonly property real p: root.paso(0)
                width: 48; height: 48
                opacity: Math.min(1, p * 1.6)
                transform: Translate { y: (1 - orbe.p) * 30 }
                // El destello al encenderse: un halo del color del modo que crece y se va (y, al pasar el ratón, un halo
                // suave que se queda)
                Rectangle {
                    anchors.centerIn: parent
                    readonly property real destello: Math.sin(Math.min(1, orbe.p) * Math.PI)
                    width: 40 + 22 * destello; height: width; radius: width / 2
                    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Math.max(0.42 * destello, orbeArea.containsMouse ? 0.22 : 0))
                    Behavior on color { enabled: orbe.p === 1; ColorAnimation { duration: 180 } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 40; height: 40; radius: 20
                    color: Tema.claro ? Tema.superficie : "#0b0e14"
                    border.width: 2
                    // (el anillo se enciende: del gris al color del modo)
                    border.color: Qt.tint(Qt.rgba(0.5, 0.55, 0.6, 0.5), Qt.rgba(root.accent.r, root.accent.g, root.accent.b, orbe.p))
                    scale: (orbeArea.pressed ? 0.92 : 1) * (0.72 + 0.28 * orbe.p)
                    Behavior on scale { enabled: orbe.p === 1; NumberAnimation { duration: 120 } }
                    Rectangle { anchors.centerIn: parent; width: 11; height: 11; radius: 5.5; color: Tema.texto; scale: Math.max(0, orbe.p * 1.4 - 0.4) }
                }
                MouseArea {
                    id: orbeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.abrirOrbita()
                }
            }
            Bolita { id: despues; m: root.modos[(root.modos.indexOf(root.modo) + 1) % 3]; Component.onCompleted: root.bolitaDespues = despues }
        }
    }

    // La bolita de otro modo, con su nombre debajo (un clic te lleva). Sube un poco después que el orbe
    component Bolita: Item {
        id: b
        property string m
        readonly property color c: root.colorModo(m)
        readonly property real p: root.paso(0.28)
        width: 50; height: 48
        opacity: p
        transform: Translate { y: (1 - b.p) * 22 }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 5
            width: 24; height: 24; radius: 12
            color: bm.containsMouse ? Qt.rgba(b.c.r, b.c.g, b.c.b, 0.25) : (Tema.claro ? Tema.superficie : "#151b24")
            border.width: 1.5
            border.color: b.c
            scale: bm.pressed ? 0.88 : bm.containsMouse ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: 140 } }
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        Texto {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 32
            text: root.nombreModo(b.m)
            color: b.c
            wrapMode: Text.NoWrap
            font { pixelSize: 10; weight: Font.DemiBold }
        }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.irA(b.m) }
    }
}
