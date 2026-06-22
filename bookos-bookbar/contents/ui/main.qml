/*
    BookOS Book Bar — plasmoid (desktop widget) port of lockscreen pill.
    SPDX-License-Identifier: GPL-2.0-or-later
    QML hex = #AARRGGBB.
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: bookBar
    Plasmoid.backgroundHints: Plasmoid.NoBackground
    implicitWidth: modes.length > 0 ? barRow.implicitWidth : 0
    implicitHeight: centerPill.visible ? centerPill.height : 56

    // ── BookOS palette ───────────────────────────────────────────────────
    readonly property bool darkTheme: {
        var c = Kirigami.Theme.backgroundColor
        return (0.299*c.r + 0.587*c.g + 0.114*c.b) < 0.5
    }
    // BookOS tokens
    readonly property color bbBg:    darkTheme ? "#000000" : "#f2f2f7"
    readonly property color bbCard:  darkTheme ? "#1c1c1e" : "#FFFFFF"
    readonly property color bbTx:    darkTheme ? "#FFFFFF" : "#000000"
    readonly property color bbTx2:   "#8e8e93"
    readonly property color bbDiv:   darkTheme ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property color bbHov:   darkTheme ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06)
    readonly property color bbAct:   darkTheme ? Qt.rgba(1,1,1,0.16) : Qt.rgba(0,0,0,0.10)
    readonly property color bbBlue:  darkTheme ? "#0A84FF" : "#007AFF"
    readonly property color bbGreen: darkTheme ? "#30D158" : "#34C759"
    readonly property color bbRed:   darkTheme ? "#FF453A" : "#FF3B30"
    readonly property color bbYellow:darkTheme ? "#FFD60A" : "#FFCC00"
    // Text color on top of colored pills (always white-ish for contrast)
    readonly property color bbOn:    "#FFFFFF"
    readonly property color iconTint: darkTheme ? "white" : "#1c1c1e"

    // Color dinámico: acento del album art si hay música; verde si está cargando; nada si idle
    readonly property bool hasDynamicAccent: (hasMusic && artUrl !== "") || isCharging
    readonly property color dynamicAccent: {
        if (isCharging) return bbGreen
        if (hasMusic && artUrl !== "") return artColor
        return bbBlue
    }

    // ── MPRIS ─────────────────────────────────────────────────────────────
    Mpris.Mpris2Model { id: mpris2Model }

    readonly property int    playerCount: mpris2Model ? mpris2Model.count || 0 : 0
    readonly property var    player:     mpris2Model.currentPlayer

    // Filtered real player rows (excludes multiplexer)
    property var realRows: []
    function updateRealRows() {
        var a = []
        for (var i = 0; i < muxFilter.count; i++) {
            var o = muxFilter.itemAt(i)
            if (o && !o.isMux && o.hasContent) a.push(o.rowIdx)
        }
        realRows = a
    }
    readonly property int realCount: realRows.length
    function realIdxOf(rowIdx) {
        for (var i = 0; i < realRows.length; i++) if (realRows[i] === rowIdx) return i
        return 0
    }

    Item {
        id: muxFilterHost
        visible: false
        Repeater {
            id: muxFilter
            model: mpris2Model
            delegate: Item {
                readonly property int rowIdx: index
                readonly property bool isMux: (typeof model.isMultiplexer !== "undefined") && model.isMultiplexer === true
                readonly property string mTrack: (typeof model.track !== "undefined") ? (model.track || "") : ""
                readonly property int mStatus: (typeof model.playbackStatus !== "undefined") ? (model.playbackStatus || 0) : 0
                readonly property bool hasContent:
                    !isMux && (mTrack.length > 0) &&
                    mStatus !== Mpris.PlaybackStatus.Stopped
                Component.onCompleted: bookBar.updateRealRows()
                Component.onDestruction: bookBar.updateRealRows()
                onIsMuxChanged: bookBar.updateRealRows()
                onHasContentChanged: bookBar.updateRealRows()
            }
            onCountChanged: bookBar.updateRealRows()
        }
    }

    function cyclePlayer() {
        if (realCount < 2) return
        try {
            var curReal = realIdxOf(mpris2Model.currentIndex)
            var nextReal = (curReal + 1) % realCount
            mpris2Model.currentIndex = realRows[nextReal]
        } catch(e) { /* API unavailable */ }
    }
    readonly property bool   hasMusic:   player !== null && player !== undefined
    readonly property string songTitle:  hasMusic ? (player.track  || "") : ""
    readonly property string songArtist: hasMusic ? (player.artist || "") : ""
    readonly property string artUrl:     hasMusic ? (player.artUrl || "") : ""
    readonly property string appIcon:    hasMusic ? (player.iconName || player.desktopEntry || player.identity || "applications-multimedia") : "applications-multimedia"
    readonly property bool   isPlaying:  hasMusic && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool   canPrev:    hasMusic && (player.canGoPrevious || false)
    readonly property bool   canNext:    hasMusic && (player.canGoNext     || false)
    readonly property bool   canSeek:    hasMusic && (player.canSeek       || false)
    readonly property real   songLen:    hasMusic ? (player.length   || 0) : 0
    readonly property bool   validLen:   songLen > 0 && songLen < 1e12
    property real            songPos:    0

    Timer {
        interval: 500; running: bookBar.hasMusic && bookBar.isPlaying; repeat: true
        onTriggered: if (bookBar.hasMusic) { bookBar.player.updatePosition(); bookBar.songPos = bookBar.player.position || 0 }
    }
    Connections {
        target: bookBar.player
        ignoreUnknownSignals: true
        function onPositionChanged() { bookBar.songPos = bookBar.player.position || 0 }
    }

    function mprisPlay() { if (hasMusic) player.PlayPause() }
    function mprisPrev() { if (hasMusic) player.Previous() }
    function mprisNext() { if (hasMusic) player.Next()     }

    property bool liked:     false
    property bool shuffling: false

    // ── Battery ──────────────────────────────────────────────────────────
    property int  battPct:     0
    property bool isCharging:  false
    property bool hasBattery:  false
    property int  minsToFull:  0
    property int  minsToEmpty: 0
    property int  chargeLimit: 100
    property int  estMinsToLimit: 0
    property real _pw: 0
    property real _ef: 0
    property real _in: 0
    property real _cf: 0

    function recomputeEst() {
        var remain = (chargeLimit - battPct) / 100.0
        if (remain <= 0) { estMinsToLimit = 0; return }
        var mins = 0
        if (_pw > 0 && _ef > 0)      mins = Math.round((_ef * remain) / _pw * 60.0)
        else if (_in > 0 && _cf > 0) mins = Math.round((_cf * remain) / _in * 60.0)
        estMinsToLimit = (mins > 0 && mins < 600) ? mins : 0
    }
    onBattPctChanged:     recomputeEst()
    onChargeLimitChanged: recomputeEst()

    P5Support.DataSource {
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
        onDataChanged: {
            var bat = data["Battery"] || {}
            bookBar.hasBattery = (bat["Has Battery"] !== undefined) ? bat["Has Battery"] : (bat["Percent"] !== undefined)
            bookBar.battPct    = bat["Percent"] || 0
            var st = bat["State"] || ""
            bookBar.isCharging = st === "Charging"
            bookBar.minsToFull  = Math.round((bat["Time To Full"]  || 0) / 60)
            bookBar.minsToEmpty = Math.round((bat["Time To Empty"] || 0) / 60)
            bookBar.updateModes()
        }
    }

    P5Support.DataSource {
        id: chargeLimitSrc
        engine: "executable"
        connectedSources: ["sh -c 'cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -1'"]
        interval: 30000
        onNewData: (src, data) => {
            var v = parseInt(((data["stdout"] || "") + "").trim())
            if (!isNaN(v) && v > 0 && v <= 100) bookBar.chargeLimit = v
        }
    }

    P5Support.DataSource {
        id: chargeEstSrc
        engine: "executable"
        // only poll while charging — the estimate is only shown then
        connectedSources: bookBar.isCharging ? ["sh -c 'r(){ cat $1 2>/dev/null | head -1; }; P=$(r /sys/class/power_supply/BAT*/power_now); E=$(r /sys/class/power_supply/BAT*/energy_full); I=$(r /sys/class/power_supply/BAT*/current_now); C=$(r /sys/class/power_supply/BAT*/charge_full); echo \"${P:-0} ${E:-0} ${I:-0} ${C:-0}\"'"] : []
        interval: 10000
        onNewData: (src, data) => {
            var parts = ((data["stdout"] || "") + "").trim().split(/\s+/)
            bookBar._pw = parseFloat(parts[0]) || 0
            bookBar._ef = parseFloat(parts[1]) || 0
            bookBar._in = parseFloat(parts[2]) || 0
            bookBar._cf = parseFloat(parts[3]) || 0
            bookBar.recomputeEst()
        }
    }

    function batterySubtitle() {
        if (isCharging && battPct >= chargeLimit) return "Limit " + chargeLimit + "%"
        if (isCharging) {
            if (minsToFull > 0)      return minsToFull + " min to full"
            if (estMinsToLimit > 0)  return estMinsToLimit + " min to " + chargeLimit + "%"
            return "Charging to " + chargeLimit + "%"
        }
        if (battPct >= 99)           return "Full"
        if (minsToEmpty > 0) {
            if (minsToEmpty >= 60)   return Math.floor(minsToEmpty/60) + "h " + (minsToEmpty%60) + "m"
            return minsToEmpty + " min left"
        }
        return "Battery"
    }

    // ── Routine ──────────────────────────────────────────────────────────
    property var routine: null
    property bool routineDismissed: false

    P5Support.DataSource {
        id: routineSrc
        engine: "executable"
        connectedSources: ["cat $HOME/.config/bookos-active-routine.json 2>/dev/null"]
        interval: 5000
        onNewData: (src, data) => {
            if (bookBar.routineDismissed) return
            try {
                var j = JSON.parse((data["stdout"] || "").trim())
                bookBar.routine = (j && j.active && j.name) ? j : null
            } catch(e) { bookBar.routine = null }
            bookBar.updateModes()
        }
    }

    P5Support.DataSource { id: shellExec; engine: "executable" }
    Timer { id: undismissT; interval: 8000; onTriggered: bookBar.routineDismissed = false }
    function deactivateRoutine() {
        routineDismissed = true
        routine = null
        expanded = false
        updateModes()
        shellExec.connectSource("sh -c 'echo {\\\"active\\\":false} > $HOME/.config/bookos-active-routine.json'")
        undismissT.restart()
    }

    // ── Audio output name ────────────────────────────────────────────────
    property string audioOut: "Speakers"
    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["sh -c 'D=$(pactl get-default-sink 2>/dev/null); pactl list sinks 2>/dev/null | awk -v d=\"$D\" \"/^Sink/{n=0} \\$0 ~ \\\"Name: \\\"d {n=1} n && /Description:/{sub(/.*Description: /,\\\"\\\"); print; exit}\"'"]
        interval: 10000
        onNewData: (src, data) => {
            var s = (data["stdout"] || "").trim()
            if (s !== "") bookBar.audioOut = s
        }
    }

    // ── Modes ─────────────────────────────────────────────────────────────
    property var  modes:    []
    property int  modeIdx:  0
    property bool expanded: false
    property bool pendingExpand: false

    function updateModes() {
        var m = []
        if (hasMusic && songTitle !== "")        m.push("music")
        if (routine !== null && routine.active)  m.push("routine")
        if (hasBattery)                          m.push("battery")
        modes = m
        if (modes.length === 0) { expanded = false; return }
        if (modeIdx >= modes.length) modeIdx = modes.length - 1
    }

    onHasMusicChanged: {
        updateModes()
        if (!hasMusic || artUrl === "") artColor = bbCard
    }
    onSongTitleChanged: updateModes()
    Component.onCompleted: updateModes()

    // Re-extract color when art URL changes — even if status doesn't fire Ready
    // (Spotify reuses URLs, Qt sometimes skips reload). Force fresh load + retry.
    property int artReloadTick: 0
    onArtUrlChanged: {
        if (artUrl === "") { artColor = bbCard; return }
        artReloadTick++           // bust Qt internal cache + retrigger thumb load
        artRetryTimer.restart()
    }
    Timer {
        id: artRetryTimer
        interval: 250; repeat: false
        onTriggered: {
            if (artThumb.status === Image.Ready) colorCanvas.requestPaint()
            else if (artThumb.status === Image.Error) { bookBar.artColor = bookBar.bbCard }
            // else still loading — onStatusChanged will fire when Ready/Error
        }
    }

    readonly property string curMode:   modes.length > 0 ? modes[modeIdx] : ""
    readonly property string leftMode:  modes.length > 1 ? modes[(modeIdx - 1 + modes.length) % modes.length] : ""
    readonly property string rightMode: modes.length > 1 ? modes[(modeIdx + 1) % modes.length] : ""

    // ── Colors ────────────────────────────────────────────────────────────
    property color artColor: bbCard

    function modeColor(m) {
        if (m === "battery")  return bbCard
        if (m === "music")    return artColor
        if (m === "routine")  return bbCard
        return bbCard
    }

    Image {
        id: artThumb; visible: false
        // Append tick as fragment to bust Qt image cache when URL repeats.
        source: bookBar.artUrl === "" ? "" : bookBar.artUrl + (bookBar.artUrl.indexOf("#") < 0 ? "#" : "&") + "t=" + bookBar.artReloadTick
        width: 16; height: 16; fillMode: Image.Stretch; cache: false; asynchronous: true
        onStatusChanged: {
            if (status === Image.Ready) colorCanvas.requestPaint()
            else if (status === Image.Error) bookBar.artColor = bookBar.bbCard
        }
    }
    Canvas {
        id: colorCanvas; visible: false; width: 16; height: 16
        onPaint: {
            var ctx = getContext("2d")
            ctx.drawImage(artThumb, 0, 0, 16, 16)
            var d = ctx.getImageData(0, 0, 16, 16).data
            var best = null, bestScore = -1
            for (var i = 0; i < 256; i++) {
                var r = d[i*4], g = d[i*4+1], b = d[i*4+2]
                var mx = Math.max(r, g, b), mn = Math.min(r, g, b)
                if (mx === 0) continue
                var sat = (mx - mn) / mx
                var lum = (0.299*r + 0.587*g + 0.114*b) / 255
                if (lum < 0.12 || lum > 0.92) continue
                var score = sat * (1 - Math.abs(lum - 0.55) * 0.9)
                if (score > bestScore) { bestScore = score; best = [r, g, b] }
            }
            if (!best) { bookBar.artColor = bookBar.bbCard; return }
            var r = best[0], g = best[1], b = best[2]
            var mx = Math.max(r, g, b)
            var f  = mx > 0 ? 190 / mx : 1
            var rr = Math.min(255, r * f), gg = Math.min(255, g * f), bb = Math.min(255, b * f)
            var bMix = (0.299*rr + 0.587*gg + 0.114*bb) / 255
            if (bMix > 0.75) { rr *= 0.78; gg *= 0.78; bb *= 0.78 }
            bookBar.artColor = Qt.rgba(rr/255, gg/255, bb/255, 1)
        }
    }

    // ── Slide animation ──────────────────────────────────────────────────
    property real slideX:     0
    property int  pendingIdx: -1

    function switchMode(newIdx) {
        if (modes.length < 2 || newIdx === modeIdx) return
        expanded   = false
        pendingIdx = newIdx
        var goRight = (newIdx === (modeIdx + 1) % modes.length)
        slideOut.to = goRight ? -(centerPill.width + 16) : (centerPill.width + 16)
        slideOut.start()
    }

    function switchModeAndOpen(newIdx) {
        if (newIdx === modeIdx) return
        switchMode(newIdx)
    }

    NumberAnimation { id: slideOut; target: bookBar; property: "slideX"; duration: 280
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 1, 1, 1, 1]
        onFinished: { bookBar.modeIdx = bookBar.pendingIdx; bookBar.slideX = -slideOut.to * 0.25; slideIn.start() } }
    NumberAnimation { id: slideIn;  target: bookBar; property: "slideX"; to: 0; duration: 380
        easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1]
        onFinished: { if (bookBar.pendingExpand) { bookBar.pendingExpand = false; bookBar.expanded = true } } }

    // D-shape pill: outer side fully round, inner side slightly rounded
    // side: "left" → outer round on LEFT, inner (right) softly rounded
    //       "right" → outer round on RIGHT, inner (left) softly rounded
    function svgDPill(w, h, side, fillHex, borderHex, borderWidth) {
        var r = h / 2
        var ri = 6 // inner corner radius
        var path
        if (side === "left") {
            path = "M " + (w-ri) + ",0 " +
                   "L " + r + ",0 " +
                   "A " + r + "," + r + " 0 0 0 " + r + "," + h + " " +
                   "L " + (w-ri) + "," + h + " " +
                   "Q " + w + "," + h + " " + w + "," + (h-ri) + " " +
                   "L " + w + "," + ri + " " +
                   "Q " + w + ",0 " + (w-ri) + ",0 Z"
        } else {
            path = "M " + ri + ",0 " +
                   "L " + (w-r) + ",0 " +
                   "A " + r + "," + r + " 0 0 1 " + (w-r) + "," + h + " " +
                   "L " + ri + "," + h + " " +
                   "Q 0," + h + " 0," + (h-ri) + " " +
                   "L 0," + ri + " " +
                   "Q 0,0 " + ri + ",0 Z"
        }
        var bw = borderWidth || 0
        var stroke = bw > 0 ? ' stroke="' + borderHex + '" stroke-width="' + bw + '"' : ''
        return "data:image/svg+xml," + encodeURIComponent(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + w + ' ' + h + '">' +
            '<path d="' + path + '" fill="' + fillHex + '"' + stroke + '/></svg>')
    }

    function colorToHex(c) {
        var s = (c || "").toString()
        if (s.startsWith("#")) return s.length === 9 ? "#" + s.substring(3, 9) : s.substring(0, 7)
        return s
    }

    function fmtTime(us) {
        if (!us || us < 0) return "0:00"
        var s = Math.floor(us / 1000000)
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // ── Layout ───────────────────────────────────────────────────────────
    Row {
        id: barRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        spacing: 8

        // Left mini pill (D-shape, lado interior recto)
        Item {
            id: leftPill
            visible: bookBar.leftMode !== "" && !bookBar.expanded
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 44
            opacity: leftMA.containsMouse ? 1.0 : 0.92
            scale: leftMA.pressed ? 0.94 : 1.0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

            // D-shape background — glow del artColor cuando hay música
            Image {
                anchors.fill: parent; smooth: true
                sourceSize: Qt.size(width * 2, height * 2)
                source: bookBar.svgDPill(parent.width, parent.height, "left",
                    bookBar.colorToHex(bookBar.bbCard),
                    bookBar.colorToHex(bookBar.dynamicAccent),
                    bookBar.hasDynamicAccent ? 1.5 : 0)
            }
            TintIcon {
                visible: bookBar.leftMode === "battery"
                anchors.centerIn: parent; size: 22
                source: Qt.resolvedUrl("bookbar-icons/charging.svg")
                tint: bookBar.isCharging ? bookBar.bbGreen : bookBar.bbTx
            }
            Item {
                visible: bookBar.leftMode === "music"
                anchors.centerIn: parent
                width: 36; height: 36
                Rectangle { id: lArtMask; anchors.fill: parent; radius: 18; color: "white"; visible: false; layer.enabled: true }
                Image { id: lArtImg; anchors.fill: parent
                    source: bookBar.artUrl === "" ? "" : bookBar.artUrl + (bookBar.artUrl.indexOf("#") < 0 ? "#" : "&") + "t=" + bookBar.artReloadTick
                    fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true; asynchronous: true
                    cache: false
                    readonly property bool isReady: status === Image.Ready && bookBar.artUrl !== ""
                    visible: false; layer.enabled: isReady }
                OpacityMask { anchors.fill: parent; source: lArtImg; maskSource: lArtMask; visible: lArtImg.isReady }
                TintIcon {
                    visible: bookBar.artUrl === "" || !lArtImg.isReady
                    anchors.centerIn: parent; size: 20; tint: "white"
                    source: bookBar.isPlaying ? Qt.resolvedUrl("bookbar-icons/pause.svg") : Qt.resolvedUrl("bookbar-icons/play.svg")
                }
                Rectangle {
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.rightMargin: -3; anchors.bottomMargin: -3
                    width: 17; height: 17; radius: 8.5
                    color: bookBar.bbCard
                    Kirigami.Icon { anchors.centerIn: parent; width: 11; height: 11
                        source: bookBar.appIcon; fallback: "applications-multimedia" }
                }
                Rectangle {
                    visible: bookBar.playerCount > 1
                    anchors.left: parent.left; anchors.top: parent.top
                    anchors.leftMargin: -3; anchors.topMargin: -3
                    width: 15; height: 15; radius: 7.5
                    color: bookBar.bbBlue
                    Text { anchors.centerIn: parent; text: bookBar.playerCount; color: "white"
                        font.pixelSize: 9; font.weight: Font.Bold }
                }
            }
            Text { visible: bookBar.leftMode === "routine"; anchors.centerIn: parent
                   text: bookBar.routine ? (bookBar.routine.icon || "\u2699\uFE0F") : "\u2699\uFE0F"; font.pixelSize: 18 }
            MouseArea { id: leftMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: bookBar.switchModeAndOpen((bookBar.modeIdx - 1 + bookBar.modes.length) % bookBar.modes.length) }
        }

        // Center pill
        Rectangle {
            id: centerPill
            anchors.verticalCenter: parent.verticalCenter
            radius: bookBar.expanded ? 26 : 28
            color: bookBar.modeColor(bookBar.curMode)
            clip: true
            visible: bookBar.modes.length > 0
            width: {
                if (!visible || bookBar.curMode === "") return 0
                if (bookBar.expanded) return bookBar.curMode === "music" ? 340 : 320
                return compactRow.implicitWidth + 40
            }
            height: bookBar.expanded ? (bookBar.curMode === "music" ? 520 : 200) : 56
            Behavior on width  { NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] } }
            Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] } }
            Behavior on radius { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on color  { ColorAnimation  { duration: 350 } }

            // Borde dinámico (glow del album art o verde si carga)
            border.color: bookBar.hasDynamicAccent
                ? Qt.rgba(bookBar.dynamicAccent.r, bookBar.dynamicAccent.g, bookBar.dynamicAccent.b, 0.55)
                : "transparent"
            border.width: bookBar.hasDynamicAccent ? 1.5 : 0
            Behavior on border.color { ColorAnimation { duration: 400 } }

            // Charging level fill — left→right, width = battPct %, masked to pill shape
            Rectangle {
                id: chargeFillMask
                anchors.fill: parent; radius: centerPill.radius; color: "white"
                visible: false; layer.enabled: true
            }
            Rectangle {
                id: chargeFillRaw
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.darker(bookBar.bbGreen, 1.15) }
                    GradientStop { position: 1.0; color: bookBar.bbGreen }
                }
                width: bookBar.isCharging ? centerPill.width * (Math.min(bookBar.battPct, bookBar.chargeLimit) / 100) : 0
                visible: false; layer.enabled: true
                Behavior on width { NumberAnimation { duration: 1100; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] } }
            }
            OpacityMask {
                anchors.fill: parent
                visible: bookBar.curMode === "battery" && !bookBar.expanded
                source: chargeFillRaw
                maskSource: chargeFillMask
            }

            // ── Compact ───────────────────────────────────────────────────
            Row {
                id: compactRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: bookBar.slideX
                spacing: 10
                readonly property real swipeProgress: Math.min(1, Math.abs(bookBar.slideX) / (centerPill.width + 16))
                opacity: bookBar.expanded ? 0 : Math.max(0, 1 - swipeProgress * 1.4)
                scale: 1 - swipeProgress * 0.08
                Behavior on opacity { NumberAnimation { duration: 180 } }

                // Battery
                Row {
                    visible: bookBar.curMode === "battery"; spacing: 12
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 38; height: 38; radius: 19; anchors.verticalCenter: parent.verticalCenter
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: bookBar.isCharging ? Qt.lighter(bookBar.bbGreen, 1.18) : (bookBar.darkTheme ? "#3a3a3c" : "#e5e5ea") }
                            GradientStop { position: 1.0; color: bookBar.isCharging ? bookBar.bbGreen : (bookBar.darkTheme ? "#2c2c2e" : "#d1d1d6") }
                        }
                        TintIcon {
                            anchors.centerIn: parent; size: 20
                            source: Qt.resolvedUrl("bookbar-icons/charging.svg")
                            tint: bookBar.isCharging ? "white" : bookBar.bbTx
                        }
                        SequentialAnimation on scale {
                            running: bookBar.isCharging; loops: Animation.Infinite
                            NumberAnimation { to: 1.06; duration: 800; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0;  duration: 800; easing.type: Easing.InOutQuad }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 0
                        Text { text: bookBar.battPct + "%"; color: bookBar.bbTx; font.pixelSize: 20; font.weight: Font.Bold; font.letterSpacing: -0.4 }
                        Text { text: bookBar.batterySubtitle(); color: bookBar.bbTx2; font.pixelSize: 10; font.weight: Font.Medium }
                    }
                }

                // Music compact
                Row {
                    visible: bookBar.curMode === "music"; spacing: 12
                    anchors.verticalCenter: parent.verticalCenter
                    Item {
                        width: 42; height: 42
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            anchors.fill: parent; radius: 21
                            color: bookBar.bbHov
                            visible: !compactArtImg.isReady
                        }
                        Kirigami.Icon {
                            visible: !compactArtImg.isReady
                            anchors.centerIn: parent; width: 22; height: 22
                            source: bookBar.appIcon
                            fallback: "applications-multimedia"
                        }
                        Rectangle { id: compactArtMask; anchors.fill: parent; radius: 21; color: "white"; visible: false; layer.enabled: true }
                        Image {
                            id: compactArtImg
                            anchors.fill: parent
                            source: bookBar.artUrl === "" ? "" : bookBar.artUrl + (bookBar.artUrl.indexOf("#") < 0 ? "#" : "&") + "t=" + bookBar.artReloadTick
                            fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true; asynchronous: true
                            cache: false
                            visible: false
                            readonly property bool isReady: status === Image.Ready && bookBar.artUrl !== ""
                            layer.enabled: isReady
                        }
                        OpacityMask {
                            anchors.fill: parent
                            visible: compactArtImg.isReady
                            source: compactArtImg
                            maskSource: compactArtMask
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 0
                        Text {
                            text: bookBar.songTitle.length > 22 ? bookBar.songTitle.slice(0,22) + "…" : bookBar.songTitle
                            color: bookBar.bbTx; font.pixelSize: 14; font.weight: Font.DemiBold; font.letterSpacing: -0.2
                        }
                        Text {
                            visible: bookBar.songArtist !== ""
                            text: bookBar.songArtist.length > 24 ? bookBar.songArtist.slice(0,24) + "…" : bookBar.songArtist
                            color: bookBar.bbTx2; font.pixelSize: 10; font.weight: Font.Medium
                        }
                    }
                }

                // Routine compact
                Row {
                    visible: bookBar.curMode === "routine"; spacing: 12
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: bookBar.bbHov
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.centerIn: parent
                            text: bookBar.routine ? (bookBar.routine.icon || "\u2699\uFE0F") : "\u2699\uFE0F"
                            font.pixelSize: 18
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 0
                        Text { text: bookBar.routine ? bookBar.routine.name : ""; color: bookBar.bbTx; font.pixelSize: 15; font.weight: Font.DemiBold; font.letterSpacing: -0.2 }
                        Text { text: "Rutina activa"; color: bookBar.bbTx2; font.pixelSize: 10; font.weight: Font.Medium }
                    }
                }
            }

            // ── Expanded: music ───────────────────────────────────────────
            Item {
                id: musicExpanded
                anchors.fill: parent
                opacity: (bookBar.expanded && bookBar.curMode === "music") ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                ListView {
                    id: musicList
                    anchors.fill: parent
                    orientation: ListView.Vertical
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    highlightMoveDuration: 240
                    highlightMoveVelocity: -1
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    model: mpris2Model
                    cacheBuffer: 4000
                    interactive: false

                    Behavior on contentY {
                        NumberAnimation { duration: 240; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] }
                    }

                    readonly property int visibleIdx: currentIndex
                    function goTo(i) {
                        if (i < 0 || i >= count) return
                        currentIndex = i
                    }
                    function advance(delta) { goTo(Math.max(0, Math.min(count - 1, currentIndex + delta))) }
                    onCurrentIndexChanged: {
                        try { if (mpris2Model.currentIndex !== currentIndex) mpris2Model.currentIndex = currentIndex } catch(e) {}
                    }

                    Connections {
                        target: mpris2Model
                        function onCurrentIndexChanged() {
                            if (musicList.currentIndex !== mpris2Model.currentIndex)
                                musicList.currentIndex = mpris2Model.currentIndex
                        }
                    }

                    delegate: Item {
                        id: playerCard
                        width: musicList.width
                        readonly property bool isMux: (typeof model.isMultiplexer !== "undefined") ? (model.isMultiplexer === true) : false
                        readonly property int mStatus: (typeof model.playbackStatus !== "undefined") ? (model.playbackStatus || 0) : 0
                        readonly property bool hidden: isMux || dTrack.length === 0 || mStatus === Mpris.PlaybackStatus.Stopped
                        height: hidden ? 0 : musicList.height
                        visible: !hidden

                        readonly property string dTrack:   (typeof model.track   !== "undefined") ? (model.track   || "") : ""
                        readonly property string dArtist:  (typeof model.artist  !== "undefined") ? (model.artist  || "") : ""
                        readonly property string dArtUrl:  (typeof model.artUrl  !== "undefined") ? (model.artUrl  || "") : ""
                        readonly property bool   dPlaying: (typeof model.playbackStatus !== "undefined") && model.playbackStatus === Mpris.PlaybackStatus.Playing
                        readonly property bool   dCanPrev: (typeof model.canGoPrevious !== "undefined") && (model.canGoPrevious || false)
                        readonly property bool   dCanNext: (typeof model.canGoNext !== "undefined") && (model.canGoNext || false)
                        readonly property bool   dCanSeek: (typeof model.canSeek !== "undefined") && (model.canSeek || false)
                        readonly property real   dLen:     (typeof model.length !== "undefined") ? (model.length || 0) : 0
                        readonly property bool   dValidLen: dLen > 0 && dLen < 1e12
                        property real            dPos:     0
                        readonly property string dIcon:    (typeof model.iconName !== "undefined") ? (model.iconName || model.desktopEntry || model.identity || "applications-multimedia") : "applications-multimedia"

                        function activateAndRun(fn) {
                            try { mpris2Model.currentIndex = index } catch(e) {}
                            if (mpris2Model.currentPlayer) fn(mpris2Model.currentPlayer)
                        }

                        Timer {
                            interval: 500; running: playerCard.visible && playerCard.dPlaying && musicList.currentIndex === index; repeat: true
                            onTriggered: {
                                if (mpris2Model.currentPlayer && musicList.currentIndex === index) {
                                    mpris2Model.currentPlayer.updatePosition && mpris2Model.currentPlayer.updatePosition()
                                    playerCard.dPos = mpris2Model.currentPlayer.position || 0
                                }
                            }
                        }

                        Item {
                            id: dAlbum
                            anchors.top: parent.top
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.topMargin: 14; anchors.leftMargin: 14; anchors.rightMargin: 14
                            height: width

                            // Rounded background (visible, fallback when no art)
                            Rectangle {
                                anchors.fill: parent
                                radius: 26
                                gradient: Gradient {
                                    orientation: Gradient.Vertical
                                    GradientStop { position: 0; color: bookBar.darkTheme ? "#2c2c2e" : "#e5e5ea" }
                                    GradientStop { position: 1; color: bookBar.darkTheme ? "#1c1c1e" : "#d1d1d6" }
                                }
                            }
                            Kirigami.Icon {
                                visible: !dAlbumImg.visible
                                anchors.centerIn: parent
                                width: parent.width * 0.45; height: width
                                source: playerCard.dIcon
                                fallback: "applications-multimedia"
                                opacity: 0.75
                            }

                            // Rounded album art via OpacityMask
                            Rectangle {
                                id: dAlbumMask
                                anchors.fill: parent
                                radius: 26
                                color: "white"
                                visible: false
                                layer.enabled: true
                                layer.smooth: true
                            }
                            Image {
                                id: dAlbumImg
                                anchors.fill: parent
                                source: playerCard.dArtUrl
                                fillMode: Image.PreserveAspectCrop
                                smooth: true; mipmap: true; asynchronous: true
                                cache: false
                                visible: false
                                layer.enabled: status === Image.Ready && playerCard.dArtUrl !== ""
                                layer.smooth: true
                                readonly property bool isReady: status === Image.Ready && playerCard.dArtUrl !== ""
                            }
                            OpacityMask {
                                anchors.fill: parent
                                visible: dAlbumImg.isReady
                                source: dAlbumImg
                                maskSource: dAlbumMask
                                antialiasing: true
                            }

                            // Clic en album art cierra la pill expandida
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bookBar.expanded = false
                            }
                        }

                        Column {
                            anchors.top: dAlbum.bottom
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 14; anchors.rightMargin: 14
                            anchors.topMargin: 12; anchors.bottomMargin: 14
                            spacing: 10

                            Column {
                                width: parent.width; spacing: 2
                                Text { text: playerCard.dTrack;  color: bookBar.bbTx; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: -0.2; elide: Text.ElideRight; width: parent.width }
                                Text { text: playerCard.dArtist; color: bookBar.bbTx2; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width }
                            }

                            Item {
                                width: parent.width; height: 22
                                Row {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                                    Rectangle {
                                        width: 22; height: 22; radius: 6; color: bookBar.bbHov
                                        Kirigami.Icon {
                                            anchors.centerIn: parent; width: 14; height: 14
                                            source: playerCard.dIcon; fallback: "applications-multimedia"
                                        }
                                    }
                                    Text {
                                        text: bookBar.audioOut; color: bookBar.bbTx2; font.pixelSize: 10; font.weight: Font.SemiBold
                                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                                        width: Math.max(40, centerPill.width - 80)
                                    }
                                }
                            }

                            Column {
                                width: parent.width; spacing: 3
                                Item {
                                    width: parent.width; height: 12
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 2; color: bookBar.bbDiv }
                                    Rectangle {
                                        visible: playerCard.dValidLen
                                        anchors.verticalCenter: parent.verticalCenter; height: 3; radius: 2; color: bookBar.bbTx
                                        width: playerCard.dValidLen ? parent.width * Math.min(1, playerCard.dPos / playerCard.dLen) : 0
                                    }
                                    Rectangle {
                                        visible: playerCard.dValidLen
                                        width: 10; height: 10; radius: 5; color: bookBar.bbTx
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: playerCard.dValidLen ? Math.max(0, parent.width * Math.min(1, playerCard.dPos / playerCard.dLen) - 5) : 0
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: playerCard.dCanSeek && playerCard.dValidLen
                                        onClicked: mouse => {
                                            if (!playerCard.dValidLen) return
                                            var targetUs = (mouse.x / parent.width) * playerCard.dLen
                                            playerCard.activateAndRun(function(p){ p.Seek(targetUs - playerCard.dPos) })
                                            mouse.accepted = true
                                        }
                                    }
                                }
                                Item {
                                    width: parent.width; height: 12
                                    Text { anchors.left: parent.left;  text: playerCard.dValidLen ? bookBar.fmtTime(playerCard.dPos) : "--:--"; color: bookBar.bbTx2; font.pixelSize: 9; font.weight: Font.Medium }
                                    Text { anchors.right: parent.right; text: playerCard.dValidLen ? bookBar.fmtTime(playerCard.dLen) : "--:--"; color: bookBar.bbTx2; font.pixelSize: 9; font.weight: Font.Medium }
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 22
                                Item {
                                    width: 34; height: 34
                                    TintIcon { anchors.centerIn: parent; size: 22
                                        tint: bookBar.liked ? bookBar.bbRed : bookBar.bbTx
                                        source: bookBar.liked ? Qt.resolvedUrl("bookbar-icons/liked-song.svg") : Qt.resolvedUrl("bookbar-icons/like-song.svg") }
                                    scale: likeMA.pressed ? 0.88 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                    MouseArea { id: likeMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bookBar.liked = !bookBar.liked }
                                }
                                Item {
                                    width: 34; height: 34; opacity: playerCard.dCanPrev ? 1 : 0.4
                                    TintIcon { anchors.centerIn: parent; size: 24; tint: bookBar.bbTx
                                        source: Qt.resolvedUrl("bookbar-icons/previous-track.svg") }
                                    scale: prevMA.pressed ? 0.9 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                    MouseArea { id: prevMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: playerCard.activateAndRun(function(p){ p.Previous() }) }
                                }
                                Item {
                                    width: 44; height: 44
                                    Rectangle {
                                        anchors.centerIn: parent; width: 44; height: 44; radius: 22
                                        color: playMA.containsMouse ? bookBar.bbAct : bookBar.bbHov
                                        Behavior on color { ColorAnimation { duration: 140 } }
                                    }
                                    TintIcon { anchors.centerIn: parent; size: 22; tint: bookBar.bbTx
                                        source: playerCard.dPlaying ? Qt.resolvedUrl("bookbar-icons/pause.svg") : Qt.resolvedUrl("bookbar-icons/play.svg") }
                                    scale: playMA.pressed ? 0.92 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                    MouseArea { id: playMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: playerCard.activateAndRun(function(p){ p.PlayPause() }) }
                                }
                                Item {
                                    width: 34; height: 34; opacity: playerCard.dCanNext ? 1 : 0.4
                                    TintIcon { anchors.centerIn: parent; size: 24; tint: bookBar.bbTx
                                        source: Qt.resolvedUrl("bookbar-icons/next-track.svg") }
                                    scale: nextMA.pressed ? 0.9 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120 } }
                                    MouseArea { id: nextMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: playerCard.activateAndRun(function(p){ p.Next() }) }
                                }
                                Item {
                                    width: 34; height: 34
                                    TintIcon { anchors.centerIn: parent; size: 22
                                        tint: bookBar.shuffling ? bookBar.bbBlue : bookBar.bbTx
                                        source: bookBar.shuffling ? Qt.resolvedUrl("bookbar-icons/random-selected.svg") : Qt.resolvedUrl("bookbar-icons/random.svg") }
                                    scale: shufMA.pressed ? 0.88 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140 } }
                                    MouseArea { id: shufMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bookBar.shuffling = !bookBar.shuffling }
                                }
                            }
                        }
                    }
                }

                DragHandler {
                    id: vDrag
                    target: null
                    xAxis.enabled: false
                    yAxis.enabled: true
                    grabPermissions: PointerHandler.CanTakeOverFromAnything
                    property real _startY: 0
                    onActiveChanged: {
                        if (active) {
                            _startY = centroid.position.y
                        } else {
                            var dy = centroid.position.y - _startY
                            if (dy < -40) musicList.advance(1)
                            else if (dy > 40) musicList.advance(-1)
                        }
                    }
                }
                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (event.angleDelta.y < -10) musicList.advance(1)
                        else if (event.angleDelta.y > 10) musicList.advance(-1)
                    }
                }
            }

            // ── Expanded: routine ─────────────────────────────────────────
            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 12
                opacity: (bookBar.expanded && bookBar.curMode === "routine") ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Row {
                    id: routineHeader
                    spacing: 12
                    Rectangle {
                        width: 44; height: 44; radius: 22; color: bookBar.bbHov
                        anchors.verticalCenter: parent.verticalCenter
                        Text { anchors.centerIn: parent; text: bookBar.routine ? (bookBar.routine.icon || "\u2699\uFE0F") : "\u2699\uFE0F"; font.pixelSize: 22 }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text { text: bookBar.routine ? bookBar.routine.name : ""; color: bookBar.bbTx; font.pixelSize: 18; font.weight: Font.Bold; font.letterSpacing: -0.3 }
                        Text { text: "Rutina activa"; color: bookBar.bbTx2; font.pixelSize: 11; font.weight: Font.Medium }
                    }
                    // Clic en el header cierra la pill
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bookBar.expanded = false }
                }

                Row {
                    spacing: 8; width: parent.width
                    Rectangle {
                        width: (parent.width-8)/2; height: 64; radius: 16; color: bookBar.bbHov
                        Column {
                            anchors.centerIn: parent; spacing: 3
                            Text { text: "Horario"; color: bookBar.bbTx2; font.pixelSize: 9; font.weight: Font.SemiBold; anchors.horizontalCenter: parent.horizontalCenter }
                            Row {
                                spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                Text { text: bookBar.routine ? bookBar.routine.startTime : "--"; color: bookBar.bbTx; font.pixelSize: 13; font.weight: Font.Bold }
                                Text { text: "\u2192"; color: bookBar.bbTx2; font.pixelSize: 11 }
                                Text { text: bookBar.routine ? bookBar.routine.endTime : "--"; color: bookBar.bbTx; font.pixelSize: 13; font.weight: Font.Bold }
                            }
                        }
                    }
                    Rectangle {
                        width: (parent.width-8)/2; height: 64; radius: 16; color: bookBar.bbHov
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { text: "Objetivo"; color: bookBar.bbTx2; font.pixelSize: 9; font.weight: Font.SemiBold; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: bookBar.routine ? bookBar.routine.objective : "--"; color: bookBar.bbTx; font.pixelSize: 20; font.weight: Font.Bold; font.letterSpacing: -0.4; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 38; radius: 19
                    color: deactMA.containsMouse ? Qt.rgba(bookBar.bbRed.r, bookBar.bbRed.g, bookBar.bbRed.b, 0.18) : bookBar.bbHov
                    Behavior on color { ColorAnimation { duration: 140 } }
                    scale: deactMA.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 140 } }
                    Text { anchors.centerIn: parent; text: "Desactivar rutina"
                        color: deactMA.containsMouse ? bookBar.bbRed : bookBar.bbTx; font.pixelSize: 12; font.weight: Font.SemiBold }
                    MouseArea {
                        id: deactMA
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => { bookBar.deactivateRoutine(); mouse.accepted = true }
                    }
                }
            }

            // Expand-on-click (solo cuando colapsada). Cerrar = clic en album art.
            MouseArea {
                anchors.fill: parent
                z: -1
                enabled: !bookBar.expanded
                onClicked: mouse => {
                    if (bookBar.curMode === "music" || bookBar.curMode === "routine") bookBar.expanded = true
                    else mouse.accepted = false
                }
            }
        }

        // Outer player dots (right of centerPill, expanded music only)
        Column {
            id: playerDotsRow
            visible: bookBar.expanded && bookBar.curMode === "music" && bookBar.realCount >= 2
            width: visible ? 26 : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            readonly property int activeReal: bookBar.realIdxOf(musicList.currentIndex)
            Repeater {
                model: bookBar.realCount
                delegate: Rectangle {
                    readonly property bool isActive: index === playerDotsRow.activeReal
                    width: 9
                    height: isActive ? 30 : 9
                    radius: width / 2
                    color: isActive ? bookBar.bbTx : Qt.rgba(bookBar.bbTx.r, bookBar.bbTx.g, bookBar.bbTx.b, 0.45)
                    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
                    layer.enabled: true
                    layer.smooth: true
                    Behavior on height {
                        NumberAnimation { duration: 220; easing.bezierCurve: [0.32, 0.72, 0, 1, 1, 1] }
                    }
                    Behavior on color { ColorAnimation { duration: 180 } }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        onClicked: if (bookBar.realCount > 1) musicList.goTo(bookBar.realRows[index])
                    }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: counterTxt.implicitWidth + 10
                height: 16
                radius: 8
                color: bookBar.bbHov
                Text {
                    id: counterTxt
                    anchors.centerIn: parent
                    text: (playerDotsRow.activeReal + 1) + " / " + bookBar.realCount
                    color: bookBar.bbTx2
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }
        }

        // Right mini pill (D-shape, lado interior recto)
        Item {
            id: rightPill
            visible: bookBar.rightMode !== "" && !bookBar.expanded
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 44
            opacity: rightMA.containsMouse ? 1.0 : 0.92
            scale: rightMA.pressed ? 0.94 : 1.0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

            Image {
                anchors.fill: parent; smooth: true
                sourceSize: Qt.size(width * 2, height * 2)
                source: bookBar.svgDPill(parent.width, parent.height, "right",
                    bookBar.colorToHex(bookBar.bbCard),
                    bookBar.colorToHex(bookBar.dynamicAccent),
                    bookBar.hasDynamicAccent ? 1.5 : 0)
            }
            TintIcon {
                visible: bookBar.rightMode === "battery"
                anchors.centerIn: parent; size: 22
                source: Qt.resolvedUrl("bookbar-icons/charging.svg")
                tint: bookBar.isCharging ? bookBar.bbGreen : bookBar.bbTx
            }
            Item {
                visible: bookBar.rightMode === "music"
                anchors.centerIn: parent
                width: 36; height: 36
                Rectangle { id: rArtMask; anchors.fill: parent; radius: 18; color: "white"; visible: false; layer.enabled: true }
                Image { id: rArtImg; anchors.fill: parent
                    source: bookBar.artUrl === "" ? "" : bookBar.artUrl + (bookBar.artUrl.indexOf("#") < 0 ? "#" : "&") + "t=" + bookBar.artReloadTick
                    fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true; asynchronous: true
                    cache: false
                    readonly property bool isReady: status === Image.Ready && bookBar.artUrl !== ""
                    visible: false; layer.enabled: isReady }
                OpacityMask { anchors.fill: parent; source: rArtImg; maskSource: rArtMask; visible: rArtImg.isReady }
                TintIcon {
                    visible: bookBar.artUrl === "" || !rArtImg.isReady
                    anchors.centerIn: parent; size: 20; tint: "white"
                    source: bookBar.isPlaying ? Qt.resolvedUrl("bookbar-icons/pause.svg") : Qt.resolvedUrl("bookbar-icons/play.svg")
                }
                Rectangle {
                    anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.rightMargin: -3; anchors.bottomMargin: -3
                    width: 17; height: 17; radius: 8.5
                    color: bookBar.bbCard
                    Kirigami.Icon { anchors.centerIn: parent; width: 11; height: 11
                        source: bookBar.appIcon; fallback: "applications-multimedia" }
                }
                Rectangle {
                    visible: bookBar.playerCount > 1
                    anchors.left: parent.left; anchors.top: parent.top
                    anchors.leftMargin: -3; anchors.topMargin: -3
                    width: 15; height: 15; radius: 7.5
                    color: bookBar.bbBlue
                    Text { anchors.centerIn: parent; text: bookBar.playerCount; color: "white"
                        font.pixelSize: 9; font.weight: Font.Bold }
                }
            }
            Text { visible: bookBar.rightMode === "routine"; anchors.centerIn: parent
                   text: bookBar.routine ? (bookBar.routine.icon || "\u2699\uFE0F") : "\u2699\uFE0F"; font.pixelSize: 18 }
            MouseArea { id: rightMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: bookBar.switchModeAndOpen((bookBar.modeIdx + 1) % bookBar.modes.length) }
        }
    }

    // ── Tinted icon (SVGs are black by default → colorize)
    component TintIcon: Item {
        property string source
        property int    size: 22
        property color  tint: "white"
        property bool   preserveColor: false
        width: size; height: size
        Image {
            id: srcImg
            anchors.centerIn: parent
            width: parent.size; height: parent.size
            source: parent.source
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            sourceSize.width:  parent.size * 2
            sourceSize.height: parent.size * 2
            visible: parent.preserveColor
            smooth: true
            mipmap: true
            layer.enabled: !parent.preserveColor
        }
        MultiEffect {
            source: srcImg
            anchors.fill: srcImg
            visible: !parent.preserveColor
            colorization: 1.0
            colorizationColor: parent.tint
            brightness: 0.0
        }
    }

    component BarBtn: Rectangle {
        property string iconSrc
        property int    size: 34
        property real   iconRatio: 0.52
        property bool   visualEnabled: true
        signal triggered
        width: size; height: size; radius: size/2
        color: ma.containsMouse ? bookBar.bbAct : bookBar.bbHov
        opacity: visualEnabled ? 1.0 : 0.45
        scale: ma.pressed ? 0.92 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120 } }
        TintIcon { anchors.centerIn: parent; size: parent.size * parent.iconRatio; source: parent.iconSrc; tint: bookBar.bbTx }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: mouse => { parent.triggered(); mouse.accepted = true } }
    }
}
