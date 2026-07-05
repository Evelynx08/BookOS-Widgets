import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.brightnesscontrolplugin as BC
import org.kde.notificationmanager as NotificationManager
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── ESTADO ───────────────────────────────────────────────────────────
    property bool wifiOn:    true
    property bool btOn:      false
    property int  volume:    50
    property bool muted:     false
    property bool dragging:  false
    property bool nightOn:   !BC.NightLightInhibitor.inhibited
    property bool dndOn:     false
    property bool airplaneOn:   false
    property bool saverOn:      false
    property bool keepScreenOn: false

    // perfil de usuario
    property string userName: ""
    property string userId:   ""
    property string facePath: ""

    Connections {
        target: BC.NightLightInhibitor
        function onInhibitedChanged() { root.nightOn = !BC.NightLightInhibitor.inhibited }
    }

    // ── Brillo de pantalla (PowerDevil vía DBus — fiable) ────────────────
    readonly property string brPath: "org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl org.kde.Solid.PowerManagement.Actions.BrightnessControl"
    property real brVal: 0
    property real brMax: 0
    readonly property bool brAvail: brMax > 0
    readonly property int  brightness: brMax > 0 ? Math.round(brVal / brMax * 100) : 0

    // ── Detalle Wi-Fi / Bluetooth (One UI: tocar cuerpo abre lista) ──────
    property string page: "main"     // "main" | "wifi" | "bluetooth"
    property var networks: []        // [{ssid, signal, secure, active}]
    property var btDevices: []       // [{name, mac, connected, type}]
    function btType(name) {
        var n = (name || "").toLowerCase()
        if (n.includes("buds") || n.includes("airpod") || n.includes("headphone") || n.includes("headset") || n.includes("wh-") || n.includes("wf-")) return "headphones"
        if (n.includes("speaker") || n.includes("altavoz")) return "speaker"
        if (n.includes("mouse") || n.includes("ratón")) return "mouse"
        if (n.includes("keyboard") || n.includes("teclado")) return "keyboard"
        if (n.includes("phone") || n.includes("galaxy") || n.includes("pixel") || n.includes("iphone") || n.includes("redmi")) return "phone"
        if (n.includes("watch") || n.includes("band")) return "watch"
        if (n.includes("pc") || n.includes("laptop") || n.includes("desktop") || n.includes("call")) return "laptop"
        return "bt"
    }
    function connectNet(ssid) {
        cmd.run("sh -c 'nmcli connection up id \"" + ssid.replace(/"/g,'') + "\" 2>/dev/null || nmcli device wifi connect \"" + ssid.replace(/"/g,'') + "\"'")
        listTimer.restart()
    }
    function toggleBtDev(d) {
        if (!d.mac) return
        cmd.run("bluetoothctl " + (d.connected ? "disconnect" : "connect") + " " + d.mac)
        listTimer.restart()
    }
    Timer { id: listTimer; interval: 1800; onTriggered: { wifiListSrc.refresh(); btListSrc.refresh() } }

    // ── Tiles del grid (configurables: 1–4 filas) ────────────────────────
    property int gridRows: Plasmoid.configuration.gridRows || 2
    property string headerAlign: Plasmoid.configuration.headerAlign || "right"
    // orden de secciones (reordenable)
    property string sectionOrder: Plasmoid.configuration.sectionOrder || "connectivity,grid,sliders,media"
    readonly property var sectionList: sectionOrder.split(",").filter(function(s){ return s.trim() !== "" })
    function sectionLabel(id) {
        switch (id) {
        case "connectivity": return tr("Conectividad","Connectivity")
        case "grid":         return tr("Accesos rápidos","Quick toggles")
        case "sliders":      return tr("Brillo y volumen","Brightness & volume")
        case "media":        return tr("Reproductor","Media player")
        default:             return id
        }
    }
    function sectionIcon(id) {
        switch (id) {
        case "connectivity": return "wifi"
        case "grid":         return "sliders"
        case "sliders":      return "sun"
        case "media":        return "volhigh"
        default:             return "settings"
        }
    }
    function moveSection(from, to) {
        var l = sectionList.slice()
        if (from < 0 || from >= l.length || to < 0 || to >= l.length) return
        var it = l.splice(from, 1)[0]
        l.splice(to, 0, it)
        Plasmoid.configuration.sectionOrder = l.join(",")
    }

    // ── Modo edición en el sitio (reordenar arrastrando) ─────────────────
    property bool editing: false
    ListModel { id: workModel }
    function startEdit() {
        workModel.clear()
        var l = root.sectionList
        for (var i = 0; i < l.length; i++) workModel.append({ sid: l[i] })
        root.editing = true
    }
    function commitEdit() {
        var ids = []
        for (var i = 0; i < workModel.count; i++) ids.push(workModel.get(i).sid)
        Plasmoid.configuration.sectionOrder = ids.join(",")
        root.editing = false
    }
    function cancelEdit() { root.editing = false }   // descarta cambios sin guardar
    readonly property var allTiles: [
        { id: "airplane",   tipEs: "Modo avión",     tipEn: "Airplane mode",  toggle: true },
        { id: "dnd",        tipEs: "No molestar",    tipEn: "Do Not Disturb", toggle: true },
        { id: "saver",      tipEs: "Ahorro energía", tipEn: "Power Saver",     toggle: true },
        { id: "keepon",     tipEs: "Mantener pantalla", tipEn: "Keep screen on", toggle: true },
        { id: "night",      tipEs: "Luz nocturna",   tipEn: "Night Light",    toggle: true },
        { id: "dark",       tipEs: "Modo oscuro",    tipEn: "Dark Mode",      toggle: true },
        { id: "share",      tipEs: "Book Share",     tipEn: "Book Share",     toggle: false },
        { id: "screenshot", tipEs: "Captura",        tipEn: "Screenshot",     toggle: false },
        { id: "lock",       tipEs: "Bloquear",       tipEn: "Lock",           toggle: false },
        { id: "settings",   tipEs: "Ajustes",        tipEn: "Settings",       toggle: false },
        { id: "suspend",    tipEs: "Suspender",      tipEn: "Suspend",        toggle: false },
        { id: "colorpick",  tipEs: "Captura región", tipEn: "Region capture", toggle: false }
    ]
    readonly property int maxRows: 4
    // tiles habilitados (editable) en orden
    property string enabledTiles: Plasmoid.configuration.enabledTiles || "airplane,dnd,saver,keepon,dark,share,screenshot,lock"
    readonly property var enabledList: enabledTiles.split(",").filter(function(s){ return s.trim() !== "" })
    function isTileEnabled(id) { return enabledList.indexOf(id) >= 0 }
    function toggleTileEnabled(id) {
        var l = enabledList.slice()
        var i = l.indexOf(id)
        if (i >= 0) l.splice(i, 1); else l.push(id)
        Plasmoid.configuration.enabledTiles = l.join(",")
    }
    // tiles visibles en el grid principal: habilitados, en su orden, limitados por filas
    function tileById(id) { for (var i=0;i<allTiles.length;i++) if (allTiles[i].id===id) return allTiles[i]; return null }
    readonly property var visibleTiles: {
        var out = []
        for (var i = 0; i < enabledList.length && out.length < gridRows*4; i++) {
            var t = tileById(enabledList[i]); if (t) out.push(t)
        }
        return out
    }
    function tileActive(id) {
        switch (id) {
        case "airplane": return airplaneOn
        case "dnd":      return dndOn
        case "saver":    return saverOn
        case "keepon":   return keepScreenOn
        case "night":    return nightOn
        case "dark":     return isDarkMode
        default:         return false
        }
    }
    function tileIcon(id) {
        switch (id) {
        case "airplane": return "airplane"
        case "dnd":      return dndOn ? "belloff" : "bell"
        case "saver":    return "leaf"
        case "keepon":   return "eye"
        case "night":    return "night"
        case "dark":     return isDarkMode ? "moon" : "dark"
        case "share":    return "share"
        case "screenshot": return "screenshot"
        case "colorpick":  return "screenshot"
        case "lock":     return "lock-s"
        case "settings": return "settings"
        case "suspend":  return "suspend"
        default:         return "settings"
        }
    }
    function tileTrigger(id) {
        switch (id) {
        case "airplane": toggleAirplane(); break
        case "dnd":      toggleDnd(); break
        case "saver":    toggleSaver(); break
        case "keepon":   toggleKeepOn(); break
        case "night":    toggleNight(); break
        case "dark":     toggleDark(); break
        case "share":    openSettings("bookshare"); break
        case "screenshot": actScreenshot(); break
        case "colorpick":  root.expanded = false; cmd.run("spectacle -r"); break
        case "lock":     actLock(); break
        case "settings": openSettings(""); break
        case "suspend":  actSuspend(); break
        }
    }

    // ── Paleta BookOS adaptable (claro/oscuro, igual que los otros widgets) ──
    readonly property bool isDarkMode: {
        var b = Kirigami.Theme.backgroundColor
        return (b.r + b.g + b.b) / 3.0 < 0.5
    }
    readonly property color bg:       isDarkMode ? Qt.color("#000000") : Qt.color("#FFFFFF")
    readonly property color txt:      isDarkMode ? Qt.color("#FFFFFF") : Qt.color("#000000")
    readonly property color txt2:     Qt.color("#8e8e93")
    readonly property color accent:   Qt.color("#4184FF")        // activos / sliders
    readonly property color inactive: Qt.color("#AECAFF")        // toggles desactivados
    // contenedores: #DFDFDF al 80% (claro) / gris oscuro al 80% (oscuro)
    readonly property color container:    isDarkMode ? Qt.rgba(0.16,0.16,0.17,0.80) : Qt.rgba(0.874,0.874,0.874,0.80)
    readonly property color containerHov: isDarkMode ? Qt.rgba(0.22,0.22,0.23,0.85) : Qt.rgba(0.80,0.80,0.80,0.85)
    readonly property color glassBrd:     isDarkMode ? Qt.rgba(1,1,1,0.07) : Qt.rgba(0,0,0,0.04)
    // pista del slider: más clara que el contenedor
    readonly property color trough:   isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.color("#F3F3F3")
    readonly property color shadowCol:isDarkMode ? Qt.rgba(0,0,0,0.55) : Qt.rgba(0,0,0,0.18)
    readonly property color panelIconColor: txt
    readonly property string resolvedFont: Kirigami.Theme.defaultFont.family

    readonly property bool popupOpen: root.expanded
    function tr(es, en) { return Qt.locale().name.indexOf("es") === 0 ? es : en }

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── MPRIS ────────────────────────────────────────────────────────────
    Mpris.Mpris2Model { id: mpris2Model }
    readonly property var  player:    mpris2Model.currentPlayer
    readonly property bool hasMusic:  player && player.canControl
    readonly property string songTitle:  hasMusic ? (player.track  || "") : ""
    readonly property string songArtist: hasMusic ? (player.artist || "") : ""
    readonly property string artUrl:     hasMusic ? (player.artUrl || "") : ""
    readonly property string appName:    hasMusic ? (player.identity || "") : ""
    readonly property bool   isPlaying:  hasMusic && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property real   songLen:    hasMusic ? (player.length || 0) : 0
    property real songPos: 0
    Timer {
        running: root.hasMusic && root.isPlaying && root.popupOpen; interval: 1000; repeat: true
        onTriggered: if (root.hasMusic) { root.player.updatePosition(); root.songPos = root.player.position || 0 }
    }
    Connections {
        target: root.player; ignoreUnknownSignals: true
        function onPositionChanged() { root.songPos = root.player.position || 0 }
    }
    function fmtTime(us) {
        if (!us || us <= 0) return "0:00"
        var s = Math.floor(us / 1000000); var m = Math.floor(s / 60); var ss = s % 60
        return m + ":" + (ss < 10 ? "0" : "") + ss
    }

    // ── DND ──────────────────────────────────────────────────────────────
    NotificationManager.Settings { id: notifSettings }
    function computeDnd() {
        var u = notifSettings.notificationsInhibitedUntil
        if (u && !isNaN(u.getTime()) && Date.now() < u.getTime()) return true
        if (notifSettings.notificationsInhibitedByApplication) return true
        return false
    }
    Connections {
        target: notifSettings
        function onNotificationsInhibitedUntilChanged() { root.dndOn = root.computeDnd() }
        function onNotificationsInhibitedByApplicationChanged() { root.dndOn = root.computeDnd() }
    }
    Component.onCompleted: root.dndOn = computeDnd()
    onExpandedChanged: {
        if (expanded) {
            root.refresh()
        } else {
            // al cerrar: cancela edición y vuelve al inicio (descarta cambios sin guardar)
            root.cancelEdit()
            root.page = "main"
        }
    }

    // ── SVG icons ────────────────────────────────────────────────────────
    function toHex(c) {
        if (!c) return "#888888"
        var s = c.toString()
        if (s.startsWith("#")) return s.length === 9 ? "#" + s.substring(3, 9) : s.substring(0, 7)
        return s
    }
    function svg(body, color, sw) {
        var c = toHex(color); var w = sw || 2
        return "data:image/svg+xml," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + c +
            '" stroke-width="' + w + '" stroke-linecap="round" stroke-linejoin="round">' + body + '</svg>')
    }
    function svgFill(body, color) {
        return "data:image/svg+xml," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="' + toHex(color) + '">' + body + '</svg>')
    }
    function ico(name, color) {
        switch (name) {
        case "wifi":     return svg('<path d="M5 12.55a11 11 0 0 1 14.08 0"/><path d="M1.42 9a16 16 0 0 1 21.16 0"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/>', color)
        case "bt":       return svg('<polyline points="6.5 6.5 17.5 17.5 12 23 12 1 17.5 6.5 6.5 17.5"/>', color)
        case "bell":     return svg('<path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>', color)
        case "belloff":  return svg('<path d="M13.73 21a2 2 0 0 1-3.46 0"/><path d="M18.63 13A17.89 17.89 0 0 1 18 8"/><path d="M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7-3 9-3 9h14"/><path d="M18 8a6 6 0 0 0-9.33-5"/><line x1="1" y1="1" x2="23" y2="23"/>', color)
        case "moon":     return svg('<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>', color)
        case "night":    return svg('<path d="M17 18a5 5 0 0 0-10 0"/><line x1="12" y1="9" x2="12" y2="3"/><line x1="4.22" y1="10.22" x2="5.64" y2="11.64"/><line x1="1" y1="18" x2="3" y2="18"/><line x1="21" y1="18" x2="23" y2="18"/><line x1="18.36" y1="11.64" x2="19.78" y2="10.22"/><line x1="23" y1="22" x2="1" y2="22"/><polyline points="16 5 12 9 8 5"/>', color)
        case "dark":     return svg('<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 0 0 18z" fill="' + toHex(color) + '"/>', color)
        case "screenshot": return svg('<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>', color)
        case "lock":     return svg('<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>', color)
        case "settings": return svg('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>', color)
        case "suspend":  return svg('<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>', color)
        case "power":    return svg('<path d="M18.36 6.64a9 9 0 1 1-12.73 0"/><line x1="12" y1="2" x2="12" y2="12"/>', color)
        case "sun":      return svg('<g transform="translate(2.5 2.5) scale(0.79)"><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></g>', color)
        case "volhigh":  return svg('<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" fill="' + toHex(color) + '"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>', color)
        case "volmute":  return svg('<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" fill="' + toHex(color) + '"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/>', color)
        case "sliders":  return svg('<line x1="4" y1="21" x2="4" y2="14"/><line x1="4" y1="10" x2="4" y2="3"/><line x1="12" y1="21" x2="12" y2="12"/><line x1="12" y1="8" x2="12" y2="3"/><line x1="20" y1="21" x2="20" y2="16"/><line x1="20" y1="12" x2="20" y2="3"/><line x1="1" y1="14" x2="7" y2="14"/><line x1="9" y1="8" x2="15" y2="8"/><line x1="17" y1="16" x2="23" y2="16"/>', color)
        case "airplane": return svgFill('<path d="M21 16v-2l-8-5V3.5a1.5 1.5 0 0 0-3 0V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5z"/>', color)
        case "leaf":     return svg('<path d="M11 20A7 7 0 0 1 9.8 6.9C15.5 4.9 17 3.5 19 2c1 2 2 4.5 1 8-1.5 5.5-4 7-9 10z"/><path d="M10.7 13.8c2.1-1.4 3.3-3.3 4.1-5.5"/>', color)
        case "eye":      return svg('<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>', color)
        case "share":    return svg('<path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"/><polyline points="16 6 12 2 8 6"/><line x1="12" y1="2" x2="12" y2="15"/>', color)
        case "back":     return svg('<polyline points="15 18 9 12 15 6"/>', color, 2.4)
        case "edit":     return svg('<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4z"/>', color)
        case "plus":     return svg('<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>', color, 2.4)
        case "check":    return svg('<polyline points="20 6 9 17 4 12"/>', color, 2.6)
        case "minus":    return svg('<line x1="5" y1="12" x2="19" y2="12"/>', color, 2.6)
        case "lock-s":   return svg('<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>', color)
        case "headphones": return svg('<path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3z"/><path d="M3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/>', color)
        case "speaker":  return svg('<rect x="4" y="2" width="16" height="20" rx="2"/><circle cx="12" cy="14" r="4"/><line x1="12" y1="6" x2="12.01" y2="6"/>', color)
        case "mouse":    return svg('<rect x="6" y="3" width="12" height="18" rx="6"/><line x1="12" y1="7" x2="12" y2="11"/>', color)
        case "keyboard": return svg('<rect x="2" y="6" width="20" height="12" rx="2"/><line x1="6" y1="10" x2="6" y2="10"/><line x1="10" y1="10" x2="10" y2="10"/><line x1="14" y1="10" x2="14" y2="10"/><line x1="18" y1="10" x2="18" y2="10"/><line x1="8" y1="14" x2="16" y2="14"/>', color)
        case "phone":    return svg('<rect x="5" y="2" width="14" height="20" rx="2"/><line x1="12" y1="18" x2="12.01" y2="18"/>', color)
        case "watch":    return svg('<circle cx="12" cy="12" r="6"/><polyline points="12 10 12 12 13 13"/><path d="M16.51 17.35l-.35 3.83a2 2 0 0 1-2 1.82H9.83a2 2 0 0 1-2-1.82l-.35-3.83m.01-10.7l.35-3.83A2 2 0 0 1 9.83 1h4.35a2 2 0 0 1 2 1.82l.35 3.83"/>', color)
        case "laptop":   return svg('<rect x="3" y="4" width="18" height="12" rx="2"/><line x1="2" y1="20" x2="22" y2="20"/>', color)
        default:         return svg('<circle cx="12" cy="12" r="9"/>', color)
        }
    }
    function icoPlay(c)  { return svgFill('<polygon points="6 4 20 12 6 20 6 4"/>', c) }
    function icoPause(c) { return svgFill('<rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/>', c) }
    function icoPrev(c)  { return svgFill('<polygon points="19 20 9 12 19 4 19 20"/><rect x="5" y="4" width="2.5" height="16" rx="1"/>', c) }
    function icoNext(c)  { return svgFill('<polygon points="5 4 15 12 5 20 5 4"/><rect x="16.5" y="4" width="2.5" height="16" rx="1"/>', c) }

    // ═══════════════════════════════════════════════════════════════════════
    // COMPACT
    // ═══════════════════════════════════════════════════════════════════════
    compactRepresentation: Item {
        Layout.preferredWidth:  Math.round(Kirigami.Units.iconSizes.small * 1.15)
        Layout.preferredHeight: Layout.preferredWidth
        implicitWidth:  Layout.preferredWidth
        implicitHeight: Layout.preferredHeight
        PlasmaComponents.ToolTip { text: root.tr("Centro de control","Control Center") }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            onClicked: root.expanded = !root.expanded
            Image {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small; height: width
                sourceSize: Qt.size(width * 2, height * 2); smooth: true
                source: root.ico("sliders", root.panelIconColor)
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FULL — popup (One UI dark glass)
    // ═══════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        id: fullRep
        Layout.minimumWidth: 360; Layout.preferredWidth: 360; Layout.maximumWidth: 360
        // altura dinámica: se ajusta al panel visible (main / detalle / edición)
        readonly property real activeHeight: (root.page === "main" ? popupCol.implicitHeight
            : root.page === "edit" ? editCol.implicitHeight
            : detailCol.implicitHeight) + 36
        Layout.minimumHeight:   activeHeight
        Layout.preferredHeight: activeHeight
        Layout.maximumHeight:   activeHeight
        Behavior on Layout.preferredHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on Layout.maximumHeight { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        function sectionComp(id) {
            return id === "connectivity" ? connComp
                 : id === "grid" ? gridComp
                 : id === "sliders" ? slidersComp
                 : id === "media" ? mediaComp : null
        }

        // fondo BookOS sólido (adaptable claro/oscuro)
        Rectangle {
            anchors.fill: parent; radius: 22
            color: root.bg
            border.width: 1; border.color: root.glassBrd
        }

        property real entryOpacity: 0.0
        property real entryScale: 0.96
        Component.onCompleted: { entryOpacity = 1.0; entryScale = 1.0; root.refresh() }
        opacity: entryOpacity; scale: entryScale
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // ── PANEL DE DETALLE (Wi-Fi / Bluetooth) ─────────────────────────
        ColumnLayout {
            id: detailCol
            readonly property bool shown: root.page === "wifi" || root.page === "bluetooth"
            visible: opacity > 0.01
            opacity: shown ? 1 : 0
            enabled: shown
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20
                    color: backM.containsMouse ? root.containerHov : root.container
                    border.width: 1; border.color: root.glassBrd
                    Image { anchors.centerIn: parent; width: 18; height: 18; sourceSize: Qt.size(36,36); smooth: true; source: root.ico("back", root.txt) }
                    MouseArea { id: backM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "main" }
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true; text: root.page === "wifi" ? "Wi-Fi" : "Bluetooth"
                    font.family: root.resolvedFont; font.pixelSize: 19; font.weight: Font.Bold; color: root.txt
                }
                Rectangle {
                    Layout.preferredWidth: 44; Layout.preferredHeight: 26; radius: 13
                    readonly property bool on: root.page === "wifi" ? root.wifiOn : root.btOn
                    color: on ? root.accent : root.inactive
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Rectangle { width: 20; height: 20; radius: 10; color: "#FFFFFF"; y: 3
                        x: parent.on ? parent.width - width - 3 : 3; Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.page === "wifi" ? root.toggleWifi() : root.toggleBt() }
                }
            }

            Rectangle {
                Layout.fillWidth: true; radius: 22
                color: root.container; border.width: 1; border.color: root.glassBrd
                implicitHeight: Math.min(440, Math.max(70, detailList.contentHeight + 16))
                ListView {
                    id: detailList
                    anchors.fill: parent; anchors.margins: 8; clip: true
                    model: root.page === "wifi" ? root.networks : root.btDevices
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        id: dgI
                        width: detailList.width; height: 52
                        readonly property bool isWifi: root.page === "wifi"
                        readonly property bool lit: isWifi ? (modelData.active === true) : (modelData.connected === true)
                        Rectangle { anchors.fill: parent; radius: 14
                            color: dm.containsMouse ? (root.isDarkMode ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.04)) : "transparent" }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 12
                            Image {
                                width: 24; height: 24; sourceSize: Qt.size(48,48); smooth: true
                                source: dgI.isWifi ? root.ico("wifi", dgI.lit ? root.accent : root.txt)
                                                   : root.ico(modelData.type || "bt", dgI.lit ? root.accent : root.txt)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    text: dgI.isWifi ? modelData.ssid : modelData.name
                                    font.family: root.resolvedFont; font.pixelSize: 14; font.weight: dgI.lit ? Font.DemiBold : Font.Medium
                                    color: dgI.lit ? root.accent : root.txt
                                }
                                PlasmaComponents.Label {
                                    visible: dgI.lit
                                    text: root.tr("Conectado","Connected"); font.family: root.resolvedFont; font.pixelSize: 11; color: root.accent
                                }
                            }
                            Image {
                                visible: dgI.isWifi && modelData.secure === true
                                width: 13; height: 13; sourceSize: Qt.size(26,26); smooth: true; source: root.ico("lock-s", root.txt2)
                            }
                            PlasmaComponents.Label {
                                visible: dgI.isWifi
                                text: (modelData.signal || 0) + "%"; font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2
                            }
                        }
                        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: dgI.isWifi ? root.connectNet(modelData.ssid) : root.toggleBtDev(modelData) }
                    }
                }
            }

            PlasmaComponents.Label {
                visible: detailList.count === 0
                Layout.alignment: Qt.AlignHCenter
                text: (root.page === "wifi" ? (root.wifiOn) : (root.btOn)) ? root.tr("Buscando…","Searching…") : root.tr("Desactivado","Off")
                font.family: root.resolvedFont; font.pixelSize: 12; color: root.txt2
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 20
                    color: detM.containsMouse ? root.containerHov : root.container; border.width: 1; border.color: root.glassBrd
                    PlasmaComponents.Label { anchors.centerIn: parent; text: root.tr("Detalles","Details"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.txt }
                    MouseArea { id: detM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openSettings(root.page === "wifi" ? "wifi" : "bluetooth") }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 20
                    color: doneM.containsMouse ? Qt.lighter(root.accent,1.1) : root.accent
                    PlasmaComponents.Label { anchors.centerIn: parent; text: root.tr("Hecho","Done"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                    MouseArea { id: doneM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "main" }
                }
            }
        }

        // ── PANEL DE EDICIÓN ─────────────────────────────────────────────
        ColumnLayout {
            id: editCol
            visible: opacity > 0.01
            opacity: root.page === "edit" ? 1 : 0
            enabled: root.page === "edit"
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20
                    color: ebackM.containsMouse ? root.containerHov : root.container
                    border.width: 1; border.color: root.glassBrd
                    Image { anchors.centerIn: parent; width: 18; height: 18; sourceSize: Qt.size(36,36); smooth: true; source: root.ico("back", root.txt) }
                    MouseArea { id: ebackM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "main" }
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true; text: root.tr("Editar accesos","Edit shortcuts")
                    font.family: root.resolvedFont; font.pixelSize: 19; font.weight: Font.Bold; color: root.txt
                }
            }

            // selector de filas (límite de visibles)
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                PlasmaComponents.Label { text: root.tr("Filas","Rows"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.Medium; color: root.txt2 }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [1, 2, 3, 4]
                    delegate: Rectangle {
                        Layout.preferredWidth: 38; Layout.preferredHeight: 32; radius: 10
                        readonly property bool sel: root.gridRows === modelData
                        color: sel ? root.accent : (rm.containsMouse ? root.containerHov : root.container)
                        border.width: 1; border.color: root.glassBrd
                        PlasmaComponents.Label { anchors.centerIn: parent; text: modelData; font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: parent.sel ? "#FFFFFF" : root.txt }
                        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Plasmoid.configuration.gridRows = modelData }
                    }
                }
            }

            // selector de posición de los botones del header
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                PlasmaComponents.Label { text: root.tr("Botones","Buttons"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.Medium; color: root.txt2 }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [{ v: "left", es: "Izq.", en: "Left" }, { v: "center", es: "Centro", en: "Center" }, { v: "right", es: "Der.", en: "Right" }]
                    delegate: Rectangle {
                        Layout.preferredWidth: 56; Layout.preferredHeight: 32; radius: 10
                        readonly property bool sel: root.headerAlign === modelData.v
                        color: sel ? root.accent : (am.containsMouse ? root.containerHov : root.container)
                        border.width: 1; border.color: root.glassBrd
                        PlasmaComponents.Label { anchors.centerIn: parent; text: root.tr(modelData.es, modelData.en); font.family: root.resolvedFont; font.pixelSize: 11; font.weight: Font.DemiBold; color: parent.sel ? "#FFFFFF" : root.txt }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Plasmoid.configuration.headerAlign = modelData.v }
                    }
                }
            }

            PlasmaComponents.Label {
                text: root.tr("Toca para mostrar u ocultar","Tap to show or hide")
                font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2
            }

            // todos los tiles disponibles
            Rectangle {
                Layout.fillWidth: true; radius: 24; color: root.container
                border.width: 1; border.color: root.glassBrd
                implicitHeight: editGrid.implicitHeight + 24
                GridLayout {
                    id: editGrid; anchors.centerIn: parent
                    columns: 4; rowSpacing: 14; columnSpacing: 16
                    Repeater {
                        model: root.allTiles
                        delegate: ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter; spacing: 4
                            readonly property bool en: root.isTileEnabled(modelData.id)
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 50; height: 50; radius: 25
                                color: en ? root.accent : root.inactive
                                opacity: en ? 1.0 : 0.6
                                Behavior on color { ColorAnimation { duration: 130 } }
                                scale: em.pressed ? 0.92 : 1.0
                                Behavior on scale { NumberAnimation { duration: 110 } }
                                Image { anchors.centerIn: parent; width: 22; height: 22; sourceSize: Qt.size(44,44); smooth: true
                                    source: root.ico(root.tileIcon(modelData.id), en ? "#FFFFFF" : root.accent) }
                                // badge +/✓
                                Rectangle {
                                    width: 18; height: 18; radius: 9; color: root.bg
                                    anchors { right: parent.right; top: parent.top; rightMargin: -2; topMargin: -2 }
                                    Rectangle { anchors.fill: parent; radius: 9; color: en ? root.accent : root.txt2 }
                                    Image { anchors.centerIn: parent; width: 12; height: 12; sourceSize: Qt.size(24,24); smooth: true
                                        source: root.ico(en ? "check" : "plus", "#FFFFFF") }
                                }
                                MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleTileEnabled(modelData.id) }
                            }
                            PlasmaComponents.Label {
                                Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 64
                                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                text: root.tr(modelData.tipEs, modelData.tipEn)
                                font.family: root.resolvedFont; font.pixelSize: 9; color: root.txt2
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 20
                color: edoneM.containsMouse ? Qt.lighter(root.accent,1.1) : root.accent
                PlasmaComponents.Label { anchors.centerIn: parent; text: root.tr("Hecho","Done"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                MouseArea { id: edoneM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "main" }
            }
        }

        ColumnLayout {
            id: popupCol
            visible: opacity > 0.01
            opacity: root.page === "main" ? 1 : 0
            enabled: root.page === "main"
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            // ── Barra de edición (modo reordenar) ────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 10; visible: root.editing
                Rectangle {
                    Layout.preferredHeight: 40; Layout.preferredWidth: panelSetRow.implicitWidth + 28; radius: 20
                    color: psM.containsMouse ? root.containerHov : root.container
                    border.width: 1; border.color: root.glassBrd
                    RowLayout {
                        id: panelSetRow; anchors.centerIn: parent; spacing: 7
                        Image { width: 17; height: 17; sourceSize: Qt.size(34,34); smooth: true; source: root.ico("settings", root.txt) }
                        PlasmaComponents.Label { text: root.tr("Ajustes del panel","Panel settings"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.txt }
                    }
                    MouseArea { id: psM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "edit" }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredHeight: 40; Layout.preferredWidth: 78; radius: 20
                    color: doneEdM.containsMouse ? Qt.lighter(root.accent,1.1) : root.accent
                    PlasmaComponents.Label { anchors.centerIn: parent; text: root.tr("Hecho","Done"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#FFFFFF" }
                    MouseArea { id: doneEdM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.commitEdit() }
                }
            }
            PlasmaComponents.Label {
                visible: root.editing; Layout.fillWidth: true; Layout.bottomMargin: 2
                horizontalAlignment: Text.AlignHCenter
                text: root.tr("Mantén pulsado y arrastra para cambiar el orden","Hold and drag to reorder")
                font.family: root.resolvedFont; font.pixelSize: 12; color: root.txt2; wrapMode: Text.WordWrap
            }

            // ── Header: perfil + acciones ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true; spacing: 10; visible: !root.editing
                HeaderButtons { visible: root.headerAlign === "left" }
                Rectangle {
                    Layout.fillWidth: root.headerAlign !== "center"; Layout.preferredHeight: 50
                    radius: 25
                    color: profMouse.containsMouse ? root.containerHov : root.container
                    border.width: 1; border.color: root.glassBrd
                    Behavior on color { ColorAnimation { duration: 130 } }
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.shadowCol; shadowVerticalOffset: 3; shadowBlur: 0.45; autoPaddingEnabled: true }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 8; spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            PlasmaComponents.Label {
                                text: root.userName !== "" ? root.userName : root.tr("Usuario","User")
                                font.family: root.resolvedFont; font.pixelSize: 15; font.weight: Font.Bold; color: root.txt
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            PlasmaComponents.Label {
                                visible: root.userId !== ""
                                text: "@" + root.userId
                                font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
                            color: root.accent
                            Image {
                                anchors.fill: parent; visible: root.facePath !== ""
                                source: root.facePath !== "" ? "file://" + root.facePath : ""
                                fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                                layer.enabled: true
                                layer.effect: OpacityMask { maskSource: Rectangle { width: 38; height: 38; radius: 19 } }
                            }
                            PlasmaComponents.Label {
                                visible: root.facePath === ""; anchors.centerIn: parent
                                text: (root.userName !== "" ? root.userName : "U").charAt(0).toUpperCase()
                                font.family: root.resolvedFont; font.pixelSize: 17; font.weight: Font.Bold; color: "#FFFFFF"
                            }
                        }
                    }
                    MouseArea { id: profMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openSettings("accounts") }
                }
                Item { Layout.fillWidth: root.headerAlign === "center" }
                HeaderButtons { visible: root.headerAlign !== "left" }
                Item { Layout.fillWidth: root.headerAlign === "center" }
            }

            // ── Secciones (normal) ───────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true; spacing: 12
                visible: !root.editing
                Repeater {
                    model: root.sectionList
                    delegate: Loader {
                        Layout.fillWidth: true
                        sourceComponent: fullRep.sectionComp(modelData)
                    }
                }
            }

            // ── Secciones (modo edición: arrastrar para reordenar) ───────
            ListView {
                id: editList
                visible: root.editing
                Layout.fillWidth: true
                Layout.preferredHeight: contentHeight
                interactive: false
                spacing: 12
                model: workModel
                cacheBuffer: 100000
                displaced: Transition { NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.OutCubic } }
                delegate: dropDelegate
            }
        }

        // delegado reordenable (DropArea + item arrastrable)
        Component {
            id: dropDelegate
            DropArea {
                id: da
                width: editList.width
                height: tileWrap.implicitHeight
                property int visualIndex: index
                onEntered: (drag) => {
                    var from = drag.source.visualIndex
                    if (from !== da.visualIndex) workModel.move(from, da.visualIndex, 1)
                }
                Item {
                    id: tileWrap
                    property int visualIndex: da.visualIndex
                    width: da.width
                    implicitHeight: Math.max(56, ldr.item ? ldr.item.implicitHeight : 56)
                    height: implicitHeight
                    Drag.active: dragMA.drag.active
                    Drag.source: tileWrap
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    opacity: dragMA.drag.active ? 0.85 : 0.55
                    scale: dragMA.drag.active ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Loader {
                        id: ldr; width: parent.width
                        enabled: false   // contenido no interactivo en edición
                        sourceComponent: fullRep.sectionComp(model.sid)
                    }
                    MouseArea {
                        id: dragMA; anchors.fill: parent
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: tileWrap; drag.axis: Drag.YAxis
                        onReleased: tileWrap.Drag.drop()
                    }
                    states: State {
                        when: dragMA.drag.active
                        ParentChange { target: tileWrap; parent: editList }
                    }
                }
            }
        }

        // ═══ COMPONENTES DE SECCIÓN (reordenables) ═══════════════════════
        Component {
            id: connComp
            // Wi-Fi y Bluetooth: dos cajas independientes (se mueven como bloque)
            RowLayout {
                spacing: 10
                BigPill {
                    label: "Wi-Fi"; iconName: "wifi"; active: root.wifiOn
                    sub: root.wifiOn ? root.tr("Activado","On") : root.tr("Desactivado","Off")
                    onToggled: root.toggleWifi(); onOpened: root.page = "wifi"
                }
                BigPill {
                    label: "Bluetooth"; iconName: "bt"; active: root.btOn
                    sub: root.btOn ? root.tr("Activado","On") : root.tr("Desactivado","Off")
                    onToggled: root.toggleBt(); onOpened: root.page = "bluetooth"
                }
            }
        }

        Component {
            id: gridComp
            Rectangle {
                Layout.fillWidth: true; radius: 24; color: root.container
                border.width: 1; border.color: root.glassBrd
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.shadowCol; shadowVerticalOffset: 3; shadowBlur: 0.45; autoPaddingEnabled: true }
                implicitHeight: grid.implicitHeight + 22 + (handle.visible ? 14 : 0)
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 6
                    GridLayout {
                        id: grid
                        Layout.alignment: Qt.AlignHCenter
                        columns: 4; rowSpacing: 16; columnSpacing: 22
                        Repeater {
                            model: root.visibleTiles
                            delegate: Circle {
                                iconName: root.tileIcon(modelData.id)
                                tip: root.tr(modelData.tipEs, modelData.tipEn)
                                toggle: modelData.toggle
                                active: root.tileActive(modelData.id)
                                onActivated: root.tileTrigger(modelData.id)
                            }
                        }
                    }
                    Rectangle {
                        id: handle
                        visible: root.maxRows > 1
                        Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 2
                        width: 38; height: 5; radius: 2.5
                        color: root.txt2; opacity: hMouse.containsMouse ? 0.7 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        MouseArea {
                            id: hMouse; anchors.fill: parent; anchors.margins: -12
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var n = root.gridRows + 1
                                if (n > root.maxRows) n = 1
                                Plasmoid.configuration.gridRows = n
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: slidersComp
            Rectangle {
                Layout.fillWidth: true; radius: 24; color: root.container
                border.width: 1; border.color: root.glassBrd
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.shadowCol; shadowVerticalOffset: 3; shadowBlur: 0.45; autoPaddingEnabled: true }
                implicitHeight: slidersCol.implicitHeight + 28
                ColumnLayout {
                    id: slidersCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 16 }
                    spacing: 12
                    SliderRow {
                        visible: root.brAvail
                        value: root.brightness; insetIcon: "sun"
                        fillColor: root.accent
                        sideActive: root.nightOn; sideAccent: root.accent; sideIcon: "moon"
                        onMovedTo: (v) => root.setBrightness(Math.max(1, v))
                        onSideClicked: root.toggleNight()
                    }
                    SliderRow {
                        value: root.muted ? 0 : root.volume; insetIcon: root.muted ? "volmute" : "volhigh"
                        fillColor: root.accent
                        sideActive: !root.muted; sideAccent: root.accent; sideIcon: root.muted ? "volmute" : "volhigh"
                        onMovedTo: (v) => root.setVolume(v)
                        onReleasedSlider: root.playFeedback()
                        onSideClicked: root.toggleMute()
                    }
                }
            }
        }

        Component {
            id: mediaComp
            Rectangle {
                visible: root.hasMusic
                Layout.fillWidth: true
                implicitHeight: root.hasMusic ? 150 : 0
                radius: 24; clip: true
                color: "#1b1d22"
                Image { id: artBg; anchors.fill: parent; visible: false; source: root.artUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                FastBlur { anchors.fill: parent; source: artBg; radius: 80; visible: root.artUrl !== "" }
                Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0, root.artUrl !== "" ? 0.42 : 0.0) }
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 14
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true; spacing: 7
                        Rectangle { width: 8; height: 8; radius: 4; color: "#FFFFFF"; opacity: 0.85 }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: root.appName !== "" ? root.appName : "Reproductor"
                            font.family: root.resolvedFont; font.pixelSize: 11; color: "#FFFFFF"; opacity: 0.85
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: root.songTitle !== "" ? root.songTitle : root.tr("Sin reproducción","Nothing playing")
                        font.family: root.resolvedFont; font.pixelSize: 15; font.weight: Font.Bold; color: "#FFFFFF"
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true; elide: Text.ElideRight; visible: root.songArtist !== ""
                        text: root.songArtist; font.family: root.resolvedFont; font.pixelSize: 12; color: "#FFFFFF"; opacity: 0.8
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8; visible: root.songLen > 0
                        PlasmaComponents.Label { text: root.fmtTime(root.songPos); font.family: root.resolvedFont; font.pixelSize: 10; color: "#FFFFFF"; opacity: 0.8 }
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 14
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Qt.rgba(1,1,1,0.30) }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 4; radius: 2; color: "#FFFFFF"
                                width: parent.width * (root.songLen > 0 ? Math.min(1, root.songPos / root.songLen) : 0) }
                            Rectangle { width: 11; height: 11; radius: 5.5; color: "#FFFFFF"; anchors.verticalCenter: parent.verticalCenter
                                x: (parent.width - width) * (root.songLen > 0 ? Math.min(1, root.songPos / root.songLen) : 0) }
                            MouseArea { anchors.fill: parent; enabled: root.hasMusic && (root.player.canSeek || false)
                                onClicked: (m) => root.seek(Math.min(1, Math.max(0, m.x / width))) }
                        }
                        PlasmaComponents.Label { text: root.fmtTime(root.songLen); font.family: root.resolvedFont; font.pixelSize: 10; color: "#FFFFFF"; opacity: 0.8 }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 26
                        MediaBtn { iconSrc: root.icoPrev("#FFFFFF"); size: 24; onActivated: { if (root.hasMusic) root.player.Previous() } }
                        MediaBtn { iconSrc: root.isPlaying ? root.icoPause("#FFFFFF") : root.icoPlay("#FFFFFF"); size: 30; onActivated: { if (root.hasMusic) root.player.PlayPause() } }
                        MediaBtn { iconSrc: root.icoNext("#FFFFFF"); size: 24; onActivated: { if (root.hasMusic) root.player.Next() } }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // COMPONENTES
    // ═══════════════════════════════════════════════════════════════════════
    component CircleBtn: Rectangle {
        property string iconName: ""
        signal activated
        Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 19
        color: cbm.containsMouse ? root.containerHov : root.container
        Behavior on color { ColorAnimation { duration: 130 } }
        scale: cbm.pressed ? 0.90 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Image { anchors.centerIn: parent; width: 17; height: 17; sourceSize: Qt.size(34,34); smooth: true
            source: root.ico(iconName, root.txt) }
        MouseArea { id: cbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activated() }
    }

    component HeaderButtons: RowLayout {
        spacing: 10
        CircleBtn { iconName: "edit"; onActivated: root.startEdit() }
        CircleBtn { iconName: "power"; onActivated: root.actPower() }
        CircleBtn { iconName: "settings"; onActivated: root.openSettings("") }
    }

    component BigPill: Rectangle {
        id: pill
        property string label: ""
        property string iconName: ""
        property bool active: false
        property string sub: ""
        property bool flat: false     // dentro de un contenedor compartido
        signal toggled        // tocar el icono → enciende/apaga
        signal opened         // tocar el cuerpo → abre detalle
        Layout.fillWidth: true; Layout.preferredHeight: 64
        radius: 22
        color: flat ? (pmouse.containsMouse ? Qt.rgba(0,0,0, root.isDarkMode ? 0 : 0.03) : "transparent")
                    : (pmouse.containsMouse ? root.containerHov : root.container)
        border.width: flat ? 0 : 1; border.color: root.glassBrd
        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        layer.enabled: !flat
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.shadowCol; shadowVerticalOffset: 3; shadowBlur: 0.45; autoPaddingEnabled: true }
        // punch del cuerpo al abrir
        SequentialAnimation {
            id: bodyPulse
            NumberAnimation { target: pill; property: "scale"; to: 0.97; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: pill; property: "scale"; to: 1.0; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
        }
        // cuerpo: abre el detalle
        MouseArea { id: pmouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onPressed: bodyPulse.restart()
            onClicked: pill.opened() }
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 14; spacing: 12
            // icono: enciende/apaga (su propio área, encima del cuerpo)
            Rectangle {
                id: iconCirc
                Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 22
                color: pill.active ? root.accent : root.inactive
                Behavior on color { ColorAnimation { duration: 200 } }
                Image { anchors.centerIn: parent; width: 22; height: 22; sourceSize: Qt.size(44,44); smooth: true
                    source: root.ico(pill.iconName, pill.active ? "#FFFFFF" : root.accent) }
                SequentialAnimation {
                    id: iconPulse
                    NumberAnimation { target: iconCirc; property: "scale"; to: 0.82; duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: iconCirc; property: "scale"; to: 1.0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.8 }
                }
                MouseArea { id: imouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onPressed: iconPulse.restart()
                    onClicked: pill.toggled() }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                PlasmaComponents.Label {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    text: pill.label; font.family: root.resolvedFont; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.txt
                }
                PlasmaComponents.Label {
                    visible: pill.sub !== ""; Layout.fillWidth: true; elide: Text.ElideRight
                    text: pill.sub; font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2
                }
            }
        }
    }

    component Circle: Item {
        id: circ
        property string iconName: ""
        property string tip: ""
        property bool toggle: false
        property bool active: false
        property color accentCol: root.accent
        signal activated
        Layout.preferredWidth: 52; Layout.preferredHeight: 52
        PlasmaComponents.ToolTip { text: tip; visible: cm.containsMouse && tip !== "" }
        readonly property bool litUp: !toggle || active   // acción o toggle activo → azul
        // animación de entrada (pop)
        opacity: 0
        Component.onCompleted: { opacity = 1; scale = 1 }
        scale: 0.6
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        Rectangle {
            id: circBg
            anchors.fill: parent; radius: width / 2
            color: litUp ? (cm.containsMouse ? Qt.lighter(accentCol, 1.10) : accentCol)
                         : (cm.containsMouse ? Qt.darker(root.inactive, 1.05) : root.inactive)
            Behavior on color { ColorAnimation { duration: 180 } }
            Image {
                anchors.centerIn: parent; width: 23; height: 23; sourceSize: Qt.size(46,46); smooth: true
                source: root.ico(iconName, litUp ? "#FFFFFF" : root.accent)
            }
        }
        SequentialAnimation {
            id: pulse
            NumberAnimation { target: circBg; property: "scale"; to: 0.84; duration: 90; easing.type: Easing.OutQuad }
            NumberAnimation { target: circBg; property: "scale"; to: 1.0; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onPressed: pulse.restart()
            onClicked: circ.activated() }
    }

    component SliderRow: RowLayout {
        id: srow
        property int value: 0
        property int dragVal: 0
        property bool sliding: false
        property string insetIcon: ""
        property color fillColor: root.accent
        property bool sideActive: false
        property color sideAccent: root.accent
        property string sideIcon: ""
        signal movedTo(int v)
        signal releasedSlider
        signal sideClicked
        Layout.fillWidth: true; spacing: 12

        Item {
            id: track
            Layout.fillWidth: true; Layout.preferredHeight: 40
            // durante el arrastre usa el valor local (instantáneo, sin esperar al backend)
            readonly property real frac: Math.min(1, Math.max(0, (srow.sliding ? srow.dragVal : srow.value) / 100))

            // pista
            Rectangle { anchors.fill: parent; radius: height / 2; color: root.trough }

            // relleno sólido tipo píldora (crece desde la izquierda, extremos redondeados)
            Rectangle {
                anchors.left: parent.left; anchors.leftMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height - 6; radius: height / 2
                color: srow.fillColor
                visible: track.frac > 0.001
                width: Math.max(height, track.frac * (track.width - 6))
                Behavior on width { enabled: !srow.sliding; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            // icono incrustado a la izquierda (dentro del relleno)
            Image {
                anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 11
                width: 17; height: 17; sourceSize: Qt.size(34,34); smooth: true
                source: root.ico(srow.insetIcon, track.frac > 0.07 ? "#FFFFFF" : root.txt)
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                function setX(mx) {
                    var v = Math.round(Math.min(1, Math.max(0, mx / width)) * 100)
                    srow.dragVal = v; srow.movedTo(v)
                }
                onPressed: (m) => { srow.sliding = true; root.dragging = true; setX(m.x) }
                onPositionChanged: (m) => { if (pressed) setX(m.x) }
                onReleased: { srow.sliding = false; root.dragging = false; srow.releasedSlider() }
                onCanceled: { srow.sliding = false; root.dragging = false }
                onWheel: (w) => srow.movedTo(Math.max(0, Math.min(100, srow.value + (w.angleDelta.y > 0 ? 5 : -5))))
            }
        }
        Rectangle {
            visible: srow.sideIcon !== ""
            Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20
            color: srow.sideActive ? srow.sideAccent : root.inactive
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: sbm.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
            Image { anchors.centerIn: parent; width: 19; height: 19; sourceSize: Qt.size(38,38); smooth: true
                source: root.ico(srow.sideIcon, srow.sideActive ? "#FFFFFF" : root.accent) }
            MouseArea { id: sbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: srow.sideClicked() }
        }
    }

    component MediaBtn: Item {
        property string iconSrc: ""
        property int size: 24
        signal activated
        Layout.preferredWidth: size + 14; Layout.preferredHeight: size + 14
        Image { anchors.centerIn: parent; width: size; height: size; sourceSize: Qt.size(size*2, size*2); smooth: true; source: iconSrc; opacity: mbm.pressed ? 0.6 : 1.0 }
        MouseArea { id: mbm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: activated() }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ACCIONES
    // ═══════════════════════════════════════════════════════════════════════
    function toggleWifi() { root.wifiOn = !root.wifiOn; cmd.run("nmcli radio wifi " + (root.wifiOn ? "on" : "off")); stTimer.restart() }
    // rfkill persiste entre reinicios (systemd-rfkill); `bluetoothctl power off` no (AutoEnable lo reenciende).
    function toggleBt()   { root.btOn = !root.btOn; cmd.run(root.btOn ? "sh -c 'rfkill unblock bluetooth; bluetoothctl power on'" : "rfkill block bluetooth"); stTimer.restart() }
    function toggleNight(){ BC.NightLightInhibitor.toggleInhibition() }
    function toggleAirplane() {
        root.airplaneOn = !root.airplaneOn
        cmd.run("rfkill " + (root.airplaneOn ? "block" : "unblock") + " all")
        stTimer.restart()
    }
    function toggleSaver() {
        root.saverOn = !root.saverOn
        cmd.run("powerprofilesctl set " + (root.saverOn ? "power-saver" : "balanced"))
        stTimer.restart()
    }
    function toggleKeepOn() {
        root.keepScreenOn = !root.keepScreenOn
        if (!root.keepScreenOn) cmd.run("pkill -f BookOSKeepScreenOn")
    }
    function toggleDark() { cmd.run("sh -c 'bookos-settings --toggle 2>/dev/null || gtk-launch bookos-settings.desktop'") }
    function toggleDnd() {
        if (computeDnd()) {
            notifSettings.notificationsInhibitedUntil = undefined
            notifSettings.revokeApplicationInhibitions()
            notifSettings.screensMirrored = false
        } else {
            var d = new Date(); d.setFullYear(d.getFullYear() + 1)
            notifSettings.notificationsInhibitedUntil = d
        }
        notifSettings.save(); root.dndOn = computeDnd()
    }
    function setBrightness(v) {
        if (root.brMax <= 0) return
        var nv = Math.round(Math.max(1, Math.min(100, v)) / 100 * root.brMax)
        root.brVal = nv
        cmd.run("qdbus6 " + root.brPath + ".setBrightness " + nv)
    }
    function setVolume(v) { root.volume = v; if (root.muted && v > 0) root.muted = false; cmd.run("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (v/100).toFixed(2)) }
    function toggleMute() { root.muted = !root.muted; cmd.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") }
    function playFeedback() { if (!root.muted) cmd.run("sh -c 'canberra-gtk-play -i audio-volume-change 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null'") }
    function seek(frac) { if (root.hasMusic) { try { root.player.position = Math.round(frac * root.songLen); root.songPos = root.player.position } catch(e) {} } }

    function actScreenshot() { root.expanded = false; cmd.run("spectacle") }
    function actLock()       { root.expanded = false; cmd.run("sh -c 'qdbus6 org.kde.screensaver /ScreenSaver Lock || loginctl lock-session'") }
    function actSuspend()    { root.expanded = false; cmd.run("systemctl suspend") }
    function actReboot()     { root.expanded = false; cmd.run("sh -c 'qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot'") }
    function actPower()      { root.expanded = false; cmd.run("sh -c 'qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptAll'") }
    function openSettings(page) {
        root.expanded = false
        var p = page && page !== "" ? "echo " + page + " > /tmp/bookos-start-page; " : ""
        cmd.run("sh -c '" + p + "gtk-launch bookos-settings.desktop 2>/dev/null || bookos-settings'")
    }
    function refresh() { stSource.refresh() }
    Timer { id: stTimer; interval: 1500; onTriggered: stSource.refresh() }

    // ═══════════════════════════════════════════════════════════════════════
    // DATA SOURCES
    // ═══════════════════════════════════════════════════════════════════════
    Plasma5Support.DataSource {
        id: stSource; engine: "executable"
        connectedSources: ["sh -c 'echo wifi:$(nmcli -t -f WIFI radio 2>/dev/null); " +
            "echo bt:$(bluetoothctl show 2>/dev/null | grep -i \"Powered:\" | head -n1 | grep -qi yes && echo on || echo off); " +
            "b=$(rfkill list 2>/dev/null | grep -c \"Soft blocked: yes\"); t=$(rfkill list 2>/dev/null | grep -c \"Soft blocked:\"); [ \"$t\" -gt 0 ] && [ \"$b\" -eq \"$t\" ] && echo air:on || echo air:off; " +
            "echo saver:$(powerprofilesctl get 2>/dev/null); " +
            "echo brc:$(qdbus6 " + root.brPath + ".brightness 2>/dev/null); " +
            "echo brm:$(qdbus6 " + root.brPath + ".brightnessMax 2>/dev/null); " +
            "echo vol:$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)'"]
        interval: root.popupOpen ? 3000 : 0
        function refresh() { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) }
        onNewData: (s, data) => {
            if (!data["stdout"]) return
            data["stdout"].trim().split('\n').forEach(function(l){
                if (l.startsWith("wifi:")) root.wifiOn = l.substring(5).trim() === "enabled"
                else if (l.startsWith("bt:")) root.btOn = l.substring(3).trim() === "on"
                else if (l.startsWith("air:")) root.airplaneOn = l.substring(4).trim() === "on"
                else if (l.startsWith("saver:")) root.saverOn = l.substring(6).trim() === "power-saver"
                else if (l.startsWith("brm:")) { var mx = parseInt(l.substring(4).trim()); if (!isNaN(mx)) root.brMax = mx }
                else if (l.startsWith("brc:")) { var bc = parseInt(l.substring(4).trim()); if (!isNaN(bc) && !root.dragging) root.brVal = bc }
                else if (l.startsWith("vol:")) {
                    var m = l.substring(4).trim().match(/Volume:\s+([0-9.]+)(\s+\[MUTED\])?/)
                    if (m && !root.dragging) { root.volume = Math.round(parseFloat(m[1])*100); root.muted = m[2] !== undefined }
                }
            })
        }
    }

    Plasma5Support.DataSource {
        id: userSource; engine: "executable"
        connectedSources: ["sh -c 'n=$(getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1); [ -z \"$n\" ] && n=$USER; echo \"name:$n\"; echo \"user:$USER\"; for f in \"$HOME/.face.icon\" \"$HOME/.face\" \"/var/lib/AccountsService/icons/$USER\"; do [ -f \"$f\" ] && { echo \"face:$f\"; break; }; done'"]
        onNewData: (s, data) => {
            disconnectSource(s)
            if (!data["stdout"]) return
            data["stdout"].trim().split('\n').forEach(function(l){
                if (l.startsWith("name:")) root.userName = l.substring(5).trim()
                else if (l.startsWith("user:")) root.userId = l.substring(5).trim()
                else if (l.startsWith("face:")) root.facePath = l.substring(5).trim()
            })
        }
    }

    // Mantener pantalla encendida: el proceso vive mientras la fuente está conectada;
    // al desconectar (keepScreenOn=false) se libera la inhibición.
    Plasma5Support.DataSource {
        id: caffeineSrc; engine: "executable"
        connectedSources: root.keepScreenOn
            ? ["systemd-inhibit --what=idle:sleep --who=BookOSKeepScreenOn --why=BookOSKeepScreenOn sleep infinity"]
            : []
        onNewData: (s, data) => {}
    }

    Plasma5Support.DataSource {
        id: wifiListSrc; engine: "executable"
        connectedSources: (root.expanded && root.page === "wifi") ?
            ["sh -c 'nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null | sort -t: -k2 -rn'"] : []
        interval: (root.expanded && root.page === "wifi") ? 6000 : 0
        function refresh() { if (connectedSources.length) { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) } }
        onNewData: (s, data) => {
            if (!data["stdout"]) { root.networks = []; return }
            var seen = {}, list = []
            data["stdout"].trim().split('\n').forEach(function(l){
                var p = l.split(':'); if (p.length < 4) return
                var ssid = p.slice(3).join(':').trim(); if (ssid === "" || ssid === "--" || seen[ssid]) return
                seen[ssid] = true
                list.push({ ssid: ssid, signal: parseInt(p[1].trim())||0, secure: (p[2].trim()!=="" && p[2].trim()!=="--"), active: p[0].trim()==="*" })
            })
            root.networks = list
        }
    }

    Plasma5Support.DataSource {
        id: btListSrc; engine: "executable"
        connectedSources: (root.expanded && root.page === "bluetooth") ?
            ["sh -c 'for mac in $(bluetoothctl devices 2>/dev/null | awk \"{print \\$2}\"); do " +
             "info=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
             "name=$(echo \"$info\" | grep -i \"Name:\" | head -n1 | sed \"s/.*Name: //\"); [ -z \"$name\" ] && continue; " +
             "conn=$(echo \"$info\" | grep -i \"Connected:\" | grep -qi yes && echo 1 || echo 0); " +
             "echo \"${conn}|${mac}|${name}\"; done | sort -r'"] : []
        interval: (root.expanded && root.page === "bluetooth") ? 5000 : 0
        function refresh() { if (connectedSources.length) { disconnectSource(connectedSources[0]); connectSource(connectedSources[0]) } }
        onNewData: (s, data) => {
            if (!data["stdout"]) { root.btDevices = []; return }
            var lines = data["stdout"].trim().split('\n').filter(function(l){ return l.includes("|") })
            root.btDevices = lines.map(function(l){ var p = l.split("|"); var name = p.slice(2).join("|").trim()
                return { connected: p[0].trim()==="1", mac: p[1].trim(), name: name, type: root.btType(name) } }).filter(function(d){ return d.name !== "" })
        }
    }

    Plasma5Support.DataSource {
        id: cmd; engine: "executable"; connectedSources: []
        onNewData: (s, data) => disconnectSource(s)
        function run(c) { connectSource(c) }
    }
}
