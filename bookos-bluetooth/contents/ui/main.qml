import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.bluezqt as BluezQt
import org.kde.kirigami as Kirigami
import QtQuick.Effects

PlasmoidItem {
    id: root

    // ── ESTADO (backend nativo BluezQt) ──────────────────────────────────
    readonly property bool powered: BluezQt.Manager.bluetoothOperational
    property bool scanning:   false
    property var  devices:    []   // [{dev, name, mac, connected, type, pct}]

    // reconstruye la lista desde los objetos Device nativos del Manager
    function rebuildDevices() {
        var arr = BluezQt.Manager.devices || []
        var out = []
        for (var i = 0; i < arr.length; i++) {
            var dev = arr[i]
            if (!dev) continue
            out.push({
                dev: dev,
                name: dev.name && dev.name !== "" ? dev.name : dev.address,
                mac: dev.address,
                connected: dev.connected,
                type: root.devType(dev.name || ""),
                pct: dev.battery ? dev.battery.percentage : 0
            })
        }
        out.sort(function(a, b){ return (b.connected ? 1 : 0) - (a.connected ? 1 : 0) })
        // seguimiento de "conectado desde"
        var cs = root.connSince
        out.forEach(function(d){
            if (d.connected && !cs[d.mac]) cs[d.mac] = new Date()
            else if (!d.connected && cs[d.mac]) delete cs[d.mac]
        })
        root.connSince = cs
        root.devices = out
    }
    Connections {
        target: BluezQt.Manager
        function onDeviceAdded()   { root.rebuildDevices() }
        function onDeviceRemoved() { root.rebuildDevices() }
        function onDeviceChanged()          { root.rebuildDevices() }
        function onDevicesChanged()         { root.rebuildDevices() }
        function onConnectedDevicesChanged(){ root.rebuildDevices() }
        function onBluetoothOperationalChanged() { root.rebuildDevices() }
    }
    Component.onCompleted: rebuildDevices()

    // ── Vista de detalles ────────────────────────────────────────────────
    property bool showDetails: false
    property var  connSince: ({})  // mac → Date de primera vez visto conectado
    onExpandedChanged: if (!expanded) showDetails = false
    readonly property var connectedDevs: devices.filter(function(d){ return d.connected })
    function sinceText(mac) {
        var d = connSince[mac]
        if (!d) return "—"
        var mins = Math.floor((Date.now() - d.getTime()) / 60000)
        if (mins < 1) return tr("ahora mismo","just now")
        if (mins < 60) return mins + " min"
        var h = Math.floor(mins / 60)
        return h + " h " + (mins % 60) + " min"
    }

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
    readonly property int connectedCount: devices.filter(function(d){ return d.connected }).length

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
    function icoBt(color, off) {
        var body = '<polyline points="6.5 6.5 17.5 17.5 12 23 12 1 17.5 6.5 6.5 17.5"/>'
        if (off) body += '<line x1="2" y1="2" x2="22" y2="22" opacity="0.9"/>'
        return svg(body, color)
    }
    function devType(name) {
        var n = (name || "").toLowerCase()
        if (n.includes("buds") || n.includes("airpod") || n.includes("headphone") || n.includes("headset") || n.includes("auricular") || n.includes("wh-") || n.includes("wf-")) return "headphones"
        if (n.includes("speaker") || n.includes("altavoz") || n.includes("soundbar") || n.includes("boom")) return "speaker"
        if (n.includes("mouse") || n.includes("ratón")) return "mouse"
        if (n.includes("keyboard") || n.includes("teclado")) return "keyboard"
        if (n.includes("phone") || n.includes("iphone") || n.includes("galaxy") || n.includes("pixel") || n.includes("redmi") || n.includes("xiaomi")) return "phone"
        if (n.includes("watch") || n.includes("band") || n.includes("reloj")) return "watch"
        if (n.includes("gamepad") || n.includes("controller") || n.includes("mando") || n.includes("dualsense") || n.includes("xbox")) return "gamepad"
        return "bt"
    }
    function icoDevice(type, color) {
        switch (type) {
        case "headphones": return svg('<path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3z"/><path d="M3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/>', color)
        case "speaker":    return svg('<rect x="4" y="2" width="16" height="20" rx="2"/><circle cx="12" cy="14" r="4"/><line x1="12" y1="6" x2="12.01" y2="6"/>', color)
        case "mouse":      return svg('<rect x="6" y="3" width="12" height="18" rx="6"/><line x1="12" y1="7" x2="12" y2="11"/>', color)
        case "keyboard":   return svg('<rect x="2" y="6" width="20" height="12" rx="2"/><line x1="6" y1="10" x2="6" y2="10"/><line x1="10" y1="10" x2="10" y2="10"/><line x1="14" y1="10" x2="14" y2="10"/><line x1="18" y1="10" x2="18" y2="10"/><line x1="8" y1="14" x2="16" y2="14"/>', color)
        case "phone":      return svg('<rect x="5" y="2" width="14" height="20" rx="2"/><line x1="12" y1="18" x2="12.01" y2="18"/>', color)
        case "watch":      return svg('<circle cx="12" cy="12" r="6"/><polyline points="12 10 12 12 13 13"/><path d="M16.51 17.35l-.35 3.83a2 2 0 0 1-2 1.82H9.83a2 2 0 0 1-2-1.82l-.35-3.83m.01-10.7l.35-3.83A2 2 0 0 1 9.83 1h4.35a2 2 0 0 1 2 1.82l.35 3.83"/>', color)
        case "gamepad":    return svg('<line x1="6" y1="11" x2="10" y2="11"/><line x1="8" y1="9" x2="8" y2="13"/><line x1="15" y1="12" x2="15.01" y2="12"/><line x1="18" y1="10" x2="18.01" y2="10"/><rect x="2" y="6" width="20" height="12" rx="6"/>', color)
        default:           return icoBt(color, false)
        }
    }
    function icoRefresh(color) { return svg('<polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>', color) }
    function icoSettings(color) {
        return svg('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>', color)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COMPACT
    // ═══════════════════════════════════════════════════════════════════════
    compactRepresentation: Item {
        Layout.preferredWidth:  compactRow.implicitWidth + 6
        Layout.preferredHeight: Math.round(Kirigami.Units.iconSizes.small * 1.15)
        implicitWidth:  Layout.preferredWidth
        implicitHeight: Layout.preferredHeight

        PlasmaComponents.ToolTip {
            text: !root.powered ? root.tr("Bluetooth desactivado","Bluetooth off")
                : root.connectedCount > 0 ? "Bluetooth · " + root.connectedCount + root.tr(" conectado(s)"," connected")
                : root.tr("Bluetooth activado","Bluetooth on")
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) { root.togglePower(); return }
                root.expanded = !root.expanded
            }
            RowLayout {
                id: compactRow
                anchors.centerIn: parent
                spacing: 3
                Image {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Layout.preferredWidth
                    sourceSize: Qt.size(width * 2, height * 2); smooth: true
                    source: root.icoBt(root.powered ? root.hi : root.txt2, !root.powered)
                }
                PlasmaComponents.Label {
                    visible: root.powered && root.connectedCount > 0
                    text: root.connectedCount
                    font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.Bold
                    color: root.hi
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FULL — popup
    // ═══════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        // altura según contenido, calculada aquí (no negociada con el contenedor)
        readonly property int fixedH: root.showDetails
            ? (root.connectedDevs.length > 0 ? Math.min(170 + root.connectedDevs.length * 265, 560) : 265)
            : (!root.powered || root.devices.length === 0) ? 225
            : 170 + Math.min(root.devices.length, 5) * 54 + 6
        implicitWidth: 320
        implicitHeight: fixedH
        Layout.minimumWidth: 320; Layout.preferredWidth: 320; Layout.maximumWidth: 320
        Layout.minimumHeight: fixedH
        Layout.preferredHeight: fixedH
        Layout.maximumHeight: fixedH

        Rectangle { anchors.fill: parent; radius: 18; color: root.bg }

        property real entryOpacity: 0.0
        property real entryScale: 0.96
        Component.onCompleted: { entryOpacity = 1.0; entryScale = 1.0; root.rebuildDevices() }
        opacity: entryOpacity; scale: entryScale
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: popupCol
            anchors { fill: parent; margins: 16 }
            spacing: 14

            // ── Header con toggle ────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: "Bluetooth"
                    font.family: root.resolvedFont; font.weight: Font.Bold
                    font.pixelSize: 18; font.letterSpacing: -0.3
                    color: root.txt
                    Layout.fillWidth: true
                }
                // Buscar (junto al toggle)
                Rectangle {
                    visible: root.powered
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
                    color: scanBtnM.containsMouse ? (root.isDarkMode ? Qt.rgba(1,1,1,0.16) : Qt.rgba(0,0,0,0.10)) : (root.isDarkMode ? Qt.rgba(1,1,1,0.09) : Qt.rgba(0,0,0,0.06))
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Image {
                        anchors.centerIn: parent; width: 16; height: 16; sourceSize: Qt.size(32,32); smooth: true
                        source: root.icoRefresh(root.txt)
                        RotationAnimator on rotation { running: root.scanning; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    }
                    MouseArea { id: scanBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.scan() }
                }
                Rectangle {
                    Layout.preferredWidth: 44; Layout.preferredHeight: 26
                    radius: 15
                    color: root.powered ? root.hi : (root.isDarkMode ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.16))
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Rectangle {
                        width: 20; height: 20; radius: 10; color: "#FFFFFF"
                        y: 3; x: root.powered ? parent.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePower() }
                }
            }

            // ── Estado / vacío ───────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 16
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                implicitHeight: 48
                visible: !root.showDetails && (!root.powered || root.devices.length === 0)
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                    Image { Layout.preferredWidth: 15; Layout.preferredHeight: 15; sourceSize: Qt.size(30,30); smooth: true; source: root.icoBt(root.txt2, !root.powered) }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: !root.powered ? root.tr("Bluetooth desactivado","Bluetooth off")
                            : root.scanning ? root.tr("Buscando dispositivos…","Scanning devices…") : root.tr("Sin dispositivos","No devices")
                        font.family: root.resolvedFont; font.pixelSize: 13; color: root.txt2
                    }
                }
            }

            // ── Vista de detalles (dispositivos conectados) ──────────────
            Repeater {
                model: root.showDetails ? root.connectedDevs : []
                delegate: Rectangle {
                    Layout.fillWidth: true; radius: 16
                    color: root.card; border.width: 1; border.color: root.brdCol
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                    implicitHeight: btDetCol.implicitHeight + 24
                    ColumnLayout {
                        id: btDetCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Rectangle {
                                width: 36; height: 36; radius: 18; color: root.hi
                                Image { anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(40,40); smooth: true; source: root.icoDevice(modelData.type, "#FFFFFF") }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                PlasmaComponents.Label { text: modelData.name; font.family: root.resolvedFont; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.hi; Layout.fillWidth: true; elide: Text.ElideRight }
                                PlasmaComponents.Label { text: root.tr("Conectado","Connected"); font.family: root.resolvedFont; font.pixelSize: 11; color: root.hi }
                            }
                            PlasmaComponents.Label { visible: modelData.pct > 0; text: modelData.pct + "%"; font.family: root.resolvedFont; font.pixelSize: 12; color: root.txt2 }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.divCol }
                        Repeater {
                            model: [
                                { l: "MAC",                                        v: modelData.mac },
                                { l: root.tr("Batería","Battery"),                 v: modelData.pct > 0 ? modelData.pct + "%" : "—" },
                                { l: root.tr("Tipo","Type"),                       v: modelData.type },
                                { l: root.tr("Conectado desde hace","Connected for"), v: root.sinceText(modelData.mac) }
                            ]
                            delegate: RowLayout {
                                Layout.fillWidth: true; spacing: 8
                                PlasmaComponents.Label { text: modelData.l; font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2; Layout.preferredWidth: 120 }
                                PlasmaComponents.Label { text: modelData.v; font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.Medium; color: root.txt; Layout.fillWidth: true; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignRight }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.divCol }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 17
                            readonly property color red: root.isDarkMode ? "#FF453A" : "#FF3B30"
                            color: btDiscM.containsMouse ? Qt.rgba(red.r, red.g, red.b, 0.16) : "transparent"
                            border.width: 1; border.color: Qt.rgba(red.r, red.g, red.b, 0.4)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            PlasmaComponents.Label { anchors.centerIn: parent; text: root.tr("Desconectar","Disconnect"); font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: parent.red }
                            MouseArea { id: btDiscM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.toggleDevice(modelData); root.showDetails = false } }
                        }
                    }
                }
            }
            Rectangle {
                visible: root.showDetails && root.connectedDevs.length === 0
                Layout.fillWidth: true; radius: 16; implicitHeight: 48
                color: root.card; border.width: 1; border.color: root.brdCol
                PlasmaComponents.Label { anchors.centerIn: parent; text: root.tr("Nada conectado","Nothing connected"); font.family: root.resolvedFont; font.pixelSize: 13; color: root.txt2 }
            }

            // ── Lista de dispositivos ────────────────────────────────────
            Rectangle {
                visible: !root.showDetails && root.powered && root.devices.length > 0
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 16
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                clip: true

                Flickable {
                    anchors.fill: parent
                    contentHeight: devCol.implicitHeight
                    clip: true
                    interactive: devCol.implicitHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: devCol
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: root.devices
                        delegate: Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 54
                            Rectangle {
                                visible: !modelData.connected
                                anchors.fill: parent
                                color: devMouse.containsMouse ? root.hovCol : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            // tarjeta con borde azul para el dispositivo conectado (mockup)
                            Rectangle {
                                visible: modelData.connected
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 5; bottomMargin: 5 }
                                radius: 12
                                color: Qt.rgba(root.hi.r, root.hi.g, root.hi.b, root.isDarkMode ? 0.10 : 0.05)
                                border.width: 1.5; border.color: root.hi
                            }
                            Rectangle {
                                visible: index < root.devices.length - 1 && !devMouse.containsMouse && !modelData.connected
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16 }
                                height: 1; color: root.divCol; z: 2
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 18; spacing: 11
                                Rectangle {
                                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                                    color: modelData.connected ? root.hi : (root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06))
                                    Image {
                                        anchors.centerIn: parent; width: 16; height: 16
                                        sourceSize: Qt.size(32,32); smooth: true
                                        source: root.icoDevice(modelData.type, modelData.connected ? "#FFFFFF" : root.txt)
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    PlasmaComponents.Label {
                                        text: modelData.name; font.family: root.resolvedFont; font.pixelSize: 13
                                        font.weight: modelData.connected ? Font.DemiBold : Font.Medium
                                        color: modelData.connected ? root.hi : root.txt
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    PlasmaComponents.Label {
                                        text: modelData.connected ? root.tr("Conectado","Connected") : root.tr("Emparejado","Paired")
                                        font.family: root.resolvedFont; font.pixelSize: 10
                                        color: modelData.connected ? root.hi : root.txt2
                                    }
                                }
                                PlasmaComponents.Label {
                                    visible: modelData.connected && modelData.pct > 0
                                    text: modelData.pct + "%"
                                    font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.DemiBold
                                    color: root.hi
                                }
                            }
                            MouseArea {
                                id: devMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleDevice(modelData)
                            }
                        }
                    }
                }
                }
            }

            // relleno cuando no está la lista (detalles / vacío): footer pegado abajo
            Item {
                visible: root.showDetails || !root.powered || root.devices.length === 0
                Layout.fillHeight: true
            }

            Rectangle { Layout.fillWidth: true; Layout.topMargin: -6; height: 1; color: root.divCol }

            // ── Footer: Details / Configuration ─────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                BookButton {
                    label: root.showDetails ? root.tr("Volver","Back") : root.tr("Detalles","Details")
                    enabled: root.showDetails || root.connectedCount > 0
                    onClicked: root.showDetails = !root.showDetails
                }
                BookButton { label: root.tr("Configuración","Configuration"); onClicked: root.openSettings("bluetooth") }
            }
        }
    }

    component BookButton: Rectangle {
        id: bookBtn
        property string label: ""
        property var iconFn: null
        property bool enabled: true
        signal clicked
        readonly property bool hov: btnMouse.containsMouse
        Layout.fillWidth: true; Layout.preferredHeight: 34
        radius: 11
        opacity: enabled ? 1.0 : 0.4
        color: hov ? (root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.045)) : root.card
        border.width: 1; border.color: root.brdCol
        Behavior on color { ColorAnimation { duration: 130 } }
        scale: btnMouse.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        PlasmaComponents.Label {
            anchors.centerIn: parent
            text: bookBtn.label
            font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold
            color: root.txt
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
    function togglePower() {
        var turnOn = !root.powered
        // bloqueo rfkill vía BlueZ (persiste) + encender/apagar adaptadores
        BluezQt.Manager.bluetoothBlocked = !turnOn
        var ads = BluezQt.Manager.adapters || []
        for (var i = 0; i < ads.length; i++) ads[i].powered = turnOn
        if (turnOn) scanStopTimer.stop()
    }
    function toggleDevice(d) {
        if (!d || !d.dev) return
        if (d.dev.connected) d.dev.disconnectFromDevice()
        else                 d.dev.connectToDevice()
    }
    function scan() {
        if (!root.powered) return
        var ads = BluezQt.Manager.adapters || []
        for (var i = 0; i < ads.length; i++) {
            if (!ads[i].discovering) ads[i].startDiscovery()
        }
        root.scanning = true
        scanStopTimer.restart()
    }
    function stopScan() {
        var ads = BluezQt.Manager.adapters || []
        for (var i = 0; i < ads.length; i++) {
            if (ads[i].discovering) ads[i].stopDiscovery()
        }
        root.scanning = false
    }
    function openSettings(page) {
        root.expanded = false
        cmd.run("sh -c 'echo " + page + " > /tmp/bookos-start-page; gtk-launch bookos-settings.desktop 2>/dev/null || bookos-settings'")
    }

    // descubrir automáticamente al abrir el popup; parar al cerrar
    onPopupOpenChanged: { if (popupOpen) scan(); else stopScan() }
    Timer { id: scanStopTimer; interval: 12000; onTriggered: root.stopScan() }

    Plasma5Support.DataSource {
        id: cmd; engine: "executable"; connectedSources: []
        onNewData: (s, data) => disconnectSource(s)
        function run(c) { connectSource(c) }
    }
}
