// Apogeo: el orbe (abajo en el centro) está escondido y sale al tocar el borde de abajo con el ratón (en la parte del
// centro, donde está). Mientras el ratón esté cerca, se queda; al alejarse, se vuelve a esconder. Con una ventana a
// pantalla completa (un juego, la consola) no sale.
//
// Cómo: Plasma no deja sacar una barra escondida, así que se cambia su modo: al tocar el borde, «las ventanas van
// debajo» (se ve, sin mover las ventanas) y al orbe se le dice «asomado» (en su configuración): sube y se enciende. Al
// alejarse, «asomado» se quita (baja y se apaga) y, cuando ya ha bajado, la barra vuelve a esconderse («autohide»).
// apogeo-pisos dice si se esconde («isla», Ajustes → Orbe).

const EDGE = 1.5;         // tocar el borde: a esta distancia (en píxeles) o menos
const KEEP = 110;         // mientras el ratón esté a esta distancia del borde, sigue fuera
const ISLAND = 0.3;       // el orbe sale en el 40 % central del borde de abajo (de 0.3 a 0.7)
const DOWN = 220;         // lo que tarda el orbe en bajar antes de esconder la barra, en milisegundos

const shown = { island: false };

function plasma(script) {
    callDBus("org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", script);
}

// La barra del orbe: su modo y lo que se le dice al orbe (en el mismo script: sale a la vez)
function setIsland(hiding, asomado) {
    plasma("panels().forEach(function (p) {" +
           "  var w = p.widgets().filter(function (x) { return x.type == 'org.apogeo.isla'; })[0];" +
           "  if (!w) return;" +
           (hiding ? "  p.hiding = '" + hiding + "';" : "") +
           "  w.currentConfigGroup = ['General'];" +
           "  w.writeConfig('asomado', " + asomado + ");" +
           "  w.reloadConfig();" +
           "});");
}

// Bajar: primero el orbe y, cuando ha bajado, la barra
const hide = new QTimer();
hide.interval = DOWN;
hide.singleShot = true;
hide.timeout.connect(function () { if (!shown.island) setIsland("autohide", false); });

function fullscreen() {
    const w = workspace.activeWindow;
    return w && w.fullScreen;
}

function update() {
    if (!readConfig("isla", true)) return; // (Ajustes → Orbe: escondido)
    const pos = workspace.cursorPos;
    const g = workspace.activeScreen.geometry;
    const fromEdge = g.y + g.height - pos.y;
    const fx = (pos.x - g.x) / g.width;

    if (!shown.island && fromEdge <= EDGE && fx > ISLAND && fx < 1 - ISLAND && !fullscreen()) {
        shown.island = true;
        hide.stop();
        setIsland("windowsgobelow", true);
    } else if (shown.island && (fromEdge > KEEP || fx < ISLAND - 0.12 || fx > 1 - ISLAND + 0.12)) {
        shown.island = false;
        setIsland("", false);
        hide.start();
    }
}

workspace.cursorPosChanged.connect(update);

// Al empezar, escondido (por si la sesión anterior acabó con él fuera)
if (readConfig("isla", true)) setIsland("autohide", false);

// ---------- La barra de arriba: escondida, salvo con Ágape delante ----------
// Con Ágape como ventana activa la barra se ve (y Ágape baja un poco para dejarle sitio); con cualquier otra app, se
// esconde. Lo que es de Plasma o de Apogeo (la tarjeta rápida, la Órbita, menús…) no cuenta: al usarlos, la barra se
// queda como estaba. Con Ágape a pantalla completa, escondida.
function clase(w) { return w ? ((w.resourceClass || "") + " " + (w.desktopFileName || "")).toLowerCase() : ""; }
function esAgape(w) { return !!w && w.normalWindow && /(^|[^a-z])(ares|agape|ágape)([^a-z]|$)/.test(clase(w)); }
function noCuenta(w) {
    const c = clase(w);
    return !w || !w.normalWindow || c.indexOf("plasmashell") >= 0 || c.indexOf("apogeo") >= 0 || c.indexOf("kwin") >= 0;
}
const barra = { ver: null };
function ponerBarra(ver) {
    if (ver === barra.ver) return;
    barra.ver = ver;
    plasma("panels().forEach(function (p) {" +
           "  if (!p.widgets().some(function (w) { return w.type == 'org.apogeo.modo'; })) return;" +
           "  p.hiding = '" + (ver ? "none" : "autohide") + "';" +
           "});");
}
// (un momento después: al cambiar de ventana, la activa pasa a veces por otra un instante)
const mirar = new QTimer();
mirar.interval = 150;
mirar.singleShot = true;
mirar.timeout.connect(function () {
    const w = workspace.activeWindow;
    if (noCuenta(w) && barra.ver !== null) return;
    ponerBarra(esAgape(w) && !w.fullScreen);
});
workspace.windowActivated.connect(function () { mirar.start(); });
mirar.start();
