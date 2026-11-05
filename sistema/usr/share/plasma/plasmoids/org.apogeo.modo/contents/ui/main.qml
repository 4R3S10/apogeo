import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

// El hueco de la izquierda de la barra fina de arriba. Ya no dibuja nada: la barra se reconoce por este plasmoide
// (apogeo-pisos le pone sitio, altura y ocultación al panel que lo lleva), y el modo se cambia con los atajos o desde
// la Órbita (Meta). Antes: el punto del modo y «Escritorios»/«Aplicaciones».
PlasmoidItem {
    preferredRepresentation: fullRepresentation

    fullRepresentation: Item {
        Layout.minimumWidth: 8
        Layout.preferredWidth: 8
    }
}
