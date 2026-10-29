// Apogeo: la isla (abajo, o arriba) se esconde del todo, pero sale en cuanto el ratón entra en una franja ancha del
// borde (no hace falta llegar al último píxel). Mientras el ratón esté encima, se queda; al alejarse, se vuelve a
// esconder sola (la esconde Plasma). Con una ventana a pantalla completa (un juego, la consola) no sale.
//
// Los dos paneles («nivel pro»): el de widgets a la izquierda (Meta+A) y el rápido a la derecha (Meta+N, o la red, el
// sonido y la hora de la isla). También salen empujando el ratón contra su borde. Al abrirse hacen sitio (las ventanas
// se estrechan) y se quedan hasta que vuelves a pulsar su tecla.
//
// Cómo: Plasma no deja sacar una barra escondida, así que se cambia su modo: la isla, un momento a «las ventanas van
// debajo» (se ve, sin mover las ventanas); un panel, a «siempre visible» (y así hace sitio). Al panel se le dice si está
// abierto («abierto» en su configuración): cerrado no gasta nada.

const BAND = 26;          // alto (abajo) o ancho (derecha) de la franja que saca la isla, en píxeles
const KEEP = 110;         // mientras el ratón esté a esta distancia del borde, sigue fuera
const ISLAND = 0.3;       // la isla sale en el 40 % central del borde de abajo (de 0.3 a 0.7)
const PANELS = { left: "org.apogeo.izquierdo", right: "org.apogeo.derecho" };

const shown = { island: false };
const open = { left: false, right: false };

function plasma(script) {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", script);
}

function setHiding(location, mode) {
    plasma("panels().forEach(function (p) { if (p.location == '" + location + "') p.hiding = '" + mode + "'; });");
}

function setPanel(side, on) {
    open[side] = on;
    // (al abrir el rápido, los avisos cuentan como vistos: la campana de la isla deja de contarlos)
    const seen = side === "right" && on ? new Date().toISOString() : "";
    plasma("panels().forEach(function (p) {" +
        "  p.widgets().forEach(function (x) {" +
        "    if (x.type != 'org.apogeo.rapido' || !'" + seen + "') return;" +
        "    x.currentConfigGroup = ['General'];" +
        "    x.writeConfig('leidos', '" + seen + "');" +
        "    x.reloadConfig();" +
        "  });" +
        "  var w = p.widgets().filter(function (x) { return x.type == '" + PANELS[side] + "'; })[0];" +
        "  if (!w) return;" +
        "  p.hiding = '" + (on ? "none" : "autohide") + "';" +
        "  w.currentConfigGroup = ['General'];" +
        "  w.writeConfig('abierto', " + on + ");" +
        "  w.reloadConfig();" +
        "});");
}

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
    } else if (shown.island && (fromIslandEdge > KEEP || fx < ISLAND - 0.12 || fx > 1 - ISLAND + 0.12)) {
        shown.island = false;
        setHiding(islandAt, "autohide");
    }
}

workspace.cursorPosChanged.connect(update);

registerShortcut("apogeo-panel-izquierdo", "Apogeo: panel de widgets", "Meta+A", function () { setPanel("left", !open.left); });
registerShortcut("apogeo-panel-derecho", "Apogeo: panel rápido", "Meta+N", function () { setPanel("right", !open.right); });
// Empujando el ratón contra el borde (KWin espera un momento: pasar rozando no lo abre). Con un juego a pantalla
// completa, KWin no lo hace.
registerScreenEdge(KWin.ElectricLeft, function () { if (!open.left) setPanel("left", true); return true; });
registerScreenEdge(KWin.ElectricRight, function () { if (!open.right) setPanel("right", true); return true; });

// Al empezar, los dos cerrados (por si la sesión anterior acabó con alguno abierto)
setPanel("left", false);
setPanel("right", false);
