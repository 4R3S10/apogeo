.pragma library
// Las 20 neuronas de «Entrar con neuronas» (0-19): cada una, inconfundible, por la mezcla de su tipo de dendritas
// (estrella, axón largo, puntas en Y, rizos, abanico) y de su núcleo (lleno, anillo, rombo, doble). Siempre igual
// para el mismo número. Su letra es la de la contraseña de la cuenta (las letras de tus 5 neuronas; apogeo-neuronas usa
// las mismas).
var letras = "abcdefghjkmnpqrstuvw";   // sin i, l, o

function tipo(id) { return Math.floor(id / 4) % 5 }   // las dendritas
function nucleo(id) { return id % 4 }                  // 0 lleno, 1 anillo, 2 rombo, 3 doble

function forma(id) {
    var s = id * 7919 + 17;
    function r() { s = (s * 16807) % 2147483647; return s / 2147483647; }
    function f(v) { return v.toFixed(1); }
    var d = "", t = tipo(id), giro = r() * 6.283, i, a, L;
    if (t === 0) {            // estrella: muchas ramas cortas y rectas
        var n = 7 + Math.floor(r() * 3);
        for (i = 0; i < n; i++) { a = giro + i * 6.283 / n; L = 14 + r() * 7;
            d += "M" + f(Math.cos(a) * 8) + " " + f(Math.sin(a) * 8) + " L" + f(Math.cos(a) * L) + " " + f(Math.sin(a) * L) + " "; }
    } else if (t === 1) {     // axón largo: tres ramitas cortas y una cola larga ondulada
        for (i = 0; i < 3; i++) { a = giro + Math.PI + (i - 1) * 0.8; L = 12 + r() * 5;
            d += "M" + f(Math.cos(a) * 8) + " " + f(Math.sin(a) * 8) + " L" + f(Math.cos(a) * L) + " " + f(Math.sin(a) * L) + " "; }
        var cx = Math.cos(giro), cy = Math.sin(giro), nx = -cy, ny = cx;
        d += "M" + f(cx * 8) + " " + f(cy * 8) + " C" + f(cx * 16 + nx * 8) + " " + f(cy * 16 + ny * 8) + " " + f(cx * 22 - nx * 8) + " " + f(cy * 22 - ny * 8) + " " + f(cx * 30) + " " + f(cy * 30) + " ";
        d += "M" + f(cx * 30) + " " + f(cy * 30) + " L" + f(cx * 27 + nx * 4) + " " + f(cy * 27 + ny * 4) + " M" + f(cx * 30) + " " + f(cy * 30) + " L" + f(cx * 27 - nx * 4) + " " + f(cy * 27 - ny * 4) + " ";
    } else if (t === 2) {     // puntas en Y: cuatro ramas que se abren en dos
        for (i = 0; i < 4; i++) { a = giro + i * 1.571; L = 16 + r() * 4;
            var px = Math.cos(a) * L, py = Math.sin(a) * L;
            d += "M" + f(Math.cos(a) * 8) + " " + f(Math.sin(a) * 8) + " L" + f(px) + " " + f(py) + " ";
            d += "M" + f(px) + " " + f(py) + " L" + f(px + Math.cos(a + 0.6) * 8) + " " + f(py + Math.sin(a + 0.6) * 8) + " ";
            d += "M" + f(px) + " " + f(py) + " L" + f(px + Math.cos(a - 0.6) * 8) + " " + f(py + Math.sin(a - 0.6) * 8) + " "; }
    } else if (t === 3) {     // rizos: tres ramas que acaban en espiral
        for (i = 0; i < 3; i++) { a = giro + i * 2.094; L = 18;
            var ex = Math.cos(a) * L, ey = Math.sin(a) * L, k = Math.cos(a + 1.571) * 6, m = Math.sin(a + 1.571) * 6;
            d += "M" + f(Math.cos(a) * 8) + " " + f(Math.sin(a) * 8) + " L" + f(ex) + " " + f(ey) + " ";
            d += "M" + f(ex) + " " + f(ey) + " Q" + f(ex + Math.cos(a) * 8 + k) + " " + f(ey + Math.sin(a) * 8 + m) + " " + f(ex + k * 1.2) + " " + f(ey + m * 1.2) + " ";
            d += "Q" + f(ex + k * 0.6 - Math.cos(a) * 3) + " " + f(ey + m * 0.6 - Math.sin(a) * 3) + " " + f(ex + k * 0.4) + " " + f(ey + m * 0.4) + " "; }
    } else {                  // abanico: cinco ramas curvas hacia un solo lado
        for (i = 0; i < 5; i++) { a = giro + (i - 2) * 0.42; L = 18 + (i % 2) * 8;
            var qx = Math.cos(a + 0.5) * L * 0.6, qy = Math.sin(a + 0.5) * L * 0.6;
            d += "M" + f(Math.cos(a) * 8) + " " + f(Math.sin(a) * 8) + " Q" + f(qx) + " " + f(qy) + " " + f(Math.cos(a) * L) + " " + f(Math.sin(a) * L) + " "; }
    }
    return d;
}
