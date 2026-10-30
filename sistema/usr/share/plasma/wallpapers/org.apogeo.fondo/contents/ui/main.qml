import QtQuick
import Apogeo
import QtQuick.Window
import QtMultimedia
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

// Fondo de Órbita. Cada modo pone el suyo (apogeo-pisos):
//  - los fondos animados con los colores del modo (grafito, cian, violeta o ámbar): se dibujan a un tercio de la
//    resolución y como mucho a 30 imágenes por segundo;
//  - o una imagen o un vídeo tuyo en alta calidad («Archivo»). El vídeo va en bucle, sin sonido, y se para cuando una
//    ventana maximizada o a pantalla completa lo tapa (primero la salud del equipo).
// Al cambiar de fondo, el nuevo aparece fundiéndose sobre el anterior.
WallpaperItem {
    id: root

    TaskManager.VirtualDesktopInfo { id: desktops }
    readonly property var styles: ["tinta", "humo", "seda", "marmol", "relieve", "remolino", "dunas", "luces", "orbitas", "nebulosa", "aurora"]
    // El piso en el que estás (por el nombre del escritorio) y su fondo; en la pantalla de bloqueo, el de «Estilo»/«Archivo»
    readonly property string floorName: {
        const i = desktops.desktopIds.indexOf(desktops.currentDesktop);
        const n = i >= 0 ? String(desktops.desktopNames[i] || "") : "";
        return ["Jugar", "Navegar", "Estudiar"].indexOf(n) >= 0 ? n : "";
    }
    readonly property bool porPiso: root.configuration.PorPiso && floorName !== ""
    // Los colores de este piso (Aspecto «Del fondo»: cada piso con los suyos), al momento: en Plasma, para todo
    readonly property string floorKey: (porPiso ? floorName : String(root.configuration.Piso || "")).toLowerCase()
    onFloorKeyChanged: Tema.piso = floorKey
    readonly property string estilo: porPiso ? root.configuration["Estilo" + floorName] : root.configuration.Estilo
    readonly property int kind: Math.max(0, styles.indexOf(estilo))
    readonly property string file: (porPiso ? root.configuration["Archivo" + floorName] : root.configuration.Archivo) || ""
    function videoFile(f) { return /\.(mp4|webm|mkv|mov|m4v)$/i.test(f) }
    // Sin gráfica (el dibujo lo haría el procesador) se queda quieto: primero la salud del equipo
    readonly property bool animate: root.configuration.Animar && GraphicsInfo.api !== GraphicsInfo.Software
    property real time: 40

    // ¿Hay algo maximizado o a pantalla completa en este escritorio? Entonces el fondo no se ve: ni animar ni reproducir
    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: true
        virtualDesktop: desktops.currentDesktop
        filterMinimized: true
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    property int covering: 0
    Instantiator {
        model: tasks
        delegate: QtObject {
            readonly property bool covers: !!(model.IsMaximized || model.IsFullScreen)
            onCoversChanged: root.covering += covers ? 1 : -1
            Component.onCompleted: if (covers) root.covering += 1
            Component.onDestruction: if (covers) root.covering -= 1
        }
    }
    readonly property bool seen: root.visible && covering <= 0

    Rectangle { anchors.fill: parent; color: Tema.fondo }

    // ----- El animado -----
    Item {
        id: animated
        anchors.fill: parent
        visible: root.file === "" || opacity > 0
        opacity: root.file === "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
        ShaderEffect {
            id: fx
            width: Math.max(2, Math.round(root.width / 3))
            height: Math.max(2, Math.round(root.height / 3))
            property real t: root.time
            property real kind: root.kind
            property real light: Tema.claro ? 1 : 0   // (Estudiar en papel, de día)
            property size res: Qt.size(root.width, root.height)
            property color base: Tema.fondo
            property color c1: Tema.wp[0]
            property color c2: Tema.wp[1]
            property color c3: Tema.wp[2]
            fragmentShader: Qt.resolvedUrl("../shaders/fondo.frag.qsb")
        }
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: fx
            textureSize: Qt.size(fx.width, fx.height)
            smooth: true
            live: true
            hideSource: true
        }
    }
    // 30 imágenes por segundo como mucho (lo mismo que Ágape)
    Timer {
        interval: 33
        repeat: true
        running: root.animate && root.seen && root.file === ""
        onTriggered: root.time += 0.033
    }

    // ----- Imagen tuya: una por modo, cargada una sola vez (cambiar de modo no la vuelve a leer del disco) y la del modo
    // al que llegas se funde encima de la anterior -----
    Repeater {
        model: root.porPiso ? ["Jugar", "Navegar", "Estudiar"] : [""]
        delegate: Image {
            id: foto
            required property string modelData
            readonly property string archivo: (modelData ? root.configuration["Archivo" + modelData] : root.configuration.Archivo) || ""
            readonly property bool esta: modelData === "" || modelData === root.floorName
            anchors.fill: parent
            z: esta ? 2 : 1
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
            sourceSize: Qt.size(root.width * Screen.devicePixelRatio, root.height * Screen.devicePixelRatio)
            source: archivo !== "" && !root.videoFile(archivo) ? "file://" + archivo.split("/").map(encodeURIComponent).join("/") : ""
            opacity: esta && status === Image.Ready ? 1 : 0
            // (la que se va espera a que la nueva esté encima: sin ver el fondo vacío en medio)
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation { duration: foto.esta ? 0 : 520 }
                    NumberAnimation { duration: foto.esta ? 500 : 0; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    // ----- Vídeo tuyo: en bucle y sin sonido -----
    Video {
        id: video
        anchors.fill: parent
        z: 3
        fillMode: VideoOutput.PreserveAspectCrop
        loops: MediaPlayer.Infinite
        muted: true
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
        onPlaybackStateChanged: if (playbackState === MediaPlayer.PlayingState) opacity = 1
    }

    function show() {
        if (!videoFile(root.file)) {
            video.stop(); video.source = ""; video.opacity = 0;
            return;
        }
        const url = "file://" + root.file.split("/").map(encodeURIComponent).join("/");
        if (video.source.toString() !== url) { video.opacity = 0; video.source = url; }
        if (root.seen) video.play();
    }
    onFileChanged: show()
    onSeenChanged: if (videoFile(root.file)) { if (root.seen) video.play(); else video.pause(); }
    Component.onCompleted: { Tema.piso = floorKey; show() }
}
