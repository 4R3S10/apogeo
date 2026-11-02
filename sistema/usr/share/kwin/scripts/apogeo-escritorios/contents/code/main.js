// Apogeo: escritorios dentro de cada modo. Los escritorios virtuales de KWin son una rejilla: una fila por modo (Jugar,
// Navegar, Estudiar; apogeo-pisos pone las 3 filas) y una columna por escritorio («Navegar», «Navegar 2»… hasta 4). Así
// el efecto Deslizar de KWin sube o baja al cambiar de modo y va de lado al cambiar de escritorio, con el fondo quieto.
//
// - Ctrl+Alt+← →: el escritorio de al lado en este modo. En el último, Ctrl+Alt+→ abre uno nuevo (hasta 4). En Jugar
//   no hay (es la consola).
// - Ctrl+Alt+Mayús+← →: lo mismo llevándote la ventana.
// - Meta+Ctrl+↑ ↓ (y Mayús para llevarte la ventana): el modo de arriba o de abajo, al escritorio en el que estabas en él.
// - Un escritorio abierto es el que tiene ventanas (o en el que estás): si te vas de uno y queda vacío, se cierra (sus
//   vecinos de la derecha se corren, sin que se vea). Las columnas que no usa ningún modo se quitan (también las del
//   medio): sin abrir ninguno, son los 3 escritorios de siempre.
// - Cada app se queda en el escritorio en el que la abriste: si una ventana de otro escritorio se pone delante (un aviso,
//   un enlace), en este modo vas a su escritorio; si es de otro modo, se viene a este (nunca cambias de modo sin querer).
//   Para eso KWin no hace nada al activarla (ActivationDesktopPolicy=DoNothing, en /etc/xdg/kwinrc) y lo decide esto.
// - apogeo-pisos cambia de modo con los atajos sin tecla «apogeo-ir-jugar/navegar/estudiar» (la isla, la Órbita, la
//   pantalla de bloqueo) y los puntos de la barra fina van al escritorio con su id (org.apogeo.modo).

const MODOS = ["Jugar", "Navegar", "Estudiar"];
const MAX = 4;
// Al cambiar de modo, el orbe se expande (Transicion.qml de apogeo-buscador): se le pide y, cuando ya tapa la pantalla,
// se cambia de escritorio debajo (lo que tarda en taparla: «tapar» en Transicion.qml). Sin el buscador, igual (un
// momento después). Se apaga en kwinrc ([Script-apogeo-escritorios] transicion=false)
const TAPAR = 260;
const cambio = new QTimer();
cambio.singleShot = true;
cambio.interval = TAPAR;
let pendiente = null;
cambio.timeout.connect(function () { const p = pendiente; pendiente = null; if (p) ir(p.d, p.w); });

function lista() { return workspace.desktops; }
function columnas() { return Math.max(1, Math.ceil(lista().length / MODOS.length)); }
function sitio(d) {
    const i = lista().indexOf(d), c = columnas();
    return i < 0 ? null : { fila: Math.floor(i / c), col: i % c };
}
function en(fila, col) { return lista()[fila * columnas() + col] || null; }
function nombre(fila, col) { return col === 0 ? MODOS[fila] : MODOS[fila] + " " + (col + 1); }

// Las ventanas que cuentan (las de verdad: ni paneles ni las de Apogeo que van en todos)
function cuenta(w) { return w.normalWindow && !w.skipTaskbar && !w.onAllDesktops; }
function ventanas(d) { return workspace.windowList().filter(function (w) { return cuenta(w) && w.desktops.indexOf(d) >= 0; }); }
function abierto(fila, col) {
    const d = en(fila, col);
    return !!d && (col === 0 || d === workspace.currentDesktop || ventanas(d).length > 0);
}
function abiertos(fila) {
    const r = [];
    for (let c = 0; c < columnas(); c++) if (abierto(fila, c)) r.push(c);
    return r;
}

// Los nombres, siempre según su sitio en la rejilla
function nombrar() {
    const c = columnas();
    lista().forEach(function (d, i) {
        const n = nombre(Math.min(MODOS.length - 1, Math.floor(i / c)), i % c);
        if (d.name !== n) d.name = n;
    });
}

// Una columna más al final (un escritorio en cada modo: la rejilla tiene que ser rectangular)
function columnaNueva() {
    const c = columnas();
    for (let f = 0; f < MODOS.length; f++) workspace.createDesktop(f * (c + 1) + c, nombre(f, c));
    nombrar();
}

// El escritorio en el que estabas en cada modo (su id)
const ultimo = {};
function recordar() {
    const s = sitio(workspace.currentDesktop);
    if (s) ultimo[s.fila] = workspace.currentDesktop.id;
}
function destino(fila) {
    const d = lista().find(function (x) { return x.id === ultimo[fila]; });
    const s = d && sitio(d);
    return s && s.fila === fila && abierto(fila, s.col) && ventanas(d).length > 0 ? d : en(fila, 0);
}

function ir(d, w) {
    if (!d) return;
    if (w) { w.onAllDesktops = false; w.desktops = [d]; }
    workspace.currentDesktop = d;
    if (w) workspace.activeWindow = w;
}

// Ctrl+Alt+← → (con la ventana, si se la lleva)
function lado(paso, llevar) {
    const s = sitio(workspace.currentDesktop);
    if (!s || s.fila === 0) return;
    const w = llevar ? workspace.activeWindow : null;
    if (llevar && (!w || !cuenta(w))) return;
    const ab = abiertos(s.fila);
    const sig = paso > 0 ? ab.filter(function (c) { return c > s.col; })[0] : ab.filter(function (c) { return c < s.col; }).pop();
    if (sig !== undefined) { ir(en(s.fila, sig), w); return; }
    if (paso < 0 || ab.length >= MAX) return;
    // (en uno nuevo que sigue vacío no se abre otro: ya tienes uno vacío)
    if (!llevar && s.col > 0 && !ventanas(workspace.currentDesktop).length) return;
    // Uno nuevo: la primera columna libre a la derecha (o, si no la hay, la primera libre)
    let col = -1;
    for (let c = s.col + 1; c < MAX && col < 0; c++) if (!abierto(s.fila, c)) col = c;
    for (let c = 1; c < MAX && col < 0; c++) if (!abierto(s.fila, c)) col = c;
    if (col < 0) return;
    while (columnas() <= col) columnaNueva();
    ir(en(s.fila, col), w);
}

// Meta+Ctrl+↑ ↓ (con la ventana, si se la lleva) y los modos por nombre
function modo(fila, llevar) {
    if (fila < 0 || fila >= MODOS.length) return;
    const w = llevar ? workspace.activeWindow : null;
    if (llevar && (!w || !cuenta(w))) return;
    const s = sitio(workspace.currentDesktop);
    if (s && s.fila === fila) return;
    if (!readConfig("transicion", true)) { ir(destino(fila), w); return; }
    const otra = pendiente !== null;
    pendiente = { d: destino(fila), w: w };
    if (otra) return;   // (ya está tapándose: va al último que pidas)
    callDBus("org.apogeo.Buscador", "/Buscador", "org.apogeo.Buscador", "Transicion", MODOS[fila].toLowerCase());
    cambio.start();
}
function arriba(paso, llevar) {
    const s = sitio(workspace.currentDesktop);
    modo((s ? s.fila : 1) + paso, llevar);
}

// Ordenar sin que se vea: en los otros modos, las ventanas juntas desde el primero; en este, solo a la derecha del
// escritorio en el que estás. Y fuera las columnas que nadie usa.
function ordenar() {
    const actual = sitio(workspace.currentDesktop);
    if (!actual) return;
    for (let f = 1; f < MODOS.length; f++) {
        const desde = f === actual.fila ? actual.col + 1 : 1;
        let libre = desde;
        for (let c = desde; c < columnas(); c++) {
            const d = en(f, c), ws = ventanas(d);
            if (!ws.length) continue;
            if (c !== libre) {
                const a = en(f, libre);
                ws.forEach(function (w) { w.desktops = [a]; });
                if (ultimo[f] === d.id) ultimo[f] = a.id;
            }
            libre++;
        }
    }
    // (también una del medio: así no quedan huecos a la izquierda del escritorio en el que estás; quitar otro escritorio
    // no cambia el tuyo, así que no se nota)
    for (let c = columnas() - 1; c >= 1; c--) {
        const col = [];
        for (let f = 0; f < MODOS.length; f++) col.push(en(f, c));
        const usada = col.some(function (d) { return !d || d === workspace.currentDesktop || ventanas(d).length > 0; });
        if (!usada) col.forEach(function (d) { workspace.removeDesktop(d); });
    }
    nombrar();
}
const orden = new QTimer();
orden.interval = 700;   // (después de la animación del cambio)
orden.singleShot = true;
orden.timeout.connect(ordenar);
function luego() { orden.stop(); orden.start(); }

// Una ventana de otro escritorio se pone delante: en este modo, vas a ella; de otro modo, se viene aquí
function delante(w) {
    if (!w || w.onAllDesktops || w.desktopWindow || w.dock || !w.desktops.length) return;
    if (w.desktops.indexOf(workspace.currentDesktop) >= 0) return;
    // (las ventanas de Apogeo se colocan solas: la consola vive en Jugar)
    if ((w.resourceClass || "").indexOf("apogeo") >= 0) return;
    const a = sitio(workspace.currentDesktop), b = sitio(w.desktops[0]);
    if (a && b && a.fila === b.fila) workspace.currentDesktop = w.desktops[0];
    else w.desktops = [workspace.currentDesktop];
}

workspace.currentDesktopChanged.connect(function () { recordar(); luego(); });
workspace.windowRemoved.connect(luego);
workspace.windowActivated.connect(delante);

registerShortcut("apogeo-escritorio-izquierda", "Apogeo: el escritorio de la izquierda", "Ctrl+Alt+Left", function () { lado(-1, false); });
registerShortcut("apogeo-escritorio-derecha", "Apogeo: el escritorio de la derecha (o uno nuevo)", "Ctrl+Alt+Right", function () { lado(1, false); });
registerShortcut("apogeo-ventana-izquierda", "Apogeo: llevar la ventana al escritorio de la izquierda", "Ctrl+Alt+Shift+Left", function () { lado(-1, true); });
registerShortcut("apogeo-ventana-derecha", "Apogeo: llevar la ventana al escritorio de la derecha", "Ctrl+Alt+Shift+Right", function () { lado(1, true); });
registerShortcut("apogeo-modo-arriba", "Apogeo: el modo de arriba", "Meta+Ctrl+Up", function () { arriba(-1, false); });
registerShortcut("apogeo-modo-abajo", "Apogeo: el modo de abajo", "Meta+Ctrl+Down", function () { arriba(1, false); });
registerShortcut("apogeo-ventana-arriba", "Apogeo: llevar la ventana al modo de arriba", "Meta+Ctrl+Shift+Up", function () { arriba(-1, true); });
registerShortcut("apogeo-ventana-abajo", "Apogeo: llevar la ventana al modo de abajo", "Meta+Ctrl+Shift+Down", function () { arriba(1, true); });
MODOS.forEach(function (m, f) {
    registerShortcut("apogeo-ir-" + m.toLowerCase(), "Apogeo: ir a " + m, "", function () { modo(f, false); });
});

recordar();
ordenar();
