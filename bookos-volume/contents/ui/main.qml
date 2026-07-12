import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── ESTADO ───────────────────────────────────────────────────────────
    property int  volume:     50      // 0-100 (sink)
    property bool muted:      false
    property int  micVolume:  50      // 0-100 (source)
    property bool micMuted:   false
    property bool dragging:   false

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
    readonly property string spk: '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" fill="CC"/>'
    function icoVol(v, m, color) {
        var base = spk.replace("CC", toHex(color))
        if (m || v <= 0) return svg(base + '<line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/>', color)
        if (v < 40) return svg(base, color)
        if (v < 75) return svg(base + '<path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>', color)
        return svg(base + '<path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>', color)
    }
    function icoMic(m, color) {
        var b = '<rect x="9" y="2" width="6" height="11" rx="3" fill="CC"/><path d="M19 10v1a7 7 0 0 1-14 0v-1"/><line x1="12" y1="18" x2="12" y2="22"/><line x1="8" y1="22" x2="16" y2="22"/>'
        b = b.replace("CC", m ? "none" : toHex(color))
        if (m) b += '<line x1="3" y1="3" x2="21" y2="21" stroke="' + toHex(color) + '"/>'
        return svg(b, color)
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

        PlasmaComponents.ToolTip { text: root.muted ? root.tr("Silenciado","Muted") : root.tr("Volumen ","Volume ") + root.volume + "%" }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) { root.toggleMute(); return }
                root.expanded = !root.expanded
            }
            onWheel: (w) => {
                var step = w.angleDelta.y > 0 ? 5 : -5
                root.setVolume(Math.max(0, Math.min(100, root.volume + step)))
            }
            Image {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small; height: width
                sourceSize: Qt.size(width * 2, height * 2); smooth: true
                source: root.icoVol(root.volume, root.muted, root.muted ? root.txt2 : root.txt)
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
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: -2
                PlasmaComponents.Label {
                    text: root.tr("Sonido","Sound")
                    font.family: root.resolvedFont; font.weight: Font.Bold
                    font.pixelSize: 18; font.letterSpacing: -0.3
                    color: root.txt
                    Layout.fillWidth: true
                }
                Rectangle {
                    Layout.preferredHeight: 26; Layout.preferredWidth: sndCfgTxt.implicitWidth + 22
                    radius: 13
                    color: sndCfgM.containsMouse ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, root.isDarkMode ? 0.18 : 0.12)
                                                  : (root.isDarkMode ? Qt.rgba(1,1,1,0.09) : Qt.rgba(0,0,0,0.06))
                    Behavior on color { ColorAnimation { duration: 120 } }
                    PlasmaComponents.Label {
                        id: sndCfgTxt; anchors.centerIn: parent
                        text: "Config"
                        font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold
                        color: sndCfgM.containsMouse ? root.hi : root.txt
                    }
                    MouseArea { id: sndCfgM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.expanded = false; root.openSettings("sonido") } }
                }
            }

            // ── Salida ───────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: root.tr("Altavoces","Speakers"); font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.Medium; color: root.txt2; Layout.fillWidth: true }
                    PlasmaComponents.Label { text: root.muted ? root.tr("Silenciado","Muted") : root.volume + "%"; font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.muted ? root.txt2 : root.txt }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    BookPill {
                        Layout.fillWidth: true
                        value: root.volume
                        muted: root.muted
                        onMovedTo: (v) => { root.dragging = true; root.setVolume(v) }
                        onReleased: { root.dragging = false; root.playFeedback() }
                    }
                    Rectangle {
                        Layout.preferredWidth: 38; Layout.preferredHeight: 38
                        radius: 19
                        color: root.muted ? (root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06)) : root.hi
                        Image {
                            anchors.centerIn: parent; width: 19; height: 19
                            sourceSize: Qt.size(38, 38); smooth: true
                            source: root.icoVol(root.volume, root.muted, root.muted ? root.txt2 : "#FFFFFF")
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMute() }
                    }
                }
            }

            // ── Entrada (micrófono) ──────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label { text: root.tr("Micrófono","Microphone"); font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.Medium; color: root.txt2; Layout.fillWidth: true }
                    PlasmaComponents.Label { text: root.micMuted ? root.tr("Silenciado","Muted") : root.micVolume + "%"; font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.micMuted ? root.txt2 : root.txt }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    BookPill {
                        Layout.fillWidth: true
                        value: root.micVolume
                        muted: root.micMuted
                        onMovedTo: (v) => { root.dragging = true; root.setMic(v) }
                        onReleased: root.dragging = false
                    }
                    Rectangle {
                        Layout.preferredWidth: 38; Layout.preferredHeight: 38
                        radius: 19
                        color: root.micMuted ? (root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06)) : root.hi
                        Image {
                            anchors.centerIn: parent; width: 19; height: 19
                            sourceSize: Qt.size(38, 38); smooth: true
                            source: root.icoMic(root.micMuted, root.micMuted ? root.txt2 : "#FFFFFF")
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMicMute() }
                    }
                }
            }

        }
    }

    // ── BookOS fat pill slider (One UI) ──────────────────────────────────
    component BookPill: Item {
        property int value: 0
        property bool muted: false
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
                color: muted ? root.txt2 : root.hi
                Behavior on width { enabled: !root.dragging; NumberAnimation { duration: 120 } }
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

    // ═══════════════════════════════════════════════════════════════════════
    // ACCIONES
    // ═══════════════════════════════════════════════════════════════════════
    function setVolume(v) {
        root.volume = v
        if (root.muted && v > 0) root.muted = false
        cmd.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (v/100).toFixed(2))
    }
    function toggleMute() { root.muted = !root.muted; cmd.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"); if (!root.muted) playFeedback() }
    function setMic(v) {
        root.micVolume = v
        if (root.micMuted && v > 0) root.micMuted = false
        cmd.run("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + (v/100).toFixed(2))
    }
    function toggleMicMute() { root.micMuted = !root.micMuted; cmd.run("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") }
    function playFeedback() {
        if (root.muted) return
        cmd.run("sh -c 'canberra-gtk-play -i audio-volume-change 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null'")
    }
    function openSettings(page) {
        root.expanded = false
        cmd.run("sh -c 'echo " + page + " > /tmp/bookos-start-page; gtk-launch bookos-settings.desktop 2>/dev/null || bookos-settings'")
    }
    function refresh() { sinkSource.refresh() }

    // ═══════════════════════════════════════════════════════════════════════
    // DATA SOURCES
    // ═══════════════════════════════════════════════════════════════════════
    Plasma5Support.DataSource {
        id: sinkSource; engine: "executable"
        connectedSources: ["sh -c 'echo o:$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "echo i:$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null)'"]
        interval: root.popupOpen ? 1500 : 4000
        function refresh() { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) }
        onNewData: (s, data) => {
            if (!data["stdout"] || root.dragging) return
            data["stdout"].trim().split('\n').forEach(function(l){
                var m = l.match(/^([oi]):Volume:\s+([0-9.]+)(\s+\[MUTED\])?/)
                if (!m) return
                var v = Math.round(parseFloat(m[2]) * 100)
                var muted = m[3] !== undefined
                if (m[1] === "o") { root.volume = v; root.muted = muted }
                else { root.micVolume = v; root.micMuted = muted }
            })
        }
    }

    Plasma5Support.DataSource {
        id: cmd; engine: "executable"; connectedSources: []
        onNewData: (s, data) => disconnectSource(s)
        function run(c) { connectSource(c) }
    }
}
