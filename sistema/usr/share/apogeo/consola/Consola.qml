import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Apogeo

// La consola de Jugar («C8 · Cinta panorámica»): tus juegos en una cinta de portadas abajo; el elegido pinta la pantalla
// con su arte. Arriba: Inicio (lo descargado, lo último jugado primero) y una pestaña por tienda o plataforma con toda tu
// biblioteca para descargar y quitar. Mando (PlayStation o Xbox) o teclado: ← → elegir · ✕ (A)/Intro jugar o descargar ·
// □ (X)/Supr quitar · L1 R1 (LB RB)/Q E pestaña · ○ (B)/Esc atrás · ↓ bajar a Navegar. La última pestaña,
// Herramientas («H1»): Discord, Spotify, OBS, Mission Center, CoolerControl, ProtonPlus, Hydra y los FPS en pantalla.
// En Inicio, estantes (↑ ↓): Recientes, Más jugados, Sin empezar y tus colecciones. △ (Y)/I la ficha del juego (tus
// capturas, lo jugado, colecciones, su carpeta y su tienda). ☰/O cambia el orden; F o / busca escribiendo. Suena y el
// mando vibra un poco al elegir.
// «consola» es apogeo-consola.
Window {
    id: win
    title: "Jugar"
    color: Tema.fondo
    visible: true
    Component.onCompleted: { Tema.piso = "jugar"; showFullScreen(); }
    // Siempre con los colores de Jugar, aunque esté abierta (escondida) mientras estás en otro modo: así sale ya en violeta
    Connections { target: Tema; function onPisoChanged() { if (Tema.piso !== "jugar") Tema.piso = "jugar"; } }

    // Dormida: si llevas 2 minutos sin la consola delante, suelta las imágenes (portadas y arte) y deja de mirar tus
    // juegos cada 20 segundos; al volver a ella se despierta al momento
    readonly property bool despierta: win.active || awake.running
    Timer { id: awake; interval: 120000; running: true }
    // (no se cierra sola: apogeo-pisos la abre al entrar en la sesión para que Jugar salga al instante)
    onActiveChanged: { if (!active) awake.restart(); }
    onDespiertaChanged: {
        consola.activa(despierta);
        if (despierta) { fondo.reload(); return; }
        a.source = ""; b.source = "";
        Qt.callLater(() => { gc(); win.releaseResources(); consola.dormir(); });
    }

    // El fondo se mueve solo con la consola delante y con gráfica de verdad (en una máquina sin 3D lo haría el procesador)
    Binding { target: Tema; property: "animar"; value: consola.gpu && win.active && win.visibility !== Window.Minimized }
    // Los botones como en tu mando: PlayStation (lo de serie) o Xbox (si el que hay conectado es de Xbox)
    readonly property var btn: consola.mando === "xbox" ? { a: "A", b: "B", x: "X", y: "Y", lb: "LB", rb: "RB", start: "☰" }
                                                        : { a: "✕", b: "○", x: "□", y: "△", lb: "L1", rb: "R1", start: "☰" }
    readonly property var lib: consola.tabs
    readonly property var allTabs: [
        { clave: "inicio", texto: "Inicio" }, { clave: "steam", texto: "Steam" }, { clave: "epic", texto: "Epic" },
        { clave: "emuladores", texto: "Emuladores" }, { clave: "ps5", texto: "PS5" }, { clave: "windows", texto: "Windows" },
        { clave: "herramientas", texto: "Herramientas" }
    ]
    // Windows solo si hay un Windows escondido (o algún juego suyo); las demás, siempre (vacías explican qué hacer)
    readonly property var shownTabs: allTabs.filter(t => t.clave !== "windows" || lib.windowsHay || (lib.windows || []).length > 0)
    property int tab: 0
    readonly property string tabKey: shownTabs[Math.min(tab, shownTabs.length - 1)].clave
    readonly property bool enHerr: tabKey === "herramientas"
    // Las herramientas y, al final, los FPS en pantalla (MangoHud)
    readonly property var herr: consola.herramientas.concat([{ clave: "fps", nombre: "FPS en pantalla", texto: "Arriba a la izquierda, en tus juegos", hay: true }])
    property int hsel: 0
    function herrHacer(i) {
        const h = herr[i];
        if (!h) return;
        hsel = i;
        if (h.clave === "fps") { consola.setFpsVisibles(!consola.fpsVisibles); say(consola.fpsVisibles ? "Los FPS se ven en tus juegos" : "Los FPS ya no se ven (el límite sigue)"); return; }
        if (!h.hay) { say(h.nombre + " no está instalada"); return; }
        consola.herramienta(h.clave);
        say("Abriendo " + h.nombre + "…");
    }
    property string sys: ""                       // el sistema elegido en Emuladores ("" = todos)
    readonly property var systems: {
        const o = [];
        for (const g of (lib.emuladores || [])) if (!o.some(s => s.clave === g.system)) o.push({ clave: g.system, texto: g.systemName });
        return o;
    }
    // ---------- Inicio: los estantes (↑ ↓) ----------
    function clave(g) { return g.store + ":" + g.id }
    readonly property var colecciones: consola.colecciones
    readonly property var todos: {
        const m = {};
        for (const k of ["steam", "epic", "emuladores", "ps5", "windows"]) for (const g of (lib[k] || [])) m[clave(g)] = g;
        return m;
    }
    readonly property var estantes: {
        const ins = lib.inicio || [];
        const out = [{ clave: "recientes", texto: "Recientes", juegos: ins }];
        const mas = ins.filter(g => (g.minutes || 0) > 0).sort((a, b) => b.minutes - a.minutes);
        if (mas.length > 1) out.push({ clave: "mas", texto: "Más jugados", juegos: mas });
        const sin = ins.filter(g => !(g.minutes > 0) && !g.last);
        if (sin.length) out.push({ clave: "sin", texto: "Sin empezar", juegos: sin });
        for (const c of colecciones) {
            const js = c.juegos.map(k => todos[k]).filter(g => !!g);
            if (js.length) out.push({ clave: "c:" + c.nombre, texto: c.nombre, juegos: js, coleccion: true });
        }
        return out;
    }
    property int fila: 0
    readonly property int filaOk: Math.max(0, Math.min(fila, estantes.length - 1))
    readonly property bool enInicio: tabKey === "inicio"

    // ---------- Orden (☰) y buscar escribiendo (F o /) ----------
    readonly property var ordenes: [["reciente", "Recientes"], ["nombre", "Nombre"], ["horas", "Horas jugadas"], ["tamano", "Tamaño"]]
    property int orden: 0
    property string filtro: ""
    property bool buscando: false
    function plano(t) {
        const s = String(t).toLowerCase();
        try { return s.normalize("NFD").replace(/[\u0300-\u036f]/g, ""); } catch (e) { return s; }
    }
    readonly property var base: enInicio ? (estantes[filaOk] ? estantes[filaOk].juegos : [])
                                         : (lib[tabKey] || []).filter(g => tabKey !== "emuladores" || sys === "" || g.system === sys)
    readonly property var list: {
        let l = base;
        if (filtro !== "") { const q = plano(filtro); l = l.filter(g => plano(g.name).indexOf(q) >= 0); }
        const o = ordenes[orden][0];
        if (o === "nombre") l = l.slice().sort((a, b) => a.name.localeCompare(b.name));
        else if (o === "horas") l = l.slice().sort((a, b) => (b.minutes || 0) - (a.minutes || 0));
        else if (o === "tamano") l = l.slice().sort((a, b) => (b.size || 0) - (a.size || 0));
        return l;
    }
    readonly property string selKey: tabKey + sys + (enInicio ? ":" + filaOk : "") + "|" + filtro + "|" + orden
    property var selByTab: ({})
    readonly property int sel: Math.max(0, Math.min(selByTab[selKey] || 0, list.length - 1))
    readonly property var game: list.length ? list[sel] : null
    readonly property var dl: game ? (lib.descargas || {})[game.id] : undefined
    property string toast: ""
    property bool asking: false                   // «¿Quitar…?»

    readonly property int total: (lib[tabKey] || []).length
    readonly property int installed: (lib[tabKey] || []).filter(g => g.installed).length
    function countOf(key) { return (lib[key] || []).length }

    function select(i) {
        const n = Math.max(0, Math.min(i, list.length - 1));
        if (n !== sel) sonar("mover");
        const s = Object.assign({}, selByTab);
        s[selKey] = n;
        selByTab = s;
        cinta.positionViewAtIndex(sel, ListView.Contain);
    }
    function setTab(i) { tab = (i + shownTabs.length) % shownTabs.length; sys = ""; filtro = ""; buscando = false; sonar("pestana"); }
    function setFila(i) {
        const n = Math.max(0, Math.min(i, estantes.length - 1));
        if (n === filaOk) return;
        fila = n;
        sonar("pestana");
    }

    // ---------- Sonidos y el mando que vibra ----------
    // (los toca apogeo-consola con pw-play: QtMultimedia, con MangoHud cargado en la consola, la tiraba al arrancar)
    function sonar(nombre) { if (win.active) consola.sonar(nombre) }

    // Al cambiar de pestaña o de estante, la cinta y el elegido entran deslizándose
    property real entra: 1
    NumberAnimation { id: entraAnim; target: win; property: "entra"; from: 0; to: 1; duration: 340; easing.type: Easing.OutCubic }
    onTabKeyChanged: entraAnim.restart()
    onFilaOkChanged: entraAnim.restart()

    // ---------- La ficha de un juego (△) ----------
    property var ficha: null                      // el juego
    property var fichaDatos: ({})
    property int fsel: 0
    property bool fichaCol: false                 // eligiendo colecciones
    property int csel: 0
    readonly property var sugeridas: ["Favoritos", "Con amigos", "Pendientes", "Cortos"]
    readonly property var fichaAcciones: {
        const g = ficha;
        if (!g) return [];
        const out = [{ k: "jugar", t: g.installed ? "Jugar" : g.store === "ps5" ? "Convertir" : "Descargar", principal: true }];
        out.push({ k: "coleccion", t: "Colecciones" });
        if (g.installed && (g.store === "steam" || g.store === "epic")) out.push({ k: "fps", t: "FPS" });
        if (fichaDatos.carpeta) out.push({ k: "carpeta", t: "Abrir su carpeta" });
        if (fichaDatos.tienda) out.push({ k: "tienda", t: "Ver en la tienda" });
        if (g.installed && g.store !== "windows") out.push({ k: "quitar", t: "Quitar" });
        return out;
    }
    // Las colecciones para elegir: las tuyas (con ✓ si está) y, debajo, las sugeridas que aún no tienes
    readonly property var fichaColecciones: {
        if (!ficha) return [];
        const k = clave(ficha);
        const out = colecciones.map(c => ({ nombre: c.nombre, dentro: c.juegos.indexOf(k) >= 0 }));
        for (const n of sugeridas) if (!out.some(c => c.nombre === n)) out.push({ nombre: n, dentro: false, nueva: true });
        return out;
    }
    function abrirFicha() {
        if (!game) return;
        ficha = game;
        try { fichaDatos = JSON.parse(consola.ficha(game)); } catch (e) { fichaDatos = {}; }
        fsel = 0;
        fichaCol = false;
        sonar("abrir");
    }
    function cerrarFicha() { ficha = null; fichaCol = false; sonar("atras"); }
    function fichaHacer() {
        const a = fichaAcciones[fsel];
        if (!a) return;
        const g = ficha;
        if (a.k === "jugar") { ficha = null; primary(); }
        else if (a.k === "coleccion") { fichaCol = true; csel = 0; sonar("abrir"); }
        else if (a.k === "fps") {
            const seq = [0, 30, 45, 60], key = g.store + ":" + g.id;
            const v = seq[(seq.indexOf(consola.juegosFps[key] || 0) + 1) % seq.length];
            consola.setFps(key, v);
            say(v ? v + " FPS en " + g.name : g.name + ": FPS como todos");
            sonar("elegir");
        }
        else if (a.k === "carpeta") { consola.abrirCarpeta(fichaDatos.carpeta); say("Abriendo su carpeta…"); }
        else if (a.k === "tienda") { consola.abrirTienda(fichaDatos.tienda); say("Abriendo su página en Steam…"); }
        else if (a.k === "quitar") { ficha = null; secondary(); }
    }
    function coleccionHacer(i) {
        const c = fichaColecciones[i];
        if (!c || !ficha) return;
        consola.coleccion(c.nombre, clave(ficha), !c.dentro);
        say(c.dentro ? "Fuera de «" + c.nombre + "»" : "En «" + c.nombre + "»");
        sonar("elegir");
    }
    function say(t) { toast = t; toastTimer.restart(); }
    Timer { id: toastTimer; interval: 4500; onTriggered: win.toast = "" }

    function primary() {
        if (!game || (dl && dl.estado !== "error")) return;
        sonar("elegir");
        consola.vibrar();
        if (game.store === "windows") { salto = game; cuenta = 10; return; }   // «W1»: 10 s para cancelar
        if (game.installed) {
            const msg = consola.play(game);
            if (msg) say(msg);
            else { say("Abriendo " + game.name + "…"); hideTimer.restart(); }
        } else {
            const msg = consola.install(game);
            say(msg || (game.store === "steam" ? "Steam te pregunta dónde descargarlo" : game.store === "ps5" ? "Convirtiendo con AnyPS5…" : "Descargando " + game.name + "…"));
        }
    }
    function secondary() {
        if (!game || dl || !game.installed || game.store === "windows") return;
        asking = true;
    }
    function confirmRemove() {
        asking = false;
        const msg = consola.uninstall(game);
        say(msg || (game.store === "steam" ? "Steam te pide que lo confirmes" : game.store === "emu" ? "A la papelera (se puede recuperar)" : "Quitando " + game.name + "…"));
    }
    Timer { id: hideTimer; interval: 1200; onTriggered: win.visibility = Window.Minimized } // (el juego se ve)

    // ---------- A Windows («W1 · Cuenta atrás») ----------
    property var salto: null          // el juego (o "escritorio", para instalar) al que se va
    property int cuenta: 10
    Timer { interval: 1000; repeat: true; running: win.salto !== null; onTriggered: { win.cuenta -= 1; if (win.cuenta <= 0) win.irAWindows(); } }
    function irAWindows() {
        const s = salto;
        salto = null;
        const msg = s === "escritorio" ? consola.windowsDesktop() : consola.play(s);
        say(msg || "Reiniciando en Windows…");
    }

    function key(k) {
        if (salto !== null) {
            if (k === "a") irAWindows();
            else if (k === "b") salto = null;
            return;
        }
        if (asking) {
            if (k === "a") confirmRemove();
            else if (k === "b") asking = false;
            return;
        }
        if (ficha) {
            if (fichaCol) {
                const n = fichaColecciones.length;
                if (k === "arriba" || k === "izquierda") { csel = (csel - 1 + n) % n; sonar("mover"); }
                else if (k === "abajo" || k === "derecha") { csel = (csel + 1) % n; sonar("mover"); }
                else if (k === "a") coleccionHacer(csel);
                else if (k === "b") { fichaCol = false; sonar("atras"); }
                return;
            }
            const n = fichaAcciones.length;
            if (k === "izquierda") { fsel = Math.max(0, fsel - 1); sonar("mover"); }
            else if (k === "derecha") { fsel = Math.min(n - 1, fsel + 1); sonar("mover"); }
            else if (k === "a") fichaHacer();
            else if (k === "b" || k === "y") cerrarFicha();
            return;
        }
        if (enHerr && ["izquierda", "derecha", "arriba", "abajo", "a"].indexOf(k) >= 0) {
            const cols = herrGrid.columns;
            if (k === "a") herrHacer(hsel);
            else hsel = Math.max(0, Math.min(herr.length - 1, hsel + ({ izquierda: -1, derecha: 1, arriba: -cols, abajo: cols })[k]));
            return;
        }
        if (k === "izquierda") select(sel - 1);
        else if (k === "derecha") select(sel + 1);
        else if (k === "a") primary();
        else if (k === "x") secondary();
        else if (k === "y") abrirFicha();
        else if (k === "start") { orden = (orden + 1) % ordenes.length; sonar("pestana"); say("Orden: " + ordenes[orden][1]); }
        else if (k === "b" && (filtro !== "" || buscando)) { filtro = ""; buscando = false; sonar("atras"); }
        else if (k === "lb") setTab(tab - 1);
        else if (k === "rb") setTab(tab + 1);
        else if (k === "abajo" && enInicio && filaOk < estantes.length - 1) setFila(filaOk + 1);
        else if (k === "abajo") consola.floor(1);
        else if (k === "arriba" && enInicio) setFila(filaOk - 1);
        else if (k === "arriba" && tabKey === "emuladores" && systems.length) {
            const i = systems.findIndex(s => s.clave === sys);
            sys = i + 1 < systems.length ? systems[i + 1].clave : "";
        }
    }
    Connections {
        target: consola
        function onPad(button) { if (win.active) win.key(button) }
        function onShown() { win.showFullScreen(); win.raise(); win.requestActivate(); consola.refresh(); }
        function onIrA(t) { const i = win.shownTabs.findIndex(x => x.clave === t); if (i >= 0) win.setTab(i); }
    }
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            // Buscando: las letras van al filtro (Intro o las flechas siguen eligiendo; Esc lo borra)
            if (win.buscando && !win.ficha) {
                if (e.key === Qt.Key_Backspace) { win.filtro = win.filtro.slice(0, -1); e.accepted = true; return; }
                if (e.text && e.text.length === 1 && e.text.charCodeAt(0) >= 32 && e.text.charCodeAt(0) !== 127) {
                    win.filtro += e.text; e.accepted = true; return;
                }
            }
            if (!win.ficha && !win.asking && (e.key === Qt.Key_F || e.key === Qt.Key_Slash)) {
                win.buscando = true; e.accepted = true; return;
            }
            const m = { [Qt.Key_Left]: "izquierda", [Qt.Key_Right]: "derecha", [Qt.Key_Up]: "arriba", [Qt.Key_Down]: "abajo",
                        [Qt.Key_Return]: "a", [Qt.Key_Enter]: "a", [Qt.Key_Space]: "a", [Qt.Key_Escape]: "b",
                        [Qt.Key_Delete]: "x", [Qt.Key_X]: "x", [Qt.Key_Q]: "lb", [Qt.Key_E]: "rb", [Qt.Key_Tab]: "rb",
                        [Qt.Key_Backtab]: "lb", [Qt.Key_I]: "y", [Qt.Key_O]: "start" };
            if (m[e.key]) { win.key(m[e.key]); e.accepted = true; }
        }
    }

    function ago(t) {
        if (!t) return "";
        const s = Date.now() / 1000 - t;
        if (s < 3600) return "hace un rato";
        if (s < 86400) return "hace " + Math.round(s / 3600) + " h";
        if (s < 172800) return "ayer";
        if (s < 604800) return "hace " + Math.round(s / 86400) + " días";
        if (s < 2592000) { const n = Math.round(s / 604800); return "hace " + n + (n === 1 ? " semana" : " semanas"); }
        const n = Math.round(s / 2592000);
        return "hace " + n + (n === 1 ? " mes" : " meses");
    }
    // Lo que has jugado: «35 min», «2,5 h», «120 h» (de Steam, de Heroic o del cronómetro de la consola)
    function hours(m) {
        if (!m || m < 1) return "";
        if (m < 60) return Math.round(m) + " min jugados";
        const h = m / 60;
        return (h < 10 ? (Math.round(h * 10) / 10).toString().replace(".", ",") : Math.round(h)) + " h jugadas";
    }
    function gb(b) { return b > 0 ? (b / 1073741824 >= 1 ? (b / 1073741824).toFixed(1).replace(".", ",") + " GB" : Math.max(1, Math.round(b / 1048576)) + " MB") : "" }
    readonly property var storeNames: ({ steam: "Steam", epic: "Epic", emu: "", ps5: "PS5 · AnyPS5", windows: "Windows" })
    function where(g) { return g.store === "emu" ? g.systemName : storeNames[g.store] || "" }
    function badges(g) {
        if (!g) return [];
        const out = [where(g)].filter(x => x);
        out.push(g.installed ? "Instalado" : "En la biblioteca");
        const extra = { steam: "Proton", epic: "Heroic", ps5: "AnyPS5", windows: "Anticheat" }[g.store];
        if (extra) out.push(extra);
        return out.filter((x, i) => out.indexOf(x) === i);
    }
    // Un color por juego (para cuando no hay portada)
    function tint(name) { let h = 0; for (const c of name) h = (h * 31 + c.charCodeAt(0)) % 360; return Qt.hsla(h / 360, 0.45, 0.32, 1) }

    // ---------- El fondo vivo: el arte del elegido ----------
    // El arte se mueve muy despacio (se acerca y se aleja) y, al pasar de un juego a otro, se queda un poco atrás, como
    // si estuviera más lejos que la cinta (paralaje). Sus colores, mezclados con el violeta de Jugar, tiñen el grafito.
    property color artColor: win.game ? win.tint(win.game.name) : Tema.acento
    // (los colores del arte, más vivos, y un poco de violeta)
    property color mood: {
        const c = win.artColor;
        const v = Qt.hsla(c.hslHue < 0 ? 0.73 : c.hslHue, Math.max(0.45, c.hslSaturation), Math.min(0.55, Math.max(0.4, c.hslLightness)), 1);
        return Qt.tint(v, Qt.rgba(Tema.acento.r, Tema.acento.g, Tema.acento.b, 0.4));
    }
    Behavior on mood { ColorAnimation { duration: 900 } }
    // La muestra: el arte a 4×4 píxeles, para sacar su color medio
    Canvas {
        id: muestra
        width: 4; height: 4
        opacity: 0.01
        property string src: ""
        onImageLoaded: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, 4, 4);
            if (!src || !isImageLoaded(src)) return;
            ctx.drawImage(src, 0, 0, 4, 4);
            const d = ctx.getImageData(0, 0, 4, 4).data;
            let r = 0, g = 0, b = 0;
            for (let i = 0; i < 64; i += 4) { r += d[i]; g += d[i + 1]; b += d[i + 2]; }
            win.artColor = Qt.rgba(r / 4080, g / 4080, b / 4080, 1);
        }
        function sample(url) {
            if (src) unloadImage(src);
            src = url;
            if (!url) return;
            if (isImageLoaded(url)) requestPaint(); else loadImage(url);
        }
    }
    property int lastSel: 0
    onSelChanged: { fondo.deriva = (sel > lastSel ? 1 : -1) * 34; lastSel = sel; deriva.restart(); }
    NumberAnimation { id: deriva; target: fondo; property: "deriva"; to: 0; duration: 1100; easing.type: Easing.OutCubic }
    Item {
        id: fondo
        anchors.fill: parent
        property string src: win.game ? (win.game.hero || win.game.cover) : ""
        property bool flip: false
        property real deriva: 0
        onSrcChanged: reload()
        function reload() {
            if (!win.despierta) return;
            flip = !flip; (flip ? b : a).source = src;
            if (!src && win.game) win.artColor = win.tint(win.game.name);
            muestra.sample(src);
        }
        // Sin arte (o mientras llega): el fondo animado de Jugar, «Nebulosa»
        Fondo { anchors.fill: parent; tipo: 1; visible: a.status !== Image.Ready && b.status !== Image.Ready }
        Rectangle { anchors.fill: parent; visible: !!win.game; color: win.game ? win.tint(win.game.name) : "transparent"; opacity: 0.35 }
        Item {
            id: arte
            anchors.fill: parent
            // Acercarse y alejarse muy despacio (solo con gráfica de verdad y la consola delante)
            property real zoom: 0
            SequentialAnimation on zoom {
                running: Tema.animar
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 22000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 22000; easing.type: Easing.InOutSine }
            }
            scale: 1.06 + 0.04 * zoom
            transform: Translate { x: fondo.deriva - 18 * arte.zoom; y: -8 * arte.zoom }
            Image {
                id: a
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize.height: win.height   // (el arte, al tamaño de la pantalla: no más grande)
                asynchronous: true
                opacity: !fondo.flip && status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 450 } }
            }
            Image {
                id: b
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                sourceSize.height: win.height
                asynchronous: true
                opacity: fondo.flip && status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 450 } }
            }
        }
        // Oscuro a la izquierda y abajo (para leer encima), en el grafito de Órbita teñido con los colores del arte
        readonly property color sombra: Qt.tint("#080a0f", Qt.rgba(win.mood.r, win.mood.g, win.mood.b, 0.1))
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(fondo.sombra.r, fondo.sombra.g, fondo.sombra.b, 0.94) }
                GradientStop { position: 0.45; color: Qt.rgba(fondo.sombra.r, fondo.sombra.g, fondo.sombra.b, 0.6) }
                GradientStop { position: 0.8; color: Qt.rgba(fondo.sombra.r, fondo.sombra.g, fondo.sombra.b, 0.2) }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 0.8; color: Qt.rgba(fondo.sombra.r, fondo.sombra.g, fondo.sombra.b, 0.94) }
            }
        }
        // Un resplandor de esos colores abajo, detrás de la cinta, y otro más leve arriba a la derecha
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * 0.42
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(win.mood.r, win.mood.g, win.mood.b, 0.16) }
            }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.6; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(win.mood.r, win.mood.g, win.mood.b, 0.08) }
            }
        }
    }

    // ---------- Arriba: la marca, los modos, la hora y tú ----------
    Item {
        id: barra
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 86

        Row {
            x: 48
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Nucleo { width: 34; height: 34; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Texto {
                    text: "ÓRBITA"
                    font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 3.2 }
                    color: Tema.apagado
                }
                Texto { text: "Jugar"; font { pixelSize: 19; weight: Font.ExtraBold; letterSpacing: -0.2 } }
            }
        }

        // Los tres modos, en una pastilla de cristal
        Rectangle {
            anchors.centerIn: parent
            width: modos.implicitWidth + 8
            height: 40
            radius: Tema.r(14)
            color: Qt.rgba(Tema.superficie.r, Tema.superficie.g, Tema.superficie.b, 0.55)
            border.color: Tema.borde
            Row {
                id: modos
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: ["Jugar", "Navegar", "Estudiar"]
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool on: index === 0
                        width: ml.implicitWidth + 24; height: 34; radius: Tema.r(11)
                        color: on ? Tema.acento : (mm.containsMouse ? Tema.encima : "transparent")
                        Texto {
                            id: ml
                            anchors.centerIn: parent
                            text: parent.modelData
                            font { pixelSize: 13; weight: parent.on ? Font.Bold : Font.Medium }
                            color: parent.on ? Tema.sobreAcento : Tema.apagado
                        }
                        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: consola.floor(parent.index) }
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right; anchors.rightMargin: 48
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Texto { id: reloj; anchors.verticalCenter: parent.verticalCenter; font { family: Tema.mono; pixelSize: 14; weight: Font.DemiBold } text: Qt.formatTime(new Date(), "HH:mm") }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: reloj.text = Qt.formatTime(new Date(), "HH:mm") }
            Rectangle {
                width: 38; height: 38; radius: 19
                color: Tema.rosaSuave
                border.width: 2; border.color: Tema.acento
                clip: true
                Image { anchors.fill: parent; anchors.margins: 2; source: consola.avatar; fillMode: Image.PreserveAspectCrop; visible: status === Image.Ready }
                Texto { anchors.centerIn: parent; visible: consola.avatar === ""; text: "●"; font.pixelSize: 12; color: Tema.acento }
            }
        }
    }

    // ---------- Las pestañas de la biblioteca ----------
    Row {
        id: pestanas
        x: 48; y: 92
        spacing: 4
        Repeater {
            model: win.shownTabs
            delegate: Rectangle {
                id: t
                required property var modelData
                required property int index
                readonly property bool on: win.tab === index
                width: tl.implicitWidth + 30; height: 38; radius: Tema.r(12)
                color: on ? Tema.rosa : tm.containsMouse ? Tema.encima : "transparent"
                border.width: on ? 0 : 1
                border.color: Tema.linea
                Row {
                    id: tl
                    anchors.centerIn: parent
                    spacing: 7
                    Texto { text: t.modelData.texto; font { pixelSize: 14; weight: t.on ? Font.Bold : Font.Medium } color: t.on ? Tema.sobreRosa : Tema.apagado }
                    Texto {
                        visible: win.countOf(t.modelData.clave) > 0
                        text: win.countOf(t.modelData.clave)
                        font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold }
                        color: t.on ? Tema.sobreRosa : Tema.tenue
                    }
                }
                MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.setTab(t.index) }
            }
        }
    }

    // Emuladores: los sistemas (↑ para cambiar)
    Row {
        visible: win.tabKey === "emuladores" && win.systems.length > 1
        x: 48; y: 140
        spacing: 6
        Repeater {
            model: [{ clave: "", texto: "Todos" }].concat(win.systems)
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: win.sys === modelData.clave
                width: sl.implicitWidth + 24; height: 28; radius: Tema.r(9)
                color: on ? Tema.rosaSuave : Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.55)
                border.color: on ? Tema.acento : Tema.borde
                Texto { id: sl; anchors.centerIn: parent; text: parent.modelData.texto; font.pixelSize: 12; color: parent.on ? Tema.texto : Tema.apagado }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.sys = parent.modelData.clave }
            }
        }
    }

    // ---------- El elegido ----------
    Column {
        visible: !!win.game
        opacity: win.entra
        x: 48; y: 178
        width: parent.width * 0.55
        spacing: 0
        Row {
            spacing: 8
            Rectangle { width: 6; height: 6; radius: 3; color: Tema.acento; anchors.verticalCenter: parent.verticalCenter }
            Texto {
                text: {
                    const g = win.game;
                    if (!g) return "";
                    const w = win.where(g).toUpperCase();
                    if (!g.installed) return (g.store === "ps5" ? "SIN CONVERTIR" : "SIN DESCARGAR") + (w ? " · " + w : "");
                    return (g.last ? "JUGADO " + win.ago(g.last).toUpperCase() : "DESCARGADO") + (w ? " · " + w : "");
                }
                color: Tema.acento
                font { family: Tema.mono; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.4 }
            }
        }
        Texto {
            width: parent.width
            text: win.game ? win.game.name : ""
            font { pixelSize: 60; weight: Font.ExtraBold; letterSpacing: -1.4 }
            maximumLineCount: 2; elide: Text.ElideRight
            lineHeight: 0.92
        }
        Item { width: 1; height: 12 }
        // La compatibilidad, sin promesas: la tienda, el estado y la capa que lo hace funcionar
        Row {
            spacing: 7
            Repeater {
                model: win.badges(win.game)
                delegate: Rectangle {
                    required property string modelData
                    width: bd.implicitWidth + 18; height: 26; radius: Tema.r(8)
                    color: Tema.encima
                    border.color: Tema.borde
                    Texto { id: bd; anchors.centerIn: parent; text: parent.modelData; font { family: Tema.mono; pixelSize: 10; letterSpacing: 0.6 } color: Tema.apagado }
                }
            }
        }
        Item { width: 1; height: 18 }
        Row {
            spacing: 10
            // Jugar · Descargar · el progreso
            Rectangle {
                id: boton
                readonly property bool busy: !!win.dl
                width: busy ? 280 : bl.implicitWidth + 64
                height: 54; radius: Tema.r(16)
                color: busy ? Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.7) : Tema.acento
                border.color: busy ? Tema.borde : "transparent"
                RectangularShadow { anchors.fill: parent; z: -1; visible: !boton.busy; offset.y: 6; blur: 26; spread: -4; radius: parent.radius; color: Tema.acento; opacity: 0.7 }
                Rectangle {
                    visible: !boton.busy
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: parent.height / 2; radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                Rectangle {
                    visible: boton.busy && win.dl.estado !== "error"
                    x: 0; y: 0; height: parent.height; radius: parent.radius
                    width: parent.width * Math.max(0.06, (win.dl && win.dl.progreso) || 0)
                    color: Tema.rosaSuave
                }
                Texto {
                    id: bl
                    anchors.centerIn: parent
                    text: boton.busy ? (win.dl.estado === "error" ? win.dl.mensaje : (win.dl.estado === "quitando" ? "Quitando… " : "Descargando… ") + Math.round((win.dl.progreso || 0) * 100) + " %")
                        : win.game && win.game.installed ? "▶  Jugar" : win.game && win.game.store === "ps5" ? "Convertir con AnyPS5" : "↓  Descargar"
                    color: boton.busy ? Tema.texto : Tema.sobreAcento
                    font { pixelSize: boton.busy ? 14 : 17; weight: Font.ExtraBold }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.primary() }
            }
            Rectangle {
                visible: !!win.game && win.game.installed && !win.dl && win.game.store !== "windows"
                width: ql.implicitWidth + 40; height: 54; radius: Tema.r(16)
                color: qm.containsMouse ? Tema.pulsado : Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.55)
                border.color: Tema.borde
                Texto { id: ql; anchors.centerIn: parent; text: win.game && win.game.store === "ps5" ? "Quitar lo convertido" : "Quitar del PC"; font.pixelSize: 14 }
                MouseArea { id: qm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.secondary() }
            }
            // Los FPS de este juego (con MangoHud): como todos (Salud del PC) o 30, 45 o 60; un clic pasa al siguiente
            Rectangle {
                id: fpsPill
                readonly property string key: win.game ? win.game.store + ":" + win.game.id : ""
                readonly property int mine: consola.juegosFps[key] || 0
                visible: !!win.game && win.game.installed && !win.dl && (win.game.store === "steam" || win.game.store === "epic")
                width: fl.implicitWidth + 40; height: 54; radius: Tema.r(16)
                color: fm.containsMouse ? Tema.pulsado : Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.55)
                border.color: mine ? Tema.acento : Tema.borde
                Texto {
                    id: fl
                    anchors.centerIn: parent
                    font.pixelSize: 14
                    text: fpsPill.mine ? fpsPill.mine + " FPS en este juego" : "FPS como todos (" + consola.fpsTodos + ")"
                }
                MouseArea {
                    id: fm
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { const seq = [0, 30, 45, 60]; consola.setFps(fpsPill.key, seq[(seq.indexOf(fpsPill.mine) + 1) % seq.length]); }
                }
            }
            Repeater {
                model: win.game ? [win.hours(win.game.minutes), win.gb(win.game.size), win.dl && win.dl.mensaje && win.dl.estado !== "error" ? win.dl.mensaje : ""].filter(x => x) : []
                delegate: Rectangle {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: cl.implicitWidth + 24; height: 30; radius: Tema.r(9)
                    color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.55); border.color: Tema.borde
                    Texto { id: cl; anchors.centerIn: parent; text: parent.modelData; font { family: Tema.mono; pixelSize: 11 } color: Tema.apagado }
                }
            }
        }
    }

    // ---------- Vacío: qué hacer ----------
    Column {
        visible: !win.game && !win.enHerr
        x: 48; y: 196
        width: parent.width * 0.5
        spacing: 16
        Row {
            spacing: 10
            Nucleo { width: 34; height: 34; disco: false; anchors.verticalCenter: parent.verticalCenter }
            Texto {
                anchors.verticalCenter: parent.verticalCenter
                text: "BIBLIOTECA VACÍA"
                color: Tema.acento
                font { family: Tema.mono; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.6 }
            }
        }
        Texto {
            width: parent.width
            font { pixelSize: 40; weight: Font.ExtraBold; letterSpacing: -0.8 }
            text: ({ inicio: "Aún no tienes juegos descargados", steam: "Entra en Steam", epic: "Entra en Epic con Heroic",
                     emuladores: "Pon tus juegos y a jugar", ps5: "Tus juegos de PS5", windows: "Instala tus juegos de Windows" })[win.tabKey] || ""
        }
        Texto {
            width: parent.width
            color: Tema.apagado
            font.pixelSize: 16
            lineHeight: 1.25
            text: ({
                inicio: "Elige Steam, Epic, Emuladores o PS5 arriba (" + win.btn.lb + " / " + win.btn.rb + ") y descarga lo que te apetezca.",
                steam: "Abre Steam y entra con tu cuenta: aquí saldrá toda tu biblioteca para descargar y quitar.",
                epic: "Abre Heroic y entra con tu cuenta de Epic: aquí saldrá toda tu biblioteca.",
                emuladores: "Copia tus juegos (tus copias de tus discos y cartuchos) en la carpeta de cada sistema, dentro de " + consola.folder + ". Salen aquí solos, con su portada. En LEEME.txt tienes cómo.",
                ps5: "Pon cada juego volcado de tu PS5 en una carpeta dentro de " + consola.folder + "/PS5 y Apogeo lo convierte con AnyPS5. Es experimental: por ahora van muy pocos juegos.",
                windows: "Solo para los que no van en Apogeo (Valorant, EA FC…). Ve a Windows, instálalos con su tienda (Riot, EA app…) y pulsa «Volver a Apogeo»: saldrán aquí solos."
            })[win.tabKey] || ""
        }
        Rectangle {
            visible: win.tabKey !== "inicio"
            width: ol.implicitWidth + 48; height: 46; radius: Tema.r(14)
            color: Tema.acento
            Texto {
                id: ol
                anchors.centerIn: parent
                color: Tema.sobreAcento; font { pixelSize: 15; weight: Font.Bold }
                text: ({ steam: "Abrir Steam", epic: "Abrir Heroic", emuladores: "Abrir la carpeta", ps5: "Abrir la carpeta", windows: "Ir a Windows a instalar" })[win.tabKey] || ""
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (win.tabKey === "windows") { win.salto = "escritorio"; win.cuenta = 10; }
                    else consola.open(({ steam: "steam", epic: "epic" })[win.tabKey] || "carpeta");
                }
            }
        }
    }
    // Antes de ir a Windows: lo que conviene saber (Secure Boot, TPM, BitLocker, sitio en su arranque), arriba a la
    // derecha en la pestaña Windows. Solo avisa: Apogeo nunca toca las claves del arranque por su cuenta.
    Rectangle {
        id: avisosBox
        readonly property var avisos: lib.windowsAvisos || []
        visible: win.tabKey === "windows" && avisos.length > 0
        anchors { right: parent.right; rightMargin: 48; top: barra.bottom; topMargin: 8 }
        width: 440
        height: avisosCol.implicitHeight + 32
        radius: Tema.r(16)
        color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.82)
        border.color: Tema.borde
        z: 5
        Column {
            id: avisosCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 10
            Texto {
                text: "ANTES DE IR A WINDOWS"
                color: Tema.apagado
                font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.6 }
            }
            Repeater {
                model: avisosBox.avisos
                delegate: Row {
                    required property var modelData
                    spacing: 10
                    Rectangle {
                        y: 6
                        width: 8; height: 8; radius: 4
                        color: modelData.nivel === "aviso" ? "#ffc857" : Tema.acento
                    }
                    Texto {
                        width: 390
                        text: modelData.texto
                        wrapMode: Text.Wrap
                        font.pixelSize: 14
                        lineHeight: 1.2
                    }
                }
            }
        }
    }
    // La marca de agua, muy tenue, a la derecha del vacío
    Nucleo {
        visible: !win.game && !win.enHerr
        anchors.right: parent.right; anchors.rightMargin: 140
        y: 200
        width: 280; height: 280
        opacity: 0.06
        disco: false
    }

    // ---------- Herramientas («H1»): una rejilla de tarjetas de cristal ----------
    Grid {
        id: herrGrid
        visible: win.enHerr
        x: 48; y: 158
        columns: Math.max(2, Math.min(4, Math.floor((win.width - 96 + 22) / (300 + 22))))
        spacing: 22
        Repeater {
            model: win.herr
            delegate: Rectangle {
                id: ht
                required property var modelData
                required property int index
                readonly property bool on: win.hsel === index
                readonly property bool esFps: modelData.clave === "fps"
                width: 300; height: 168; radius: Tema.r(18)
                color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, htm.containsMouse || on ? 0.78 : 0.6)
                border.width: on ? 2 : 1
                border.color: on ? Tema.acento : Tema.borde
                opacity: modelData.hay ? 1 : 0.5
                scale: on ? 1.03 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                RectangularShadow { visible: ht.on; anchors.fill: parent; z: -1; blur: 34; spread: 0; radius: parent.radius; color: Tema.acento; opacity: 0.35 }
                // Su icono (el de la app); los FPS, un «FPS» en el acento
                Rectangle {
                    x: 22; y: 22
                    width: 56; height: 56; radius: Tema.r(16)
                    color: Tema.encima
                    border.color: Tema.borde
                    Image {
                        visible: !ht.esFps
                        anchors.centerIn: parent
                        width: 36; height: 36
                        source: ht.esFps ? "" : ht.modelData.icono
                        sourceSize: Qt.size(72, 72)
                    }
                    Texto {
                        visible: ht.esFps
                        anchors.centerIn: parent
                        text: "FPS"
                        color: Tema.acento
                        font { family: Tema.mono; pixelSize: 15; weight: Font.Bold }
                    }
                }
                // Los FPS: un interruptor
                Rectangle {
                    visible: ht.esFps
                    anchors.right: parent.right; anchors.rightMargin: 22; y: 38
                    width: 50; height: 28; radius: 14
                    color: consola.fpsVisibles ? Tema.acento : Qt.rgba(1, 1, 1, 0.16)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Rectangle {
                        width: 22; height: 22; radius: 11; y: 3
                        x: consola.fpsVisibles ? parent.width - width - 3 : 3
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 140 } }
                    }
                }
                Column {
                    x: 22; y: 96
                    width: parent.width - 44
                    spacing: 4
                    Texto { width: parent.width; text: ht.modelData.nombre; font { pixelSize: 19; weight: Font.Bold } elide: Text.ElideRight; wrapMode: Text.NoWrap }
                    Texto {
                        width: parent.width
                        text: ht.modelData.hay ? ht.modelData.texto : "No está instalada"
                        color: Tema.apagado; font.pixelSize: 13
                        elide: Text.ElideRight; wrapMode: Text.NoWrap
                    }
                }
                MouseArea { id: htm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.herrHacer(ht.index) }
            }
        }
    }

    // ---------- La cinta de portadas ----------
    Rectangle {
        visible: !win.enHerr
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 370
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.45; color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.72) }
            GradientStop { position: 1; color: Tema.fondo }
        }
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 62 }
        height: 1
        color: Tema.linea
    }
    // Encima de la cinta: en Inicio, los estantes (↑ ↓); en las demás, cuántos hay. A la derecha, el orden y lo que buscas
    Row {
        visible: !win.enHerr
        anchors { left: parent.left; leftMargin: 48; bottom: cinta.top; bottomMargin: 14 }
        spacing: 10
        Rectangle { width: 4; height: 14; radius: 2; color: Tema.acento; anchors.verticalCenter: parent.verticalCenter }
        Texto {
            visible: !win.enInicio
            text: "BIBLIOTECA"
            color: Tema.apagado
            font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 2.2 }
            anchors.verticalCenter: parent.verticalCenter
        }
        Texto {
            visible: !win.enInicio
            text: win.total + (win.total === 1 ? " juego" : " juegos") + (win.installed > 0 ? " · " + win.installed + " listos" : "")
            color: Tema.tenue
            font { family: Tema.mono; pixelSize: 10 }
            anchors.verticalCenter: parent.verticalCenter
        }
        Repeater {
            model: win.enInicio ? win.estantes : []
            delegate: Rectangle {
                id: est
                required property var modelData
                required property int index
                readonly property bool on: index === win.filaOk
                anchors.verticalCenter: parent.verticalCenter
                width: el.implicitWidth + 22; height: 28; radius: Tema.r(9)
                color: on ? Tema.rosaSuave : em.containsMouse ? Tema.encima : "transparent"
                border.color: on ? Tema.acento : "transparent"
                Behavior on color { ColorAnimation { duration: 160 } }
                Row {
                    id: el
                    anchors.centerIn: parent
                    spacing: 6
                    Texto { visible: est.modelData.coleccion === true; text: "◆"; color: Tema.acento; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
                    Texto {
                        text: est.modelData.texto
                        color: est.on ? Tema.texto : Tema.apagado
                        font { pixelSize: 12; weight: est.on ? Font.Bold : Font.Medium }
                    }
                    Texto { text: est.modelData.juegos.length; color: Tema.tenue; font { family: Tema.mono; pixelSize: 10 } anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.setFila(est.index) }
            }
        }
        Texto {
            visible: win.enInicio && win.estantes.length > 1
            anchors.verticalCenter: parent.verticalCenter
            text: "↑ ↓"
            color: Tema.tenue
            font { family: Tema.mono; pixelSize: 10 }
        }
    }
    Row {
        visible: !win.enHerr
        anchors { right: parent.right; rightMargin: 48; bottom: cinta.top; bottomMargin: 14 }
        spacing: 8
        Rectangle {   // lo que buscas (F o /)
            visible: win.buscando || win.filtro !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(150, bq.implicitWidth + 44); height: 28; radius: Tema.r(9)
            color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.7)
            border.color: win.buscando ? Tema.acento : Tema.borde
            Icono { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; nombre: "buscar"; color: Tema.apagado }
            Texto {
                id: bq
                x: 30; anchors.verticalCenter: parent.verticalCenter
                text: win.filtro !== "" ? win.filtro : "Escribe…"
                color: win.filtro !== "" ? Tema.texto : Tema.tenue
                font.pixelSize: 12
            }
            Rectangle {   // el cursor
                visible: win.buscando
                x: bq.x + (win.filtro !== "" ? bq.implicitWidth : 0) + 1
                anchors.verticalCenter: parent.verticalCenter
                width: 1.5; height: 14; color: Tema.acento
                SequentialAnimation on opacity { running: win.buscando; loops: Animation.Infinite; NumberAnimation { to: 0; duration: 500 } NumberAnimation { to: 1; duration: 500 } }
            }
        }
        Rectangle {   // el orden (☰)
            anchors.verticalCenter: parent.verticalCenter
            width: ol2.implicitWidth + 22; height: 28; radius: Tema.r(9)
            color: om.containsMouse ? Tema.encima : "transparent"
            border.color: win.orden ? Tema.acento : Tema.borde
            Texto { id: ol2; anchors.centerIn: parent; text: win.btn.start + "  " + win.ordenes[win.orden][1]; color: win.orden ? Tema.texto : Tema.apagado; font { family: Tema.mono; pixelSize: 10 } }
            MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.key("start") }
        }
    }

    ListView {
        id: cinta
        visible: !win.enHerr
        opacity: win.entra
        transform: Translate { x: (1 - win.entra) * 46 }
        x: 48
        width: parent.width - 48
        height: 256
        anchors.bottom: parent.bottom; anchors.bottomMargin: 78
        orientation: ListView.Horizontal
        spacing: 14
        model: win.list
        currentIndex: win.sel
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: 0; preferredHighlightEnd: width * 0.6
        highlightMoveDuration: 220
        boundsBehavior: Flickable.StopAtBounds
        clip: false
        delegate: Item {
            id: d
            required property var modelData
            required property int index
            readonly property bool on: index === win.sel
            width: on ? 166 : 118
            height: cinta.height
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Rectangle {
                id: carta
                anchors.bottom: parent.bottom
                width: parent.width; height: width * 1.5
                scale: cartaRaton.containsMouse && !d.on ? 1.04 : 1
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                radius: Tema.r(14)
                // (detrás de las cajas de los emuladores, que no llenan la carta, un oscuro neutro)
                color: d.modelData.store === "emu" && portada.status === Image.Ready ? Tema.fondo : win.tint(d.modelData.name)
                clip: true
                opacity: d.modelData.installed || d.on ? 1 : 0.55
                border.width: 1; border.color: d.on ? Tema.acento : Tema.borde
                Image {
                    id: portada
                    anchors.fill: parent
                    source: win.despierta ? d.modelData.cover : ""
                    sourceSize: Qt.size(332, 498)
                    // (las cajas de los emuladores tienen cada una su forma: enteras, sin recortar)
                    fillMode: d.modelData.store === "emu" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    asynchronous: true
                }
                // Sin portada: el nombre sobre su color
                Texto {
                    visible: portada.status !== Image.Ready
                    anchors.fill: parent; anchors.margins: 12
                    verticalAlignment: Text.AlignBottom
                    text: d.modelData.name
                    font { pixelSize: d.on ? 16 : 13; weight: Font.ExtraBold }
                    maximumLineCount: 4; elide: Text.ElideRight
                }
                // Sin descargar: la flechita
                Rectangle {
                    visible: !d.modelData.installed
                    anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                    width: 26; height: 26; radius: 13
                    color: "#cc080a0f"
                    Texto { anchors.centerIn: parent; text: "↓"; font.pixelSize: 14; font.weight: Font.Bold }
                }
                // Una raya de luz del acento en la elegida
                Rectangle {
                    visible: d.on
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 3; color: Tema.acento
                }
                // Un brillo que sigue al ratón por la portada
                Rectangle {
                    visible: cartaRaton.containsMouse
                    width: carta.width * 1.4; height: width; radius: width / 2
                    x: cartaRaton.mouseX - width / 2; y: cartaRaton.mouseY - height / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.14) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                    }
                    rotation: -35
                }
            }
            Rectangle {
                visible: d.on
                anchors.fill: carta; anchors.margins: -5
                radius: Tema.r(18)
                color: "transparent"
                border.width: 2; border.color: Tema.acento
            }
            RectangularShadow {
                visible: d.on
                anchors.fill: carta; z: -1
                blur: 38; spread: 2; radius: Tema.r(18)
                color: Tema.acento; opacity: 0.42
            }
            MouseArea {
                id: cartaRaton
                anchors.fill: carta
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) { win.select(d.index); win.abrirFicha(); }
                    else if (d.on) win.primary();
                    else win.select(d.index);
                }
            }
        }
    }

    // ---------- Abajo: los botones del mando ----------
    Row {
        x: 48
        anchors.bottom: parent.bottom; anchors.bottomMargin: 20
        spacing: 20
        Repeater {
            model: win.enHerr ? [
                { b: [win.btn.a], t: "Abrir" },
                { b: ["←", "→", "↑", "↓"], t: "Elegir" },
                { b: [win.btn.lb, win.btn.rb], t: "Pestaña" }
            ] : [
                { b: [win.btn.a], t: win.game && !win.game.installed ? "Descargar" : "Jugar" },
                { b: [win.btn.y], t: "Ficha" },
                { b: [win.btn.x], t: "Quitar" },
                { b: [win.btn.lb, win.btn.rb], t: "Pestaña" },
                { b: [win.btn.start], t: "Orden" },
                { b: win.enInicio && win.estantes.length > 1 ? ["↑", "↓"] : ["↓"], t: win.enInicio && win.estantes.length > 1 ? "Estante" : "Navegar" }
            ]
            delegate: Row {
                required property var modelData
                spacing: 5
                Repeater {
                    model: parent.modelData.b
                    delegate: Rectangle {
                        required property string modelData
                        width: Math.max(24, bt.implicitWidth + 12); height: 24; radius: Tema.r(7)
                        color: Tema.encima; border.color: Tema.borde
                        Texto { id: bt; anchors.centerIn: parent; text: parent.modelData; font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold } }
                    }
                }
                Texto { text: parent.modelData.t; color: Tema.apagado; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Texto {
        anchors.right: parent.right; anchors.rightMargin: 48
        anchors.bottom: parent.bottom; anchors.bottomMargin: 23
        text: "Meta+Tab en un juego: Discord y la música"
        color: Tema.tenue; font { family: Tema.mono; pixelSize: 10 }
    }

    // ---------- La ficha de un juego (△ o clic derecho) ----------
    Rectangle {
        id: fichaVista
        visible: opacity > 0.01
        opacity: win.ficha ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        anchors.fill: parent
        z: 8
        color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.86)
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: win.cerrarFicha() }
        // (lo último que se abrió, para que no se vacíe mientras se va)
        property var g: ({})
        Connections { target: win; function onFichaChanged() { if (win.ficha) fichaVista.g = win.ficha } }
        Rectangle {
            id: fichaCaja
            anchors.centerIn: parent
            width: Math.min(1120, parent.width - 120)
            height: fichaColumna.implicitHeight + fichaColumna.y + 40
            radius: Tema.r(26)
            color: Tema.elevada
            border.color: Tema.borde
            clip: true
            scale: win.ficha ? 1 : 0.96
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent }
            // El arte, arriba, fundiéndose con la ficha
            Image {
                id: fichaArte
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 300
                source: fichaVista.g.hero || fichaVista.g.cover || ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 1200
            }
            Rectangle {
                anchors.fill: fichaArte
                color: fichaArte.status === Image.Ready ? "transparent" : win.tint(fichaVista.g.name || "")
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(Tema.elevada.r, Tema.elevada.g, Tema.elevada.b, 0.15) }
                    GradientStop { position: 0.7; color: Qt.rgba(Tema.elevada.r, Tema.elevada.g, Tema.elevada.b, 0.75) }
                    GradientStop { position: 1; color: Tema.elevada }
                }
            }
            Column {
                id: fichaColumna
                x: 40; y: fichaArte.status === Image.Ready ? 170 : 44
                width: parent.width - 80 - (win.fichaCol ? 352 : 0)   // (con las colecciones abiertas, a su lado)
                spacing: 18
                Column {
                    spacing: 6
                    width: parent.width
                    Texto {
                        text: (win.where(fichaVista.g) || "").toUpperCase() + (fichaVista.g.installed ? " · INSTALADO" : " · EN LA BIBLIOTECA")
                        color: Tema.acento
                        font { family: Tema.mono; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.4 }
                    }
                    Texto {
                        width: parent.width
                        text: fichaVista.g.name || ""
                        font { pixelSize: 46; weight: Font.ExtraBold; letterSpacing: -1 }
                        elide: Text.ElideRight; wrapMode: Text.NoWrap
                    }
                }
                // Lo que has jugado
                Row {
                    spacing: 12
                    Repeater {
                        model: {
                            const g = fichaVista.g, d = win.fichaDatos || {};
                            const out = [];
                            out.push({ t: "Jugado", v: win.hours(g.minutes) ? win.hours(g.minutes).replace(" jugadas", "").replace(" jugados", "") : "Nada aún" });
                            if (d.dosSemanas) out.push({ t: "Últimas 2 semanas", v: win.hours(d.dosSemanas).replace(" jugadas", "").replace(" jugados", "") });
                            if (g.last) out.push({ t: "Última vez", v: win.ago(g.last) });
                            if (g.size) out.push({ t: "Tamaño", v: win.gb(g.size) });
                            return out;
                        }
                        delegate: Rectangle {
                            id: dato
                            required property var modelData
                            width: Math.max(150, dv.implicitWidth + 36); height: 74; radius: Tema.r(16)
                            color: Tema.encima; border.color: Tema.borde
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 18; spacing: 4
                                Texto { text: dato.modelData.t.toUpperCase(); color: Tema.tenue; font { family: Tema.mono; pixelSize: 10; letterSpacing: 1.2 } }
                                Texto { id: dv; text: dato.modelData.v; font { pixelSize: 22; weight: Font.Bold } }
                            }
                        }
                    }
                }
                // Tus capturas (las de Steam)
                Column {
                    visible: (win.fichaDatos.capturas || []).length > 0
                    width: parent.width
                    spacing: 8
                    Texto { text: "TUS CAPTURAS"; color: Tema.tenue; font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.6 } }
                    Row {
                        spacing: 10
                        Repeater {
                            model: (win.fichaDatos.capturas || []).slice(0, 6)
                            delegate: Rectangle {
                                required property string modelData
                                width: 168; height: 95; radius: Tema.r(10)
                                color: Tema.encima; clip: true
                                Image { anchors.fill: parent; source: parent.modelData; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 336 }
                            }
                        }
                    }
                }
                // En tus colecciones
                Row {
                    visible: win.fichaColecciones.some(c => c.dentro)
                    spacing: 8
                    Repeater {
                        model: win.fichaColecciones.filter(c => c.dentro)
                        delegate: Rectangle {
                            required property var modelData
                            width: cn.implicitWidth + 24; height: 28; radius: Tema.r(9)
                            color: Tema.rosaSuave; border.color: Tema.acento
                            Texto { id: cn; anchors.centerIn: parent; text: "◆ " + parent.modelData.nombre; font.pixelSize: 12 }
                        }
                    }
                }
                // Lo que se puede hacer (← → y ✕)
                Flow {
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: win.fichaAcciones
                        delegate: Rectangle {
                            id: fa
                            required property var modelData
                            required property int index
                            readonly property bool on: win.fsel === index && !win.fichaCol
                            width: fl2.implicitWidth + 44; height: 52; radius: Tema.r(15)
                            color: modelData.principal ? Tema.acento : on ? Tema.pulsado : Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.5)
                            border.width: on ? 2 : 1
                            border.color: on ? (modelData.principal ? Tema.texto : Tema.acento) : Tema.borde
                            scale: on ? 1.04 : 1
                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            Texto {
                                id: fl2
                                anchors.centerIn: parent
                                text: fa.modelData.k === "fps"
                                      ? (consola.juegosFps[fichaVista.g.store + ":" + fichaVista.g.id] || 0
                                         ? consola.juegosFps[fichaVista.g.store + ":" + fichaVista.g.id] + " FPS" : "FPS como todos")
                                      : (fa.modelData.principal ? "▶  " : "") + fa.modelData.t
                                color: fa.modelData.principal ? Tema.sobreAcento : Tema.texto
                                font { pixelSize: 15; weight: fa.modelData.principal ? Font.ExtraBold : Font.Medium }
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: if (!win.fichaCol) win.fsel = fa.index
                                onClicked: { win.fsel = fa.index; win.fichaHacer(); }
                            }
                        }
                    }
                }
                Texto {
                    text: "← → elegir · " + win.btn.a + " hacer · " + win.btn.b + " volver"
                    color: Tema.tenue
                    font { family: Tema.mono; pixelSize: 10 }
                }
            }
            // Elegir colecciones (✓ las que lo tienen; las sugeridas se crean al elegirlas)
            Rectangle {
                visible: win.fichaCol
                anchors.right: parent.right; anchors.rightMargin: 32
                anchors.top: parent.top; anchors.topMargin: 32
                width: 320; height: ccCol.implicitHeight + 24
                radius: Tema.r(18)
                color: Tema.superficie
                border.color: Tema.acento
                MouseArea { anchors.fill: parent }
                Column {
                    id: ccCol
                    x: 12; y: 12
                    width: parent.width - 24
                    spacing: 2
                    Texto { leftPadding: 10; bottomPadding: 6; text: "COLECCIONES"; color: Tema.tenue; font { family: Tema.mono; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 1.6 } }
                    Repeater {
                        model: win.fichaColecciones
                        delegate: Rectangle {
                            id: cc
                            required property var modelData
                            required property int index
                            readonly property bool on: win.csel === index
                            width: ccCol.width; height: 40; radius: Tema.r(11)
                            color: on ? Tema.pulsado : ccm.containsMouse ? Tema.encima : "transparent"
                            Rectangle {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                width: 20; height: 20; radius: Tema.r(6)
                                color: cc.modelData.dentro ? Tema.acento : "transparent"
                                border.color: cc.modelData.dentro ? Tema.acento : Tema.borde
                                Texto { anchors.centerIn: parent; visible: cc.modelData.dentro; text: "✓"; color: Tema.sobreAcento; font { pixelSize: 12; weight: Font.Bold } }
                            }
                            Texto {
                                x: 42; anchors.verticalCenter: parent.verticalCenter
                                text: (cc.modelData.nueva ? "+ " : "") + cc.modelData.nombre
                                color: cc.modelData.nueva ? Tema.apagado : Tema.texto
                                font.pixelSize: 14
                            }
                            MouseArea { id: ccm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: win.csel = cc.index; onClicked: win.coleccionHacer(cc.index) }
                        }
                    }
                    Texto { leftPadding: 10; topPadding: 6; text: win.btn.a + " meter o sacar · " + win.btn.b + " listo"; color: Tema.tenue; font { family: Tema.mono; pixelSize: 10 } }
                }
            }
        }
    }

    // ---------- La cuenta atrás a Windows ----------
    Rectangle {
        visible: win.salto !== null
        anchors.fill: parent
        z: 10
        color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.82)
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: 560; height: sc.implicitHeight + 64; radius: Tema.r(24)
            color: Tema.elevada; border.color: Tema.borde
            Column {
                id: sc
                anchors.centerIn: parent
                width: parent.width - 64
                spacing: 12
                Item {
                    width: 120; height: 120
                    anchors.horizontalCenter: parent.horizontalCenter
                    Canvas {
                        id: aro
                        anchors.fill: parent
                        property real parte: win.cuenta / 10
                        onParteChanged: requestPaint()
                        onPaint: {
                            const g = getContext("2d");
                            g.reset();
                            g.lineWidth = 8; g.lineCap = "round";
                            g.strokeStyle = Tema.tinte(0.1);
                            g.beginPath(); g.arc(60, 60, 52, 0, 2 * Math.PI); g.stroke();
                            g.strokeStyle = Tema.acento;
                            g.beginPath(); g.arc(60, 60, 52, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * parte); g.stroke();
                        }
                    }
                    Texto { anchors.centerIn: parent; text: String(win.cuenta); font { pixelSize: 40; weight: Font.ExtraBold; family: Tema.mono } }
                }
                Texto {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: win.salto === "escritorio" ? "A Windows, a instalar juegos" : (win.salto ? win.salto.name : "") + " va en Windows"
                    font { pixelSize: 24; weight: Font.Bold }
                }
                Texto {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    color: Tema.apagado; font.pixelSize: 15
                    text: win.salto === "escritorio" ? "Apogeo se reinicia en Windows con su escritorio. Cuando acabes, pulsa «Volver a Apogeo»."
                                                     : "Apogeo se reinicia en Windows y lo abre. Al cerrar el juego vuelves aquí solo."
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Boton { tipo: "principal"; text: win.btn.a + "  Ya"; onClicked: win.irAWindows() }
                    Boton { text: win.btn.b + "  Cancelar"; onClicked: win.salto = null }
                }
            }
        }
    }

    // ---------- Avisos y «¿Quitar?» ----------
    Rectangle {
        visible: win.toast !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: 146
        width: tt.implicitWidth + 40; height: 42; radius: Tema.r(13)
        color: Qt.rgba(Tema.elevada.r, Tema.elevada.g, Tema.elevada.b, 0.96); border.color: Tema.borde
        Texto { id: tt; anchors.centerIn: parent; text: win.toast; font.pixelSize: 14 }
    }
    Rectangle {
        visible: win.asking
        anchors.fill: parent
        color: Qt.rgba(Tema.fondo.r, Tema.fondo.g, Tema.fondo.b, 0.84)
        MouseArea { anchors.fill: parent; onClicked: win.asking = false }
        Rectangle {
            anchors.centerIn: parent
            width: 520; height: qc.implicitHeight + 56; radius: Tema.r(24)
            color: Tema.elevada; border.color: Tema.borde
            Column {
                id: qc
                anchors.centerIn: parent
                width: parent.width - 56
                spacing: 12
                Texto { text: "¿Quitar " + (win.game ? win.game.name : "") + "?"; font { pixelSize: 22; weight: Font.Bold } width: parent.width; elide: Text.ElideRight }
                Texto {
                    width: parent.width
                    color: Tema.apagado
                    text: !win.game ? "" : win.game.store === "emu" ? "Va a la papelera: se puede recuperar."
                        : win.game.store === "ps5" ? "Solo lo convertido; tu volcado se queda en su carpeta."
                        : "Se borra del PC. Tus partidas guardadas en la nube siguen; lo puedes volver a descargar cuando quieras."
                }
                Row {
                    spacing: 10
                    Boton { tipo: "principal"; text: win.btn.a + "  Quitar"; onClicked: win.confirmRemove() }
                    Boton { text: win.btn.b + "  Cancelar"; onClicked: win.asking = false }
                }
            }
        }
    }
}
