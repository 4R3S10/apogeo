// Apogeo: la isla (abajo, o arriba) y la barra de pisos (derecha, o izquierda) se esconden del todo, pero salen en cuanto el ratón entra en
// una franja ancha del borde (no hace falta llegar al último píxel). Mientras el ratón esté encima, se quedan; al
// alejarse, se vuelven a esconder solas (las esconde Plasma). Con una ventana a pantalla completa (un juego, la
// consola) no sale nada.
//
// Cómo: Plasma no deja sacar una barra escondida, así que se cambia un momento su modo a «las ventanas van debajo»
// (se ve, sin mover las ventanas) y, al alejarse el ratón, se devuelve a «esconder solo».

const BAND = 26;          // alto (abajo) o ancho (derecha) de la franja que las saca, en píxeles
const KEEP = 110;         // mientras el ratón esté a esta distancia del borde, siguen fuera
const ISLAND = 0.3;       // la isla sale en el 40 % central del borde de abajo (de 0.3 a 0.7)
const RAIL = 0.25;        // los pisos, en el 50 % central del borde derecho (de 0.25 a 0.75)

const shown = { island: false, rail: false };

function setHiding(location, mode) {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript",
        "panels().forEach(function (p) { if (p.location == '" + location + "') p.hiding = '" + mode + "'; });");
}

function fullscreen() {
    const w = workspace.activeWindow;
    return w && w.fullScreen;
}

function update() {
    const island = readConfig("isla", true), rail = readConfig("pisos", true); // (Ajustes → Isla: esconderse sola)
    // Dónde están (Ajustes → Aspecto): la isla abajo o arriba; la columna a la derecha o a la izquierda
    const top = readConfig("islaArriba", false), left = readConfig("pisosIzquierda", false);
    const islandAt = top ? "top" : "bottom", railAt = left ? "left" : "right";
    const pos = workspace.cursorPos;
    const g = workspace.activeScreen.geometry;
    const fromIslandEdge = top ? pos.y - g.y : g.y + g.height - pos.y;
    const fromRailEdge = left ? pos.x - g.x : g.x + g.width - pos.x;
    const fx = (pos.x - g.x) / g.width;
    const fy = (pos.y - g.y) / g.height;

    if (island && !shown.island && fromIslandEdge <= BAND && fx > ISLAND && fx < 1 - ISLAND && !fullscreen()) {
        shown.island = true;
        setHiding(islandAt, "windowsgobelow");
    } else if (island && shown.island && (fromIslandEdge > KEEP || fx < ISLAND - 0.12 || fx > 1 - ISLAND + 0.12)) {
        shown.island = false;
        setHiding(islandAt, "autohide");
    }

    if (rail && !shown.rail && fromRailEdge <= BAND && fy > RAIL && fy < 1 - RAIL && !fullscreen()) {
        shown.rail = true;
        setHiding(railAt, "windowsgobelow");
    } else if (rail && shown.rail && (fromRailEdge > KEEP || fy < RAIL - 0.1 || fy > 1 - RAIL + 0.1)) {
        shown.rail = false;
        setHiding(railAt, "autohide");
    }
}

workspace.cursorPosChanged.connect(update);
