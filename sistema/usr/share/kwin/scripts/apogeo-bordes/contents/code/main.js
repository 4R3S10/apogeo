// Apogeo: el orbe (abajo, o arriba) está escondido (la isla de Clásico se aparta de las ventanas), pero sale en cuanto
// el ratón entra en una franja ancha del borde (no hace falta llegar al último píxel). Mientras el ratón esté encima, se queda; al alejarse, se vuelve a
// esconder sola (la esconde Plasma). Con una ventana a pantalla completa (un juego, la consola) no sale.
//
// La isla también sale sola cuando tiene algo que enseñar (un aviso, el volumen…: «isla dinámica»): la isla llama al
// atajo «apogeo-isla-mostrar» y, al acabar, a «apogeo-isla-soltar» (sin teclas; los invoca por D-Bus).
//
// Cómo: Plasma no deja sacar una barra escondida, así que se cambia su modo: la isla, un momento a «las ventanas van
// debajo» (se ve, sin mover las ventanas).

const BAND = 26;          // alto de la franja que saca la isla, en píxeles
const KEEP = 110;         // mientras el ratón esté a esta distancia del borde, sigue fuera
const ISLAND = 0.3;       // la isla sale en el 40 % central del borde de abajo (de 0.3 a 0.7)

const shown = { island: false, forced: false };

function plasma(script) {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", script);
}

// (solo la isla: la barra fina de Órbita puede estar en el mismo borde)
function setHiding(location, mode) {
    plasma("panels().forEach(function (p) { if (p.location == '" + location + "' && p.widgets().some(function (w) {" +
           " return w.type == 'org.apogeo.isla'; })) p.hiding = '" + mode + "'; });");
}
// Sin nada que enseñar: el orbe de Órbita, escondido siempre; la isla de Clásico se aparta de las ventanas (con el
// escritorio a la vista, se ve). Lo dice apogeo-pisos («reposo»)
function rest() { return readConfig("reposo", "dodgewindows"); }

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
        setHiding(islandAt, rest());
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
    if ((top ? pos.y - g.y : g.y + g.height - pos.y) > KEEP) { shown.island = false; setHiding(islandAt(), rest()); }
});
