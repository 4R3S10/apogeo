import QtQuick

// El color de una imagen (la portada de lo que suena): «vivo», el más llamativo (claro, para leerse sobre oscuro) y
// «oscuro», uno de fondo con su tono. Se mira la imagen en 12 × 12; sin imagen o en gris, los del piso.
Canvas {
    id: k
    property string fuente
    property color vivo: Tema.rosa
    property color oscuro: Tema.superficie
    property string _cargada: ""
    width: 12; height: 12
    opacity: 0   // (tiene que estar a la vista para pintar)
    onFuenteChanged: {
        if (_cargada) unloadImage(_cargada);
        _cargada = fuente;
        if (!fuente) { vivo = Tema.rosa; oscuro = Tema.superficie; return; }
        loadImage(fuente);
        if (isImageLoaded(fuente)) requestPaint();
    }
    onImageLoaded: requestPaint()
    onPaint: {
        if (!fuente || !isImageLoaded(fuente)) return;
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, 12, 12);
        ctx.drawImage(fuente, 0, 0, 12, 12);
        const d = ctx.getImageData(0, 0, 12, 12).data;
        let r = 0, g = 0, b = 0, n = 0, mejor = 0, vivo = null;
        for (let i = 0; i < d.length; i += 4) {
            const R = d[i] / 255, G = d[i + 1] / 255, B = d[i + 2] / 255;
            r += R; g += G; b += B; n++;
            const mx = Math.max(R, G, B), sat = mx ? (mx - Math.min(R, G, B)) / mx : 0;
            const nota = sat * (mx > 0.25 ? mx : mx * 0.3);
            if (nota > mejor) { mejor = nota; vivo = Qt.rgba(R, G, B, 1); }
        }
        if (!n) return;
        const medio = Qt.rgba(r / n, g / n, b / n, 1);
        const base = mejor > 0.18 ? vivo : null;
        k.vivo = base ? Qt.hsla(base.hslHue, Math.max(0.5, base.hslSaturation), Math.min(0.8, Math.max(0.66, base.hslLightness)), 1) : Tema.rosa;
        const o = base || medio;
        k.oscuro = Qt.hsla(Math.max(0, o.hslHue), Math.min(0.6, o.hslSaturation * 0.8), 0.16, 1);
    }
}
