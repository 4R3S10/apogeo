# Apogeo: en la primera pantalla se abre el instalador a pantalla completa (cage). En las demás (Ctrl+Alt+F2…), una
# consola por si hay que mirar algo a mano.
if [[ "$(tty)" == /dev/tty1 ]]; then
    export XKB_DEFAULT_LAYOUT=es QT_QPA_PLATFORM=wayland QT_QUICK_CONTROLS_STYLE=Basic XCURSOR_THEME=Adwaita
    cage -s -- /usr/lib/apogeo-instalador/apogeo-instalador
fi
