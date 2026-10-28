import QtQuick
import QtQuick.Controls
import Apogeo

// Ajustes → Novedades («N3»): lo que trae cada actualización de Apogeo, con palabras normales y cómo usarlo, de la más
// nueva a la más vieja. Después de actualizar, un aviso «Ver novedades» trae aquí (apogeo-revision). Lo que se cuenta
// está en /usr/share/apogeo/novedades.json (va con cada versión).
Seccion {
    id: sec
    property string palabras: "novedades nuevo version cambios que hay de nuevo actualizacion historial"
    titulo: "Novedades"
    intro: "Lo que trae cada actualización de Apogeo y cómo se usa."

    Repeater {
        model: apogeo.news
        delegate: Column {
            id: entry
            required property var modelData
            required property int index
            width: sec.width
            spacing: 4
            topPadding: index === 0 ? 4 : 16
            Row {
                spacing: 8
                Rectangle {
                    visible: entry.index === 0
                    width: newText.implicitWidth + 14; height: 20
                    radius: Tema.r(7)
                    color: Tema.rosa
                    anchors.verticalCenter: parent.verticalCenter
                    Texto { id: newText; anchors.centerIn: parent; text: "Lo último"; color: Tema.sobreRosa; font.pixelSize: 11; font.weight: Font.Bold }
                }
                Texto {
                    text: entry.modelData.titulo
                    color: entry.index === 0 ? Tema.texto : Tema.apagado
                    font.weight: Font.Bold
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Repeater {
                model: entry.modelData.cosas
                delegate: Row {
                    id: thing
                    required property var modelData
                    width: entry.width
                    spacing: 12
                    topPadding: 6
                    Rectangle {
                        width: 32; height: 32
                        radius: Tema.r(10)
                        color: Tema.rosaSuave
                        Icono { anchors.centerIn: parent; nombre: thing.modelData.icono || "novedades"; color: Tema.rosa }
                    }
                    Column {
                        width: parent.width - 44
                        spacing: 1
                        Texto { width: parent.width; text: thing.modelData.titulo; font.weight: Font.DemiBold }
                        Texto { width: parent.width; visible: !!thing.modelData.como; text: thing.modelData.como || ""; color: Tema.apagado; font.pixelSize: 13 }
                    }
                }
            }
        }
    }
}
