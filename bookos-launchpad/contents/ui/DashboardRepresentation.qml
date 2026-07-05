/*
    BookOS Launchpad — DashboardRepresentation.qml
    Paginated grid, swipe gestures, search, folders, blur, dark/light theme.
    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import QtQml 2.15

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker


Kicker.DashboardWindow {
    id: root

    // ── config shortcuts ────────────────────────────────────────────────
    property int  cfg_iconSize:   Plasmoid.configuration.iconSize
    property real cfg_blur:       Plasmoid.configuration.blurRadius
    property bool cfg_showLabels: Plasmoid.configuration.showLabels
    property string cfg_scrollMode: Plasmoid.configuration.scrollMode || "paged"
    property bool isPaged: cfg_scrollMode === "paged"

    // Auto-detect dark/light from KDE color scheme luminance
    property bool cfg_darkTheme: {
        var bg = Kirigami.Theme.backgroundColor
        // perceptual luminance
        var lum = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        return lum < 0.5
    }

    // ── derived ──────────────────────────────────────────────────────────
    // Fixed grid: 6 columns × 5 rows.
    property int cfg_cols: 6
    property int cfg_rows: 5
    property int appsPerPage: cfg_cols * cfg_rows

    // Compute icon size from available area so 6×5 fills nicely.
    property int gridAvailW: Math.max(640, width  * 0.72)
    property int gridAvailH: Math.max(480, height * 0.72)
    property int cellW:      Math.max(80, Math.floor(gridAvailW / cfg_cols))
    property int cellH:      Math.max(80, Math.floor(gridAvailH / cfg_rows))
    property int labelH:     cfg_showLabels ? Kirigami.Units.gridUnit * 2 : 0
    property int iconPx:     Math.max(48, Math.min(cellW - Kirigami.Units.gridUnit * 3,
                                                    cellH - labelH - Kirigami.Units.gridUnit * 2))

    // palette helpers
    property color fgColor: cfg_darkTheme ? Qt.rgba(1, 1, 1, 1)
                                          : Qt.rgba(0.10, 0.10, 0.10, 1)
    property color bgColor: cfg_darkTheme ? Qt.rgba(0.12, 0.12, 0.13, 0.92)
                                          : Qt.rgba(0.98, 0.98, 0.98, 0.92)
    property color overlayColor: cfg_darkTheme
                                 ? Qt.rgba(0.06, 0.06, 0.08, 1.0)
                                 : Qt.rgba(0.96, 0.96, 0.98, 1.0)
    property color searchBg: cfg_darkTheme
                              ? Qt.rgba(1, 1, 1, 0.12)
                              : Qt.rgba(0, 0, 0, 0.08)
    property color dotActive: cfg_darkTheme ? Qt.rgba(1, 1, 1, 1)
                                            : Qt.rgba(0.10, 0.10, 0.10, 1)
    property color dotInact:  cfg_darkTheme ? Qt.rgba(1, 1, 1, 0.35)
                                            : Qt.rgba(0, 0, 0, 0.25)

    // ── state ────────────────────────────────────────────────────────────
    property bool  searching:    searchField.text.length > 0
    property int   currentPage:  0
    property int   pageCount:    Math.max(1, Math.ceil(unifiedCount / appsPerPage))

    // Folders: array of { name, members: [globalIdx,…] }. Persisted via configuration.
    property var folders: {
        try { return JSON.parse(Plasmoid.configuration.foldersJson || "[]") }
        catch (e) { return [] }
    }
    function saveFolders() {
        Plasmoid.configuration.foldersJson = JSON.stringify(folders)
        foldersChanged()
        rebuildTick++
    }

    // Item order: { "App Name": position, "folder:0": position }
    property var itemOrder: {
        try { return JSON.parse(Plasmoid.configuration.orderJson || "{}") }
        catch (e) { return {} }
    }
    function saveOrder() {
        Plasmoid.configuration.orderJson = JSON.stringify(itemOrder)
        itemOrderChanged()
        rebuildTick++
    }
    function itemKey(it) {
        return it.type === "folder" ? ("folder:" + it.folderIdx) : it.name
    }

    // Drag state for creating folders
    property int   dragSourceIdx: -1
    property int   dragHoverIdx:  -1

    // Inner-folder drag state (app being dragged out of an open folder)
    property bool  draggingOutOfFolder: false
    property int   innerDragMemberIdx:  -1
    property int   innerDragFolderIdx:  -1
    property string innerDragAppName:   ""

    backgroundColor: "transparent"

    // ── keyboard ─────────────────────────────────────────────────────────
    onKeyEscapePressed: {
        if (openFolder.visible) { openFolder.close(); return }
        if (searching)          { searchField.clear(); return }
        root.toggle()
    }

    // Global key handling: arrows and page-up/down to paginate when not searching
    Keys.onPressed: event => {
        if (searching || openFolder.visible) return
        if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Right) {
            event.accepted = true
            goNextPage()
        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Left) {
            event.accepted = true
            goPrevPage()
        }
    }

    onVisibleChanged: {
        if (visible) {
            appearAnim.start()
            searchField.clear()
            searchField.forceActiveFocus()
            currentPage = 0
        } else {
            mainContent.opacity = 0
        }
    }

    // allApps: pick the All-Apps row from RootModel.
    property var allApps: {
        if (!kicker.rootModelObj) return null
        var rm = kicker.rootModelObj
        if (rm.count <= 0) return null
        var best = null
        var bestCount = -1
        for (var i = 0; i < rm.count; i++) {
            var m = rm.modelForRow(i)
            if (m && m.count > bestCount) { best = m; bestCount = m.count }
        }
        return best
    }

    // Tick bumped any time folders/order change to force re-eval
    property int rebuildTick: 0

    // Unified items list: { type, name, icon, sourceIdx, members?, folderIdx? }
    property var unifiedItems: {
        // explicit deps so Qt re-evaluates
        var _ = rebuildTick
        return rebuildUnifiedItems(allApps, folders, itemOrder)
    }

    // Caché de apps: nombre, nombre normalizado (para buscar) e icono, leídos
    // UNA vez del modelo. Antes cada tecla de búsqueda releía model.data() +
    // normalize() para todas las apps. La lectura de model.count dentro del
    // binding registra la dependencia → se rehace solo si cambia el modelo.
    property var appCache: {
        var model = allApps
        if (!model) return []
        var out = []
        for (var i = 0; i < model.count; i++) {
            var name = model.data(model.index(i, 0), Qt.DisplayRole) || ""
            out.push({
                name: name,
                nName: normalize(name),
                icon: model.data(model.index(i, 0), Qt.DecorationRole) || "",
                sourceIdx: i
            })
        }
        return out
    }

    function rebuildUnifiedItems(model, folderArr, orderMap) {
        if (!model) return []
        // Map of folder member names → owning folder index
        var memberSet = {}
        for (var f = 0; f < folderArr.length; f++) {
            var m = folderArr[f].members || []
            for (var k = 0; k < m.length; k++) memberSet[m[k]] = f
        }
        // Resolver por nombre desde la caché (sin releer el modelo)
        var appIdxByName = {}
        var appIconByName = {}
        var apps = []
        for (var i = 0; i < appCache.length; i++) {
            var entry = appCache[i]
            appIdxByName[entry.name]  = entry.sourceIdx
            appIconByName[entry.name] = entry.icon
            if (memberSet.hasOwnProperty(entry.name)) continue   // hidden inside folder
            apps.push({ type: "app", name: entry.name, icon: entry.icon, sourceIdx: entry.sourceIdx })
        }
        // Folders go first (typical macOS launchpad behaviour: folders mixed at front)
        var out = []
        for (var f2 = 0; f2 < folderArr.length; f2++) {
            var fol = folderArr[f2]
            var resolved = []
            var miniIcons = []
            for (var j = 0; j < (fol.members || []).length; j++) {
                var mn = fol.members[j]
                if (appIdxByName.hasOwnProperty(mn)) {
                    resolved.push({ name: mn, icon: appIconByName[mn], sourceIdx: appIdxByName[mn] })
                    if (miniIcons.length < 4) miniIcons.push(appIconByName[mn])
                }
            }
            // Skip empty folders (all members uninstalled)
            if (resolved.length === 0) continue
            out.push({
                type: "folder",
                name: fol.name || i18n("Folder"),
                miniIcons: miniIcons,
                members: resolved,
                folderIdx: f2,
                color: fol.color || "#3F51B5"
            })
        }
        var combined = out.concat(apps)

        // Apply persisted ordering. Items with order go first sorted by it,
        // unordered items keep their natural sequence at the end.
        var withOrder = []
        var withoutOrder = []
        for (var ci = 0; ci < combined.length; ci++) {
            var it = combined[ci]
            var key = it.type === "folder" ? ("folder:" + it.folderIdx) : it.name
            if (orderMap && orderMap.hasOwnProperty(key)) {
                withOrder.push({ it: it, p: orderMap[key] })
            } else {
                withoutOrder.push(it)
            }
        }
        withOrder.sort(function(a, b) { return a.p - b.p })
        var sorted = withOrder.map(function(x) { return x.it }).concat(withoutOrder)
        return sorted
    }

    // Total items count
    property int unifiedCount: unifiedItems.length

    // ── local search: filtra la caché (apps + miembros de folders) ──
    property string searchText: ""
    property var searchResults: filterSearch(searchText, appCache)
    property int searchSelectedIdx: 0
    onSearchResultsChanged: searchSelectedIdx = 0

    function activateSearchResult(idx) {
        if (idx < 0 || idx >= searchResults.length) return
        var entry = searchResults[idx]
        if (root.allApps && entry) {
            root.allApps.trigger(entry.sourceIdx, "", null)
            root.toggle()
        }
    }

    function normalize(s) {
        if (!s) return ""
        // NFD: separa letra + diacritico, luego elimina combining marks U+0300-U+036F
        return s.toString()
                .normalize("NFD")
                .replace(/[̀-ͯ]/g, "")
                .toLowerCase()
                .trim()
    }

    // Puntúa un candidato contra la query normalizada. Menor = mejor; -1 = no matchea.
    //   0 exacto · 1 prefijo · 2 prefijo de palabra ("code"→"Visual Studio Code")
    //   3 iniciales ("vsc"→"Visual Studio Code") · 4+ substring (penaliza posición)
    //   8 subsecuencia difusa ("gmp"→"Gimp", solo con query de 3+ letras)
    function scoreMatch(nName, q) {
        if (nName === q) return 0
        if (nName.indexOf(q) === 0) return 1
        var words = nName.split(/[\s\-_.()]+/)
        var initials = ""
        for (var w = 0; w < words.length; w++) {
            if (!words[w]) continue
            if (w > 0 && words[w].indexOf(q) === 0) return 2
            initials += words[w].charAt(0)
        }
        if (q.length >= 2 && initials.indexOf(q) === 0) return 3
        var pos = nName.indexOf(q)
        if (pos > 0) return 4 + Math.min(pos, 30) / 100
        if (q.length >= 3) {
            var qi = 0
            for (var i = 0; i < nName.length && qi < q.length; i++)
                if (nName.charAt(i) === q.charAt(qi)) qi++
            if (qi === q.length) return 8
        }
        return -1
    }

    function filterSearch(query, cache) {
        if (!query || !cache) return []
        var q = normalize(query)
        if (q.length === 0) return []
        var hits = []
        for (var i = 0; i < cache.length; i++) {
            var entry = cache[i]
            var s = scoreMatch(entry.nName, q)
            if (s < 0) continue
            hits.push({ name: entry.name, nName: entry.nName, score: s,
                        icon: entry.icon, sourceIdx: entry.sourceIdx })
        }
        // mejor puntuación primero; a igualdad, nombre más corto y luego alfabético
        hits.sort(function(a, b) {
            if (a.score !== b.score) return a.score - b.score
            if (a.nName.length !== b.nName.length) return a.nName.length - b.nName.length
            return a.nName.localeCompare(b.nName)
        })
        if (hits.length > 64) hits.length = 64
        return hits
    }

    function reset() {
        currentPage = 0
    }

    // Drop logic.
    // mode: "merge" → over another cell → create / add to folder
    //       "move"  → empty area or insertion point → reorder
    function dropOnto(srcUnified, dstUnified, mode) {
        if (srcUnified < 0) return
        var src = unifiedItems[srcUnified]
        if (!src) return

        if (mode === "move") {
            moveItemTo(srcUnified, dstUnified)
            return
        }

        // merge mode (default)
        if (dstUnified < 0 || dstUnified === srcUnified) return
        var dst = unifiedItems[dstUnified]
        if (!dst) return
        if (src.type !== "app") {
            // dragging a folder onto something → just move it
            moveItemTo(srcUnified, dstUnified)
            return
        }
        var arr = folders.slice()
        if (dst.type === "folder") {
            var f = Object.assign({}, arr[dst.folderIdx])
            f.members = (f.members || []).slice()
            if (f.members.indexOf(src.name) === -1) f.members.push(src.name)
            arr[dst.folderIdx] = f
        } else {
            arr.push({
                name: i18n("New folder"),
                members: [src.name, dst.name]
            })
        }
        folders = arr
        saveFolders()
    }

    // Reorder: place srcUnified at dstUnified position (insert), shifting others.
    function moveItemTo(srcIdx, dstIdx) {
        if (srcIdx < 0 || srcIdx >= unifiedItems.length) return
        if (dstIdx < 0) dstIdx = unifiedItems.length
        if (dstIdx > unifiedItems.length) dstIdx = unifiedItems.length
        if (srcIdx === dstIdx) return

        // Build new sequence
        var seq = unifiedItems.slice()
        var moved = seq.splice(srcIdx, 1)[0]
        // Adjust dstIdx if we removed before it
        var insertAt = (dstIdx > srcIdx) ? dstIdx - 1 : dstIdx
        if (insertAt > seq.length) insertAt = seq.length
        seq.splice(insertAt, 0, moved)

        // Persist by writing positions for ALL items (consistent ordering)
        var newOrder = {}
        for (var i = 0; i < seq.length; i++) {
            var it = seq[i]
            var key = it.type === "folder" ? ("folder:" + it.folderIdx) : it.name
            newOrder[key] = i
        }
        itemOrder = newOrder
        saveOrder()
    }

    function openFolderAt(folderItem) {
        if (!folderItem || folderItem.type !== "folder") return
        var appsList = []
        for (var i = 0; i < folderItem.members.length; i++) {
            var m = folderItem.members[i]
            ;(function(idx, name, icon) {
                appsList.push({
                    name: name,
                    icon: icon,
                    trigger: function() {
                        if (root.allApps) root.allApps.trigger(idx, "", null)
                    }
                })
            })(m.sourceIdx, m.name, m.icon)
        }
        openFolder.folderApps  = appsList
        openFolder.folderName  = folderItem.name
        openFolder.folderIdx   = folderItem.folderIdx
        openFolder.folderColor = folders[folderItem.folderIdx].color || "#3F51B5"
        innerDragFolderIdx     = folderItem.folderIdx
        openFolder.open()
    }

    function removeAppFromFolder(folderIdx, appName) {
        if (folderIdx < 0 || folderIdx >= folders.length) return
        var arr = folders.slice()
        var f = Object.assign({}, arr[folderIdx])
        f.members = (f.members || []).filter(function(n) { return n !== appName })
        if (f.members.length === 0) {
            // remove empty folder entirely
            arr.splice(folderIdx, 1)
            // adjust order keys for shifted folder indices
            var newOrder = {}
            for (var k in itemOrder) {
                if (!itemOrder.hasOwnProperty(k)) continue
                if (k === ("folder:" + folderIdx)) continue
                if (k.indexOf("folder:") === 0) {
                    var oldIdx = parseInt(k.split(":")[1])
                    if (oldIdx > folderIdx) {
                        newOrder["folder:" + (oldIdx - 1)] = itemOrder[k]
                        continue
                    }
                }
                newOrder[k] = itemOrder[k]
            }
            itemOrder = newOrder
            saveOrder()
        } else {
            arr[folderIdx] = f
        }
        folders = arr
        saveFolders()
    }

    function reorderFolderMember(folderIdx, fromIdx, toIdx) {
        if (folderIdx < 0 || folderIdx >= folders.length) return
        var arr = folders.slice()
        var f = Object.assign({}, arr[folderIdx])
        var members = (f.members || []).slice()
        if (fromIdx < 0 || fromIdx >= members.length) return
        if (toIdx > members.length) toIdx = members.length
        var moved = members.splice(fromIdx, 1)[0]
        var insertAt = (toIdx > fromIdx) ? toIdx - 1 : toIdx
        members.splice(insertAt, 0, moved)
        f.members = members
        arr[folderIdx] = f
        folders = arr
        saveFolders()

        // Reopen folder visually (rebuild appsList)
        openFolderAt({
            type: "folder",
            name: f.name || i18n("Folder"),
            members: members.map(function(n) { return { name: n, sourceIdx: -1, icon: "" } }),
            folderIdx: folderIdx
        })
    }

    function findUnifiedIdx(appName) {
        for (var i = 0; i < unifiedItems.length; i++) {
            var it = unifiedItems[i]
            if (it.type === "app" && it.name === appName) return i
        }
        return -1
    }

    function renameFolder(idx, newName) {
        if (idx < 0 || idx >= folders.length) return
        var arr = folders.slice()
        var f = Object.assign({}, arr[idx])
        f.name = newName
        arr[idx] = f
        folders = arr
        saveFolders()
    }

    function recolorFolder(idx, color) {
        if (idx < 0 || idx >= folders.length) return
        var arr = folders.slice()
        var f = Object.assign({}, arr[idx])
        f.color = color
        arr[idx] = f
        folders = arr
        saveFolders()
    }


    // Drop-mode: "merge" (center of cell, ≤45% from center) or "move" (edges)
    property string dragHoverMode: "none"

    function updateDragHover(x, y) {
        if (!gridArea.visible) {
            root.dragHoverIdx = -1
            root.dragHoverMode = "none"
            return
        }
        // Auto-page-flip when cursor is near horizontal edge of gridArea
        var pGrid = mainContent.mapToItem(gridArea, x, y)
        var edgePad = root.cellW * 0.5
        var nearLeft  = pGrid.x < edgePad
        var nearRight = pGrid.x > gridArea.width - edgePad
        if (root.dragSourceIdx >= 0) {
            if (nearRight) edgeFlipTimer.flipDir = 1
            else if (nearLeft) edgeFlipTimer.flipDir = -1
            else edgeFlipTimer.flipDir = 0
            edgeFlipTimer.running = (edgeFlipTimer.flipDir !== 0)
        }
        var p = mainContent.mapToItem(pagesContainer, x, y)
        var localX = p.x - root.currentPage * gridArea.gridW
        var col = Math.floor(localX / root.cellW)
        var row = Math.floor(p.y / root.cellH)
        if (col < 0 || col >= cfg_cols || row < 0 || row >= cfg_rows) {
            root.dragHoverIdx = -1
            root.dragHoverMode = "none"
            return
        }
        var startIdx = root.currentPage * appsPerPage
        var idx = startIdx + row * cfg_cols + col
        if (idx >= unifiedCount) {
            // empty slot inside grid → move to end of page
            root.dragHoverIdx = unifiedCount
            root.dragHoverMode = "move"
            return
        }
        // Decide merge vs move based on cursor position within cell:
        // central 50%×50% area → merge, otherwise → move (insert before/after)
        var cx = (col + 0.5) * root.cellW
        var cy = (row + 0.5) * root.cellH
        var dx = localX - cx
        var dy = p.y - cy
        var inCenter = Math.abs(dx) < root.cellW * 0.25 && Math.abs(dy) < root.cellH * 0.25
        if (inCenter) {
            root.dragHoverIdx  = idx
            root.dragHoverMode = "merge"
        } else {
            // insert: if cursor is on the right half, insert AFTER; else BEFORE
            var insertAt = (localX > cx) ? idx + 1 : idx
            root.dragHoverIdx  = insertAt
            root.dragHoverMode = "move"
        }
    }

    // ── page swipe helper ────────────────────────────────────────────────
    function goNextPage() {
        if (currentPage < pageCount - 1) currentPage++
    }
    function goPrevPage() {
        if (currentPage > 0) currentPage--
    }

    // ── wheel/touchpad gesture state (root scope, plain JS object) ──────
    property real _accumX: 0
    property real _accumY: 0
    property double _lastFire: 0

    function processWheel(dx, dy) {
        if (openFolder.visible || searching) return false
        if (dx === 0 && dy === 0) return true

        var now = Date.now()
        // During cooldown: drop events so they don't pile into the next swipe
        if (now - _lastFire < 180) {
            _accumX = 0; _accumY = 0
            return true
        }

        _accumX += dx
        _accumY += dy
        if (gestResetTimer) gestResetTimer.restart()

        // Horizontal wins on tie — touchpad two-finger swipe
        var horizDominant = Math.abs(_accumX) >= Math.abs(_accumY) * 0.4
        if (horizDominant) {
            if (_accumX <= -20) {
                goNextPage(); _accumX = 0; _accumY = 0; _lastFire = now
                return true
            }
            if (_accumX >= 20) {
                goPrevPage(); _accumX = 0; _accumY = 0; _lastFire = now
                return true
            }
        }
        // Vertical (mouse wheel; touchpad two-finger vertical)
        if (_accumY <= -100) {
            goNextPage(); _accumX = 0; _accumY = 0; _lastFire = now
            return true
        }
        if (_accumY >= 100) {
            goPrevPage(); _accumX = 0; _accumY = 0; _lastFire = now
            return true
        }
        return true
    }

    // ── main item ────────────────────────────────────────────────────────
    mainItem: Item {
        id: mainContent
        width:   root.width
        height:  root.height
        opacity: 0

        // Open animation: fade + gentle zoom-out (Launchpad style)
        ParallelAnimation {
            id: appearAnim
            NumberAnimation { target: mainContent; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: mainContent; property: "scale"; from: 1.06; to: 1; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        // ── wallpaper blur overlay ────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: overlayColor
        }

        // ── kicker reset hookup ───────────────────────────────────────
        Connections {
            target: kicker
            function onReset() { root.reset() }
        }

        Timer {
            id: gestResetTimer
            interval: 250
            onTriggered: {
                root._accumX = 0
                root._accumY = 0
            }
        }

        // ── auto page-flip timer (during drag near edges) ─────────────
        Timer {
            id: edgeFlipTimer
            interval: 700
            repeat: true
            running: false
            property int flipDir: 0
            onTriggered: {
                if (root.dragSourceIdx < 0) { running = false; return }
                if (flipDir > 0) goNextPage()
                else if (flipDir < 0) goPrevPage()
            }
        }

        // Mouse wheel (vertical) → page change (paged) or smooth scroll (continuous).
        // Touchpad horiz scroll handled by Flickable nativamente.
        WheelHandler {
            id: pageWheel
            target: mainContent
            acceptedDevices: PointerDevice.Mouse
            onWheel: (event) => {
                var dy = event.angleDelta.y
                if (root.isPaged) {
                    if (dy <= -60) goNextPage()
                    else if (dy >= 60) goPrevPage()
                } else {
                    // Convert wheel to horizontal scroll on Flickable
                    var step = root.cellW * 1.2
                    pagesFlick.contentX = Math.max(0,
                        Math.min(pagesFlick.contentWidth - pagesFlick.width,
                                 pagesFlick.contentX - (dy / 120) * step))
                }
                event.accepted = true
            }
        }

        // ── click+drag swipe + wheel fallback ─────────────────────────
        MouseArea {
            id: swipeArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            preventStealing: false
            z: -1
            // wheel handled by global WheelHandler — don't double-process here

            property real pressX: 0
            property real pressY: 0
            property bool dragging: false
            property bool vertDrag: false

            onPressed: mouse => {
                pressX = mouse.x; pressY = mouse.y
                dragging = false; vertDrag = false
                mouse.accepted = false
            }
            onPositionChanged: mouse => {
                if (!dragging) {
                    var dx = Math.abs(mouse.x - pressX)
                    var dy = Math.abs(mouse.y - pressY)
                    if (dx > 8 || dy > 8) { dragging = true; vertDrag = dy > dx }
                }
            }
            onReleased: mouse => {
                if (!dragging || vertDrag || openFolder.visible || searching) return
                var d = mouse.x - pressX
                if (d < -60)     goNextPage()
                else if (d > 60) goPrevPage()
            }
            onClicked: mouse => {
                if (openFolder.visible) openFolder.close()
            }
        }

        // ── search bar ───────────────────────────────────────────────
        Item {
            id: searchBar
            anchors.top:              parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin:        Kirigami.Units.largeSpacing * 4
            width:                    Kirigami.Units.gridUnit * 20
            height:                   Kirigami.Units.gridUnit * 3

            Rectangle {
                anchors.fill: parent
                radius:        height / 2
                color:         searchBg
                border.color:  cfg_darkTheme ? Qt.rgba(1,1,1,0.15) : Qt.rgba(0,0,0,0.10)
                border.width:  1
            }

            Kirigami.Icon {
                id: searchIcon
                anchors.left:           parent.left
                anchors.leftMargin:     Kirigami.Units.largeSpacing
                anchors.verticalCenter: parent.verticalCenter
                source:  "search"
                width:   Kirigami.Units.iconSizes.small
                height:  width
                color:   fgColor
                opacity: 0.6
            }

            TextField {
                id: searchField
                anchors.left:           searchIcon.right
                anchors.right:          clearBtn.left
                anchors.leftMargin:     Kirigami.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter
                placeholderText:        i18n("Search apps…")
                background:            null
                color:                 fgColor
                placeholderTextColor:  Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.5)
                font.pixelSize:        Kirigami.Units.gridUnit * 0.85

                onTextChanged: root.searchText = text

                Keys.onPressed: event => {
                    if (!root.searching) {
                        // Sin búsqueda el foco vive aquí: si no tratamos las
                        // flechas, el TextField se las queda (mover cursor) y
                        // nunca llegan al paginador global de root.
                        if (event.key === Qt.Key_Escape) {
                            event.accepted = true
                            root.toggle()
                        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown || event.key === Qt.Key_Down) {
                            event.accepted = true
                            goNextPage()
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp || event.key === Qt.Key_Up) {
                            event.accepted = true
                            goPrevPage()
                        }
                        return
                    }
                    var n = root.searchResults.length
                    var col = cfg_cols
                    if (event.key === Qt.Key_Right) {
                        event.accepted = true
                        if (n > 0) root.searchSelectedIdx = Math.min(n - 1, root.searchSelectedIdx + 1)
                    } else if (event.key === Qt.Key_Left) {
                        event.accepted = true
                        if (n > 0) root.searchSelectedIdx = Math.max(0, root.searchSelectedIdx - 1)
                    } else if (event.key === Qt.Key_Down) {
                        event.accepted = true
                        if (n > 0) root.searchSelectedIdx = Math.min(n - 1, root.searchSelectedIdx + col)
                    } else if (event.key === Qt.Key_Up) {
                        event.accepted = true
                        if (n > 0) root.searchSelectedIdx = Math.max(0, root.searchSelectedIdx - col)
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        event.accepted = true
                        root.activateSearchResult(root.searchSelectedIdx)
                    } else if (event.key === Qt.Key_Escape) {
                        event.accepted = true
                        clear()
                    }
                }
                function clear() { text = "" }
            }

            ToolButton {
                id: clearBtn
                anchors.right:          parent.right
                anchors.rightMargin:    Kirigami.Units.smallSpacing
                anchors.verticalCenter: parent.verticalCenter
                visible:                searchField.text.length > 0
                icon.name:              "edit-clear"
                icon.color:             fgColor
                flat:                   true
                onClicked:              searchField.clear()
            }
        }

        // ── paginated app grid (fixed cols × rows, horizontal sliding) ─
        Item {
            id: gridArea
            anchors.top:              searchBar.bottom
            anchors.bottom:           dotsRow.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin:        Kirigami.Units.gridUnit * 2
            anchors.bottomMargin:     Kirigami.Units.gridUnit
            width:                    cfg_cols * root.cellW
            height:                   cfg_rows * root.cellH
            visible:                  !searching
            clip:                     true

            property int gridW: cfg_cols * root.cellW
            property int gridH: cfg_rows * root.cellH

            // La rueda del ratón: el Flickable consumía el evento antes de que
            // llegara al WheelHandler global — este overlay (solo rueda, los
            // clicks pasan) la captura primero y pagina.
            Item {
                anchors.fill: parent
                z: 40
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: (event) => {
                        var dy = event.angleDelta.y
                        if (root.isPaged) {
                            if (dy <= -60) goNextPage()
                            else if (dy >= 60) goPrevPage()
                        } else {
                            var step = root.cellW * 1.2
                            pagesFlick.contentX = Math.max(0,
                                Math.min(pagesFlick.contentWidth - pagesFlick.width,
                                         pagesFlick.contentX - (dy / 120) * step))
                        }
                        event.accepted = true
                    }
                }
            }

            Flickable {
                id: pagesFlick
                anchors.fill: parent
                contentWidth: gridArea.gridW * Math.max(1, root.pageCount)
                contentHeight: gridArea.gridH
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                interactive: true
                clip: true
                pixelAligned: false
                flickDeceleration: 1500
                maximumFlickVelocity: 15000

                property bool snapping: false
                property real dragStartX: 0
                onMovementStarted: dragStartX = contentX
                onMovementEnded: {
                    if (!root.isPaged) {
                        // continuous: just update currentPage indicator from position
                        var p = Math.round(contentX / gridArea.gridW)
                        root.currentPage = Math.max(0, Math.min(root.pageCount - 1, p))
                        return
                    }
                    snapping = true
                    var delta = contentX - dragStartX
                    var page = root.currentPage
                    var threshold = gridArea.gridW * 0.04
                    if (delta > threshold) page++
                    else if (delta < -threshold) page--
                    page = Math.max(0, Math.min(root.pageCount - 1, page))
                    root.currentPage = page
                    snapAnim.to = page * gridArea.gridW
                    snapAnim.start()
                }
                NumberAnimation {
                    id: snapAnim
                    target: pagesFlick
                    property: "contentX"
                    duration: 200
                    easing.type: Easing.OutQuad
                    onFinished: pagesFlick.snapping = false
                }

                Connections {
                    target: root
                    function onCurrentPageChanged() {
                        if (pagesFlick.snapping) return
                        if (pagesFlick.moving) return
                        snapAnim.to = root.currentPage * gridArea.gridW
                        snapAnim.start()
                    }
                }

            Item {
                id: pagesContainer
                width:  gridArea.gridW * Math.max(1, root.pageCount)
                height: gridArea.gridH
                x:      0
                y:      0

                Repeater {
                    id: pageRep
                    model: root.pageCount

                    Grid {
                        id: pageGrid
                        required property int index
                        x:              index * gridArea.gridW
                        width:          gridArea.gridW
                        height:         gridArea.gridH
                        columns:        cfg_cols
                        rowSpacing:     0
                        columnSpacing:  0
                        // Solo renderiza la página actual y sus vecinas (o todas
                        // mientras el Flickable se mueve) — el resto no pinta.
                        visible: pagesFlick.moving || pagesFlick.snapping
                                 || Math.abs(index - root.currentPage) <= 1

                        property int startIdx: index * appsPerPage
                        property int countOnPage: Math.min(appsPerPage,
                                                           Math.max(0, root.unifiedCount - startIdx))

                        Repeater {
                            model: pageGrid.countOnPage

                            delegate: Item {
                                id: cell
                                required property int index
                                property int globalIdx: pageGrid.startIdx + index
                                property var item: root.unifiedItems[globalIdx] || null

                                property bool isFolder: item ? item.type === "folder" : false
                                property string appName: item ? item.name : ""
                                property var appIcon: item ? item.icon : ""

                                width:  root.cellW
                                height: root.cellH

                                property bool isMergeTarget: root.dragSourceIdx >= 0
                                                      && root.dragHoverMode === "merge"
                                                      && root.dragHoverIdx === globalIdx
                                                      && root.dragSourceIdx !== globalIdx
                                property bool isInsertBefore: root.dragSourceIdx >= 0
                                                      && root.dragHoverMode === "move"
                                                      && root.dragHoverIdx === globalIdx
                                                      && root.dragSourceIdx !== globalIdx
                                property bool isInsertAfter:  root.dragSourceIdx >= 0
                                                      && root.dragHoverMode === "move"
                                                      && root.dragHoverIdx === globalIdx + 1
                                                      && root.dragSourceIdx !== globalIdx

                                // hover suave — mismo estilo que la selección en búsqueda
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    radius: Kirigami.Units.gridUnit
                                    visible: cellHover.hovered && root.dragSourceIdx < 0
                                    color: root.cfg_darkTheme
                                           ? Qt.rgba(1, 1, 1, 0.08)
                                           : Qt.rgba(0, 0, 0, 0.06)
                                }
                                HoverHandler { id: cellHover }

                                // merge highlight (centered glow)
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    radius: Kirigami.Units.gridUnit
                                    color: cell.isMergeTarget ? Qt.rgba(1,1,1,0.18) : "transparent"
                                    border.color: cell.isMergeTarget ? Qt.rgba(1,1,1,0.5) : "transparent"
                                    border.width: cell.isMergeTarget ? 2 : 0
                                    visible: cell.isMergeTarget
                                }
                                // move insertion line (left edge)
                                Rectangle {
                                    visible: cell.isInsertBefore
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width:  3
                                    height: parent.height * 0.7
                                    radius: 2
                                    color:  root.fgColor
                                }
                                // move insertion line (right edge)
                                Rectangle {
                                    visible: cell.isInsertAfter
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width:  3
                                    height: parent.height * 0.7
                                    radius: 2
                                    color:  root.fgColor
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Kirigami.Units.smallSpacing

                                    // Folder cell: rounded square with 2x2 mini icons + color tint
                                    Item {
                                        visible: cell.isFolder
                                        width:  root.iconPx
                                        height: root.iconPx
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width * 0.22
                                            color: root.cfg_darkTheme
                                                   ? Qt.rgba(1, 1, 1, 0.10)
                                                   : Qt.rgba(0, 0, 0, 0.06)
                                            border.color: root.cfg_darkTheme
                                                          ? Qt.rgba(1, 1, 1, 0.15)
                                                          : Qt.rgba(0, 0, 0, 0.10)
                                            border.width: 1

                                            // Color tint overlay
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                color:  cell.isFolder && cell.item ? cell.item.color : "transparent"
                                                opacity: 0.30
                                                visible: cell.isFolder
                                            }
                                        }
                                        Grid {
                                            anchors.centerIn: parent
                                            columns: 2
                                            spacing: 4
                                            Repeater {
                                                model: cell.isFolder && cell.item ? Math.min(4, cell.item.miniIcons.length) : 0
                                                Kirigami.Icon {
                                                    source: cell.item.miniIcons[index] || ""
                                                    width:  root.iconPx * 0.36
                                                    height: width
                                                    roundToIconSize: false
                                                    smooth: true
                                                    animated: false
                                                }
                                            }
                                        }

                                        scale: cellMouse.pressed && !cellMouse.drag.active ? 0.88 : 1.0
                                        Behavior on scale { SpringAnimation { spring: 4; damping: 0.28; mass: 0.8 } }
                                    }

                                    // Single app icon
                                    Kirigami.Icon {
                                        visible: !cell.isFolder
                                        source: cell.appIcon || "application-x-executable"
                                        fallback: "application-x-executable"
                                        width:  root.iconPx
                                        height: width
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        roundToIconSize: false
                                        smooth: true
                                        animated: false
                                        scale: cellMouse.pressed && !cellMouse.drag.active ? 0.88 : 1.0
                                        Behavior on scale { SpringAnimation { spring: 4; damping: 0.28; mass: 0.8 } }
                                    }

                                    Text {
                                        visible:             root.cfg_showLabels
                                        text:                cell.appName
                                        color:               root.fgColor
                                        font.pixelSize:      Kirigami.Units.gridUnit * 0.75
                                        font.weight:         Font.Medium
                                        style:               Text.Raised
                                        styleColor:          Qt.rgba(0, 0, 0, 0.6)
                                        renderType:          Text.NativeRendering
                                        elide:               Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        width:               root.cellW - Kirigami.Units.smallSpacing
                                    }
                                }

                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    pressAndHoldInterval: 350
                                    preventStealing: true
                                    hoverEnabled: false
                                    // Only apps are draggable (folders use long-press → rename)
                                    drag.target: dragMode ? dragGhost : null

                                    property bool dragMode: false

                                    onPressAndHold: mouse => {
                                        dragMode = true
                                        root.dragSourceIdx = cell.globalIdx
                                        var p = mapToItem(mainContent, mouse.x, mouse.y)
                                        dragGhost.x = p.x - dragGhost.width / 2
                                        dragGhost.y = p.y - dragGhost.height / 2
                                        if (cell.isFolder && cell.item) {
                                            dragGhost.ghostIsFolder    = true
                                            dragGhost.ghostMiniIcons   = cell.item.miniIcons || []
                                            dragGhost.ghostFolderColor = cell.item.color || "#3F51B5"
                                            dragGhost.ghostIcon        = ""
                                        } else {
                                            dragGhost.ghostIsFolder    = false
                                            dragGhost.ghostMiniIcons   = []
                                            dragGhost.ghostIcon        = cell.appIcon || ""
                                        }
                                        dragGhost.visible = true
                                    }

                                    onPositionChanged: mouse => {
                                        if (!dragMode) return
                                        var p = mapToItem(mainContent, mouse.x, mouse.y)
                                        root.updateDragHover(p.x, p.y)
                                    }

                                    onReleased: mouse => {
                                        if (dragMode) {
                                            var src = root.dragSourceIdx
                                            var dst = root.dragHoverIdx
                                            var mode = root.dragHoverMode
                                            dragMode = false
                                            dragGhost.visible = false
                                            dragGhost.ghostIcon = ""
                                            dragGhost.ghostIsFolder = false
                                            dragGhost.ghostMiniIcons = []
                                            root.dragSourceIdx = -1
                                            root.dragHoverIdx  = -1
                                            root.dragHoverMode = "none"
                                            edgeFlipTimer.running = false
                                            edgeFlipTimer.flipDir = 0
                                            if (mode !== "none") {
                                                root.dropOnto(src, dst, mode)
                                            }
                                        }
                                    }
                                    onCanceled: {
                                        if (dragMode) {
                                            dragMode = false
                                            dragGhost.visible = false
                                            dragGhost.ghostIcon = ""
                                            dragGhost.ghostIsFolder = false
                                            dragGhost.ghostMiniIcons = []
                                            root.dragSourceIdx = -1
                                            root.dragHoverIdx  = -1
                                            root.dragHoverMode = "none"
                                        }
                                    }
                                    onClicked: mouse => {
                                        if (dragMode) return
                                        if (mouse.button === Qt.RightButton) {
                                            if (cell.isFolder) {
                                                folderCtxMenu.folderIdx = cell.item.folderIdx
                                                folderCtxMenu.folderName = cell.item.name
                                                folderCtxMenu.popup()
                                            } else if (cell.item) {
                                                appCtxMenu.appName = cell.item.name
                                                appCtxMenu.sourceIdx = cell.item.sourceIdx
                                                appCtxMenu.popup()
                                            }
                                            return
                                        }
                                        if (mouse.button !== Qt.LeftButton) return
                                        if (cell.isFolder) {
                                            root.openFolderAt(cell.item)
                                        } else if (root.allApps && cell.item) {
                                            root.allApps.trigger(cell.item.sourceIdx, "", null)
                                            root.toggle()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            }
        }

        // ── search results (local filter) ──────────────────────────
        Item {
            id: searchResultsGrid
            anchors.top:              searchBar.bottom
            anchors.bottom:           dotsRow.top
            anchors.horizontalCenter: parent.horizontalCenter
            // mismo margen que gridArea: al buscar, la cuadrícula no salta
            anchors.topMargin:        Kirigami.Units.gridUnit * 2
            anchors.bottomMargin:     Kirigami.Units.gridUnit
            width:  cfg_cols * root.cellW
            height: cfg_rows * root.cellH
            visible: searching
            clip: true

            Flickable {
                id: searchScroll
                anchors.fill: parent
                contentWidth:  width
                contentHeight: searchGrid.implicitHeight
                clip: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                Grid {
                    id: searchGrid
                    width:    parent.width
                    columns:  cfg_cols
                    rowSpacing:    Kirigami.Units.smallSpacing
                    columnSpacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: root.searchResults

                        delegate: Item {
                            id: srItem
                            required property int index
                            required property var modelData
                            width:  root.cellW
                            height: root.cellH

                            // selection highlight (only for first / arrow-selected)
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                radius: Kirigami.Units.gridUnit
                                visible: root.searchSelectedIdx === srItem.index
                                color:  root.cfg_darkTheme
                                        ? Qt.rgba(1, 1, 1, 0.16)
                                        : Qt.rgba(0, 0, 0, 0.10)
                                border.color: root.cfg_darkTheme
                                              ? Qt.rgba(1, 1, 1, 0.45)
                                              : Qt.rgba(0, 0, 0, 0.35)
                                border.width: 2
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: srItem.modelData.icon || "application-x-executable"
                                    fallback: "application-x-executable"
                                    width:  root.iconPx
                                    height: width
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    roundToIconSize: false
                                    smooth: true
                                    animated: false
                                    scale: srTap.pressed ? 0.88 : 1.0
                                    Behavior on scale { SpringAnimation { spring: 4; damping: 0.28; mass: 0.8 } }
                                }
                                Text {
                                    visible: root.cfg_showLabels
                                    text:    srItem.modelData.name
                                    color:   root.fgColor
                                    font.pixelSize:      Kirigami.Units.gridUnit * 0.75
                                    font.weight:         Font.Medium
                                    style:               Text.Raised
                                    styleColor:          Qt.rgba(0, 0, 0, 0.6)
                                    renderType:          Text.NativeRendering
                                    elide:               Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    width:               root.cellW - Kirigami.Units.smallSpacing
                                }
                            }

                            // Hover updates selection so mouse and keyboard are consistent
                            HoverHandler {
                                onHoveredChanged: if (hovered) root.searchSelectedIdx = srItem.index
                            }
                            TapHandler {
                                id: srTap
                                onTapped: root.activateSearchResult(srItem.index)
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.searchResults.length === 0 && root.searchText.length > 0
                text: i18n("No results")
                color: root.fgColor
                opacity: 0.5
                font.pixelSize: Kirigami.Units.gridUnit
            }
        }

        // ── page dot indicator ────────────────────────────────────────
        PageDots {
            id: dotsRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom:           parent.bottom
            anchors.bottomMargin:     Kirigami.Units.largeSpacing * 3
            visible:                  !searching && root.pageCount > 1
            pageCount:                root.pageCount
            current:                  root.currentPage
            activeColor:              root.dotActive
            inactiveColor:            root.dotInact
            onPageClicked: function(p) { root.currentPage = p }
        }

        // ── drag ghost (icon que sigue al cursor) ────────────────────
        Item {
            id: dragGhost
            visible: false
            width:   root.iconPx
            height:  root.iconPx
            z:       1000
            opacity: 0.85

            property var ghostIcon: ""
            property bool ghostIsFolder: false
            property var  ghostMiniIcons: []
            property string ghostFolderColor: "#3F51B5"

            // single app icon mode
            Kirigami.Icon {
                anchors.fill: parent
                visible: !dragGhost.ghostIsFolder
                source: dragGhost.ghostIcon || "application-x-executable"
                fallback: "application-x-executable"
                roundToIconSize: false
                smooth: true
                animated: false
            }
            // folder mode: rounded rect with mini icons
            Item {
                anchors.fill: parent
                visible: dragGhost.ghostIsFolder
                Rectangle {
                    anchors.fill: parent
                    radius: width * 0.22
                    color: Qt.rgba(0.5, 0.5, 0.5, 0.25)
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: dragGhost.ghostFolderColor
                        opacity: 0.35
                    }
                }
                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    spacing: 4
                    Repeater {
                        model: Math.min(4, dragGhost.ghostMiniIcons.length)
                        Kirigami.Icon {
                            source: dragGhost.ghostMiniIcons[index] || ""
                            width:  dragGhost.width * 0.36
                            height: width
                            roundToIconSize: false
                            smooth: true
                            animated: false
                        }
                    }
                }
            }
        }


        // ── folder popup ──────────────────────────────────────────────
        FolderView {
            id: openFolder
            iconSize:    Math.min(root.iconPx, 80)
            cellWidth:   Math.min(root.cellW, 120)
            cellHeight:  Math.min(root.cellH, 140)
            showLabel:   root.cfg_showLabels
            fgColor:     root.fgColor
            bgColor:     root.bgColor
            darkTheme:   root.cfg_darkTheme
            onAppLaunched:    root.toggle()
            onRenamed:        function(idx, newName)  { root.renameFolder(idx, newName) }
            onColorChanged:   function(idx, newColor) { root.recolorFolder(idx, newColor) }

            // Inner drag: app within folder being moved
            onInnerDragStart: function(memberIdx, appName, iconSrc) {
                root.innerDragMemberIdx = memberIdx
                root.innerDragAppName   = appName
                dragGhost.ghostIcon     = iconSrc || ""
                dragGhost.visible       = true
            }
            onInnerDragMove: function(x, y) {
                // x,y are in folderView coords == fullscreen coords
                dragGhost.x = x - dragGhost.width  / 2
                dragGhost.y = y - dragGhost.height / 2
                // If cursor leaves the card, close folder and switch to grid drag
                var pCard = openFolder.mapToItem(openFolder.card, x, y)
                var insideCard = pCard.x >= 0 && pCard.y >= 0
                                  && pCard.x <= openFolder.card.width
                                  && pCard.y <= openFolder.card.height
                if (!insideCard && !root.draggingOutOfFolder) {
                    root.draggingOutOfFolder = true
                    // Convert inner drag → outer grid drag
                    root.dragSourceIdx = -2   // sentinel: from folder
                    openFolder.close()
                }
                if (root.draggingOutOfFolder) {
                    root.updateDragHover(x, y)
                }
            }
            onInnerDragEnd: function(x, y) {
                if (root.draggingOutOfFolder) {
                    // dropped on grid: remove app from folder, place at hover position
                    var dst  = root.dragHoverIdx
                    var mode = root.dragHoverMode
                    root.removeAppFromFolder(root.innerDragFolderIdx, root.innerDragAppName)
                    if (mode === "move" && dst >= 0) {
                        // The app reappeared at end of unifiedItems; move it to dst
                        var newSrcIdx = root.findUnifiedIdx(root.innerDragAppName)
                        if (newSrcIdx >= 0) root.moveItemTo(newSrcIdx, dst)
                    }
                    root.draggingOutOfFolder = false
                } else {
                    // dropped inside card → reorder within folder if hover detected
                    var hoverIdx = openFolder.computeInnerHoverIdx(x, y)
                    if (hoverIdx >= 0
                        && hoverIdx !== root.innerDragMemberIdx) {
                        root.reorderFolderMember(root.innerDragFolderIdx,
                                                 root.innerDragMemberIdx,
                                                 hoverIdx)
                    }
                }
                dragGhost.visible   = false
                dragGhost.ghostIcon = ""
                root.dragHoverIdx   = -1
                root.dragHoverMode  = "none"
                root.dragSourceIdx  = -1
                root.innerDragMemberIdx = -1
                root.innerDragAppName   = ""
            }
        }

        // ── App context menu (right-click) ────────────────────────
        // Solid opaque background: these QML popups get no KWin blur, so a
        // translucent theme background makes the text unreadable over icons.
        component CtxMenuBackground : Rectangle {
            implicitWidth: 230
            color: {
                var c = Kirigami.Theme.backgroundColor
                return Qt.rgba(c.r, c.g, c.b, 1.0)
            }
            radius: 10
            border.width: 1
            border.color: (0.299*color.r + 0.587*color.g + 0.114*color.b) < 0.5
                          ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.12)
        }

        PlasmaComponents3.Menu {
            id: appCtxMenu
            property string appName: ""
            property int sourceIdx: -1
            background: CtxMenuBackground {}

            PlasmaComponents3.MenuItem {
                text: i18n("Launch")
                icon.name: "system-run"
                onTriggered: {
                    if (root.allApps && appCtxMenu.sourceIdx >= 0) {
                        root.allApps.trigger(appCtxMenu.sourceIdx, "", null)
                        root.toggle()
                    }
                }
            }
            PlasmaComponents3.MenuSeparator {}
            PlasmaComponents3.MenuItem {
                text: kicker.globalFavorites && kicker.globalFavorites.isFavorite(appCtxMenu.appName)
                      ? i18n("Unpin from Favorites")
                      : i18n("Pin to Favorites")
                icon.name: "favorite"
                onTriggered: {
                    if (!kicker.globalFavorites) return
                    if (kicker.globalFavorites.isFavorite(appCtxMenu.appName))
                        kicker.globalFavorites.removeFavorite(appCtxMenu.appName)
                    else
                        kicker.globalFavorites.addFavorite(appCtxMenu.appName)
                }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Add to Desktop")
                icon.name: "user-desktop"
                onTriggered: {
                    if (root.allApps && appCtxMenu.sourceIdx >= 0)
                        root.allApps.trigger(appCtxMenu.sourceIdx, "addToDesktop", null)
                }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Add to Panel (Widget)")
                icon.name: "list-add"
                onTriggered: {
                    if (root.allApps && appCtxMenu.sourceIdx >= 0)
                        root.allApps.trigger(appCtxMenu.sourceIdx, "addToPanel", null)
                }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Add as Launcher to Panel")
                icon.name: "list-add"
                onTriggered: {
                    if (root.allApps && appCtxMenu.sourceIdx >= 0)
                        root.allApps.trigger(appCtxMenu.sourceIdx, "addLauncher", null)
                }
            }
            PlasmaComponents3.MenuSeparator {}
            PlasmaComponents3.MenuItem {
                text: i18n("Show in File Manager")
                icon.name: "folder-open"
                onTriggered: {
                    if (root.allApps && appCtxMenu.sourceIdx >= 0)
                        root.allApps.trigger(appCtxMenu.sourceIdx, "_kicker_jumpListAction", "openParentFolder")
                }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Edit Application…")
                icon.name: "document-edit"
                onTriggered: {
                    if (root.allApps && appCtxMenu.sourceIdx >= 0)
                        root.allApps.trigger(appCtxMenu.sourceIdx, "editApplication", null)
                }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Properties")
                icon.name: "document-properties"
                onTriggered: {
                    if (root.allApps && appCtxMenu.sourceIdx >= 0)
                        root.allApps.trigger(appCtxMenu.sourceIdx, "_kicker_fileItem_properties", null)
                }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Uninstall…")
                icon.name: "edit-delete"
                onTriggered: {
                    // Try common pkg managers via xdg-open of software center
                    processRunner.runMenuEditor()  // fallback if uninstall unsupported
                }
            }
        }

        // ── Folder context menu ───────────────────────────────────
        PlasmaComponents3.Menu {
            id: folderCtxMenu
            property int folderIdx: -1
            property string folderName: ""
            background: CtxMenuBackground {}

            PlasmaComponents3.MenuItem {
                text: i18n("Rename Folder…")
                icon.name: "edit-rename"
                onTriggered: {
                    if (folderCtxMenu.folderIdx >= 0) {
                        var fi = { type: "folder", folderIdx: folderCtxMenu.folderIdx,
                                   name: folderCtxMenu.folderName,
                                   members: root.folders[folderCtxMenu.folderIdx].members || [] }
                        root.openFolderAt({ type: "folder", folderIdx: fi.folderIdx,
                                            name: fi.name, members: fi.members.map(function(n) {
                                                return { name: n, sourceIdx: -1, icon: "" } }) })
                    }
                }
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Delete Folder")
                icon.name: "edit-delete"
                onTriggered: {
                    if (folderCtxMenu.folderIdx < 0) return
                    var arr = root.folders.slice()
                    arr.splice(folderCtxMenu.folderIdx, 1)
                    root.folders = arr
                    root.saveFolders()
                }
            }
        }
    } // mainItem
}
