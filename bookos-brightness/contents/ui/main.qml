import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.brightnesscontrolplugin as BC
import org.kde.kirigami as Kirigami
import QtQuick.Effects

PlasmoidItem {
    id: root

    // ── ESTADO ───────────────────────────────────────────────────────────
    property int  brightness:  50      // pantalla 0-100
    property bool dragging:    false
    readonly property int minPct: 1    // no apagar del todo la pantalla

    // teclado
    property int    kbd:        0       // 0-100
    property int    kbdMaxRaw:  0       // niveles del hardware (p.ej. 3 → 4 posiciones)
    property bool   kbdAvail:   false
    property bool   kbdDragging: false
    property int    brMaxRaw:   0       // niveles del backlight de pantalla

    // DBus PowerDevil (fiable, mismo que usa KDE)
    readonly property string brDB: "org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl"
    readonly property string kbDB: "org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/KeyboardBrightnessControl org.kde.Solid.PowerManagement.Actions.KeyboardBrightnessControl"

    // luz nocturna (night color / redshift)
    // nightOn = luz nocturna permitida (no inhibida). Suspender = inhibir.
    property bool   nightOn:     !BC.NightLightInhibitor.inhibited
    property bool   nightRunning: false   // tintando ahora mismo (dbus)
    property bool   nightAvail:   false   // KWin night light disponible (dbus)
    Connections {
        target: BC.NightLightInhibitor
        function onInhibitedChanged() { root.nightOn = !BC.NightLightInhibitor.inhibited }
    }

    // ── BookOS palette ───────────────────────────────────────────────────
    readonly property bool isDarkMode: {
        var b = Kirigami.Theme.backgroundColor
        return (b.r + b.g + b.b) / 3.0 < 0.5
    }
    readonly property color bg:     isDarkMode ? Qt.color("#000000") : Qt.color("#FFFFFF")
    readonly property color txt:    isDarkMode ? Qt.color("#FFFFFF") : Qt.color("#000000")
    readonly property color txt2:   Qt.color("#8e8e93")
    readonly property color trough: isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.10)
    readonly property color hi:     isDarkMode ? Qt.color("#0A84FF") : Qt.color("#007AFF")
    readonly property color orange: isDarkMode ? Qt.color("#FF9F0A") : Qt.color("#FF9500")
    readonly property color card:   isDarkMode ? Qt.color("#1c1c1e") : Qt.color("#FFFFFF")
    readonly property color brdCol: isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property string resolvedFont: Kirigami.Theme.defaultFont.family

    readonly property bool popupOpen: root.expanded

    // i18n ligero: español si el locale empieza por "es", inglés por defecto
    function tr(es, en) { return Qt.locale().name.indexOf("es") === 0 ? es : en }

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── SVG icons (feather style) ────────────────────────────────────────
    function toHex(c) {
        if (!c) return "#888888"
        var s = c.toString()
        if (s.startsWith("#")) return s.length === 9 ? "#" + s.substring(3, 9) : s.substring(0, 7)
        return s
    }
    function svg(body, color, sw) {
        var c = toHex(color)
        var w = sw || 2
        return "data:image/svg+xml," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + c +
            '" stroke-width="' + w + '" stroke-linecap="round" stroke-linejoin="round">' + body + '</svg>')
    }
    // sol con rayos; "small" = menos brillo (círculo pequeño, rayos cortos)
    // Se dibuja con margen interno (~14%) para que no llene el cuadro y combine
    // con el resto de iconos del panel.
    function icoSun(level, color) {
        var r = level === 0 ? 3.6 : 5
        var rays = '<line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/>' +
                   '<line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/>' +
                   '<line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/>' +
                   '<line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/>'
        var inner = '<circle cx="12" cy="12" r="' + r + '"/>' + (level !== 0 ? rays : "")
        var body = '<g transform="translate(2.5 2.5) scale(0.79)">' + inner + '</g>'
        return svg(body, color)
    }
    function icoKbd(color) {
        return svg('<rect x="2" y="6" width="20" height="12" rx="2"/>' +
            '<line x1="6" y1="10" x2="6" y2="10"/><line x1="10" y1="10" x2="10" y2="10"/><line x1="14" y1="10" x2="14" y2="10"/><line x1="18" y1="10" x2="18" y2="10"/>' +
            '<line x1="8" y1="14" x2="16" y2="14"/>', color)
    }
    function icoNight(color) {
        // atardecer: sol bajando tras el horizonte
        return svg('<path d="M17 18a5 5 0 0 0-10 0"/><line x1="12" y1="9" x2="12" y2="3"/>' +
            '<line x1="4.22" y1="10.22" x2="5.64" y2="11.64"/><line x1="1" y1="18" x2="3" y2="18"/>' +
            '<line x1="21" y1="18" x2="23" y2="18"/><line x1="18.36" y1="11.64" x2="19.78" y2="10.22"/>' +
            '<line x1="23" y1="22" x2="1" y2="22"/><polyline points="16 5 12 9 8 5"/>', color)
    }
    function icoSettings(color) {
        return svg('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>', color)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COMPACT
    // ═══════════════════════════════════════════════════════════════════════
    compactRepresentation: Item {
        Layout.preferredWidth:  Math.round(Kirigami.Units.iconSizes.small * 1.15)
        Layout.preferredHeight: Layout.preferredWidth
        implicitWidth:  Layout.preferredWidth
        implicitHeight: Layout.preferredHeight

        PlasmaComponents.ToolTip {
            text: root.tr("Brillo ","Brightness ") + root.brightness + "%" + (root.kbdAvail ? "\n" + root.tr("Teclado ","Keyboard ") + root.kbd + "%" : "")
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
            onWheel: (w) => {
                var step = w.angleDelta.y > 0 ? 5 : -5
                root.setBrightness(Math.max(root.minPct, Math.min(100, root.brightness + step)))
            }
            Image {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small; height: width
                sourceSize: Qt.size(width * 2, height * 2); smooth: true
                source: root.icoSun(1, root.txt)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FULL — popup
    // ═══════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        Layout.minimumWidth: 300; Layout.preferredWidth: 300; Layout.maximumWidth: 300
        Layout.minimumHeight:   popupCol.implicitHeight + 36
        Layout.preferredHeight: popupCol.implicitHeight + 36
        Layout.maximumHeight:   popupCol.implicitHeight + 36

        Rectangle { anchors.fill: parent; radius: 18; color: root.bg }

        property real entryOpacity: 0.0
        property real entryScale: 0.96
        Component.onCompleted: { entryOpacity = 1.0; entryScale = 1.0; root.refresh() }
        opacity: entryOpacity; scale: entryScale
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: popupCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
            spacing: 16

            PlasmaComponents.Label {
                text: root.tr("Brillo","Brightness")
                font.family: root.resolvedFont; font.weight: Font.Bold
                font.pixelSize: 18; font.letterSpacing: -0.3
                color: root.txt
                Layout.fillWidth: true
                Layout.bottomMargin: -2
            }

            // ── PANTALLA ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 7
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: root.tr("Pantalla","Screen"); font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.Medium; color: root.txt2; Layout.fillWidth: true }
                    PlasmaComponents.Label { text: root.brightness + "%"; font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: root.txt }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 9
                    Image { width: 15; height: 15; sourceSize: Qt.size(30,30); smooth: true; source: root.icoSun(0, root.txt2) }
                    BookPill {
                        Layout.fillWidth: true
                        value: root.brightness
                        active: !root.dragging
                        onMovedTo: (v) => { root.dragging = true; root.setBrightness(Math.max(root.minPct, v)) }
                        onReleased: root.dragging = false
                    }
                    Image { width: 18; height: 18; sourceSize: Qt.size(36,36); smooth: true; source: root.icoSun(1, root.txt) }
                }
            }

            // ── TECLADO ──────────────────────────────────────────────────
            ColumnLayout {
                visible: root.kbdAvail
                Layout.fillWidth: true; spacing: 7
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: root.tr("Teclado","Keyboard"); font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.Medium; color: root.txt2; Layout.fillWidth: true }
                    PlasmaComponents.Label { text: root.kbd + "%"; font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: root.txt }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 9
                    Image { width: 17; height: 17; sourceSize: Qt.size(34,34); smooth: true; source: root.icoKbd(root.kbd > 0 ? root.hi : root.txt2) }
                    BookPill {
                        Layout.fillWidth: true
                        value: root.kbd
                        active: !root.kbdDragging
                        onMovedTo: (v) => { root.kbdDragging = true; root.setKbd(v) }
                        onReleased: root.kbdDragging = false
                    }
                }
            }

            // ── LUZ NOCTURNA (toggle) ────────────────────────────────────
            Rectangle {
                visible: root.nightAvail
                Layout.fillWidth: true; Layout.topMargin: 2; radius: 14
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                implicitHeight: 52
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 11
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: root.nightOn ? root.orange : (root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06))
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Image {
                            anchors.centerIn: parent; width: 17; height: 17; sourceSize: Qt.size(34,34); smooth: true
                            source: root.icoNight(root.nightOn ? "#FFFFFF" : root.txt)
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        PlasmaComponents.Label { text: root.tr("Luz nocturna","Night Light"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.txt }
                        PlasmaComponents.Label {
                            text: !root.nightOn ? root.tr("Suspendida","Suspended")
                                : root.nightRunning ? root.tr("Activa · tono cálido","On · warm tone") : root.tr("Activa · según horario","On · scheduled")
                            font.family: root.resolvedFont; font.pixelSize: 11
                            color: root.nightOn ? root.orange : root.txt2
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 44; Layout.preferredHeight: 26
                        radius: 13
                        color: root.nightOn ? root.orange : (root.isDarkMode ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.16))
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 20; height: 20; radius: 10; color: "#FFFFFF"
                            y: 3; x: root.nightOn ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleNight() }
                    }
                }
            }
        }
    }

    // ── pill continuo ────────────────────────────────────────────────────
    component BookPill: Item {
        property int value: 0
        property bool active: true
        signal movedTo(int v)
        signal released
        implicitHeight: 26
        Layout.preferredHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.trough
            clip: true
            Rectangle {
                height: parent.height
                width: Math.max(0, Math.min(1, value / 100)) * parent.width
                radius: height / 2
                color: root.hi
                Behavior on width { enabled: active; NumberAnimation { duration: 120 } }
            }
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            function setFromX(mx) { movedTo(Math.round(Math.min(1, Math.max(0, mx / width)) * 100)) }
            onPressed: (m) => setFromX(m.x)
            onPositionChanged: (m) => { if (pressed) setFromX(m.x) }
            onReleased: parent.released()
            onWheel: (w) => movedTo(Math.max(0, Math.min(100, value + (w.angleDelta.y > 0 ? 5 : -5))))
        }
    }

    // ── pill con posiciones discretas (snap) y marcas ───────────────────
    component SnapPill: Item {
        id: snap
        property int steps: 3         // nº de divisiones → steps+1 posiciones
        property int level: 0         // 0..steps
        property bool active: true
        signal snappedTo(int lvl)
        signal released
        implicitHeight: 26
        Layout.preferredHeight: 26

        Rectangle {
            id: snapTrough
            anchors.fill: parent
            radius: height / 2
            color: root.trough
            clip: true
            Rectangle {
                height: parent.height
                width: Math.max(0, Math.min(1, snap.level / Math.max(1, snap.steps))) * parent.width
                radius: height / 2
                color: root.hi
                Behavior on width { enabled: snap.active; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }
        // marcas en las posiciones reales de cada nivel (1..steps)
        Repeater {
            model: snap.steps
            delegate: Rectangle {
                readonly property int lvl: index + 1
                width: 4; height: 4; radius: 2
                y: (snap.height - height) / 2
                x: 9 + (lvl / snap.steps) * (snap.width - 18) - width / 2
                color: snap.level >= lvl ? "#FFFFFF" : root.txt2
                opacity: snap.level >= lvl ? 0.9 : 0.55
            }
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            // ojo: no llamar "snap" — colisiona con el id del componente y el
            // motor QML resuelve el id antes que la función → TypeError en cada drag
            function snapTo(mx) {
                var f = Math.min(1, Math.max(0, mx / width))
                snappedTo(Math.round(f * steps))
            }
            onPressed: (m) => snapTo(m.x)
            onPositionChanged: (m) => { if (pressed) snapTo(m.x) }
            onReleased: parent.released()
            onWheel: (w) => snappedTo(Math.max(0, Math.min(steps, level + (w.angleDelta.y > 0 ? 1 : -1))))
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ACCIONES
    // ═══════════════════════════════════════════════════════════════════════
    function setBrightness(v) {
        root.brightness = v
        if (root.brMaxRaw <= 0) return
        var nv = Math.round(Math.max(1, Math.min(100, v)) / 100 * root.brMaxRaw)
        cmd.run("qdbus6 " + root.brDB + ".setBrightness " + nv)
    }
    function setKbd(pct) {
        if (!root.kbdAvail || root.kbdMaxRaw <= 0) return
        var lvl = Math.round(Math.max(0, Math.min(100, pct)) / 100 * root.kbdMaxRaw)
        root.kbd = Math.round(lvl * 100 / root.kbdMaxRaw)
        cmd.run("qdbus6 " + root.kbDB + ".setKeyboardBrightness " + lvl)
    }
    function toggleNight() {
        if (!root.nightAvail) return
        BC.NightLightInhibitor.toggleInhibition()      // inhibidor persistente de KWin
        nightTimer.restart()
    }
    function openSettings(page) {
        root.expanded = false
        cmd.run("sh -c 'echo " + page + " > /tmp/bookos-start-page; gtk-launch bookos-settings.desktop 2>/dev/null || bookos-settings'")
    }
    function refresh() { brSource.refresh(); kbdSource.refresh(); nightSource.refresh() }
    Timer { id: nightTimer; interval: 1500; onTriggered: nightSource.refresh() }

    // ═══════════════════════════════════════════════════════════════════════
    // DATA SOURCES
    // ═══════════════════════════════════════════════════════════════════════
    Plasma5Support.DataSource {
        id: brSource; engine: "executable"
        connectedSources: ["sh -c 'echo c:$(qdbus6 " + root.brDB + ".brightness 2>/dev/null); echo m:$(qdbus6 " + root.brDB + ".brightnessMax 2>/dev/null)'"]
        interval: root.popupOpen ? 2000 : 6000
        function refresh() { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) }
        onNewData: (s, data) => {
            if (!data["stdout"]) return
            var cur = -1, max = -1
            data["stdout"].trim().split('\n').forEach(function(l){
                if (l.startsWith("c:")) cur = parseInt(l.substring(2).trim())
                else if (l.startsWith("m:")) max = parseInt(l.substring(2).trim())
            })
            if (!isNaN(max) && max > 0) root.brMaxRaw = max
            if (!root.dragging && root.brMaxRaw > 0 && !isNaN(cur) && cur >= 0)
                root.brightness = Math.round(cur * 100 / root.brMaxRaw)
        }
    }

    Plasma5Support.DataSource {
        id: kbdSource; engine: "executable"
        connectedSources: ["sh -c 'echo c:$(qdbus6 " + root.kbDB + ".keyboardBrightness 2>/dev/null); echo m:$(qdbus6 " + root.kbDB + ".keyboardBrightnessMax 2>/dev/null)'"]
        interval: root.popupOpen ? 2000 : 8000
        function refresh() { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) }
        onNewData: (s, data) => {
            if (!data["stdout"]) return
            var cur = -1, max = -1
            data["stdout"].trim().split('\n').forEach(function(l){
                if (l.startsWith("c:")) cur = parseInt(l.substring(2).trim())
                else if (l.startsWith("m:")) max = parseInt(l.substring(2).trim())
            })
            root.kbdMaxRaw = (!isNaN(max) && max > 0) ? max : 0
            root.kbdAvail = root.kbdMaxRaw > 0
            if (root.kbdAvail && !root.kbdDragging && !isNaN(cur) && cur >= 0)
                root.kbd = Math.round(cur * 100 / root.kbdMaxRaw)
        }
    }

    Plasma5Support.DataSource {
        id: nightSource; engine: "executable"
        connectedSources: ["sh -c 'echo avail:$(qdbus6 org.kde.KWin /org/kde/KWin/NightLight available 2>/dev/null); " +
            "ct=$(qdbus6 org.kde.KWin /org/kde/KWin/NightLight currentTemperature 2>/dev/null); echo temp:${ct:-6500}'"]
        interval: root.popupOpen ? 4000 : 0
        function refresh() { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) }
        onNewData: (s, data) => {
            if (!data["stdout"]) return
            data["stdout"].trim().split('\n').forEach(function(l){
                if (l.startsWith("avail:")) root.nightAvail = l.substring(6).trim() === "true"
                else if (l.startsWith("temp:")) root.nightRunning = (parseInt(l.substring(5).trim()) || 6500) < 6000
            })
        }
    }

    Plasma5Support.DataSource {
        id: cmd; engine: "executable"; connectedSources: []
        onNewData: (s, data) => disconnectSource(s)
        function run(c) { connectSource(c) }
    }
}
