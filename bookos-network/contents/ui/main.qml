import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.networkmanagement as PlasmaNM
import org.kde.kirigami as Kirigami
import QtQuick.Effects

PlasmoidItem {
    id: root

    // ── ESTADO (backend nativo PlasmaNM) ─────────────────────────────────
    property bool   wired:       false
    property string activeSsid:  ""
    property int    activeSignal: 0
    property var    networks:    []      // [{ssid, signal, secure, active, uuid, connPath, devPath, specPath}]
    readonly property bool wifiEnabled: enabledConns.wirelessEnabled

    // NetworkManager nativo
    PlasmaNM.Handler { id: nmHandler }
    PlasmaNM.EnabledConnections { id: enabledConns }
    PlasmaNM.AppletProxyModel {
        id: netModel
        sourceModel: PlasmaNM.NetworkModel {}
    }
    // objetos vivos con los roles de cada fila del modelo
    Instantiator {
        id: netInst
        model: netModel
        delegate: QtObject {
            required property var model
            property string ssid:        model.Ssid || ""
            property int    sig:         model.Signal || 0
            property int    securityType: model.SecurityType || 0
            property int    connState:   model.ConnectionState || 0
            property string connPath:    model.ConnectionPath || ""
            property string devPath:     model.DevicePath || ""
            property string specPath:    model.SpecificPath || ""
            property string uuid:        model.Uuid || ""
        }
        onObjectAdded:   root.rebuildNetworks()
        onObjectRemoved: root.rebuildNetworks()
    }
    Connections {
        target: netModel
        function onDataChanged()    { root.rebuildNetworks() }
        function onModelReset()     { root.rebuildNetworks() }
        function onRowsInserted()   { root.rebuildNetworks() }
        function onRowsRemoved()    { root.rebuildNetworks() }
    }

    function rebuildNetworks() {
        var out = []
        var seen = {}
        var actSsid = "", actSig = 0, isWired = false
        for (var i = 0; i < netInst.count; i++) {
            var o = netInst.objectAt(i)
            if (!o) continue
            var active = o.connState === PlasmaNM.Enums.Activated
            if (!o.ssid || o.ssid === "") {           // fila no-WiFi (ethernet/vpn…)
                if (active) isWired = true
                continue
            }
            if (seen[o.ssid]) continue
            seen[o.ssid] = true
            out.push({
                ssid: o.ssid, signal: o.sig, secure: o.securityType > 0, active: active,
                uuid: o.uuid, connPath: o.connPath, devPath: o.devPath, specPath: o.specPath
            })
            if (active) { actSsid = o.ssid; actSig = o.sig }
        }
        out.sort(function(a, b){
            if (a.active !== b.active) return a.active ? -1 : 1
            return b.signal - a.signal
        })
        root.networks = out
        root.wired = isWired
        root.activeSsid = actSsid
        root.activeSignal = actSig
    }
    Component.onCompleted: rebuildNetworks()

    // ── Vista de detalles ────────────────────────────────────────────────
    property bool showDetails: false
    property var  details: ({})          // {ip, mac, gw, dns, rate, sec, since, dev}
    onExpandedChanged: if (!expanded) showDetails = false

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
        // altura según contenido, calculada aquí (no negociada con el contenedor)
        readonly property int fixedH: root.showDetails ? 505
            : (!root.wifiEnabled || root.networks.length === 0) ? 225
            : 170 + Math.min(root.networks.length, 5) * 50 + 10
        implicitWidth: 330
        implicitHeight: fixedH
        Layout.minimumWidth: 330; Layout.preferredWidth: 330; Layout.maximumWidth: 330
        Layout.minimumHeight: fixedH
        Layout.preferredHeight: fixedH
        Layout.maximumHeight: fixedH

        Rectangle { anchors.fill: parent; radius: 18; color: root.bg }

        property real entryOpacity: 0.0
        property real entryScale: 0.96
        Component.onCompleted: { entryOpacity = 1.0; entryScale = 1.0; root.scan(); root.rebuildNetworks() }
        opacity: entryOpacity; scale: entryScale
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: popupCol
            anchors { fill: parent; margins: 16 }
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
                    MouseArea { id: scanBtnM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { netSpin.restart(); root.scan() } }
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

            // ── Vista de detalles de la red activa ───────────────────────
            Rectangle {
                visible: root.showDetails
                Layout.fillWidth: true; radius: 16
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                implicitHeight: detCol.implicitHeight + 24
                ColumnLayout {
                    id: detCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        Rectangle {
                            width: 36; height: 36; radius: 18; color: root.hi
                            Image { anchors.centerIn: parent; width: 20; height: 20; sourceSize: Qt.size(40,40); smooth: true; source: root.icoWifi(root.activeSignal, "#FFFFFF", false) }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            PlasmaComponents.Label { text: root.activeSsid; font.family: root.resolvedFont; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.hi; Layout.fillWidth: true; elide: Text.ElideRight }
                            PlasmaComponents.Label { text: root.tr("Conectado","Connected"); font.family: root.resolvedFont; font.pixelSize: 11; color: root.hi }
                        }
                        PlasmaComponents.Label { text: root.activeSignal + "%"; font.family: root.resolvedFont; font.pixelSize: 12; color: root.txt2 }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.divCol }
                    Repeater {
                        model: [
                            { l: root.tr("Dirección IP","IP address"),   v: root.details.ip   || "—" },
                            { l: "MAC",                                   v: root.details.mac  || "—" },
                            { l: root.tr("Puerta de enlace","Gateway"),   v: root.details.gw   || "—" },
                            { l: "DNS",                                   v: root.details.dns  || "—" },
                            { l: root.tr("Velocidad","Speed"),            v: root.details.rate || "—" },
                            { l: root.tr("Seguridad","Security"),         v: root.details.sec  || "—" },
                            { l: root.tr("Conectado desde","Connected since"), v: root.details.since || "—" }
                        ]
                        delegate: RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            PlasmaComponents.Label { text: modelData.l; font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2; Layout.preferredWidth: 110 }
                            PlasmaComponents.Label { text: modelData.v; font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.Medium; color: root.txt; Layout.fillWidth: true; elide: Text.ElideMiddle; horizontalAlignment: Text.AlignRight }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.divCol }
                    // Desconectar
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 17
                        readonly property color red: root.isDarkMode ? "#FF453A" : "#FF3B30"
                        color: discM.containsMouse ? Qt.rgba(red.r, red.g, red.b, 0.16) : "transparent"
                        border.width: 1; border.color: Qt.rgba(red.r, red.g, red.b, 0.4)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        PlasmaComponents.Label { anchors.centerIn: parent; text: root.tr("Desconectar de esta red","Disconnect from this network"); font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: parent.red }
                        MouseArea { id: discM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.disconnectNet() }
                    }
                }
            }

            // ── Conexión por cable ───────────────────────────────────────
            Rectangle {
                visible: root.wired && !root.showDetails
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
                visible: !root.showDetails && (!root.wifiEnabled || (root.networks.length === 0))
                Layout.fillWidth: true; radius: 16
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                implicitHeight: 48
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                    Image { Layout.preferredWidth: 16; Layout.preferredHeight: 16; sourceSize: Qt.size(32,32); smooth: true; source: root.icoWifi(0, root.txt2, !root.wifiEnabled) }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: !root.wifiEnabled ? root.tr("Wi-Fi desactivado","Wi-Fi off") : root.tr("Buscando redes…","Scanning networks…")
                        font.family: root.resolvedFont; font.pixelSize: 13; color: root.txt2
                    }
                }
            }

            // ── Lista de redes ───────────────────────────────────────────
            Rectangle {
                visible: !root.showDetails && root.wifiEnabled && root.networks.length > 0
                Layout.fillWidth: true; Layout.fillHeight: true; radius: 16
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                clip: true

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
                                    visible: !modelData.active
                                    anchors.fill: parent
                                    color: netMouse.containsMouse ? root.hovCol : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                // tarjeta con borde azul para la red conectada (mockup)
                                Rectangle {
                                    visible: modelData.active
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 5; bottomMargin: 5 }
                                    radius: 12
                                    color: Qt.rgba(root.hi.r, root.hi.g, root.hi.b, root.isDarkMode ? 0.10 : 0.05)
                                    border.width: 1.5; border.color: root.hi
                                }
                                Rectangle {
                                    visible: index < root.networks.length - 1 && !netMouse.containsMouse && !modelData.active
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16 }
                                    height: 1; color: root.divCol; z: 2
                                }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; spacing: 11
                                    Image {
                                        Layout.preferredWidth: 20; Layout.preferredHeight: 20
                                        sourceSize: Qt.size(40,40); smooth: true
                                        source: root.icoWifi(modelData.signal, modelData.active ? root.hi : root.txt, false)
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: 5
                                            PlasmaComponents.Label {
                                                text: modelData.ssid; font.family: root.resolvedFont; font.pixelSize: 13
                                                font.weight: modelData.active ? Font.DemiBold : Font.Medium
                                                color: modelData.active ? root.hi : root.txt
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: 170
                                            }
                                            Image {
                                                visible: modelData.secure
                                                Layout.preferredWidth: 11; Layout.preferredHeight: 11
                                                sourceSize: Qt.size(22,22); smooth: true
                                                source: root.icoLock(modelData.active ? root.hi : root.txt2)
                                            }
                                            Item { Layout.fillWidth: true }
                                        }
                                        PlasmaComponents.Label {
                                            visible: modelData.active
                                            text: root.tr("Conectado","Connected"); font.family: root.resolvedFont; font.pixelSize: 10; color: root.hi
                                        }
                                    }
                                    PlasmaComponents.Label {
                                        text: modelData.signal + "%"; font.family: root.resolvedFont; font.pixelSize: 11
                                        font.weight: modelData.active ? Font.DemiBold : Font.Normal
                                        color: modelData.active ? root.hi : root.txt2
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

            // relleno cuando no está la lista (detalles / vacío): footer pegado abajo
            Item {
                visible: root.showDetails || !root.wifiEnabled || root.networks.length === 0
                Layout.fillHeight: true
            }

            Rectangle { Layout.fillWidth: true; Layout.topMargin: -6; height: 1; color: root.divCol }

            // ── Footer: Details / Configuration ─────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                BookButton {
                    label: root.showDetails ? root.tr("Volver","Back") : root.tr("Detalles","Details")
                    enabled: root.showDetails || (root.wifiEnabled && root.activeSsid !== "")
                    onClicked: {
                        if (!root.showDetails) root.loadDetails()
                        root.showDetails = !root.showDetails
                    }
                }
                BookButton { label: root.tr("Configuración","Configuration"); onClicked: root.openSettings("wifi") }
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
    function toggleWifi() {
        nmHandler.enableWireless(!root.wifiEnabled)
    }
    function connectNet(n) {
        if (!n || n.active) return
        if (n.uuid && n.uuid !== "")            // conexión ya conocida → activar
            nmHandler.activateConnection(n.connPath, n.devPath, n.specPath)
        else                                    // red nueva (abierta; las cifradas piden clave en Ajustes)
            nmHandler.addAndActivateConnection(n.devPath, n.specPath)
    }
    function openSettings(page) {
        root.expanded = false
        cmd.run("sh -c 'echo " + page + " > /tmp/bookos-start-page; gtk-launch bookos-settings.desktop 2>/dev/null || bookos-settings'")
    }
    function disconnectNet() {
        // busca la conexión WiFi activa y la desactiva
        for (var i = 0; i < root.networks.length; i++) {
            var n = root.networks[i]
            if (n.active) { nmHandler.deactivateConnection(n.connPath, n.devPath); break }
        }
        root.showDetails = false
    }
    function scan() { if (root.wifiEnabled) nmHandler.requestScan() }
    onPopupOpenChanged: if (popupOpen) scan()
    Timer { running: root.popupOpen && root.wifiEnabled; interval: 10000; repeat: true; onTriggered: root.scan() }
    function loadDetails() {
        root.details = {}
        detSource.refresh()
    }
    Plasma5Support.DataSource {
        id: detSource; engine: "executable"; connectedSources: []
        function refresh() {
            var c = "sh -c '" +
                "dev=$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: \"\\$2==\\\"wifi\\\" && \\$3==\\\"connected\\\"{print \\$1; exit}\"); " +
                "[ -z \"$dev\" ] && exit 0; " +
                "echo ip:$(nmcli -t -g IP4.ADDRESS device show $dev | head -n1 | cut -d/ -f1); " +
                "echo mac:$(nmcli -t -g GENERAL.HWADDR device show $dev | sed \"s/\\\\\\\\//g\"); " +
                "echo gw:$(nmcli -t -g IP4.GATEWAY device show $dev); " +
                "echo dns:$(nmcli -t -g IP4.DNS device show $dev | head -n1); " +
                "echo rate:$(nmcli -t -f IN-USE,RATE device wifi list ifname $dev | grep \"^\\*\" | cut -d: -f2); " +
                "echo sec:$(nmcli -t -f IN-USE,SECURITY device wifi list ifname $dev | grep \"^\\*\" | cut -d: -f2); " +
                "ts=$(nmcli -t -f NAME,TIMESTAMP connection show | awk -F: -v n=\"$(nmcli -t -g GENERAL.CONNECTION device show $dev)\" \"\\$1==n{print \\$2; exit}\"); " +
                "[ -n \"$ts\" ] && echo since:$(date -d @$ts \"+%H:%M\") " +
                "'"
            connectSource(c)
        }
        onNewData: (s, data) => {
            disconnectSource(s)
            if (!data.stdout) return
            var d = {}
            data.stdout.trim().split("\n").forEach(function(l){
                var i = l.indexOf(":")
                if (i > 0) d[l.substring(0, i)] = l.substring(i + 1).trim()
            })
            root.details = d
        }
    }
    Plasma5Support.DataSource {
        id: cmd; engine: "executable"; connectedSources: []
        onNewData: (s, data) => disconnectSource(s)
        function run(c) { connectSource(c) }
    }
}
