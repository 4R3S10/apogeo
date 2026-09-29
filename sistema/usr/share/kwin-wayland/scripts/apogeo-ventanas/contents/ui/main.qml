import QtQuick
import org.kde.kwin

// La consola del piso Jugar se abre a pantalla completa. KWin no lo aplica hasta que la ventana tiene su título y se
// ve, así que se reintenta un momento después de aparecer.
Item {
    id: root
    property var pending: []

    function added(w) {
        const cls = (w.resourceClass || "") + " " + (w.desktopFileName || "");
        if (w.normalWindow && cls.indexOf("plasmawindowed") >= 0) {
            pending.push(w);
            retry.start();
        }
    }
    function console_(w) {
        if (w.caption !== "Jugar") return false;
        w.fullScreen = true;
        return w.fullScreen;
    }
    Component.onCompleted: Workspace.windows.forEach(added)
    Connections {
        target: Workspace
        function onWindowAdded(w) { root.added(w) }
    }
    Timer {
        id: retry
        interval: 150
        repeat: true
        onTriggered: {
            root.pending = root.pending.filter(x => x && !root.console_(x));
            if (!root.pending.length) stop();
        }
    }
}
