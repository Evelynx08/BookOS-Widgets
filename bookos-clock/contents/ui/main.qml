import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.kirigami as Kirigami
import QtQuick.Effects

PlasmoidItem {
    id: root

    // ── Reloj ────────────────────────────────────────────────────────────
    property var now: new Date()
    Timer {
        interval: Plasmoid.configuration.showSeconds ? 1000 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // ── BookOS palette ───────────────────────────────────────────────────
    readonly property bool isDarkMode: {
        var b = Kirigami.Theme.backgroundColor
        return (b.r + b.g + b.b) / 3.0 < 0.5
    }
    readonly property color bg:     isDarkMode ? Qt.color("#000000") : Qt.color("#FFFFFF")
    readonly property color card:   isDarkMode ? Qt.color("#1c1c1e") : Qt.color("#FFFFFF")
    readonly property color card2:  isDarkMode ? Qt.color("#2c2c2e") : Qt.color("#f2f2f7")
    readonly property color txt:    isDarkMode ? Qt.color("#FFFFFF") : Qt.color("#000000")
    readonly property color txt2:   Qt.color("#8e8e93")
    readonly property color divCol: isDarkMode ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.08)
    readonly property color brdCol: isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property color hovCol: isDarkMode ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.04)
    readonly property color hi:     isDarkMode ? Qt.color("#0A84FF") : Qt.color("#007AFF")
    readonly property color green:  isDarkMode ? Qt.color("#30D158") : Qt.color("#34C759")
    readonly property color red:    isDarkMode ? Qt.color("#FF453A") : Qt.color("#FF3B30")
    readonly property string resolvedFont: (Plasmoid.configuration.fontFamily && Plasmoid.configuration.fontFamily !== "")
        ? Plasmoid.configuration.fontFamily : Kirigami.Theme.defaultFont.family
    // peso del reloj compacto: 0=Normal 1=Medium 2=DemiBold 3=Bold
    function weightVal(i) { return [Font.Normal, Font.Medium, Font.DemiBold, Font.Bold][i] !== undefined
                                    ? [Font.Normal, Font.Medium, Font.DemiBold, Font.Bold][i] : Font.Bold }

    function tr(es, en) { return Qt.locale().name.indexOf("es") === 0 ? es : en }

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── Estado del calendario ────────────────────────────────────────────
    property date selDate: new Date()
    property int  viewYear:  new Date().getFullYear()
    property int  viewMonth: new Date().getMonth()   // 0-11
    property int  calMode: 0                          // 0=Days 1=Weeks 2=Years
    property bool adding: false
    property int  newType: 0                           // índice en itemTypes (form)
    property string expandedEvt: ""                    // clave del evento abierto (ver evKey)
    property bool calCollapsed: false                  // calendario plegado → Eventos a pantalla completa
    function evKey(ev) { return (ev.date||"") + "|" + (ev.time||"") + "|" + (ev.title||"") }
    function typeLabelByKey(k) {
        for (var i = 0; i < itemTypes.length; i++) if (itemTypes[i].key === k) return typeLabel(i)
        return ""
    }

    // paleta de colores para ítems (ampliada para que no se agote al exigir únicos)
    readonly property var evColors: [
        "#0A84FF", "#30D158", "#FF9F0A", "#FF453A", "#BF5AF2",
        "#64D2FF", "#FF375F", "#FFD60A", "#5E5CE6", "#66D4CF"
    ]

    // tipos de ítem: nombre, color, y comportamiento temporal
    //   start: pide hora de inicio · end: pide hora de fin ·
    //   optionalTime: la hora puede quedar vacía ("todo el día")
    readonly property var itemTypes: [
        { key: "event",    es: "Evento",       en: "Event",    color: "#0A84FF", start: true,  end: true,  optionalTime: false },
        { key: "reminder", es: "Recordatorio", en: "Reminder", color: "#FF9F0A", start: true,  end: false, optionalTime: false },
        { key: "task",     es: "Tarea",        en: "Task",     color: "#30D158", start: true,  end: false, optionalTime: true  },
        { key: "goal",     es: "Objetivo",     en: "Goal",     color: "#BF5AF2", start: false, end: false, optionalTime: true  }
    ]
    function typeLabel(i) { return tr(itemTypes[i].es, itemTypes[i].en) }

    // colores ya ocupados por otros ítems del día seleccionado (no reutilizables)
    function usedColorsForSel() {
        var used = {}
        var list = eventsForDate(root.selDate)
        for (var i = 0; i < list.length; i++) if (list[i].color) used[list[i].color.toLowerCase()] = true
        return used
    }
    // color por defecto del tipo, o el primero libre si el suyo ya está ocupado
    function defaultColorForType(t) {
        var used = usedColorsForSel()
        var dc = itemTypes[t].color
        if (!used[dc.toLowerCase()]) return dc
        for (var i = 0; i < evColors.length; i++)
            if (!used[evColors[i].toLowerCase()]) return evColors[i]
        return dc
    }

    // ── Modelo de eventos (persistido en configuración) ──────────────────
    property var events: []
    function loadEvents() {
        try { root.events = JSON.parse(Plasmoid.configuration.eventsJson || "[]") }
        catch (e) { root.events = [] }
    }
    function saveEvents() {
        Plasmoid.configuration.eventsJson = JSON.stringify(root.events)
    }
    Component.onCompleted: loadEvents()
    Connections {
        target: Plasmoid.configuration
        function onEventsJsonChanged() { root.loadEvents() }
    }

    // ── Eventos de Akonadi / Google (plugin PIM del calendario) ──────────
    // KDE expone el calendario de Google (cuenta añadida en Ajustes del sistema
    // › Cuentas en línea) a través de Akonadi; el plugin "pimevents" del
    // calendario de Plasma nos da esos eventos aquí.
    property int pimTick: 0
    PlasmaCalendar.EventPluginsManager {
        id: eventPluginsManager
        enabledPlugins: ["pimevents"]
    }
    PlasmaCalendar.Calendar {
        id: pimBackend
        days: 7; weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: root.now
        Component.onCompleted: daysModel.setPluginsManager(eventPluginsManager)
    }
    Connections {
        target: pimBackend.daysModel
        function onAgendaUpdated() { root.pimTick++ }
    }
    // mantiene el backend en el mes mostrado para que eventsForDate tenga datos
    function syncPimMonth() {
        if (pimBackend.year !== root.viewYear || (pimBackend.month - 1) !== root.viewMonth)
            pimBackend.goToYearAndMonth(root.viewYear, root.viewMonth)
    }
    onViewYearChanged: syncPimMonth()
    onViewMonthChanged: syncPimMonth()

    function pimEventsForDate(d) {
        var out = []
        try {
            var list = pimBackend.daysModel.eventsForDate(d)
            for (var i = 0; i < list.length; i++) {
                var e = list[i]
                out.push({
                    date: dateKey(d),
                    time: e.isAllDay ? "" : Qt.formatTime(e.startDateTime, "HH:mm"),
                    end:  (e.isAllDay || !e.endDateTime) ? "" : Qt.formatTime(e.endDateTime, "HH:mm"),
                    title: e.title || "",
                    color: e.eventColor && e.eventColor !== "" ? e.eventColor : "#0A84FF",
                    pim: true
                })
            }
        } catch (err) { /* plugin aún no listo */ }
        return out
    }

    function dateKey(d) { return Qt.formatDate(d, "yyyy-MM-dd") }
    function eventsForDate(d) {
        var pim = pimTick, k = dateKey(d)          // pimTick fuerza reevaluación
        var local = root.events.filter(function(e) { return e.date === k })
        return local.concat(pimEventsForDate(d))
                    .sort(function(a, b) { return (a.time || "").localeCompare(b.time || "") })
    }
    function hasEvents(d) {
        var pim = pimTick, k = dateKey(d)
        for (var i = 0; i < root.events.length; i++) if (root.events[i].date === k) return true
        return pimEventsForDate(d).length > 0
    }
    function addEvent(title, time, endTime, color, type) {
        var arr = root.events.slice()
        arr.push({ date: dateKey(root.selDate), time: time, end: endTime, title: title, color: color, type: type })
        root.events = arr; saveEvents()
    }
    // texto de hora mostrado según lo que tenga el ítem
    function timeText(ev) {
        if (ev.end && ev.end !== "") return (ev.time || "") + "–" + ev.end
        return ev.time || ""
    }
    function removeEvent(ev) {
        var arr = root.events.slice()
        for (var i = 0; i < arr.length; i++) {
            if (arr[i].date === ev.date && arr[i].time === ev.time && arr[i].title === ev.title) {
                arr.splice(i, 1); break
            }
        }
        root.events = arr; saveEvents()
    }

    // formato "8th of july 2026"
    function ordinal(n) {
        var s = ["th", "st", "nd", "rd"], v = n % 100
        return n + (s[(v - 20) % 10] || s[v] || s[0])
    }
    function longDate(d) {
        if (Qt.locale().name.indexOf("es") === 0)
            return Qt.formatDate(d, "dddd, d 'de' MMMM 'de' yyyy")
        return Qt.formatDate(d, "dddd") + ", " + ordinal(d.getDate()) + " of " +
               Qt.formatDate(d, "MMMM yyyy")
    }

    // ── SVG icons (feather) ──────────────────────────────────────────────
    function toHex(c) {
        if (!c) return "#888888"
        var s = c.toString()
        if (s.startsWith("#")) return s.length === 9 ? "#" + s.substring(3, 9) : s.substring(0, 7)
        return s
    }
    function svg(body, color, sw) {
        var c = toHex(color), w = sw || 2
        return "data:image/svg+xml," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + c +
            '" stroke-width="' + w + '" stroke-linecap="round" stroke-linejoin="round">' + body + '</svg>')
    }
    function icoChevL(c) { return svg('<polyline points="15 18 9 12 15 6"/>', c) }
    function icoChevR(c) { return svg('<polyline points="9 18 15 12 9 6"/>', c) }
    function icoChevD(c) { return svg('<polyline points="6 9 12 15 18 9"/>', c) }
    function icoPlus(c)  { return svg('<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>', c) }
    function icoTrash(c) { return svg('<polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>', c) }

    // formato de hora del reloj compacto
    function fmtTime(d) {
        var f = Plasmoid.configuration.use24h
            ? (Plasmoid.configuration.showSeconds ? "H:mm:ss" : "H:mm")
            : (Plasmoid.configuration.showSeconds ? "h:mm:ss" : "h:mm")
        return Qt.formatTime(d, f)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COMPACT — fecha + hora
    // ═══════════════════════════════════════════════════════════════════════
    compactRepresentation: MouseArea {
        id: compactRoot
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        Layout.minimumWidth: compactRow.implicitWidth + 16
        implicitWidth: compactRow.implicitWidth + 16
        implicitHeight: Kirigami.Units.iconSizes.medium

        PlasmaComponents.ToolTip { text: root.longDate(root.now) }

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: 6
            PlasmaComponents.Label {
                text: Qt.formatDate(root.now, Plasmoid.configuration.dateFormat || "d/M/yy")
                font.family: root.resolvedFont; font.weight: root.weightVal(Plasmoid.configuration.clockWeight)
                font.pixelSize: Plasmoid.configuration.fontSize || 14
                color: root.txt
            }
            PlasmaComponents.Label {
                text: root.fmtTime(root.now)
                font.family: root.resolvedFont; font.weight: root.weightVal(Plasmoid.configuration.clockWeight)
                font.pixelSize: Plasmoid.configuration.fontSize || 14
                color: root.txt
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FULL — eventos + calendario
    // ═══════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        Layout.minimumWidth: 620;  Layout.preferredWidth: 620
        Layout.minimumHeight: 340; Layout.preferredHeight: 340

        Rectangle { anchors.fill: parent; radius: 20; color: root.bg }

        property real entryOpacity: 0.0
        property real entryScale: 0.97
        Component.onCompleted: {
            entryOpacity = 1.0; entryScale = 1.0
            root.selDate = new Date()
            root.viewYear = root.selDate.getFullYear()
            root.viewMonth = root.selDate.getMonth()
        }
        opacity: entryOpacity; scale: entryScale
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // ─────────────────────────── EVENTS ───────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: root.calCollapsed
                Layout.preferredWidth: root.calCollapsed ? 120 : 250
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                radius: 18
                color: root.card2
                border.width: 1; border.color: root.brdCol

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: root.tr("Eventos", "Events")
                            font.family: root.resolvedFont; font.weight: Font.Bold
                            font.pixelSize: 18; font.letterSpacing: -0.3
                            color: root.txt; Layout.fillWidth: true
                        }
                        // plegar/expandir el calendario (Eventos a pantalla completa)
                        Rectangle {
                            Layout.preferredHeight: 26; Layout.preferredWidth: 26; radius: 8
                            color: collM.containsMouse ? root.hovCol : "transparent"
                            PlasmaComponents.ToolTip {
                                text: root.calCollapsed ? root.tr("Mostrar calendario", "Show calendar")
                                                        : root.tr("Ocultar calendario", "Hide calendar")
                            }
                            Image {
                                anchors.centerIn: parent; width: 16; height: 16
                                sourceSize: Qt.size(32, 32); smooth: true
                                source: root.calCollapsed ? root.icoChevL(root.txt2) : root.icoChevR(root.txt2)
                            }
                            MouseArea {
                                id: collM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.calCollapsed = !root.calCollapsed
                            }
                        }
                        Rectangle {
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: addRow.implicitWidth + 28
                            radius: 13
                            color: root.adding ? root.red
                                 : (addM.containsMouse ? Qt.lighter(root.green, 1.1) : root.green)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout {
                                id: addRow
                                anchors.centerIn: parent; spacing: 5
                                Image {
                                    width: 12; height: 12; sourceSize: Qt.size(24, 24); smooth: true
                                    source: root.adding
                                        ? root.svg('<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>', "#FFFFFF")
                                        : root.icoPlus("#FFFFFF")
                                }
                                PlasmaComponents.Label {
                                    id: addTxt
                                    text: root.adding ? root.tr("Cancelar", "Cancel") : root.tr("Nuevo", "Add New")
                                    font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold
                                    color: "#FFFFFF"
                                }
                            }
                            MouseArea {
                                id: addM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.adding) { newForm.fType = 0; newForm.fColor = root.defaultColorForType(0) }
                                    root.adding = !root.adding
                                }
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        text: root.longDate(root.selDate)
                        font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.Medium
                        color: root.txt2; Layout.fillWidth: true; elide: Text.ElideRight
                    }

                    // ── Formulario nuevo ítem ────────────────────────────
                    Rectangle {
                        id: newForm
                        Layout.fillWidth: true
                        radius: 14; clip: true
                        color: root.card; border.width: 1; border.color: root.brdCol
                        visible: opacity > 0.01
                        opacity: root.adding ? 1 : 0
                        Layout.preferredHeight: root.adding ? formCol.implicitHeight + 24 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        property int    fType: 0
                        property string fColor: root.itemTypes[0].color

                        ColumnLayout {
                            id: formCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 10

                            // selector de tipo
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2; rowSpacing: 6; columnSpacing: 6
                                Repeater {
                                    model: root.itemTypes.length
                                    delegate: Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: 30
                                        radius: 9
                                        property bool active: newForm.fType === index
                                        color: active ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, root.isDarkMode ? 0.20 : 0.12)
                                                      : (tM.containsMouse ? root.hovCol : root.card2)
                                        border.width: active ? 1.5 : 1
                                        border.color: active ? root.hi : root.brdCol
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        RowLayout {
                                            anchors.centerIn: parent; spacing: 6
                                            Rectangle { width: 9; height: 9; radius: 4.5; color: root.itemTypes[index].color }
                                            PlasmaComponents.Label {
                                                text: root.typeLabel(index)
                                                font.family: root.resolvedFont; font.pixelSize: 12
                                                font.weight: active ? Font.DemiBold : Font.Normal
                                                color: active ? root.txt : root.txt2
                                            }
                                        }
                                        MouseArea {
                                            id: tM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { newForm.fType = index; newForm.fColor = root.defaultColorForType(index) }
                                        }
                                    }
                                }
                            }

                            PlasmaComponents.TextField {
                                id: fTitle
                                Layout.fillWidth: true
                                placeholderText: root.tr("Título del ", "Title of ") + root.typeLabel(newForm.fType).toLowerCase()
                                font.family: root.resolvedFont; font.pixelSize: 12
                            }

                            // campos de hora según el tipo:
                            //  Evento → inicio + fin · Recordatorio → hora · Tarea → hora límite (opcional) · Objetivo → sin hora
                            RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                visible: root.itemTypes[newForm.fType].start
                                ColumnLayout {
                                    spacing: 2
                                    PlasmaComponents.Label {
                                        text: root.itemTypes[newForm.fType].end
                                                ? root.tr("Inicio", "Start")
                                                : (newForm.fType === 2 ? root.tr("Hora límite", "Due time") : root.tr("Hora", "Time"))
                                            + (root.itemTypes[newForm.fType].optionalTime ? root.tr(" (opcional)", " (optional)") : "")
                                        font.family: root.resolvedFont; font.pixelSize: 10; color: root.txt2
                                    }
                                    PlasmaComponents.TextField {
                                        id: fTime
                                        Layout.preferredWidth: 90
                                        placeholderText: "17:40"
                                        inputMask: "99:99;_"
                                        font.family: root.resolvedFont; font.pixelSize: 12
                                    }
                                }
                                ColumnLayout {
                                    spacing: 2
                                    visible: root.itemTypes[newForm.fType].end
                                    PlasmaComponents.Label {
                                        text: root.tr("Fin", "End")
                                        font.family: root.resolvedFont; font.pixelSize: 10; color: root.txt2
                                    }
                                    PlasmaComponents.TextField {
                                        id: fEnd
                                        Layout.preferredWidth: 90
                                        placeholderText: "18:40"
                                        inputMask: "99:99;_"
                                        font.family: root.resolvedFont; font.pixelSize: 12
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }

                            // paleta: colores ocupados por otros ítems del día quedan bloqueados
                            PlasmaComponents.Label {
                                text: root.tr("Color", "Color")
                                font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.Medium; color: root.txt2
                            }
                            Flow {
                                Layout.fillWidth: true; spacing: 8
                                Repeater {
                                    model: root.evColors
                                    delegate: Item {
                                        width: 24; height: 24
                                        property bool taken: {
                                            var u = root.usedColorsForSel()
                                            return u[modelData.toLowerCase()] === true && newForm.fColor.toLowerCase() !== modelData.toLowerCase()
                                        }
                                        property bool sel: newForm.fColor.toLowerCase() === modelData.toLowerCase()
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 22; height: 22; radius: 11
                                            color: modelData
                                            opacity: taken ? 0.22 : 1
                                            border.width: sel ? 3 : 0
                                            border.color: root.isDarkMode ? "#FFFFFF" : "#000000"
                                        }
                                        // candado sobre colores bloqueados
                                        Image {
                                            visible: taken
                                            anchors.centerIn: parent; width: 11; height: 11
                                            sourceSize: Qt.size(22, 22); smooth: true
                                            source: root.svg('<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>', root.txt)
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: taken ? Qt.ArrowCursor : Qt.PointingHandCursor
                                            onClicked: { if (!taken) newForm.fColor = modelData }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 34
                                radius: 10
                                color: saveM.containsMouse ? Qt.lighter(root.hi, 1.1) : root.hi
                                opacity: fTitle.text.length > 0 ? 1 : 0.4
                                PlasmaComponents.Label {
                                    anchors.centerIn: parent
                                    text: root.tr("Guardar ", "Save ") + root.typeLabel(newForm.fType).toLowerCase()
                                    font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold
                                    color: "#FFFFFF"
                                }
                                MouseArea {
                                    id: saveM; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: fTitle.text.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (fTitle.text.length === 0) return
                                        var t = root.itemTypes[newForm.fType]
                                        function clean(s) { s = s.replace(/_/g, ""); return s === ":" ? "" : s }
                                        var st = t.start ? clean(fTime.text) : ""
                                        var en = t.end   ? clean(fEnd.text)  : ""
                                        root.addEvent(fTitle.text, st, en, newForm.fColor, t.key)
                                        fTitle.text = ""; fTime.text = ""; fEnd.text = ""
                                        root.adding = false
                                    }
                                }
                            }
                        }
                    }

                    // ── Lista de eventos del día ─────────────────────────
                    ListView {
                        id: evList
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true
                        model: root.eventsForDate(root.selDate)
                        boundsBehavior: Flickable.StopAtBounds
                        spacing: 6

                        // vacío
                        PlasmaComponents.Label {
                            anchors.centerIn: parent
                            visible: evList.count === 0 && !root.adding
                            text: root.tr("Sin eventos", "No events")
                            font.family: root.resolvedFont; font.pixelSize: 12; color: root.txt2
                        }

                        delegate: Rectangle {
                            id: evDelegate
                            width: evList.width
                            property bool isOpen: root.expandedEvt === root.evKey(modelData)
                            readonly property string tt: root.timeText(modelData)
                            readonly property string typeName: root.typeLabelByKey(modelData.type)
                            implicitHeight: evCol.implicitHeight + 16
                            radius: 12
                            color: isOpen ? (root.isDarkMode ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.025)) : root.card
                            border.width: 1; border.color: isOpen ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, 0.4) : root.brdCol
                            Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 120 } }
                            clip: true

                            ColumnLayout {
                                id: evCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10; rightMargin: 8 }
                                spacing: 5

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 9
                                    Rectangle {
                                        width: 4; height: 26; radius: 2
                                        color: modelData.color || root.hi
                                    }
                                    PlasmaComponents.Label {
                                        visible: evDelegate.tt !== ""
                                        text: evDelegate.tt
                                        font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.Bold
                                        color: root.txt
                                    }
                                    PlasmaComponents.Label {
                                        visible: evDelegate.tt === ""
                                        text: root.tr("Todo el día", "All day")
                                        font.family: root.resolvedFont; font.pixelSize: 10
                                        color: root.txt2
                                    }
                                    PlasmaComponents.Label {
                                        text: modelData.title || ""
                                        font.family: root.resolvedFont; font.pixelSize: 12
                                        color: root.txt; Layout.fillWidth: true
                                        elide: evDelegate.isOpen ? Text.ElideNone : Text.ElideRight
                                        wrapMode: evDelegate.isOpen ? Text.WordWrap : Text.NoWrap
                                        maximumLineCount: evDelegate.isOpen ? 6 : 1
                                    }
                                    // eventos de Google/Akonadi: solo lectura, icono de nube
                                    Image {
                                        visible: modelData.pim === true
                                        Layout.alignment: Qt.AlignTop
                                        width: 16; height: 16; sourceSize: Qt.size(32, 32); smooth: true
                                        opacity: 0.6
                                        source: root.svg('<path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/>', root.txt2)
                                    }
                                    // eventos locales: botón borrar
                                    Rectangle {
                                        visible: modelData.pim !== true
                                        Layout.alignment: Qt.AlignTop
                                        width: 26; height: 26; radius: 8
                                        color: delM.containsMouse ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.15) : "transparent"
                                        Image {
                                            anchors.centerIn: parent; width: 14; height: 14
                                            sourceSize: Qt.size(28, 28); smooth: true
                                            source: root.icoTrash(root.red)
                                        }
                                        MouseArea {
                                            id: delM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.removeEvent(modelData)
                                        }
                                    }
                                }

                                // ── detalle al expandir: tipo + fuente ─────────
                                RowLayout {
                                    visible: evDelegate.isOpen
                                    Layout.fillWidth: true; Layout.leftMargin: 13
                                    spacing: 6
                                    Rectangle {
                                        visible: evDelegate.typeName !== ""
                                        Layout.preferredHeight: 18; Layout.preferredWidth: typeBadge.implicitWidth + 16
                                        radius: 9
                                        color: Qt.rgba((modelData.color||root.hi).r, (modelData.color||root.hi).g, (modelData.color||root.hi).b, 0.15)
                                        PlasmaComponents.Label {
                                            id: typeBadge; anchors.centerIn: parent
                                            text: evDelegate.typeName
                                            font.family: root.resolvedFont; font.pixelSize: 10; font.weight: Font.DemiBold
                                            color: modelData.color || root.hi
                                        }
                                    }
                                    PlasmaComponents.Label {
                                        text: modelData.pim ? "Google/Akonadi" : root.tr("Local", "Local")
                                        font.family: root.resolvedFont; font.pixelSize: 10
                                        color: root.txt2; Layout.fillWidth: true
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.expandedEvt = evDelegate.isOpen ? "" : root.evKey(modelData)
                            }
                        }
                    }
                }
            }

            // ────────────────────────── CALENDAR ──────────────────────────
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: !root.calCollapsed
                Layout.preferredWidth: root.calCollapsed ? 0 : 340
                visible: !root.calCollapsed
                opacity: root.calCollapsed ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
                radius: 18
                color: root.card
                border.width: 1; border.color: root.brdCol

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // ── Barra superior: tabs + Today + nav ───────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // segmented Days / Weeks / Years
                        Rectangle {
                            Layout.preferredHeight: 30
                            radius: 10
                            color: root.card2
                            implicitWidth: segRow.implicitWidth + 6
                            RowLayout {
                                id: segRow
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: [root.tr("Días", "Days"), root.tr("Semanas", "Weeks"), root.tr("Años", "Years")]
                                    delegate: Rectangle {
                                        Layout.preferredHeight: 24
                                        Layout.preferredWidth: segTxt.implicitWidth + 20
                                        radius: 8
                                        color: root.calMode === index ? root.card : "transparent"
                                        border.width: root.calMode === index ? 1 : 0
                                        border.color: root.brdCol
                                        PlasmaComponents.Label {
                                            id: segTxt; anchors.centerIn: parent
                                            text: modelData
                                            font.family: root.resolvedFont; font.pixelSize: 12
                                            font.weight: root.calMode === index ? Font.DemiBold : Font.Normal
                                            color: root.calMode === index ? root.txt : root.txt2
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.calMode = index }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Today
                        Rectangle {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: todayTxt.implicitWidth + 22
                            radius: 10
                            color: root.card2
                            PlasmaComponents.Label {
                                id: todayTxt; anchors.centerIn: parent
                                text: root.tr("Hoy", "Today")
                                font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold
                                color: root.txt
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var t = new Date()
                                    root.selDate = t; root.viewYear = t.getFullYear(); root.viewMonth = t.getMonth()
                                }
                            }
                        }

                        // nav prev/next
                        Rectangle {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 30; radius: 10
                            color: prevM.containsMouse ? root.hovCol : root.card2
                            Image { anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(32, 32); smooth: true
                                    source: root.icoChevL(root.txt) }
                            MouseArea { id: prevM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.step(-1) }
                        }
                        Rectangle {
                            Layout.preferredHeight: 30; Layout.preferredWidth: 30; radius: 10
                            color: nextM.containsMouse ? root.hovCol : root.card2
                            Image { anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(32, 32); smooth: true
                                    source: root.icoChevR(root.txt) }
                            MouseArea { id: nextM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.step(1) }
                        }
                    }

                    // ── Título del periodo ───────────────────────────────
                    PlasmaComponents.Label {
                        text: root.calMode === 2
                            ? root.viewYear
                            : Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
                        font.family: root.resolvedFont; font.weight: Font.Bold
                        font.pixelSize: 20; font.letterSpacing: -0.3; color: root.txt
                    }

                    // ── DÍAS: cuadrícula mensual ─────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        visible: root.calMode === 0
                        spacing: 4

                        // cabecera de días de la semana (lunes-domingo)
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7; columnSpacing: 2; rowSpacing: 0
                            Repeater {
                                model: [root.tr("Lun","Mon"), root.tr("Mar","Tue"), root.tr("Mié","Wed"),
                                        root.tr("Jue","Thu"), root.tr("Vie","Fri"), root.tr("Sáb","Sat"), root.tr("Dom","Sun")]
                                delegate: PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.Medium
                                    color: root.txt2
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            columns: 7; rows: 6; columnSpacing: 2; rowSpacing: 2
                            Repeater {
                                model: 42
                                delegate: Item {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    // primer día visible = lunes de la semana del día 1
                                    property date cellDate: {
                                        var first = new Date(root.viewYear, root.viewMonth, 1)
                                        var dow = (first.getDay() + 6) % 7   // 0=lunes
                                        return new Date(root.viewYear, root.viewMonth, 1 - dow + index)
                                    }
                                    property bool inMonth: cellDate.getMonth() === root.viewMonth
                                    property bool isToday: root.dateKey(cellDate) === root.dateKey(root.now)
                                    property bool isSel: root.dateKey(cellDate) === root.dateKey(root.selDate)

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) - 2
                                        height: width
                                        radius: 10
                                        color: isSel ? root.hi
                                             : (isToday ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, 0.14)
                                             : (cellM.containsMouse ? root.hovCol : "transparent"))
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        PlasmaComponents.Label {
                                            anchors.centerIn: parent
                                            text: cellDate.getDate()
                                            font.family: root.resolvedFont; font.pixelSize: 13
                                            font.weight: (isSel || isToday) ? Font.Bold : Font.Normal
                                            color: isSel ? "#FFFFFF"
                                                 : (inMonth ? (isToday ? root.hi : root.txt) : root.txt2)
                                            opacity: inMonth ? 1 : 0.45
                                        }
                                        // punto de evento
                                        Rectangle {
                                            visible: root.hasEvents(cellDate)
                                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 3 }
                                            width: 4; height: 4; radius: 2
                                            color: isSel ? "#FFFFFF" : root.hi
                                        }
                                    }
                                    MouseArea {
                                        id: cellM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selDate = cellDate
                                    }
                                }
                            }
                        }
                    }

                    // ── SEMANAS: filas de semanas del mes ────────────────
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        visible: root.calMode === 1
                        spacing: 6
                        Repeater {
                            model: 6
                            delegate: Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: 12
                                property date wkStart: {
                                    var first = new Date(root.viewYear, root.viewMonth, 1)
                                    var dow = (first.getDay() + 6) % 7
                                    return new Date(root.viewYear, root.viewMonth, 1 - dow + index * 7)
                                }
                                property date wkEnd: new Date(wkStart.getFullYear(), wkStart.getMonth(), wkStart.getDate() + 6)
                                color: wkM.containsMouse ? root.hovCol : root.card2
                                border.width: 1; border.color: root.brdCol
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                                    PlasmaComponents.Label {
                                        text: root.tr("Semana ", "Week ") + Math.ceil((wkStart.getDate() + ((new Date(wkStart.getFullYear(),0,1).getDay()+6)%7)) / 7)
                                        font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold
                                        color: root.txt; Layout.fillWidth: true
                                    }
                                    PlasmaComponents.Label {
                                        text: Qt.formatDate(wkStart, "d MMM") + " – " + Qt.formatDate(wkEnd, "d MMM")
                                        font.family: root.resolvedFont; font.pixelSize: 12
                                        color: root.txt2
                                    }
                                }
                                MouseArea { id: wkM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.selDate = wkStart; root.calMode = 0; root.viewMonth = wkStart.getMonth(); root.viewYear = wkStart.getFullYear() } }
                            }
                        }
                    }

                    // ── AÑOS: cuadrícula de meses ────────────────────────
                    GridLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        visible: root.calMode === 2
                        columns: 4; rows: 3; columnSpacing: 8; rowSpacing: 8
                        Repeater {
                            model: 12
                            delegate: Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: 12
                                property bool isCur: index === root.viewMonth
                                color: isCur ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, 0.14)
                                     : (monM.containsMouse ? root.hovCol : root.card2)
                                border.width: 1; border.color: root.brdCol
                                PlasmaComponents.Label {
                                    anchors.centerIn: parent
                                    text: Qt.formatDate(new Date(root.viewYear, index, 1), "MMM")
                                    font.family: root.resolvedFont; font.pixelSize: 13
                                    font.weight: isCur ? Font.Bold : Font.Normal
                                    color: isCur ? root.hi : root.txt
                                }
                                MouseArea { id: monM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { root.viewMonth = index; root.calMode = 0 } }
                            }
                        }
                    }
                }
            }
        }
    }

    // navegación según modo
    function step(dir) {
        if (calMode === 2) {
            viewYear += dir
        } else {
            var m = viewMonth + dir
            if (m < 0) { m = 11; viewYear -= 1 }
            else if (m > 11) { m = 0; viewYear += 1 }
            viewMonth = m
        }
    }
}
