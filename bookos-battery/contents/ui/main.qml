import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ─────────────────────────────────────────────────────────────────────
    // ESTADO
    // ─────────────────────────────────────────────────────────────────────
    property int    percentage:    0
    property bool   isCharging:    false
    property bool   isPlugged:     false
    property string powerProfile:  "balanced"
    property string timeRemaining: ""
    property real   batteryTemp:   -1
    property bool   chargeLimit:   false
    property int    batteryHealth: -1
    property string powerManager:  "detecting"
    property var    btDevices:     []
    property string topProcess:    ""
    property string cpuGovernor:   ""
    property bool   hasPstate:     false
    property real   energyRate:    -1
    property int    chargeCycles:  -1

    // ── Smart Charge Limit ───────────────────────────────────────────
    property int    chargeThreshold:  100      // charge_control_end_threshold (80, 90, 100)
    property bool   isChargeLimited:  false    // enchufado pero detenido en el límite
    property int    batteryHealthPct: -1       // salud real: energy_full/energy_full_design * 100
    property real   energyNow:        -1       // mWh actuales
    property real   energyFull:       -1       // mWh capacidad actual
    property real   energyFullDesign: -1       // mWh capacidad de fábrica

    // isCharging real = cargando activamente (no limitado)
    // isChargeLimited = enchufado pero batería llegó al threshold
    readonly property bool isActivelyCharging: isCharging && !isChargeLimited

    property bool   lastCharging:     false
    property bool   lastPlugged:      false
    property int    lastNotifiedPct:  -1
    property bool   initializedState: false

    // ── Estimación de tiempo por JS (instantánea) ────────────────────
    function calcTimeRemaining() {
        if (root.energyRate <= 0.5 || root.energyNow <= 0 || root.energyFull <= 0) { root.timeRemaining = ""; return }
        var hours, mins
        if (root.isCharging) {
            var remaining = root.energyFull - root.energyNow
            if (remaining <= 0) { root.timeRemaining = ""; return }
            hours = remaining / root.energyRate
        } else {
            hours = root.energyNow / root.energyRate
        }
        var h = Math.floor(hours)
        var m = Math.round((hours - h) * 60)
        if (h > 0) root.timeRemaining = h + " h " + m + " min"
        else if (m > 0) root.timeRemaining = m + " min"
        else root.timeRemaining = ""
    }

    // ─────────────────────────────────────────────────────────────────────
    // COLORES
    // ─────────────────────────────────────────────────────────────────────
    // Cargando = verde, Bajo = amarillo, Crítico = rojo, Normal sigue tema.

    // ── BookOS palette detection ─────────────────────────────────────
    readonly property bool isDarkMode: {
        var b = Kirigami.Theme.backgroundColor
        return (b.r + b.g + b.b) / 3.0 < 0.5
    }
    // BookOS tokens: bg, card, tx, tx2, div, brd, hov, blue
    readonly property color bg:    isDarkMode ? Qt.color("#000000") : Qt.color("#FFFFFF")
    readonly property color card:  isDarkMode ? Qt.color("#1c1c1e") : Qt.color("#FFFFFF")
    readonly property color txt:   isDarkMode ? Qt.color("#FFFFFF") : Qt.color("#000000")
    readonly property color txt2:  Qt.color("#8e8e93")
    readonly property color divCol: isDarkMode ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.08)
    readonly property color brdCol: isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property color hovCol: isDarkMode ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.04)
    readonly property color hi:    isDarkMode ? Qt.color("#0A84FF") : Qt.color("#007AFF")

    // BookOS palette: dark vs light variants
    readonly property color colCharging:    Qt.color(Plasmoid.configuration.chargingColor    || (isDarkMode ? "#30D158" : "#34C759"))
    readonly property color colPluggedFull: Qt.color(Plasmoid.configuration.pluggedFullColor || (isDarkMode ? "#30D158" : "#34C759"))
    readonly property color colCritical:    Qt.color(Plasmoid.configuration.criticalColor    || (isDarkMode ? "#FF453A" : "#FF3B30"))
    readonly property color colLow:         Qt.color(Plasmoid.configuration.lowColor         || (isDarkMode ? "#FFD60A" : "#FFCC00"))
    readonly property color colNormal:      Plasmoid.configuration.normalColor !== "" ? Qt.color(Plasmoid.configuration.normalColor) : txt
    readonly property color colPowerSave:   Qt.color(Plasmoid.configuration.powerSaveColor   || (isDarkMode ? "#FFD60A" : "#FF9500"))
    readonly property color colBalanced:    Plasmoid.configuration.balancedColor !== "" ? Qt.color(Plasmoid.configuration.balancedColor) : (isDarkMode ? Qt.color("#0A84FF") : Qt.color("#007AFF"))
    readonly property color colPerformance: Qt.color(Plasmoid.configuration.performanceColor || (isDarkMode ? "#0A84FF" : "#007AFF"))

    property int   lowThreshold:  Plasmoid.configuration.notifyLowThreshold  || 20
    property int   critThreshold: Plasmoid.configuration.notifyCritThreshold || 10

    readonly property color baseTextColor: {
        let m = Plasmoid.configuration.iconTheme
        if (m === 1) return Qt.color("#000000")
        if (m === 2) return Qt.color("#FFFFFF")
        return txt
    }

    // Color de la barra/relleno según estado
    readonly property color stateColor: {
        if (isCharging)                                     return colCharging
        if (isPlugged && percentage >= 99)                  return colPluggedFull
        if (percentage <= root.critThreshold)               return colCritical
        if (percentage <= root.lowThreshold)                return colLow
        if (powerProfile === "power-saver")                 return colPowerSave
        if (powerProfile === "performance")                 return colPerformance
        if (powerProfile === "balanced")                    return colBalanced
        return colNormal
    }

    readonly property color borderColor: Qt.rgba(baseTextColor.r, baseTextColor.g, baseTextColor.b, 0.48)

    // ─────────────────────────────────────────────────────────────────────
    // ESTILO VISUAL
    // ─────────────────────────────────────────────────────────────────────
    // Fondo del popup — simula blur con capas semitransparentes
    // En Plasma, el blur real solo funciona con KWin blur effect habilitado.
    // Esta solución usa un fondo semi-transparente + "noise" overlay + border sutil
    // que se ve bien incluso sin blur de KWin.
    readonly property color popupBgColor: {
        let ov = Plasmoid.configuration.popupBgColorOverride
        if (ov && typeof ov === "string" && ov.trim() !== "") {
            try { return Qt.color(ov) } catch(e) {}
        }
        // BookOS: bg sólido, semi-transp para blur opcional
        return bg
    }

    readonly property color popupBorderColor: brdCol

    // ─────────────────────────────────────────────────────────────────────
    // PERFILES
    // ─────────────────────────────────────────────────────────────────────
    readonly property string p1Label: Plasmoid.configuration.profile1Label || "Ahorro"
    readonly property string p1Desc:  Plasmoid.configuration.profile1Desc  || "Máx. duración de batería"
    readonly property string p1Cmd:   Plasmoid.configuration.profile1Cmd   || ""
    readonly property string p2Label: Plasmoid.configuration.profile2Label || "Equilibrado"
    readonly property string p2Desc:  Plasmoid.configuration.profile2Desc  || "Rendimiento recomendado"
    readonly property string p2Cmd:   Plasmoid.configuration.profile2Cmd   || ""
    readonly property string p3Label: Plasmoid.configuration.profile3Label || "Alto rendimiento"
    readonly property string p3Desc:  Plasmoid.configuration.profile3Desc  || "Máx. potencia del sistema"
    readonly property string p3Cmd:   Plasmoid.configuration.profile3Cmd   || ""

    // ─────────────────────────────────────────────────────────────────────
    // CONFIGURACIÓN
    // ─────────────────────────────────────────────────────────────────────
    readonly property string resolvedFont: customFont !== "" ? customFont : Kirigami.Theme.defaultFont.family
    property string customFont:    Plasmoid.configuration.customFont      || ""
    property int percentPosition:  Plasmoid.configuration.percentPosition || 0
    property int cfgW:             Plasmoid.configuration.iconWidth       || 23
    property int cfgH:             Plasmoid.configuration.iconHeight      || 11
    property int popW:             Plasmoid.configuration.popupWidth      || 340
    property int popH:             Plasmoid.configuration.popupHeight     || 0
    property int popupStyle:       Plasmoid.configuration.popupStyle      || 0

    property int  iconPreset:  Plasmoid.configuration.iconPreset   || 0
    property bool useCustomIconRadius: Plasmoid.configuration.useCustomIconRadius || false
    property int  customIconRadius:    Plasmoid.configuration.customIconRadius    !== undefined ? Plasmoid.configuration.customIconRadius : 10
    property real boltScale:   Plasmoid.configuration.boltScale    || 1.0
    property int  boltStyle:   Plasmoid.configuration.boltStyle    || 0
    property int  visualPreset: Plasmoid.configuration.visualPreset || 0

    property bool animFill:          Plasmoid.configuration.animFill          !== false
    property bool animShimmer:       Plasmoid.configuration.animShimmer       !== false
    property int  animShimmerSpeed:  Plasmoid.configuration.animShimmerSpeed  || 2400
    property bool animPulse:         Plasmoid.configuration.animPulse         !== false
    property bool animPopupEntrance: Plasmoid.configuration.animPopupEntrance !== false
    property bool animProfileSpring: Plasmoid.configuration.animProfileSpring !== false
    property bool animRainbow:       Plasmoid.configuration.animRainbow       || false
    property int  animRainbowSpeed:  Plasmoid.configuration.animRainbowSpeed  || 3000
    property bool animBounce:        Plasmoid.configuration.animBounce        || false

    property bool hasIntelLpmd: false
    property string lpmdMode:   "unknown"

    preferredRepresentation: compactRepresentation
    // BookOS: no frame de Plasma, el popup tiene su propio fondo
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ─────────────────────────────────────────────────────────────────────
    // ANIMACIONES
    // ─────────────────────────────────────────────────────────────────────
    property real chargePulse: 0.0
    SequentialAnimation {
        running: root.isActivelyCharging && root.animPulse; loops: Animation.Infinite
        NumberAnimation { target: root; property: "chargePulse"; to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "chargePulse"; to: 0.0; duration: 1600; easing.type: Easing.InOutSine }
        onStopped: root.chargePulse = 0.0
    }

    property real shimmerX: -0.4
    SequentialAnimation {
        running: root.isActivelyCharging && root.animShimmer; loops: Animation.Infinite
        NumberAnimation { target: root; property: "shimmerX"; from: -0.4; to: 1.2; duration: root.animShimmerSpeed; easing.type: Easing.InOutCubic }
        PauseAnimation  { duration: 600 }
        onStopped: root.shimmerX = -0.4
    }

    property real rainbowPhase: 0.0
    SequentialAnimation {
        running: root.isActivelyCharging && root.animRainbow; loops: Animation.Infinite
        NumberAnimation { target: root; property: "rainbowPhase"; from: 0.0; to: 1.0; duration: root.animRainbowSpeed; easing.type: Easing.Linear }
        onStopped: root.rainbowPhase = 0.0
    }

    readonly property color effectiveFillColor: {
        if (root.isActivelyCharging && root.animRainbow) {
            // Smooth gradient: green → cyan → blue → purple → pink → orange → green
            var h = root.rainbowPhase
            var hue = h  // Direct 0-1 hue rotation, smoothest possible
            return Qt.hsva(hue, 0.70, 0.95, 1.0)
        }
        return root.stateColor
    }

    property real bounceY: 0.0
    SequentialAnimation {
        running: root.isActivelyCharging && root.animBounce; loops: Animation.Infinite
        NumberAnimation { target: root; property: "bounceY"; to: -2.0; duration: 400; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bounceY"; to: 0.0;  duration: 400; easing.type: Easing.InQuad }
        PauseAnimation  { duration: 1200 }
        onStopped: root.bounceY = 0.0
    }

    // ─────────────────────────────────────────────────────────────────────
    // NOTIFICACIONES
    // ─────────────────────────────────────────────────────────────────────
    onIsChargingChanged: {
        if (!root.initializedState) return
        root.timeRemaining = ""
        if (isCharging && !lastCharging) {
            if (Plasmoid.configuration.notifyCharging) sendNotif("battery-ac-adapter", "Cargador conectado", "Cargando " + percentage + "%", 0)
        } else if (!isCharging && lastCharging && !isPlugged) {
            if (Plasmoid.configuration.notifyDischarging) sendNotif("battery", "Cargador desconectado", percentage + "%", 1)
        }
        lastCharging = isCharging
    }
    onIsPluggedChanged: {
        if (!root.initializedState) return
        root.timeRemaining = ""
        if (isPlugged && !isCharging && lastCharging) sendNotif("battery-full", "Batería completa", percentage + "%", 0)
        lastPlugged = isPlugged
    }
    onPercentageChanged: {
        if (!root.initializedState) return
        if (percentage <= root.lowThreshold && percentage > root.critThreshold && !isCharging && lastNotifiedPct !== root.lowThreshold) {
            if (Plasmoid.configuration.notifyLow) sendNotif("battery-low", "Batería baja", percentage + "%", 1)
            lastNotifiedPct = root.lowThreshold
        } else if (percentage <= root.critThreshold && !isCharging && lastNotifiedPct !== root.critThreshold) {
            if (Plasmoid.configuration.notifyLow) sendNotif("battery-caution", "Batería crítica", percentage + "%", 2)
            lastNotifiedPct = root.critThreshold
        } else if (percentage === 100 && isCharging && lastNotifiedPct !== 100) {
            if (Plasmoid.configuration.notifyFull) sendNotif("battery-full", "Carga completa", "100%", 0)
            lastNotifiedPct = 100
        } else if (isCharging && percentage > 20) { lastNotifiedPct = -1 }
    }
    function sendNotif(icon, title, body, urgency) {
        if (!Plasmoid.configuration.enableNotifications) return
        var u = urgency || 1
        notifySource.connectSource('notify-send -a "Mi Batería" -i "' + icon + '" -u ' + (u === 2 ? "critical" : u === 0 ? "low" : "normal") + ' -t ' + (u === 2 ? "8000" : "4000") + ' "' + title + '" "' + body + '"')
    }
    function profileLabel(p) { return p === "power-saver" ? root.p1Label : p === "performance" ? root.p3Label : root.p2Label }
    function resolveManager(detected) {
        var f = Plasmoid.configuration.forceManager || 0
        return f === 1 ? "ppd" : f === 2 ? "tlp" : f === 3 ? "none" : detected
    }
    function btIcon(name) {
        var n = name.toLowerCase()
        if (n.includes("buds") || n.includes("airpod") || n.includes("headphone") || n.includes("auricular")) return "🎧"
        if (n.includes("mouse")) return "🖱️"
        if (n.includes("keyboard") || n.includes("teclado")) return "⌨️"
        if (n.includes("phone") || n.includes("iphone")) return "📱"
        if (n.includes("watch") || n.includes("band")) return "⌚"
        if (n.includes("gamepad") || n.includes("controller")) return "🎮"
        return "📡"
    }

    // ─────────────────────────────────────────────────────────────────────
    // SVG — batería pill horizontal
    // ─────────────────────────────────────────────────────────────────────
    function toHex(c) {
        if (!c) return "#888888"
        var s = c.toString()
        if (s.startsWith("#")) return s.length === 9 ? "#" + s.substring(3, 9) : s.substring(0, 7)
        return s
    }
    function getAlpha(c) {
        if (!c) return 1.0
        var s = c.toString()
        return (s.startsWith("#") && s.length === 9) ? parseInt(s.substring(1, 3), 16) / 255.0 : 1.0
    }

    // Rayo SVG: grueso, redondeado
    function svgBolt(color) {
        var c = toHex(color)
        if (root.boltStyle === 1) {
            return "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><polygon points="62,4 22,52 46,48 36,96 80,48 56,52" fill="' + c + '" stroke="' + c + '" stroke-width="4" stroke-linejoin="round"/></svg>')
        }
        return "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><polygon points="64,2 18,54 46,50 36,98 82,46 54,50" fill="' + c + '"/></svg>')
    }
    function svgPlug(color) {
        var c = toHex(color)
        return "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect x="20" y="38" width="60" height="32" rx="10" fill="' + c + '"/><line x1="35" y1="38" x2="35" y2="16" stroke="' + c + '" stroke-width="12" stroke-linecap="round"/><line x1="65" y1="38" x2="65" y2="16" stroke="' + c + '" stroke-width="12" stroke-linecap="round"/><line x1="50" y1="70" x2="50" y2="90" stroke="' + c + '" stroke-width="12" stroke-linecap="round"/></svg>')
    }
    function svgBattery(fillRatio, fillColor, borderColor, withBolt, boltColor) {
        var fc = toHex(fillColor); var bc = toHex(borderColor)
        var blc = boltColor ? toHex(boltColor) : "#FFFFFF"
        var fw = Math.max(0, Math.round(fillRatio * 78))
        var cid = "bp_" + fw

        var rx = root.useCustomIconRadius ? root.customIconRadius : 10
        if (!root.useCustomIconRadius) { if (root.iconPreset === 1) rx = 22; if (root.iconPreset === 2) rx = 3; if (root.iconPreset === 3) rx = 28 }
        var sw = root.iconPreset === 2 && !root.useCustomIconRadius ? "3.0" : "4.5"
        var capRx = root.iconPreset === 1 ? 6 : root.iconPreset === 3 ? 8 : 4
        var fillRx = Math.max(1, rx - 4)

        var fillSvg = fw > 0 ? '<rect x="5" y="9" width="' + fw + '" height="42" rx="' + fillRx + '" fill="' + fc + '" clip-path="url(#' + cid + ')"/>' : ""
        var boltSvg = ""
        if (withBolt) {
            boltSvg = root.boltStyle === 1
                ? '<polygon points="55,12 35,32 45,31 40,48 62,28 52,29" fill="' + blc + '" opacity="0.92" stroke="' + blc + '" stroke-width="2.5" stroke-linejoin="round"/>'
                : '<polygon points="54,14 36,32 46,31 42,46 62,28 52,29" fill="' + blc + '" opacity="0.85"/>'
        }
        return "data:image/svg+xml," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 60">' +
            '<defs><clipPath id="' + cid + '"><rect x="5" y="9" width="78" height="42" rx="' + fillRx + '"/></clipPath></defs>' +
            '<rect x="90" y="21" width="9" height="18" rx="' + capRx + '" fill="' + bc + '" opacity="0.75"/>' +
            '<rect x="1" y="5" width="87" height="50" rx="' + rx + '" fill="none" stroke="' + bc + '" stroke-width="' + sw + '" opacity="0.88"/>' +
            fillSvg + boltSvg + '</svg>')
    }

    // ═════════════════════════════════════════════════════════════════════
    // COMPACT
    // ═════════════════════════════════════════════════════════════════════
    compactRepresentation: Item {
        Layout.preferredWidth:  compactRow.implicitWidth + 10
        Layout.preferredHeight: compactRow.implicitHeight + 6
        implicitWidth:  Layout.preferredWidth
        implicitHeight: Layout.preferredHeight

        PlasmaComponents.ToolTip {
            text: {
                var st = root.isActivelyCharging ? "Cargando" : root.isChargeLimited ? "Límite " + root.chargeThreshold + "%"  : root.isPlugged ? "Enchufado" : "Batería"
                var tr = root.timeRemaining !== "" ? "\n" + root.timeRemaining + (root.isCharging ? " para carga" : " restante") : ""
                return st + " " + root.percentage + "%" + tr + "\nPerfil: " + profileLabel(root.powerProfile) + (root.energyRate > 0 ? "\n" + root.energyRate.toFixed(1) + " W" : "")
            }
        }

        MouseArea {
            anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton
            onClicked: root.expanded = !root.expanded
            RowLayout {
                id: compactRow; anchors.centerIn: parent; spacing: 5
                anchors.verticalCenterOffset: (root.animBounce && root.isCharging) ? root.bounceY : 0

                PlasmaComponents.Label {
                    id: pctL; visible: root.percentPosition === 1; text: root.percentage + "%"
                    font.family: root.resolvedFont; font.weight: Font.Medium; font.pixelSize: 12
                    color: root.baseTextColor; opacity: 0.92
                }

                Item {
                    width: root.cfgW + 3; height: root.cfgH
                    Rectangle {
                        id: batteryBody; width: root.cfgW; height: root.cfgH
                        radius: Math.max(2, root.cfgH / 4); color: "transparent"
                        border.color: root.borderColor; border.width: 1; clip: true

                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1.5 }
                            radius: Math.min(Math.max(1, root.cfgH / 8), width / 2)
                            width: Math.max(0, (root.cfgW - 3) * (root.percentage / 100))
                            color: root.effectiveFillColor
                            opacity: root.isActivelyCharging ? (0.82 + 0.18 * root.chargePulse) : 1.0
                            Behavior on width { enabled: root.animFill; NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 350 } }
                            Rectangle {
                                visible: root.isActivelyCharging && root.animShimmer
                                anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: parent.width * 0.35; x: root.shimmerX * parent.width
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.rgba(1,1,1,0.20) }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                        }
                        Image {
                            visible: root.isActivelyCharging && root.percentPosition !== 2; anchors.centerIn: parent
                            width: Math.max(7, root.cfgH * 0.68 * root.boltScale); height: Math.max(9, root.cfgH * 0.90 * root.boltScale)
                            sourceSize: Qt.size(width*2, height*2); smooth: true
                            source: root.svgBolt(root.percentage > 52 ? root.bg : Qt.rgba(1,1,1,0.95))
                            opacity: 0.80 + 0.20 * root.chargePulse
                        }
                        Image {
                            visible: root.isPlugged && !root.isCharging && root.percentPosition !== 2; anchors.centerIn: parent
                            width: Math.max(6, root.cfgH * 0.60); height: Math.max(7, root.cfgH * 0.78)
                            sourceSize: Qt.size(width*2, height*2); smooth: true
                            source: root.svgPlug(root.percentage > 52 ? root.bg : Qt.rgba(1,1,1,0.95)); opacity: 0.88
                        }
                        PlasmaComponents.Label {
                            visible: root.percentPosition === 2 && root.cfgW >= 28 && !root.isCharging && !root.isPlugged
                            text: root.percentage + "%"; anchors.centerIn: parent
                            font.family: root.resolvedFont; font.pixelSize: Math.max(6, root.cfgH - 4); font.weight: Font.Bold
                            color: root.percentage > 45 ? root.bg : root.baseTextColor
                        }
                    }
                    Rectangle {
                        anchors.left: batteryBody.right; anchors.verticalCenter: batteryBody.verticalCenter
                        width: 2; height: Math.max(4, root.cfgH / 2.5); radius: 1
                        color: Qt.rgba(root.baseTextColor.r, root.baseTextColor.g, root.baseTextColor.b, 0.65)
                    }
                }

                PlasmaComponents.Label {
                    id: pctR; visible: root.percentPosition === 0; text: root.percentage + "%"
                    font.family: root.resolvedFont; font.weight: Font.Medium; font.pixelSize: 12
                    color: root.baseTextColor; opacity: 0.92
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // FULL — popup
    // Diseño: cabecera → barra → info → perfiles → BT → consumo → prefs
    // ═════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        id: fullRepRoot
        Layout.minimumWidth: root.popW; Layout.preferredWidth: root.popW; Layout.maximumWidth: root.popW
        Layout.minimumHeight:   root.popH > 0 ? root.popH : popupCol.implicitHeight + 32
        Layout.preferredHeight: root.popH > 0 ? root.popH : popupCol.implicitHeight + 32
        clip: false

        // Fondo BookOS — sólido, sin borde
        Rectangle {
            anchors.fill: parent; radius: 18
            color: root.popupBgColor
            Behavior on color { ColorAnimation { duration: 300 } }

            // Capa frosted para popupStyle 2
            Rectangle {
                visible: root.popupStyle === 2; anchors.fill: parent; radius: 18
                color: Qt.rgba(bg.r, bg.g, bg.b, 0.45)
            }
        }

        // Entrada animada
        property real entryOpacity: 0.0
        property real entryScale: 0.96
        Component.onCompleted: { entryOpacity = 1.0; entryScale = 1.0 }
        opacity: root.animPopupEntrance ? entryOpacity : 1.0
        scale: root.animPopupEntrance ? entryScale : 1.0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Flickable {
            anchors.fill: parent; contentHeight: popupCol.implicitHeight + 32; clip: true
            interactive: root.popH > 0 && popupCol.implicitHeight + 32 > root.popH

            ColumnLayout {
                id: popupCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 14

                // ── TÍTULO (BookOS header style) ─────────────────────
                PlasmaComponents.Label {
                    Layout.fillWidth: true; Layout.bottomMargin: -4
                    text: "Batería"
                    font.family: root.resolvedFont; font.weight: Font.Bold
                    font.pixelSize: 22; font.letterSpacing: -0.4
                    color: root.txt
                }

                // ── CARD: Estado + barra + métricas ──────────────────
                Rectangle {
                    Layout.fillWidth: true; radius: 22
                    color: root.card; border.width: 1; border.color: root.brdCol
                    implicitHeight: stateCol.implicitHeight + 32

                    ColumnLayout {
                        id: stateCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true; spacing: 14

                            Item {
                                Layout.preferredWidth: 60; Layout.preferredHeight: 30
                                Image {
                                    anchors.fill: parent; sourceSize: Qt.size(120, 60); smooth: true
                                    source: root.svgBattery(root.percentage / 100, root.effectiveFillColor,
                                        Qt.rgba(root.txt.r, root.txt.g, root.txt.b, 0.50),
                                        root.isActivelyCharging, root.percentage > 55 ? root.card : root.txt)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                PlasmaComponents.Label {
                                    text: root.percentage + "%"
                                    font.family: root.resolvedFont; font.pixelSize: 30; font.weight: Font.Bold
                                    font.letterSpacing: -0.8
                                    color: root.isActivelyCharging ? root.colCharging : root.txt
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }
                                PlasmaComponents.Label {
                                    visible: text !== ""
                                    text: {
                                        if (root.isActivelyCharging) return root.timeRemaining !== "" ? root.timeRemaining + " para completar" : ""
                                        if (root.isChargeLimited) return "Carga pausada"
                                        if (root.isPlugged && root.percentage >= 99) return ""
                                        if (root.isPlugged) return "Conectado a la corriente"
                                        return root.timeRemaining !== "" ? root.timeRemaining + " restante" : "En batería"
                                    }
                                    font.family: root.resolvedFont; font.pixelSize: 12
                                    color: root.txt2
                                }
                            }

                            Rectangle {
                                visible: root.isActivelyCharging || root.isPlugged
                                readonly property color chipColor: root.isActivelyCharging ? root.colCharging
                                    : root.isChargeLimited ? root.colLow
                                    : (root.isPlugged && root.percentage >= 99) ? root.colCharging : root.hi
                                Layout.preferredHeight: 24
                                Layout.preferredWidth: chipLabel.implicitWidth + 18
                                radius: 12
                                color: chipColor
                                PlasmaComponents.Label {
                                    id: chipLabel; anchors.centerIn: parent
                                    text: {
                                        if (root.isActivelyCharging) return "Cargando"
                                        if (root.isChargeLimited) return "Límite " + root.chargeThreshold + "%"
                                        if (root.isPlugged && root.percentage >= 99) return "Completa"
                                        if (root.isPlugged) return "Conectado"
                                        return ""
                                    }
                                    font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.Bold
                                    color: "#FFFFFF"
                                }
                            }
                        }

                        // Barra de progreso
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 6
                            Rectangle { anchors.fill: parent; radius: 3; color: root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.08) }
                            Rectangle {
                                height: parent.height; radius: 3; clip: true
                                width: parent.width * (root.percentage / 100)
                                color: "transparent"
                                Behavior on width { enabled: root.animFill; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
                                Rectangle {
                                    anchors.fill: parent; radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.rgba(root.effectiveFillColor.r * 0.85, root.effectiveFillColor.g * 0.85, root.effectiveFillColor.b * 0.85, 1.0) }
                                        GradientStop { position: 1.0; color: root.effectiveFillColor }
                                    }
                                }
                                Rectangle {
                                    visible: root.isActivelyCharging && root.animShimmer
                                    anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: Math.max(parent.width * 0.30, 20); x: root.shimmerX * parent.width
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 0.5; color: Qt.rgba(1,1,1,0.30) }
                                        GradientStop { position: 1.0; color: "transparent" }
                                    }
                                }
                            }
                        }

                        // Métricas
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: {
                                    var items = []
                                    if (root.energyRate > 0) items.push(root.energyRate.toFixed(1) + " W")
                                    if (root.batteryTemp > 0) items.push(root.batteryTemp.toFixed(0) + "°C")
                                    if (root.batteryHealthPct > 0 && root.batteryHealthPct < 100) items.push("Salud " + root.batteryHealthPct + "%")
                                    if (root.chargeCycles > 0) items.push(root.chargeCycles + " ciclos")
                                    return items
                                }
                                delegate: RowLayout {
                                    spacing: 6
                                    Rectangle { visible: index > 0; width: 3; height: 3; radius: 1.5; color: root.txt2 }
                                    PlasmaComponents.Label {
                                        text: modelData; font.family: root.resolvedFont; font.pixelSize: 11
                                        color: root.txt2
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            RowLayout {
                                spacing: 5
                                Image {
                                    width: 12; height: 12; smooth: true; sourceSize: Qt.size(24, 24)
                                    source: root.isPlugged
                                        ? "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + toHex(root.txt2) + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 7V3M15 7V3M7 7h10v5a5 5 0 0 1-10 0V7zM12 17v4"/></svg>')
                                        : "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + toHex(root.txt2) + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="18" height="10" rx="2"/><line x1="22" y1="11" x2="22" y2="13"/></svg>')
                                }
                                PlasmaComponents.Label {
                                    text: root.isPlugged ? "Corriente" : "Batería"
                                    font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.Medium
                                    color: root.txt2
                                }
                            }
                        }
                    }
                }

                // ── Sección: Modo de energía ─────────────────────────
                PlasmaComponents.Label {
                    visible: root.powerManager === "ppd"
                    text: "Modo de energía"
                    font.family: root.resolvedFont; font.weight: Font.DemiBold; font.pixelSize: 13
                    color: root.txt2
                    Layout.leftMargin: 4; Layout.bottomMargin: -8
                }

                // CARD: Perfiles
                Rectangle {
                    visible: root.powerManager === "ppd"
                    Layout.fillWidth: true; radius: 22
                    color: root.card; border.width: 1; border.color: root.brdCol
                    clip: true
                    implicitHeight: profilesCol.implicitHeight

                    ColumnLayout {
                        id: profilesCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: 0

                        Repeater {
                            model: [
                                { id: "power-saver", label: root.p1Label, desc: root.p1Desc, cmd: root.p1Cmd, type: 0 },
                                { id: "balanced",    label: root.p2Label, desc: root.p2Desc, cmd: root.p2Cmd, type: 1 },
                                { id: "performance", label: root.p3Label, desc: root.p3Desc, cmd: root.p3Cmd, type: 2 }
                            ]

                            delegate: Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 64
                                readonly property bool isActive: root.powerProfile === modelData.id
                                readonly property color profColor: modelData.type === 0 ? root.colPowerSave : modelData.type === 2 ? root.colPerformance : root.colBalanced
                                readonly property string iconHex: "#FFFFFF"

                                Rectangle {
                                    anchors.fill: parent
                                    color: rowMouse.containsMouse ? root.hovCol : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Rectangle {
                                    visible: index < 2 && !rowMouse.containsMouse
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
                                    height: 1; color: root.divCol
                                    z: 2
                                }

                                scale: rowMouse.pressed ? 0.98 : 1.0
                                Behavior on scale { enabled: root.animProfileSpring; SpringAnimation { spring: 4; damping: 0.4 } }

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 18; spacing: 14

                                    Rectangle {
                                        width: 36; height: 36; radius: 18
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Qt.lighter(profColor, 1.15) }
                                            GradientStop { position: 1.0; color: profColor }
                                        }

                                        Image {
                                            visible: modelData.type === 0
                                            anchors.centerIn: parent; width: 18; height: 18; smooth: true
                                            sourceSize: Qt.size(36, 36)
                                            source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + iconHex + '" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M11 20A7 7 0 0 1 9.8 6.9C15.5 4.9 17 3.5 19 2c1 2 2 4.5 1 8-1.5 5.5-4 7-9 10z"/><path d="M10.7 13.8c2.1-1.4 3.3-3.3 4.1-5.5"/></svg>')
                                        }
                                        Image {
                                            visible: modelData.type === 1
                                            anchors.centerIn: parent; width: 18; height: 18; smooth: true
                                            sourceSize: Qt.size(36, 36)
                                            source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + iconHex + '" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="3" fill="' + iconHex + '"/></svg>')
                                        }
                                        Image {
                                            visible: modelData.type === 2
                                            anchors.centerIn: parent; width: 18; height: 18; smooth: true
                                            sourceSize: Qt.size(36, 36)
                                            source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="' + iconHex + '"><polygon points="13,2 3,14 12,14 11,22 21,10 12,10"/></svg>')
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        PlasmaComponents.Label {
                                            text: modelData.label; font.family: root.resolvedFont; font.pixelSize: 15
                                            font.weight: Font.DemiBold; color: root.txt
                                        }
                                        PlasmaComponents.Label {
                                            text: modelData.desc; font.family: root.resolvedFont; font.pixelSize: 11
                                            color: root.txt2
                                        }
                                    }

                                    Image {
                                        visible: isActive
                                        width: 20; height: 20; smooth: true
                                        sourceSize: Qt.size(40, 40)
                                        source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + toHex(root.hi) + '" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>')
                                    }
                                }

                                MouseArea {
                                    id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.powerProfile = modelData.id
                                        profileSetSource.connectSource("powerprofilesctl set " + modelData.id)
                                        // Sync con BookOS Settings: escribe el estado compartido que la app lee.
                                        profileSetSource.connectSource("echo '{\"power_profile\":\"" + modelData.id + "\",\"source\":\"applet\",\"ts\":" + Date.now() + "}' > /tmp/bookos-state.json")
                                        if (modelData.cmd && modelData.cmd !== "") extraCmdSource.connectSource(modelData.cmd)
                                    }
                                }
                            }
                        }
                    }
                }

                // TLP info card
                Rectangle {
                    visible: root.powerManager === "tlp"
                    Layout.fillWidth: true; radius: 22
                    color: root.card; border.width: 1; border.color: root.brdCol
                    implicitHeight: 58
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                        Rectangle { width: 30; height: 30; radius: 15; color: root.colCharging
                            PlasmaComponents.Label { anchors.centerIn: parent; text: "✓"; color: "#fff"; font.pixelSize: 16; font.weight: Font.Bold }
                        }
                        ColumnLayout { spacing: 1
                            PlasmaComponents.Label { text: "TLP Activo"; font.family: root.resolvedFont; font.pixelSize: 14; font.weight: Font.Medium; color: root.txt }
                            PlasmaComponents.Label { text: "Gestión automática de energía"; font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2 }
                        }
                    }
                }

                PlasmaComponents.Label {
                    visible: root.powerManager === "none" || root.powerManager === "detecting"
                    text: root.powerManager === "detecting" ? "Detectando gestor..." : "Sin gestor de energía"
                    font.family: root.resolvedFont; font.pixelSize: 12; color: root.txt2
                    Layout.leftMargin: 4
                }

                // intel_lpmd chip-card
                Rectangle {
                    visible: root.hasIntelLpmd
                    Layout.fillWidth: true; radius: 18
                    color: root.card; border.width: 1; border.color: root.brdCol
                    implicitHeight: 48
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; spacing: 10
                        Rectangle {
                            width: 8; height: 8; radius: 4; color: root.hi
                            SequentialAnimation on opacity {
                                running: true; loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.4; duration: 1200; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.4; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
                            }
                        }
                        PlasmaComponents.Label { text: "intel_lpmd activo"; font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.Medium; color: root.txt }
                        Item { Layout.fillWidth: true }
                        PlasmaComponents.Label {
                            visible: root.lpmdMode !== "unknown" && root.lpmdMode !== "na" && root.lpmdMode !== ""
                            text: root.lpmdMode; font.family: root.resolvedFont; font.pixelSize: 11
                            color: root.txt2
                        }
                    }
                }

                // ── CARD: Bluetooth ──────────────────────────────────
                Rectangle {
                    visible: root.btDevices.length > 0
                    Layout.fillWidth: true; radius: 22
                    color: root.card; border.width: 1; border.color: root.brdCol
                    clip: true
                    implicitHeight: btCol.implicitHeight

                    ColumnLayout {
                        id: btCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: 0
                        Repeater {
                            model: root.btDevices
                            delegate: Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 44
                                Rectangle {
                                    visible: index < root.btDevices.length - 1
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16 }
                                    height: 1; color: root.divCol
                                }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
                                    PlasmaComponents.Label { text: modelData.icon || "📡"; font.pixelSize: 16 }
                                    PlasmaComponents.Label { text: modelData.name; font.family: root.resolvedFont; font.pixelSize: 13; color: root.txt; Layout.fillWidth: true; elide: Text.ElideRight }
                                    PlasmaComponents.Label {
                                        visible: modelData.pct > 0; text: modelData.pct + "%"
                                        font.family: root.resolvedFont; font.pixelSize: 12
                                        color: modelData.pct <= 20 ? root.colCritical : root.txt2
                                    }
                                }
                            }
                        }
                    }
                }

                // ── CARD: Consumo + Preferencias ─────────────────────
                Rectangle {
                    Layout.fillWidth: true; radius: 22
                    color: root.card; border.width: 1; border.color: root.brdCol
                    clip: true
                    implicitHeight: actionsCol.implicitHeight

                    ColumnLayout {
                        id: actionsCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: 0

                        // Consumo
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 56
                            Rectangle {
                                anchors.fill: parent
                                color: sysMonMouse.containsMouse ? root.hovCol : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            Rectangle {
                                visible: !sysMonMouse.containsMouse && !prefMouse.containsMouse
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 20 }
                                height: 1; color: root.divCol; z: 2
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 18; spacing: 14
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06)
                                    Image {
                                        anchors.centerIn: parent; width: 18; height: 18; smooth: true; sourceSize: Qt.size(36, 36)
                                        source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + toHex(root.txt) + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h3l2-7 4 14 2-7h3"/></svg>')
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    PlasmaComponents.Label { text: "Consumo de energía"; font.family: root.resolvedFont; font.pixelSize: 14; font.weight: Font.Medium; color: root.txt }
                                    PlasmaComponents.Label {
                                        text: (root.topProcess && !root.topProcess.includes("0% CPU"))
                                            ? root.topProcess
                                            : "Sin apps con consumo significativo"
                                        font.family: root.resolvedFont; font.pixelSize: 11
                                        color: root.txt2; Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                }
                                PlasmaComponents.Label { text: "›"; font.pixelSize: 18; font.weight: Font.Medium; color: root.txt2; opacity: 0.6 }
                            }
                            MouseArea { id: sysMonMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.expanded = false; actionSource.connectSource("plasma-systemmonitor") } }
                        }

                        // Preferencias
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 56
                            Rectangle {
                                anchors.fill: parent
                                color: prefMouse.containsMouse ? root.hovCol : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 18; spacing: 14
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06)
                                    Image {
                                        anchors.centerIn: parent; width: 18; height: 18; smooth: true; sourceSize: Qt.size(36, 36)
                                        source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + toHex(root.txt) + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" y1="6" x2="14" y2="6"/><line x1="18" y1="6" x2="20" y2="6"/><circle cx="16" cy="6" r="2" fill="' + toHex(root.card) + '"/><line x1="4" y1="12" x2="8" y2="12"/><line x1="12" y1="12" x2="20" y2="12"/><circle cx="10" cy="12" r="2" fill="' + toHex(root.card) + '"/><line x1="4" y1="18" x2="12" y2="18"/><line x1="16" y1="18" x2="20" y2="18"/><circle cx="14" cy="18" r="2" fill="' + toHex(root.card) + '"/></svg>')
                                    }
                                }
                                PlasmaComponents.Label { text: "Preferencias de Batería"; font.family: root.resolvedFont; font.pixelSize: 14; font.weight: Font.Medium; color: root.txt }
                                Item { Layout.fillWidth: true }
                                PlasmaComponents.Label { text: "›"; font.pixelSize: 18; font.weight: Font.Medium; color: root.txt2; opacity: 0.6 }
                            }
                            MouseArea { id: prefMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.expanded = false; actionSource.connectSource("sh -c 'echo bateria > /tmp/bookos-start-page; gtk-launch bookos-settings.desktop 2>/dev/null || bookos-settings --page bateria || kcmshell6 powerdevilprofilesconfig'") } }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // DATA SOURCES — detección rápida
    // ═════════════════════════════════════════════════════════════════════
    readonly property bool popupOpen: root.expanded

    // Status cada 1.5s
    Plasma5Support.DataSource {
        id: statusSource; engine: "executable"
        connectedSources: [
            "sh -c 'bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); " +
            "if [ -n \"$bat\" ]; then c=$(cat \"$bat/capacity\"); s=$(cat \"$bat/status\"); else c=-1; s=Unknown; fi; " +
            "o=$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -n1 || echo -1); " +
            "echo ${c:--1}; echo ${s:-Unknown}; echo ${o:--1}'"
        ]
        interval: 1500
        onNewData: (sourceName, data) => {
            if (!data["stdout"]) return
            var lines = data["stdout"].trim().split('\n')
            if (lines.length >= 1 && !isNaN(parseInt(lines[0]))) root.percentage = parseInt(lines[0])
            if (lines.length >= 2) { var s = lines[1].trim(); root.isCharging = (s === "Charging"); root.isPlugged = (s === "Full" || s === "Not charging" || s === "Charging") }
            if (lines.length >= 3 && lines[2].trim() === "1") root.isPlugged = true
            if (!root.initializedState) { root.lastCharging = root.isCharging; root.lastPlugged = root.isPlugged; root.initializedState = true }
        }
    }

    // (AC fast watcher removed — statusSource already reports AC online every poll)

    // ── Hardware battery reader — reads sysfs directly (no upower dependency) ──
    Plasma5Support.DataSource {
        id: batterySource; engine: "executable"
        connectedSources: [
            "sh -c 'bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1); " +
            "if [ -z \"$bat\" ]; then echo \"-1|-1|-1|-1|-1|-1|-1|-1\"; exit; fi; " +
            // temp (decidegrees or millidegrees)
            "temp=$(cat \"$bat/temp\" 2>/dev/null || echo -1); " +
            // power: try power_now first (µW), else voltage*current
            "pnow=$(cat \"$bat/power_now\" 2>/dev/null || echo 0); " +
            "if [ \"$pnow\" = \"0\" ] || [ -z \"$pnow\" ]; then " +
            "  vnow=$(cat \"$bat/voltage_now\" 2>/dev/null || echo 0); " +
            "  cnow=$(cat \"$bat/current_now\" 2>/dev/null || echo 0); " +
            "  pnow=$(echo \"$vnow $cnow\" | awk \"{printf \\\"%.0f\\\", \\$1 * \\$2 / 1000000}\"); " +
            "fi; " +
            // energy values (µWh)
            "enow=$(cat \"$bat/energy_now\" 2>/dev/null || echo -1); " +
            "efull=$(cat \"$bat/energy_full\" 2>/dev/null || echo -1); " +
            "edesign=$(cat \"$bat/energy_full_design\" 2>/dev/null || echo -1); " +
            // charge cycles
            "cycles=$(cat \"$bat/cycle_count\" 2>/dev/null || echo -1); " +
            // charge threshold
            "thresh=$(cat \"$bat/charge_control_end_threshold\" 2>/dev/null || echo 100); " +
            "echo \"$temp|$pnow|$enow|$efull|$edesign|$cycles|$thresh\"'"
        ]
        // popup shows live detail; in panel a slower cadence is plenty
        interval: root.popupOpen ? 3000 : 10000
        onNewData: (sourceName, data) => {
            if (!data["stdout"]) return
            var parts = data["stdout"].trim().split("|")
            if (parts.length < 7) return

            // Temperature (decidegrees → °C)
            var t = parseInt(parts[0])
            if (t > 0) root.batteryTemp = t > 1000 ? t / 10.0 : t / 1.0

            // Power (µW → W)
            var pw = parseFloat(parts[1])
            if (pw > 0) root.energyRate = pw / 1000000.0

            // Energy (µWh → Wh)
            var en = parseFloat(parts[2])
            var ef = parseFloat(parts[3])
            var ed = parseFloat(parts[4])
            if (en > 0) root.energyNow = en / 1000000.0
            if (ef > 0) root.energyFull = ef / 1000000.0
            if (ed > 0) root.energyFullDesign = ed / 1000000.0

            // Health %
            if (ef > 0 && ed > 0) root.batteryHealthPct = Math.round((ef / ed) * 100)

            // Cycles
            var cy = parseInt(parts[5])
            if (cy > 0) root.chargeCycles = cy

            // Charge threshold
            var th = parseInt(parts[6])
            if (th > 0 && th <= 100) root.chargeThreshold = th

            // Smart charge limit: plugged + not charging + at/above threshold
            root.isChargeLimited = root.isPlugged && !root.isCharging && root.percentage >= root.chargeThreshold - 1

            // JS time estimation (instant, no external process)
            root.calcTimeRemaining()
        }
    }

    Plasma5Support.DataSource {
        id: managerDetectSource; engine: "executable"
        connectedSources: ["sh -c 'if systemctl is-active --quiet power-profiles-daemon 2>/dev/null; then echo ppd; elif systemctl is-active --quiet tlp 2>/dev/null || command -v tlp >/dev/null; then echo tlp; else echo none; fi'"]
        interval: 30000
        onNewData: (sourceName, data) => { if (data["stdout"]) root.powerManager = root.resolveManager(data["stdout"].trim() || "none") }
    }

    Plasma5Support.DataSource {
        id: profileSource; engine: "executable"
        connectedSources: root.powerManager === "ppd" ? ["powerprofilesctl get"] : []
        interval: root.popupOpen ? 4000 : 15000
        onNewData: (sourceName, data) => { if (data["stdout"]) { var p = data["stdout"].trim(); if (p !== "") root.powerProfile = p } }
    }

    // timeSource removed — time estimation now done in JS via calcTimeRemaining()

    Plasma5Support.DataSource {
        id: topSource; engine: "executable"
        connectedSources: root.popupOpen ? ["sh -c 'ps -eo comm,pcpu --sort=-pcpu 2>/dev/null | awk \"NR==2 && \\$2+0 > 5 {printf \\\"%s (%.0f%% CPU)\\\", \\$1, \\$2}\"'"] : []
        interval: 5000
        onNewData: (sourceName, data) => { root.topProcess = data["stdout"] ? data["stdout"].trim() : "" }
    }

    Plasma5Support.DataSource {
        id: btSource; engine: "executable"
        connectedSources: root.popupOpen ? [
            "sh -c 'bluetoothctl devices Connected 2>/dev/null | awk \"{print \\$2}\" | while read mac; do " +
            "  friendly=$(bluetoothctl info \"$mac\" 2>/dev/null | grep -i \"Name:\" | head -n1 | sed \"s/.*Name: //\"); " +
            "  [ -z \"$friendly\" ] && continue; " +
            "  mac_under=$(echo \"$mac\" | tr \":\" \"_\"); " +
            "  pct=$(upower -e 2>/dev/null | grep -i \"$mac_under\" | head -n1 | xargs -I{} upower -i {} 2>/dev/null | grep -i percentage | awk \"{print \\$2}\" | tr -d \"%\"); " +
            "  echo \"${friendly}|${pct:-0}\"; done | sort -u'"
        ] : []
        interval: 15000
        onNewData: (sourceName, data) => {
            if (!data["stdout"]) { root.btDevices = []; return }
            var lines = data["stdout"].trim().split('\n').filter(function(l) { return l.includes("|") })
            root.btDevices = lines.map(function(l) { var p = l.split("|"); return { name: p[0].trim(), pct: parseInt(p[1].trim()) || 0, icon: root.btIcon(p[0].trim()) } }).filter(function(d) { return d.name !== "" })
        }
    }

    Plasma5Support.DataSource { id: profileSetSource; engine: "executable"; connectedSources: []; onNewData: (s,d) => { disconnectSource(s) } }
    Plasma5Support.DataSource { id: extraCmdSource;   engine: "executable"; connectedSources: []; onNewData: (s,d) => { disconnectSource(s) } }
    Plasma5Support.DataSource { id: actionSource;     engine: "executable"; connectedSources: []; onNewData: (s,d) => { disconnectSource(s) } }
    Plasma5Support.DataSource { id: notifySource;     engine: "executable"; connectedSources: []; onNewData: (s,d) => { disconnectSource(s) } }

    Plasma5Support.DataSource {
        id: lpmdSource; engine: "executable"
        connectedSources: ["sh -c 'if systemctl is-active --quiet intel_lpmd 2>/dev/null; then mode=$(cat /sys/devices/system/cpu/intel_lpmd/mode 2>/dev/null || echo unknown); echo active; echo $mode; else echo inactive; echo na; fi'"]
        interval: 15000
        onNewData: (sourceName, data) => {
            if (!data["stdout"]) return
            var lines = data["stdout"].trim().split('\n')
            root.hasIntelLpmd = lines[0].trim() === "active"
            root.lpmdMode = lines.length >= 2 ? lines[1].trim() : "unknown"
        }
    }
}
