import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Los datos de Apogeo para los widgets (apogeo_datos.py, en apogeo-pisos, por D-Bus): pedir(«Tiempo», [], datos => …)
// devuelve el JSON ya leído. Solo para los widgets de Plasma (usa su módulo de D-Bus).
QtObject {
    function pedir(metodo, args, hecho) {
        const tipos = (args || []).map(() => "s").join("");
        DBus.SessionBus.asyncCall({
            service: "org.apogeo.Datos", path: "/Datos", iface: "org.apogeo.Datos", member: metodo,
            arguments: (args || []).map(a => new DBus.string(String(a))), signature: tipos ? "(" + tipos + ")" : ""
        }, r => {
            if (!hecho) return;
            try { hecho(r.value && r.value.value !== undefined ? JSON.parse(r.value.value) : null); } catch (e) { hecho(null); }
        }, () => { if (hecho) hecho(null); });
    }
    function hacer(metodo, args) { pedir(metodo, args, null); }
}
