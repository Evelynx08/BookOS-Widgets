import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import QtQuick.Effects

PlasmoidItem {
    id: root

    // ── ESTADO ───────────────────────────────────────────────────────────
    property bool   wifiEnabled: true
    property bool   wired:       false
    property string activeSsid:  ""
    property int    activeSignal: 0
    property var    networks:    []      // [{ssid, signal, secure, active}]

    // ── BookOS palette ───────────────────────────────────────────────────
    readonly property bool isDarkMode: {
        var b = Kirigami.Theme.backgroundColor
        return (b.r + b.g + b.b) / 3.0 < 0.5
    }
    readonly property color bg:     isDarkMode ? Qt.color("#000000") : Qt.color("#FFFFFF")
    readonly property color card:   isDarkMode ? Qt.color("#1c1c1e") : Qt.color("#FFFFFF")
    readonly property color txt:    isDarkMode ? Qt.color("#FFFFFF") : Qt.color("#000000")
    readonly property color txt2:   Qt.color("#8e8e93")
    readonly property color divCol: isDarkMode ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.08)
    readonly property color brdCol: isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property color hovCol: isDarkMode ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.04)
    readonly property color hi:     isDarkMode ? Qt.color("#0A84FF") : Qt.color("#007AFF")
    readonly property string resolvedFont: Kirigami.Theme.defaultFont.family

    readonly property bool popupOpen: root.expanded
    readonly property bool connected: wired || (wifiEnabled && activeSsid !== "")

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
    function icoWifi(sig, color, disconnected) {
        var c = toHex(color)
        var dim = "0.22"
        function arc(d, on) { return '<path d="' + d + '" opacity="' + (on ? "1" : dim) + '"/>' }
        var a1 = sig >= 20, a2 = sig >= 45, a3 = sig >= 70
        var body = arc("M1.42 9a16 16 0 0 1 21.16 0", a3) +
                   arc("M5 12.55a11 11 0 0 1 14.08 0", a2) +
                   arc("M8.53 16.11a6 6 0 0 1 6.95 0", a1) +
                   '<line x1="12" y1="20" x2="12.01" y2="20"/>'
        if (disconnected) body += '<line x1="2" y1="2" x2="22" y2="22" opacity="0.9"/>'
        return svg(body, color)
    }
    function icoWired(color) {
        return svg('<rect x="3" y="13" width="18" height="8" rx="2"/>' +
            '<line x1="7" y1="13" x2="7" y2="9"/><line x1="12" y1="13" x2="12" y2="6"/><line x1="17" y1="13" x2="17" y2="9"/>' +
            '<line x1="7" y1="6" x2="17" y2="6"/>', color)
    }
    function icoLock(color) {
        return svg('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>', color)
    }
    function icoRefresh(color) { return svg('<polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>', color) }
    function icoSettings(color) {
        return svg('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>', color)
    }
    function panelSource(color) {
        if (wired) return icoWired(color)
        if (!wifiEnabled || activeSsid === "") return icoWifi(0, color, true)
        return icoWifi(activeSignal, color, false)
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
            text: root.wired ? root.tr("Red cableada conectada","Wired network connected")
                : !root.wifiEnabled ? root.tr("Wi-Fi desactivado","Wi-Fi off")
                : root.activeSsid !== "" ? root.activeSsid + " · " + root.activeSignal + "%"
                : root.tr("Sin conexión Wi-Fi","Not connected")
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) { root.toggleWifi(); return }
                root.expanded = !root.expanded
            }
            Image {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small; height: width
                sourceSize: Qt.size(width * 2, height * 2); smooth: true
                source: root.panelSource(root.connected ? root.hi : root.txt2)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FULL — popup
    // ═══════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        Layout.minimumWidth: 330; Layout.preferredWidth: 330; Layout.maximumWidth: 330
        Layout.minimumHeight:   popupCol.implicitHeight + 32
        Layout.preferredHeight: popupCol.implicitHeight + 32
        Layout.maximumHeight:   popupCol.implicitHeight + 32

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
            spacing: 14

            // ── Header con toggle Wi-Fi ──────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: "Wi-Fi"
                    font.family: root.resolvedFont; font.weight: Font.Bold
                    font.pixelSize: 18; font.letterSpacing: -0.3
                    color: root.txt
                    Layout.fillWidth: true
                }
                // Buscar (junto al toggle)
                Rectangle {
                    visible: root.wifiEnabled
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                    color: scanBtnM.containsMouse ? (root.isDarkMode ? Qt.rgba(1,1,1,0.16) : Qt.rgba(0,0,0,0.10)) : (root.isDarkMode ? Qt.rgba(1,1,1,0.09) : Qt.rgba(0,0,0,0.06))
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Image {
                        id: netScanImg
                        anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(32,32); smooth: true
                        source: root.icoRefresh(root.txt)
                        RotationAnimation on rotation { id: netSpin; from: 0; to: 360; duration: 700; running: false }
                    }
                    MouseArea { id: scanBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { netSpin.restart(); root.refresh() } }
                }
                Rectangle {
                    Layout.preferredWidth: 44; Layout.preferredHeight: 26
                    radius: 15
                    color: root.wifiEnabled ? root.hi : (root.isDarkMode ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.16))
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Rectangle {
                        width: 20; height: 20; radius: 10; color: "#FFFFFF"
                        y: 3; x: root.wifiEnabled ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleWifi() }
                }
            }

            // ── Conexión por cable ───────────────────────────────────────
            Rectangle {
                visible: root.wired
                Layout.fillWidth: true; radius: 16
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                implicitHeight: 56
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                    Rectangle {
                        width: 36; height: 36; radius: 18; color: root.hi
                        Image { anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(40,40); smooth: true; source: root.icoWired("#FFFFFF") }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        PlasmaComponents.Label { text: root.tr("Red cableada","Wired network"); font.family: root.resolvedFont; font.pixelSize: 14; font.weight: Font.Medium; color: root.txt }
                        PlasmaComponents.Label { text: root.tr("Conectado","Connected"); font.family: root.resolvedFont; font.pixelSize: 11; color: root.hi }
                    }
                }
            }

            // ── Estado vacío ─────────────────────────────────────────────
            Rectangle {
                visible: !root.wifiEnabled || (root.networks.length === 0)
                Layout.fillWidth: true; radius: 16
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                implicitHeight: 48
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                    Image { width: 20; height: 20; sourceSize: Qt.size(40,40); smooth: true; source: root.icoWifi(0, root.txt2, !root.wifiEnabled) }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: !root.wifiEnabled ? root.tr("Wi-Fi desactivado","Wi-Fi off") : root.tr("Buscando redes…","Scanning networks…")
                        font.family: root.resolvedFont; font.pixelSize: 13; color: root.txt2
                    }
                }
            }

            // ── Lista de redes ───────────────────────────────────────────
            Rectangle {
                visible: root.wifiEnabled && root.networks.length > 0
                Layout.fillWidth: true; radius: 16
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                clip: true
                implicitHeight: Math.min(netCol.implicitHeight, 300)

                Flickable {
                    anchors.fill: parent
                    contentHeight: netCol.implicitHeight
                    clip: true
                    interactive: netCol.implicitHeight > height

                    ColumnLayout {
                        id: netCol
                        width: parent.width
                        spacing: 0
                        Repeater {
                            model: root.networks
                            delegate: Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 50
                                Rectangle {
                                    anchors.fill: parent
                                    color: netMouse.containsMouse ? root.hovCol : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                Rectangle {
                                    visible: index < root.networks.length - 1 && !netMouse.containsMouse
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16 }
                                    height: 1; color: root.divCol; z: 2
                                }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                                    Image {
                                        width: 22; height: 22; sourceSize: Qt.size(44,44); smooth: true
                                        source: root.icoWifi(modelData.signal, modelData.active ? root.hi : root.txt, false)
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        PlasmaComponents.Label {
                                            text: modelData.ssid; font.family: root.resolvedFont; font.pixelSize: 14
                                            font.weight: modelData.active ? Font.DemiBold : Font.Medium
                                            color: modelData.active ? root.hi : root.txt
                                            Layout.fillWidth: true; elide: Text.ElideRight
                                        }
                                        PlasmaComponents.Label {
                                            visible: modelData.active
                                            text: root.tr("Conectado","Connected"); font.family: root.resolvedFont; font.pixelSize: 11; color: root.hi
                                        }
                                    }
                                    Image {
                                        visible: modelData.secure
                                        width: 13; height: 13; sourceSize: Qt.size(26,26); smooth: true
                                        source: root.icoLock(root.txt2)
                                    }
                                    PlasmaComponents.Label {
                                        text: modelData.signal + "%"; font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2
                                    }
                                }
                                MouseArea {
                                    id: netMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.connectNet(modelData)
                                }
                            }
                        }
                    }
                }
            }

            // ── Footer ───────────────────────────────────────────────────
            BookButton { label: root.tr("Ajustes","Settings"); iconFn: root.icoSettings; onClicked: root.openSettings("wifi") }
        }
    }

    component BookButton: Rectangle {
        id: bookBtn
        property string label: ""
        property var iconFn: null
        property bool enabled: true
        signal clicked
        readonly property bool hov: btnMouse.containsMouse
        readonly property color fg: hov ? root.hi : root.txt
        Layout.fillWidth: true; Layout.preferredHeight: 38
        radius: height / 2
        opacity: enabled ? 1.0 : 0.4
        color: hov ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, root.isDarkMode ? 0.18 : 0.12)
                   : (root.isDarkMode ? Qt.rgba(1,1,1,0.07) : Qt.rgba(0,0,0,0.05))
        border.width: 1
        border.color: hov ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, 0.40) : "transparent"
        Behavior on color { ColorAnimation { duration: 130 } }
        scale: btnMouse.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        RowLayout {
            anchors.centerIn: parent; spacing: 7
            Image {
                visible: bookBtn.iconFn !== null
                width: 15; height: 15; sourceSize: Qt.size(30,30); smooth: true
                source: bookBtn.iconFn ? bookBtn.iconFn(bookBtn.fg) : ""
            }
            PlasmaComponents.Label { text: bookBtn.label; font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: bookBtn.fg }
        }
        MouseArea {
            id: btnMouse; anchors.fill: parent; hoverEnabled: bookBtn.enabled
            cursorShape: bookBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (bookBtn.enabled) bookBtn.clicked()
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ACCIONES
    // ═══════════════════════════════════════════════════════════════════════
    function toggleWifi() {
        var target = root.wifiEnabled ? "off" : "on"
        root.wifiEnabled = !root.wifiEnabled
        if (!root.wifiEnabled) root.networks = []
        cmd.run("nmcli radio wifi " + target)
        listTimer.restart()
    }
    function connectNet(n) {
        if (n.active) return
        cmd.run("sh -c 'nmcli connection up id \"" + n.ssid.replace(/"/g,'') + "\" 2>/dev/null || nmcli device wifi connect \"" + n.ssid.replace(/"/g,'') + "\"'")
        listTimer.restart()
    }
    function openSettings(page) {
        root.expanded = false
        cmd.run("sh -c 'echo " + page + " > /tmp/bookos-start-page; gtk-launch bookos-settings.desktop 2>/dev/null || bookos-settings'")
    }
    function refresh() { stateSource.refresh(); listSource.refresh() }
    Timer { id: listTimer; interval: 2000; onTriggered: root.refresh() }

    // ═══════════════════════════════════════════════════════════════════════
    // DATA SOURCES
    // ═══════════════════════════════════════════════════════════════════════
    Plasma5Support.DataSource {
        id: stateSource; engine: "executable"
        connectedSources: ["sh -c 'echo wifi:$(nmcli -t -f WIFI radio 2>/dev/null); " +
            "echo wired:$(nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -E \"^ethernet:connected\" | head -n1 | wc -l); " +
            "echo act:$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: \"\\$2==\\\"802-11-wireless\\\"{print \\$1; exit}\")'"]
        interval: root.popupOpen ? 4000 : 8000
        function refresh() { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) }
        onNewData: (s, data) => {
            if (!data["stdout"]) return
            data["stdout"].trim().split('\n').forEach(function(l){
                if (l.startsWith("wifi:")) root.wifiEnabled = l.substring(5).trim() === "enabled"
                else if (l.startsWith("wired:")) root.wired = parseInt(l.substring(6).trim()) > 0
                else if (l.startsWith("act:")) {
                    var ss = l.substring(4).trim()
                    if (ss !== "") { root.activeSsid = ss; if (root.activeSignal <= 0) root.activeSignal = 75 }
                    else { root.activeSsid = ""; root.activeSignal = 0 }
                }
            })
        }
    }

    Plasma5Support.DataSource {
        id: listSource; engine: "executable"
        connectedSources: (root.popupOpen && root.wifiEnabled) ? [
            "sh -c 'nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null | sort -t: -k2 -rn'"
        ] : []
        interval: root.popupOpen ? 8000 : 0
        function refresh() { if (connectedSources.length) { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) } }
        onNewData: (s, data) => {
            if (!data["stdout"]) { root.networks = []; return }
            var seen = {}
            var list = []
            data["stdout"].trim().split('\n').forEach(function(l){
                var parts = l.split(':')
                if (parts.length < 4) return
                var active = parts[0].trim() === "*"
                var sig = parseInt(parts[1].trim()) || 0
                var sec = parts[2].trim()
                var ssid = parts.slice(3).join(':').trim()
                if (ssid === "" || ssid === "--") return
                if (seen[ssid]) return
                seen[ssid] = true
                list.push({ ssid: ssid, signal: sig, secure: (sec !== "" && sec !== "--"), active: active })
                if (active) { root.activeSsid = ssid; root.activeSignal = sig }
            })
            if (list.filter(function(n){ return n.active }).length === 0) { root.activeSsid = ""; root.activeSignal = 0 }
            root.networks = list
        }
    }

    Plasma5Support.DataSource {
        id: cmd; engine: "executable"; connectedSources: []
        onNewData: (s, data) => disconnectSource(s)
        function run(c) { connectSource(c) }
    }
}
