// Apogeo: la isla (abajo, o arriba) se aparta de las ventanas (con el escritorio a la vista, se ve), pero sale en cuanto
// el ratón entra en una franja ancha del borde (no hace falta llegar al último píxel). Mientras el ratón esté encima, se queda; al alejarse, se vuelve a
// esconder sola (la esconde Plasma). Con una ventana a pantalla completa (un juego, la consola) no sale.
//
// El panel rápido, a la derecha: solo con Meta+N o pulsando la red, el sonido y la hora de la barra de arriba (el borde
// de la pantalla no hace nada ni brilla). Al abrirse hace sitio (las ventanas se estrechan) y se queda hasta que vuelves
// a pulsar.
//
// La isla también sale sola cuando tiene algo que enseñar (un aviso, el volumen…: «isla dinámica»): la isla llama al
// atajo «apogeo-isla-mostrar» y, al acabar, a «apogeo-isla-soltar» (sin teclas; los invoca por D-Bus).
//
// Cómo: Plasma no deja sacar una barra escondida, así que se cambia su modo: la isla, un momento a «las ventanas van
// debajo» (se ve, sin mover las ventanas); el panel rápido, a «siempre visible» (y así hace sitio). Cerrado no se
// «esconde solo» (KWin le guardaría el borde: brillaría y saldría al empujar el ratón): queda en «las ventanas van
// debajo» y este script lo saca fuera de la pantalla; al abrirlo, Plasma lo vuelve a poner en su sitio. Al panel se le
// dice si está abierto («abierto» en su configuración): cerrado no gasta nada.

const BAND = 26;          // alto (abajo) o ancho (derecha) de la franja que saca la isla, en píxeles
const KEEP = 110;         // mientras el ratón esté a esta distancia del borde, sigue fuera
const ISLAND = 0.3;       // la isla sale en el 40 % central del borde de abajo (de 0.3 a 0.7)
const PANELS = { right: "org.apogeo.derecho" };

const shown = { island: false, forced: false };
const open = { right: false };

function plasma(script) {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", script);
}

// (solo la isla: la barra fina de Órbita puede estar en el mismo borde)
function setHiding(location, mode) {
    plasma("panels().forEach(function (p) { if (p.location == '" + location + "' && p.widgets().some(function (w) {" +
           " return w.type == 'org.apogeo.isla'; })) p.hiding = '" + mode + "'; });");
}
// Sin nada que enseñar, la isla se aparta de las ventanas: con el escritorio a la vista, se ve («C · Orbe central»)
const REST = "dodgewindows";

function setPanel(side, on) {
    open[side] = on;
    // (al abrir el rápido, los avisos cuentan como vistos: la campana y los números de los iconos de la isla dejan de
    // contarlos)
    const seen = side === "right" && on ? new Date().toISOString() : "";
    plasma("panels().forEach(function (p) {" +
        "  p.widgets().forEach(function (x) {" +
        "    if ((x.type != 'org.apogeo.rapido' && x.type != 'org.apogeo.isla') || !'" + seen + "') return;" +
        "    x.currentConfigGroup = ['General'];" +
        "    x.writeConfig('leidos', '" + seen + "');" +
        "    x.reloadConfig();" +
        "  });" +
        "  var w = p.widgets().filter(function (x) { return x.type == '" + PANELS[side] + "'; })[0];" +
        "  if (!w) return;" +
        "  p.hiding = '" + (on ? "none" : "windowsgobelow") + "';" +
        "  w.currentConfigGroup = ['General'];" +
        "  w.writeConfig('abierto', " + on + ");" +
        "  w.reloadConfig();" +
        "});");
    if (side === "right" && !on) { fuera(); guardar.stop(); guardar.start(); }
}

// El panel rápido (una barra de Plasma alta y estrecha, en la mitad derecha de su pantalla) y sacarlo de la pantalla
function esRapido(w) {
    if (!w || !w.dock || !w.output) return false;
    const s = w.output.geometry, g = w.frameGeometry;
    return g.height > s.height / 2 && g.width < s.width / 2 && g.x + g.width / 2 > s.x + s.width / 2;
}
function fuera() {
    if (open.right) return;
    for (const w of workspace.windowList()) {
        if (!esRapido(w)) continue;
        const s = w.output.geometry, g = w.frameGeometry;
        if (g.x < s.x + s.width) w.frameGeometry = { x: s.x + s.width + 40, y: g.y, width: g.width, height: g.height };
    }
}
// (Plasma lo recoloca a su aire: cada vez que se mueve estando cerrado, otra vez fuera; y un poco después de cerrarlo)
const guardar = new QTimer();
guardar.interval = 400;
guardar.singleShot = true;
guardar.timeout.connect(fuera);
function vigilar(w) { if (w && w.dock) w.frameGeometryChanged.connect(function () { if (!open.right && esRapido(w)) fuera(); }); }
workspace.windowList().forEach(vigilar);
workspace.windowAdded.connect(function (w) { vigilar(w); fuera(); });

function fullscreen() {
    const w = workspace.activeWindow;
    return w && w.fullScreen;
}

function update() {
    if (!readConfig("isla", true)) return; // (Ajustes → Isla: esconderse sola)
    const top = readConfig("islaArriba", false); // (Ajustes → Aspecto: la isla abajo o arriba)
    const islandAt = top ? "top" : "bottom";
    const pos = workspace.cursorPos;
    const g = workspace.activeScreen.geometry;
    const fromIslandEdge = top ? pos.y - g.y : g.y + g.height - pos.y;
    const fx = (pos.x - g.x) / g.width;

    if (!shown.island && fromIslandEdge <= BAND && fx > ISLAND && fx < 1 - ISLAND && !fullscreen()) {
        shown.island = true;
        setHiding(islandAt, "windowsgobelow");
    } else if (shown.island && !shown.forced && (fromIslandEdge > KEEP || fx < ISLAND - 0.12 || fx > 1 - ISLAND + 0.12)) {
        shown.island = false;
        setHiding(islandAt, REST);
    }
}

workspace.cursorPosChanged.connect(update);

function islandAt() { return readConfig("islaArriba", false) ? "top" : "bottom"; }
registerShortcut("apogeo-isla-mostrar", "Apogeo: la isla enseña algo", "", function () {
    if (!readConfig("isla", true) || fullscreen()) return;
    shown.forced = true;
    if (!shown.island) { shown.island = true; setHiding(islandAt(), "windowsgobelow"); }
});
registerShortcut("apogeo-isla-soltar", "Apogeo: la isla ya no enseña nada", "", function () {
    if (!shown.forced) return;
    shown.forced = false;
    // (si el ratón está encima, se queda: ya la esconderá update al irse)
    const pos = workspace.cursorPos, g = workspace.activeScreen.geometry;
    const top = readConfig("islaArriba", false);
    if ((top ? pos.y - g.y : g.y + g.height - pos.y) > KEEP) { shown.island = false; setHiding(islandAt(), REST); }
});

registerShortcut("apogeo-panel-derecho", "Apogeo: panel rápido", "Meta+N", function () { setPanel("right", !open.right); });

// Al empezar, cerrado (por si la sesión anterior acabó con él abierto)
setPanel("right", false);
