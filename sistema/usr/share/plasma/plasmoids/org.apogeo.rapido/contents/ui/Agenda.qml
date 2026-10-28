import QtQuick
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import Apogeo

// La tarjeta de la hora («T2 · Tarjeta ancha» + «A1 · Tercera columna»): al pulsar la hora de la isla sale, pegada a
// ella, con el mes (los días con algo llevan un punto), el tiempo de tu ciudad (ahora, las próximas horas y 3 días) y lo
// del día elegido: tus planes de Ágape y tus recordatorios, y los temporizadores en marcha. «+ Recordatorio» y
// «Temporizador» los crean (apogeo_datos.py los guarda y, cuando toca, suena un aviso con «Posponer 10 min»).
PlasmaCore.Dialog {
    id: agenda
    // Suelta (con sus cuatro esquinas, como la isla), encima de la pastilla de la isla o debajo si la isla va arriba
    location: PlasmaCore.Types.Floating
    property Item ancla
    function place() {
        if (!ancla) return;
        const g = ancla.mapToGlobal(0, 0);
        x = Math.max(8, g.x + ancla.width - width);
        y = Tema.posicion === "arriba-dcha" ? g.y + ancla.height + 14 : g.y - height - 14;
    }
    onHeightChanged: if (visible) place()
    hideOnWindowDeactivate: true
    flags: Qt.WindowStaysOnTopHint

    // (en un Dialog solo caben Items: lo demás va en propiedades)
    readonly property Datos datos: Datos {}

    // El mes que se ve y el día elegido (AAAA-MM-DD)
    property date month: new Date()
    property string selected: hoy()
    property var marks: []
    property var weather: ({})
    property var things: []
    property var timers: []
    property real now: Date.now() / 1000
    property string form: ""          // "" · "recordatorio" · "temporizador" · "ciudad"
    property var cities: []
    property string error: ""

    function hoy() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function monthKey() { return month.getFullYear() + "-" + pad(month.getMonth() + 1) }
    function dayKey(y, m, d) { return y + "-" + pad(m + 1) + "-" + pad(d) }
    function capital(s) { return s.charAt(0).toUpperCase() + s.slice(1) }

    function loadWeather() {
        datos.pedir("Tiempo", [], d => {
            agenda.weather = d || {};
            if (!d || (d.temp === undefined && !d.sinCiudad)) agenda.weatherRetry.restart(); // (aún lo está pidiendo)
        });
    }
    function loadDay() {
        datos.pedir("Marcas", [monthKey()], d => agenda.marks = d || []);
        datos.pedir("Agenda", [selected], d => {
            agenda.things = d ? d.cosas : [];
            agenda.timers = d ? d.temporizadores : [];
        });
    }
    function open() {
        month = new Date();
        selected = hoy();
        form = "";
        error = "";
        loadWeather();
        loadDay();
        place();
        visible = true;
        requestActivate();
        body.forceActiveFocus();
    }
    onVisibleChanged: if (!visible) form = ""
    onSelectedChanged: if (visible) loadDay()
    onMonthChanged: if (visible) loadDay()

    readonly property Timer weatherRetry: Timer { interval: 1500; onTriggered: agenda.loadWeather() }
    // Mientras se ve: la cuenta atrás de los temporizadores y, cada 10 s, lo que haya cambiado
    readonly property Timer ticker: Timer {
        interval: 1000; repeat: true; running: agenda.visible
        property int n: 0
        onTriggered: {
            agenda.now = Date.now() / 1000;
            if (++n % 10 === 0) agenda.loadDay();
        }
    }

    function sky(c, day) {
        if (c === 0) return day === false ? "luna" : "sol";
        if (c <= 2) return "nubes-sol";
        if (c === 3) return "nube";
        if (c === 45 || c === 48) return "niebla";
        if (c >= 95) return "tormenta";
        if (c >= 71 && c <= 77 || c === 85 || c === 86) return "nieve";
        return "lluvia";
    }
    function skyText(c) {
        if (c === 0) return "Despejado";
        if (c <= 2) return "Poco nuboso";
        if (c === 3) return "Nublado";
        if (c === 45 || c === 48) return "Niebla";
        if (c >= 95) return "Tormenta";
        if (c >= 71 && c <= 77 || c === 85 || c === 86) return "Nieve";
        return "Lluvia";
    }
    // Lo que le queda a un temporizador: «24 min», «1 h 5 min» o, al final, los segundos
    function left(t) {
        const s = Math.max(0, Math.round(t - now));
        if (s < 60) return s + " s";
        const m = Math.ceil(s / 60);
        return m < 60 ? m + " min" : Math.floor(m / 60) + " h" + (m % 60 ? " " + m % 60 + " min" : "");
    }

    function addReminder() {
        const m = /^(\d{1,2}):(\d{2})$/.exec(hourField.text.trim());
        if (!m || +m[1] > 23 || +m[2] > 59) { error = "Escribe la hora así: 19:30"; return; }
        const hora = pad(+m[1]) + ":" + m[2];
        if (selected < hoy() || (selected === hoy() && hora <= Qt.formatTime(new Date(), "HH:mm"))) { error = "Esa hora ya ha pasado"; return; }
        datos.pedir("Recordar", [JSON.stringify({ texto: textField.text.trim(), fecha: selected, hora: hora })], () => agenda.loadDay());
        form = "";
    }
    function addTimer(minutes) {
        if (!(minutes > 0)) { error = "¿Cuántos minutos?"; return; }
        datos.pedir("Temporizador", [JSON.stringify({ minutos: minutes, texto: timerText.text.trim() })], () => agenda.loadDay());
        form = "";
    }

    mainItem: FocusScope {
        id: body
        width: 762
        height: Math.max(calendar.implicitHeight, weatherCol.implicitHeight, dayCol.implicitHeight) + 8
        Keys.onEscapePressed: { if (agenda.form) agenda.form = ""; else agenda.visible = false; }

        Row {
            y: 4
            spacing: 0

            // ---------- El mes ----------
            Column {
                id: calendar
                width: 248
                spacing: 6
                Item {
                    width: parent.width
                    height: 30
                    Texto {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 4
                        text: agenda.capital(Qt.locale("es_ES").standaloneMonthName(agenda.month.getMonth())) + (agenda.month.getFullYear() !== new Date().getFullYear() ? " " + agenda.month.getFullYear() : "")
                        font.pixelSize: 17; font.weight: Font.Bold
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Flechita { giro: 180; onClicked: agenda.month = new Date(agenda.month.getFullYear(), agenda.month.getMonth() - 1, 1) }
                        Flechita { onClicked: agenda.month = new Date(agenda.month.getFullYear(), agenda.month.getMonth() + 1, 1) }
                    }
                }
                Grid {
                    id: days
                    columns: 7
                    readonly property int first: (new Date(agenda.month.getFullYear(), agenda.month.getMonth(), 1).getDay() + 6) % 7
                    Repeater {
                        model: ["L", "M", "X", "J", "V", "S", "D"]
                        delegate: Texto {
                            required property string modelData
                            width: 35; height: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: Tema.tenue
                            font.pixelSize: 11; font.weight: Font.Bold
                        }
                    }
                    Repeater {
                        model: 42
                        delegate: AbstractButton {
                            id: cell
                            required property int index
                            readonly property date day: new Date(agenda.month.getFullYear(), agenda.month.getMonth(), index - days.first + 1)
                            readonly property bool inMonth: day.getMonth() === agenda.month.getMonth()
                            readonly property string key: agenda.dayKey(day.getFullYear(), day.getMonth(), day.getDate())
                            readonly property bool today: key === agenda.hoy()
                            readonly property bool chosen: key === agenda.selected
                            // (la sexta fila solo si hace falta)
                            visible: index < 35 || days.first + new Date(agenda.month.getFullYear(), agenda.month.getMonth() + 1, 0).getDate() > 35
                            width: 35; height: 32
                            hoverEnabled: true
                            onClicked: {
                                agenda.selected = key;
                                agenda.form = "";
                                if (!inMonth) agenda.month = new Date(day.getFullYear(), day.getMonth(), 1);
                            }
                            background: Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: Tema.r(9)
                                color: cell.today ? Tema.rosa : cell.hovered ? Tema.pulsado : "transparent"
                                border.width: cell.chosen && !cell.today ? 1.5 : 0
                                border.color: Tema.rosa
                            }
                            contentItem: Item {
                                Texto {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    text: cell.day.getDate()
                                    font.pixelSize: 13
                                    font.weight: cell.today ? Font.Black : Font.Normal
                                    color: cell.today ? Tema.sobreRosa : cell.inMonth ? Tema.texto : Tema.tenue
                                }
                                Rectangle { // tiene algo
                                    visible: cell.inMonth && agenda.marks.indexOf(cell.day.getDate()) >= 0
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: parent.height - 9
                                    width: 4; height: 4; radius: 2
                                    color: cell.today ? Tema.sobreRosa : Tema.rosa
                                }
                            }
                        }
                    }
                }
            }

            Raya {}

            // ---------- El tiempo ----------
            Column {
                id: weatherCol
                width: 206
                spacing: 8
                readonly property var w: agenda.weather
                readonly property bool has: w.temp !== undefined
                // Elegir tu ciudad (o si aún no hay ninguna)
                Column {
                    visible: agenda.form === "ciudad" || !!weatherCol.w.sinCiudad
                    width: parent.width
                    spacing: 6
                    Texto { text: "Tu ciudad"; font.weight: Font.Bold; font.pixelSize: 15 }
                    Texto { visible: agenda.form !== "ciudad"; width: parent.width; wrapMode: Text.Wrap; color: Tema.apagado; font.pixelSize: 12; text: "Escríbela para ver aquí su tiempo." }
                    Campo {
                        id: cityField
                        width: parent.width
                        implicitHeight: 36
                        font.pixelSize: 13
                        placeholderText: "Madrid, Sevilla…"
                        onTextChanged: citySearch.restart()
                        onAccepted: citySearch.triggered()
                        Timer {
                            id: citySearch
                            interval: 450
                            onTriggered: {
                                const t = cityField.text.trim();
                                if (t.length < 2) { agenda.cities = []; return; }
                                datos.pedir("BuscarCiudad", [t], d => agenda.cities = d || []);
                            }
                        }
                    }
                    Repeater {
                        model: agenda.cities
                        delegate: AbstractButton {
                            id: cityRow
                            required property var modelData
                            width: weatherCol.width
                            height: 40
                            hoverEnabled: true
                            onClicked: {
                                datos.hacer("PonerCiudad", [JSON.stringify(modelData)]);
                                agenda.weather = {};
                                agenda.cities = [];
                                cityField.text = "";
                                agenda.form = "";
                                agenda.weatherRetry.restart();
                            }
                            background: Rectangle { radius: Tema.r(10); color: cityRow.hovered ? Tema.pulsado : "transparent" }
                            contentItem: Column {
                                leftPadding: 8
                                topPadding: 3
                                Texto { text: cityRow.modelData.name; font.pixelSize: 13; font.weight: Font.Bold; width: weatherCol.width - 16; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                                Texto { text: cityRow.modelData.zona; font.pixelSize: 11; color: Tema.apagado; width: weatherCol.width - 16; elide: Text.ElideRight; wrapMode: Text.NoWrap }
                            }
                        }
                    }
                    Boton { visible: agenda.form === "ciudad"; tipo: "plano"; text: "Cancelar"; onClicked: agenda.form = "" }
                }
                Texto {
                    visible: !weatherCol.has && !weatherCol.w.sinCiudad && agenda.form !== "ciudad"
                    text: "Mirando el tiempo…"
                    color: Tema.apagado
                    topPadding: 6
                }
                // Ahora
                Item {
                    visible: weatherCol.has && agenda.form !== "ciudad"
                    width: parent.width
                    height: 54
                    Icono { id: nowIcon; width: 42; height: 42; anchors.verticalCenter: parent.verticalCenter; nombre: agenda.sky(weatherCol.w.codigo, weatherCol.w.dia); color: Tema.rosa }
                    Column {
                        x: nowIcon.width + 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x
                        Texto { text: weatherCol.w.temp + "°"; font.pixelSize: 28; font.weight: Font.Black }
                        AbstractButton {
                            id: cityName
                            width: parent.width
                            height: 18
                            hoverEnabled: true
                            onClicked: { agenda.form = "ciudad"; cityField.forceActiveFocus(); }
                            contentItem: Texto {
                                text: (weatherCol.w.ciudad || "Tu ciudad") + (cityName.hovered ? " · cambiar" : "")
                                color: cityName.hovered ? Tema.rosa : Tema.apagado
                                font.pixelSize: 12
                                elide: Text.ElideRight; wrapMode: Text.NoWrap
                            }
                        }
                    }
                }
                Texto {
                    visible: weatherCol.has && agenda.form !== "ciudad"
                    text: agenda.skyText(weatherCol.w.codigo) + " · máx " + weatherCol.w.max + "° · mín " + weatherCol.w.min + "°"
                    color: Tema.apagado
                    font.pixelSize: 12
                }
                // Las próximas horas
                Row {
                    visible: weatherCol.has && agenda.form !== "ciudad"
                    spacing: 0
                    Repeater {
                        model: (weatherCol.w.horas || []).slice(0, 5)
                        delegate: Column {
                            required property var modelData
                            width: weatherCol.width / 5
                            Texto { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t + "°"; font.pixelSize: 13; font.weight: Font.Bold }
                            Texto { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.h + "h"; font.pixelSize: 11; color: Tema.tenue }
                        }
                    }
                }
                // Los próximos días
                Column {
                    visible: weatherCol.has && agenda.form !== "ciudad"
                    width: parent.width
                    topPadding: 2
                    Repeater {
                        model: weatherCol.w.dias || []
                        delegate: Item {
                            required property var modelData
                            width: weatherCol.width
                            height: 28
                            Texto { width: 22; anchors.verticalCenter: parent.verticalCenter; text: modelData.dia; font.weight: Font.Bold; color: Tema.apagado }
                            Icono { x: 26; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; nombre: agenda.sky(modelData.codigo, true) }
                            Texto { x: 54; anchors.verticalCenter: parent.verticalCenter; text: agenda.skyText(modelData.codigo); font.pixelSize: 12; color: Tema.apagado }
                            Texto { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.max + "° / " + modelData.min + "°"; font.pixelSize: 12 }
                        }
                    }
                }
            }

            Raya {}

            // ---------- Lo del día ----------
            Column {
                id: dayCol
                width: 260
                spacing: 6
                Texto {
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    text: agenda.selected === agenda.hoy() ? "Hoy" : agenda.capital(Qt.locale("es_ES").toString(new Date(agenda.selected + "T00:00"), "dddd d"))
                    font.pixelSize: 17; font.weight: Font.Bold
                }
                // Los temporizadores en marcha
                Repeater {
                    model: agenda.timers
                    delegate: Cosa {
                        required property var modelData
                        icono: "reloj"
                        destacada: true
                        hora: agenda.left(modelData.termina)
                        texto: modelData.texto
                        quitable: true
                        onQuitar: { datos.pedir("Quitar", [modelData.id], () => agenda.loadDay()); }
                    }
                }
                Repeater {
                    model: agenda.things
                    delegate: Cosa {
                        required property var modelData
                        icono: modelData.tipo === "agape" ? "calendario" : "campana"
                        hora: modelData.hora
                        texto: modelData.texto
                        quitable: modelData.tipo === "recordatorio"
                        onQuitar: { datos.pedir("Quitar", [modelData.id], () => agenda.loadDay()); }
                    }
                }
                Texto {
                    visible: agenda.things.length === 0 && agenda.timers.length === 0 && agenda.form === ""
                    text: "Nada apuntado"
                    color: Tema.apagado
                    font.pixelSize: 13
                    bottomPadding: 4
                }

                // Nuevo recordatorio: qué y a qué hora (el día es el elegido)
                Column {
                    visible: agenda.form === "recordatorio"
                    width: parent.width
                    spacing: 6
                    topPadding: 4
                    Campo { id: textField; width: parent.width; implicitHeight: 36; font.pixelSize: 13; placeholderText: "¿Qué te recuerdo?"; onAccepted: hourField.forceActiveFocus() }
                    Row {
                        spacing: 6
                        Campo {
                            id: hourField
                            width: 76; implicitHeight: 36; font.pixelSize: 13
                            placeholderText: "19:30"
                            inputMethodHints: Qt.ImhPreferNumbers
                            onTextEdited: agenda.error = ""
                            onAccepted: agenda.addReminder()
                        }
                        Boton { tipo: "principal"; grande: false; text: "Guardar"; onClicked: agenda.addReminder() }
                        Boton { tipo: "plano"; text: "✕"; onClicked: agenda.form = "" }
                    }
                }
                // Nuevo temporizador: 5, 10, 15, 25 o los minutos que digas
                Column {
                    visible: agenda.form === "temporizador"
                    width: parent.width
                    spacing: 6
                    topPadding: 4
                    Row {
                        spacing: 6
                        Repeater {
                            model: [5, 10, 15, 25]
                            delegate: Boton {
                                required property int modelData
                                text: modelData + "′"
                                onClicked: agenda.addTimer(modelData)
                            }
                        }
                    }
                    Row {
                        spacing: 6
                        Campo {
                            id: minutesField
                            width: 76; implicitHeight: 36; font.pixelSize: 13
                            placeholderText: "Min"
                            validator: IntValidator { bottom: 1; top: 1440 }
                            onAccepted: agenda.addTimer(parseInt(text))
                        }
                        Campo { id: timerText; width: parent.parent.width - 82 - 40; implicitHeight: 36; font.pixelSize: 13; placeholderText: "Para qué (si quieres)"; onAccepted: agenda.addTimer(parseInt(minutesField.text)) }
                        Boton { tipo: "plano"; text: "✕"; onClicked: agenda.form = "" }
                    }
                }
                Texto { visible: agenda.error !== "" && agenda.form !== ""; text: agenda.error; color: Tema.rosa; font.pixelSize: 12 }

                Row {
                    visible: agenda.form === "" || agenda.form === "ciudad"
                    spacing: 6
                    topPadding: 4
                    Boton {
                        width: (dayCol.width - 6) / 2
                        icono: "mas"
                        text: "Recordatorio"
                        enabled: agenda.selected >= agenda.hoy()
                        onClicked: {
                            agenda.error = "";
                            textField.text = "";
                            const d = new Date(Date.now() + 3600 * 1000);
                            hourField.text = agenda.selected === agenda.hoy() ? agenda.pad(d.getHours()) + ":00" : "09:00";
                            agenda.form = "recordatorio";
                            textField.forceActiveFocus();
                        }
                    }
                    Boton {
                        width: (dayCol.width - 6) / 2
                        icono: "reloj"
                        text: "Temporizador"
                        onClicked: {
                            agenda.error = "";
                            minutesField.text = "";
                            timerText.text = "";
                            agenda.form = "temporizador";
                            minutesField.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    component Raya: Item {
        width: 25
        height: body.height - 8
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 1; height: parent.height; color: Tema.linea }
    }
    component Flechita: AbstractButton {
        id: fl
        property real giro: 0
        width: 28; height: 28
        hoverEnabled: true
        background: Rectangle { radius: Tema.r(9); color: fl.hovered ? Tema.pulsado : "transparent" }
        contentItem: Item { Icono { anchors.centerIn: parent; width: 14; height: 14; rotation: fl.giro; nombre: "flecha"; color: Tema.apagado } }
    }
    component Cosa: Rectangle {
        id: c
        property string icono
        property string hora
        property string texto
        property bool destacada: false
        property bool quitable: false
        signal quitar()
        width: dayCol.width
        height: 38
        radius: Tema.r(11)
        color: c.destacada ? Tema.rosaSuave : Tema.encima
        HoverHandler { id: over }
        Icono { id: ci; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; nombre: c.icono; color: c.destacada ? Tema.rosa : Tema.apagado }
        Texto {
            id: ch
            x: ci.x + ci.width + 8
            anchors.verticalCenter: parent.verticalCenter
            visible: c.hora !== ""
            text: c.hora
            font.pixelSize: 13; font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
        Texto {
            x: (ch.visible ? ch.x + ch.implicitWidth : ci.x + ci.width) + 8
            width: parent.width - x - (rm.visible ? rm.width + 6 : 10)
            anchors.verticalCenter: parent.verticalCenter
            text: c.texto
            font.pixelSize: 13
            elide: Text.ElideRight; wrapMode: Text.NoWrap
        }
        AbstractButton {
            id: rm
            visible: c.quitable && over.hovered
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 24; height: 24
            hoverEnabled: true
            onClicked: c.quitar()
            background: Rectangle { radius: Tema.r(8); color: rm.hovered ? Tema.pulsado : "transparent" }
            contentItem: Item { Icono { anchors.centerIn: parent; width: 11; height: 11; nombre: "cerrar"; color: Tema.apagado } }
        }
    }
}
