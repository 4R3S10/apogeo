// Apogeo («7 · Animaciones con vida»): las ventanas se abren con un saltito (crecen pasándose un poco y vuelven) y se
// cierran encogiéndose y desvaneciéndose. Minimizar va aparte: la lámpara mágica de KWin, hacia su icono en la isla.
// Solo las ventanas de verdad y los diálogos: nada de menús, bocadillos, la pantalla de bloqueo ni las ventanitas de
// Plasma sin barra.
"use strict";

const OPEN_MS = 340;
const CLOSE_MS = 190;
const FROM = 0.86;

function animated(w) {
    if (w.lockScreen || w.outline || w.popupWindow || !w.managed) return false;
    if (/^(ksmserver|ksplashqml|plasmashell)/.test(w.windowClass)) return w.hasDecoration;
    if (w.windowClass === "spectacle org.kde.spectacle" && w.tag === "region-editor") return false;
    return w.hasDecoration || w.normalWindow || w.dialog;
}

function forceRoles(w, on) {
    w.setData(Effect.WindowForceBackgroundContrastRole, on ? true : null);
    w.setData(Effect.WindowForceBlurRole, on ? true : null);
}

effect.animationEnded.connect(w => forceRoles(w, false));

effects.windowAdded.connect(w => {
    if (effects.hasActiveFullScreenEffect || !animated(w) || !w.visible || effect.isGrabbed(w, Effect.WindowAddedGrabRole)) return;
    forceRoles(w, true);
    w.apogeoIn = animate({
        window: w,
        duration: animationTime(OPEN_MS),
        animations: [
            { type: Effect.Scale, from: FROM, curve: QEasingCurve.OutBack },
            { type: Effect.Opacity, from: 0, curve: QEasingCurve.OutCubic }
        ]
    });
});

effects.windowClosed.connect(w => {
    if (effects.hasActiveFullScreenEffect || !animated(w) || !w.visible || w.skipsCloseAnimation
        || effect.isGrabbed(w, Effect.WindowClosedGrabRole)) return;
    if (w.apogeoIn) { cancel(w.apogeoIn); delete w.apogeoIn; }
    forceRoles(w, true);
    w.apogeoOut = animate({
        window: w,
        duration: animationTime(CLOSE_MS),
        curve: QEasingCurve.InCubic,
        animations: [
            { type: Effect.Scale, to: FROM },
            { type: Effect.Opacity, to: 0 }
        ]
    });
});

// (si otro efecto se queda la ventana, se deja la nuestra)
effects.windowDataChanged.connect((w, role) => {
    const key = role === Effect.WindowAddedGrabRole ? "apogeoIn" : role === Effect.WindowClosedGrabRole ? "apogeoOut" : "";
    if (key && w[key] && effect.isGrabbed(w, role)) {
        cancel(w[key]);
        delete w[key];
        forceRoles(w, false);
    }
});
