# Apogeo: en la primera pantalla se abre el instalador a pantalla completa, dibujando directamente en la pantalla (eglfs,
# sin compositor: va en más gráficas, también en máquinas virtuales). Si la gráfica no da OpenGL, con el procesador
# (linuxfb). En las demás pantallas (Ctrl+Alt+F2…), una consola por si hay que mirar algo a mano.
if [[ "$(tty)" == /dev/tty1 ]]; then
    export XKB_DEFAULT_LAYOUT=es QT_QUICK_CONTROLS_STYLE=Basic QT_QPA_EGLFS_INTEGRATION=eglfs_kms
    export QT_QPA_EGLFS_HIDECURSOR=0 QT_QPA_FB_HIDECURSOR=0
    QT_QPA_PLATFORM=eglfs /usr/lib/apogeo-instalador/apogeo-instalador 2>/tmp/apogeo-pantalla.log ||
        QT_QPA_PLATFORM=linuxfb QT_QUICK_BACKEND=software /usr/lib/apogeo-instalador/apogeo-instalador 2>>/tmp/apogeo-pantalla.log
fi
