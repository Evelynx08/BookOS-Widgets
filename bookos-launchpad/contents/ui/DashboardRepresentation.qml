/*
    BookOS Launchpad — DashboardRepresentation.qml
    Paginated grid, swipe gestures, search, folders, blur, dark/light theme.
    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQml 2.15

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.plasma.plasma5support 2.0 as P5Support


Kicker.DashboardWindow {
    id: root

    // ── config shortcuts ────────────────────────────────────────────────
    property int  cfg_iconSize:   Plasmoid.configuration.iconSize
    property real cfg_blur:       Plasmoid.configuration.blurRadius
    property bool cfg_showLabels: Plasmoid.configuration.showLabels
    property bool cfg_useWallpaperBg: Plasmoid.configuration.useWallpaperBg
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

    // Compute icon size from available area so 6×5 fills nicely.
    property int gridAvailW: Math.max(640, width  * 0.72)
    property int gridAvailH: Math.max(480, height * 0.72)
    property int cellW:      Math.max(80, Math.floor(gridAvailW / cfg_cols))
    property int cellH:      Math.max(80, Math.floor(gridAvailH / cfg_rows))
    property int labelH:     cfg_showLabels ? Kirigami.Units.gridUnit * 2 : 0
    property int iconPx:     Math.max(48, Math.min(cellW - Kirigami.Units.gridUnit * 3,
                                                    cellH - labelH - Kirigami.Units.gridUnit * 2))

    // palette helpers — tokens from BookOS-HIG/AI-DESIGN-SYSTEM.md §2.1
    // (accent is the only color allowed to mean "interactive/active")
    property color fgColor: cfg_darkTheme ? Qt.rgba(1, 1, 1, 1)
                                          : Qt.rgba(0.10, 0.10, 0.10, 1)
    property color bgColor: Qt.rgba(cardColor.r, cardColor.g, cardColor.b, 0.92)
    property color overlayColor: cfg_darkTheme
                                 ? Qt.rgba(0.06, 0.06, 0.08, 1.0)
                                 : Qt.rgba(0.96, 0.96, 0.98, 1.0)
    property color searchBg: cfg_darkTheme
                              ? Qt.rgba(1, 1, 1, 0.12)
                              : Qt.rgba(0, 0, 0, 0.08)
    property color accentColor: cfg_darkTheme ? "#0a84ff" : "#007aff"
    property color cardColor:   cfg_darkTheme ? "#1c1c1e" : "#ffffff"
    property color hoverColor:  cfg_darkTheme ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
    property color borderColor: cfg_darkTheme ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.10)
    // Page dots: active = accent (this is the one "active" indicator in the
    // whole dashboard), inactive = faint fg — matches §2.1 selection rule.
    property color dotActive: accentColor
    property color dotInact:  cfg_darkTheme ? Qt.rgba(1, 1, 1, 0.35)
                                            : Qt.rgba(0, 0, 0, 0.25)

    // ── state ────────────────────────────────────────────────────────────
    property bool  searching:    searchField.text.length > 0
    property int   currentPage:  0
    property int   pageCount:    Math.max(1, layoutPages.length)

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
            // Con el fondo de pantalla activo hace falta su ruta ya al abrir;
            // si no, se sigue pidiendo solo al abrir una carpeta.
            if (cfg_useWallpaperBg) ensureWallpaperColors()
            clearDragState()
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
                    // Hasta 9: el tile grande pinta una rejilla de 3×3.
                    if (miniIcons.length < 9) miniIcons.push(appIconByName[mn])
                }
            }
            // Skip empty folders (all members uninstalled)
            if (resolved.length === 0) continue
            // Tamaño del tile: "auto" decide por contenido — con 5 o más apps
            // no caben en el cuadrado pequeño, así que va a 2×2.
            var sizeMode = fol.sizeMode || "auto"
            var big = sizeMode === "2x2"
                      || (sizeMode === "auto" && resolved.length >= 5)
            out.push({
                type: "folder",
                name: fol.name || i18n("Folder"),
                miniIcons: miniIcons,
                members: resolved,
                folderIdx: f2,
                color: fol.color || "#3F51B5",
                sizeMode: sizeMode,
                big: big
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

    // ── colocación en la rejilla ─────────────────────────────────────────
    // Las carpetas grandes ocupan 2×2 celdas, así que la rejilla ya no es
    // uniforme y no vale contar índices: cada elemento recibe su hueco aquí.
    // Devuelve una lista por página de {idx, col, row, w, h}; los elementos de
    // 1×1 rellenan los huecos que deja un tile grande, en el orden guardado.
    function computeLayout(items, cols, rows) {
        var pages = []
        if (!items || items.length === 0) return pages

        var occ = null, slots = null
        function newPage() {
            occ = []
            for (var r = 0; r < rows; r++) {
                var line = []
                for (var c = 0; c < cols; c++) line.push(false)
                occ.push(line)
            }
            slots = []
            pages.push(slots)
        }
        function fits(col, row, w, h) {
            if (col + w > cols || row + h > rows) return false
            for (var r = row; r < row + h; r++)
                for (var c = col; c < col + w; c++)
                    if (occ[r][c]) return false
            return true
        }
        function occupy(col, row, w, h) {
            for (var r = row; r < row + h; r++)
                for (var c = col; c < col + w; c++) occ[r][c] = true
        }

        newPage()
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            var w = (it && it.type === "folder" && it.big) ? 2 : 1
            var h = w
            // Una carpeta grande no cabe si la rejilla es de una sola fila/columna.
            if (w > cols || h > rows) { w = 1; h = 1 }

            var placed = false
            for (var pass = 0; pass < 2 && !placed; pass++) {
                for (var row = 0; row < rows && !placed; row++) {
                    for (var col = 0; col < cols && !placed; col++) {
                        if (!fits(col, row, w, h)) continue
                        occupy(col, row, w, h)
                        slots.push({ idx: i, col: col, row: row, w: w, h: h })
                        placed = true
                    }
                }
                if (!placed) newPage()   // segunda pasada: página nueva y vacía
            }
        }
        return pages
    }

    property var layoutPages: computeLayout(unifiedItems, cfg_cols, cfg_rows)

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

    // ── colores sugeridos a partir del fondo de pantalla ──────────────────
    // Se calcula UNA vez, la primera que se abre una carpeta, no al arrancar:
    // lanza ImageMagick y no tiene sentido pagarlo si nunca se abre ninguna.
    property string wallpaperPath: ""
    property var    wallpaperColors: []
    property bool   _wallpaperAsked: false

    function ensureWallpaperColors() {
        if (_wallpaperAsked) return
        _wallpaperAsked = true
        wallpaperSrc.connectSource(wallpaperSrc.cmd)
    }

    // Va en una propiedad, no como hijo suelto: la default property de
    // DashboardWindow es mainItem (QQuickItem) y no acepta un QtObject.
    readonly property QtObject _wallpaperSrc: P5Support.DataSource {
        id: wallpaperSrc
        engine: "executable"
        connectedSources: []
        // Primera línea: ruta del fondo. Resto: hasta 6 colores dominantes.
        // El fichero de Plasma tiene un bloque por contenedor (uno por
        // escritorio/pantalla); se toma el primero, que es el escritorio principal.
        readonly property string cmd:
            "sh -c '" +
            "W=$(grep -m1 \"^Image=\" \"$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc\" 2>/dev/null | sed \"s|^Image=file://||\"); " +
            "[ -f \"$W\" ] || exit 0; " +
            "echo \"$W\"; " +
            "command -v magick >/dev/null 2>&1 && M=magick || M=convert; " +
            "$M \"$W\" -resize 64x64! -colors 8 -format \"%c\" histogram:info: 2>/dev/null " +
            "| grep -oE \"#[0-9A-Fa-f]{6}\" | head -8'"

        onNewData: function(source, data) {
            disconnectSource(source)
            var out = (data["stdout"] || "").trim()
            if (!out) return
            var lines = out.split("\n")
            root.wallpaperPath = lines[0] ? "file://" + lines[0].trim() : ""
            var cols = []
            for (var i = 1; i < lines.length; i++) {
                var c = lines[i].trim()
                if (!/^#[0-9A-Fa-f]{6}$/.test(c)) continue
                // Descarta los extremos: un color casi negro o casi blanco no
                // distingue una carpeta de otra.
                var r = parseInt(c.substr(1, 2), 16) / 255
                var g = parseInt(c.substr(3, 2), 16) / 255
                var b = parseInt(c.substr(5, 2), 16) / 255
                var lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
                if (lum < 0.10 || lum > 0.92) continue
                if (cols.indexOf(c) === -1) cols.push(c)
                if (cols.length >= 6) break
            }
            root.wallpaperColors = cols
        }
    }

    // Se llama cada vez que el Launchpad se cierra o se vuelve a abrir
    // (kicker.onReset). Debe dejarlo como recién abierto: si no, cerrar con la
    // tecla Súper con una carpeta abierta hacía que al reabrir siguiera abierta,
    // y lo mismo con una búsqueda a medias.
    function reset() {
        currentPage = 0
        searchText = ""
        clearDragState()
        if (typeof openFolder !== "undefined" && openFolder.visible) {
            openFolder.visible = false   // sin animación: no se está viendo
        }
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

    function openFolderAt(folderItem, originX, originY) {
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
        // Los colores del fondo de pantalla se calculan la primera vez que se
        // abre una carpeta, no antes: cuestan un proceso de ImageMagick.
        ensureWallpaperColors()
        // Grow out of the clicked icon when we know where it was; otherwise
        // (e.g. opened from the rename context-menu action) just scale from center.
        openFolder.originX = (originX !== undefined) ? originX : mainContent.width  / 2
        openFolder.originY = (originY !== undefined) ? originY : mainContent.height / 2
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

    // Tamaño del tile en la rejilla: "auto", "1x1" o "2x2".
    function setFolderSize(idx, mode) {
        if (idx < 0 || idx >= folders.length) return
        var arr = folders.slice()
        var f = Object.assign({}, arr[idx])
        f.sizeMode = mode
        arr[idx] = f
        folders = arr
        saveFolders()
    }


    // Drop-mode: "merge" (center of cell, ≤45% from center) or "move" (edges)
    property string dragHoverMode: "none"

    // Deja el arrastre como si no hubiera pasado nada. Se llama al terminar, al
    // cancelar y al abrir el launchpad: un fantasma que se queda pegado en
    // pantalla no se va solo, y con él la carpeta se ve vacía.
    function clearDragState() {
        dragGhost.visible        = false
        dragGhost.ghostIcon      = ""
        dragGhost.ghostIsFolder  = false
        dragGhost.ghostMiniIcons = []
        dragHoverIdx        = -1
        dragHoverMode       = "none"
        dragSourceIdx       = -1
        innerDragMemberIdx  = -1
        innerDragAppName    = ""
        draggingOutOfFolder = false
        edgeFlipTimer.running = false
        edgeFlipTimer.flipDir = 0
    }

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
        if (localX < 0 || localX >= gridArea.gridW
            || p.y < 0 || p.y >= gridArea.gridH) {
            root.dragHoverIdx = -1
            root.dragHoverMode = "none"
            return
        }
        // Con tiles de 2×2 el índice ya no sale de col + row * cols: hay que
        // buscar el hueco cuyo rectángulo contiene el cursor.
        var slots = root.layoutPages[root.currentPage] || []
        var hit = null
        for (var i = 0; i < slots.length; i++) {
            var s = slots[i]
            var sx = s.col * root.cellW
            var sy = s.row * root.cellH
            if (localX >= sx && localX < sx + s.w * root.cellW
                && p.y >= sy && p.y < sy + s.h * root.cellH) { hit = s; break }
        }
        if (!hit) {
            // hueco vacío dentro de la rejilla → al final de la lista
            root.dragHoverIdx = unifiedCount
            root.dragHoverMode = "move"
            return
        }
        // merge vs move: el 50% central del tile (sea 1×1 o 2×2) fusiona,
        // los bordes insertan antes/después.
        var tw = hit.w * root.cellW
        var th = hit.h * root.cellH
        var cx = hit.col * root.cellW + tw / 2
        var cy = hit.row * root.cellH + th / 2
        var inCenter = Math.abs(localX - cx) < tw * 0.25
                       && Math.abs(p.y - cy) < th * 0.25
        if (inCenter) {
            root.dragHoverIdx  = hit.idx
            root.dragHoverMode = "merge"
        } else {
            // insert: if cursor is on the right half, insert AFTER; else BEFORE
            var insertAt = (localX > cx) ? hit.idx + 1 : hit.idx
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

        // Solo mientras dura la apertura: al escalar la escena, cada etiqueta
        // con NativeRendering + relieve se re-rasteriza en CADA fotograma. Con la
        // capa se rasteriza una vez y lo que se escala es una textura. El
        // resultado en pantalla es idéntico; el tirón de la apertura no.
        layer.enabled: appearAnim.running

        // Open animation: fade + gentle zoom-out (Launchpad style).
        // §2.7 "aparición de página completa": 280ms, sin rebote — un solo
        // overshoot suave se siente elegante, un muelle que oscila se ve como vibración.
        ParallelAnimation {
            id: appearAnim
            NumberAnimation { target: mainContent; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: mainContent; property: "scale"; from: 1.05; to: 1; duration: 280; easing.type: Easing.OutQuint }
        }

        // ── fondo ─────────────────────────────────────────────────────
        // El fondo de pantalla, desenfocado, cuando está activado en ajustes.
        // Se carga a un cuarto de resolución: ya da parte del desenfoque solo,
        // y evita descodificar una imagen 4K entera para verla borrosa.
        Image {
            id: wallpaperBg
            anchors.fill: parent
            visible: root.cfg_useWallpaperBg && source !== ""
            source: root.cfg_useWallpaperBg ? root.wallpaperPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: Math.max(320, Math.ceil(root.width / 4))
            layer.enabled: visible && root.cfg_blur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1.0
                blurMax: Math.round(Math.max(8, root.cfg_blur))
            }
        }

        // Velo. Sin fondo de pantalla es opaco: el aspecto de siempre.
        Rectangle {
            anchors.fill: parent
            color: overlayColor
            opacity: wallpaperBg.visible
                     ? (root.cfg_darkTheme ? 0.55 : 0.62)
                     : 1.0
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
                border.color:  searchField.activeFocus
                               ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.7)
                               : root.borderColor
                border.width:  searchField.activeFocus ? 2 : 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
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

                // Página que se está viendo AHORA, derivada del desplazamiento real.
                // currentPage solo se actualiza al terminar el movimiento, así que no
                // sirve para decidir qué pintar mientras se desliza.
                readonly property int visualPage:
                    gridArea.gridW > 0
                        ? Math.max(0, Math.min(root.pageCount - 1,
                                   Math.round(contentX / gridArea.gridW)))
                        : 0
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

                    Loader {
                        id: pageGrid
                        required property int index
                        x:              index * gridArea.gridW
                        width:          gridArea.gridW
                        height:         gridArea.gridH
                        // Solo existe la página que se ve y sus dos vecinas. Antes se
                        // creaban TODAS al abrir —cada celda con su Kirigami.Icon
                        // cargando el pixmap— aunque no se llegaran a mirar nunca.
                        // Siguiendo el desplazamiento real con visualPage la vecina se
                        // carga en cuanto empieza el gesto, así que no aparece en blanco.
                        active: Math.abs(index - pagesFlick.visualPage) <= 1
                        asynchronous: true
                        visible: status === Loader.Ready

                        property var slots: root.layoutPages[index] || []

                        sourceComponent: Item {
                        width:  pageGrid.width
                        height: pageGrid.height

                        // ── realces del arrastre ─────────────────────────────
                        // Uno por página, recolocado, en vez de tres Rectangle por
                        // celda que se quedan invisibles el 99% del tiempo.
                        property var mergeSlot: {
                            if (root.dragSourceIdx < 0 || root.dragHoverMode !== "merge") return null
                            for (var i = 0; i < pageGrid.slots.length; i++) {
                                var s = pageGrid.slots[i]
                                if (s.idx === root.dragHoverIdx && s.idx !== root.dragSourceIdx) return s
                            }
                            return null
                        }
                        // Ranura junto a la que va la línea de inserción, y de qué lado.
                        property var insertSlot: {
                            if (root.dragSourceIdx < 0 || root.dragHoverMode !== "move") return null
                            for (var i = 0; i < pageGrid.slots.length; i++) {
                                var s = pageGrid.slots[i]
                                if (s.idx === root.dragHoverIdx && s.idx !== root.dragSourceIdx)
                                    return { slot: s, after: false }
                                if (s.idx === root.dragHoverIdx - 1 && s.idx !== root.dragSourceIdx)
                                    return { slot: s, after: true }
                            }
                            return null
                        }

                        Rectangle {
                            visible: !!parent.mergeSlot
                            x:      visible ? parent.mergeSlot.col * root.cellW + Kirigami.Units.smallSpacing : 0
                            y:      visible ? parent.mergeSlot.row * root.cellH + Kirigami.Units.smallSpacing : 0
                            width:  visible ? parent.mergeSlot.w * root.cellW - Kirigami.Units.smallSpacing * 2 : 0
                            height: visible ? parent.mergeSlot.h * root.cellH - Kirigami.Units.smallSpacing * 2 : 0
                            radius: Kirigami.Units.gridUnit
                            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.20)
                            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.9)
                            border.width: 2
                            z: 5
                        }
                        Rectangle {
                            visible: !!parent.insertSlot
                            width:  3
                            radius: 2
                            color:  root.accentColor
                            height: visible ? parent.insertSlot.slot.h * root.cellH * 0.7 : 0
                            x: visible
                               ? (parent.insertSlot.after
                                  ? (parent.insertSlot.slot.col + parent.insertSlot.slot.w) * root.cellW - width
                                  : parent.insertSlot.slot.col * root.cellW)
                               : 0
                            y: visible
                               ? parent.insertSlot.slot.row * root.cellH
                                 + (parent.insertSlot.slot.h * root.cellH - height) / 2
                               : 0
                            z: 5
                        }

                        Repeater {
                            model: pageGrid.slots

                            delegate: Item {
                                id: cell
                                required property var modelData
                                property int globalIdx: modelData.idx
                                property var item: root.unifiedItems[globalIdx] || null

                                property bool isFolder: item ? item.type === "folder" : false
                                property bool isBig: isFolder && modelData.w > 1
                                // Mini-icono bajo el cursor dentro de un tile grande.
                                property int hoveredMini:
                                    (isBig && cellHover.hovered && root.dragSourceIdx < 0)
                                    ? folderTile.miniIconAt(cellHover.point.position.x,
                                                            cellHover.point.position.y)
                                    : -1
                                property string appName: item ? item.name : ""
                                property var appIcon: item ? item.icon : ""

                                x:      modelData.col * root.cellW
                                y:      modelData.row * root.cellH
                                width:  modelData.w * root.cellW
                                height: modelData.h * root.cellH

                                // hover suave — mismo estilo que la selección en búsqueda
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    radius: Kirigami.Units.gridUnit
                                    // Con el cursor sobre un mini-icono manda el realce
                                    // pequeño: dos resaltados a la vez confunden.
                                    visible: cellHover.hovered && root.dragSourceIdx < 0
                                             && cell.hoveredMini < 0
                                    color: root.hoverColor
                                }
                                // Con la carpeta abierta el hover debe morir aquí:
                                // el scrim tapa la rejilla, pero un HoverHandler
                                // seguía encendiendo el resaltado por debajo.
                                HoverHandler {
                                    id: cellHover
                                    enabled: !openFolder.visible && !root.searching
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Kirigami.Units.smallSpacing
                                    // Hide the static icon once it's actually being dragged —
                                    // the ghost item takes over. Avoids fighting for the same
                                    // "pressed" visual state as drag.active toggles.
                                    opacity: cellMouse.dragMode ? 0 : 1
                                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                    // Carpeta: cuadrado redondeado del color de la
                                    // carpeta con sus mini-iconos dentro (2×2 en el
                                    // tile pequeño, 3×3 en el grande).
                                    Item {
                                        id: folderTile
                                        visible: cell.isFolder
                                        // El pequeño va al 92% del icono: los iconos de
                                        // app traen padding transparente, así que a
                                        // igual tamaño el cuadrado se veía más grande.
                                        // El grande ocupa el bloque menos la etiqueta.
                                        width:  cell.isBig
                                                ? Math.min(cell.width, cell.height - root.labelH)
                                                  - Kirigami.Units.gridUnit
                                                : Math.round(root.iconPx * 0.92)
                                        height: width
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        readonly property color folderColor:
                                            cell.isFolder && cell.item ? cell.item.color : "#3F51B5"
                                        // El tile cerrado es una versión suave del color:
                                        // mezclado hacia blanco en tema claro y hacia el
                                        // fondo oscuro en tema oscuro. La tarjeta abierta
                                        // sí lleva el color a saco — al abrirla se entra
                                        // en la carpeta y ahí manda su color.
                                        readonly property color tileColor: {
                                            var base = root.cfg_darkTheme
                                                       ? Qt.rgba(0.11, 0.11, 0.12, 1)
                                                       : Qt.rgba(1, 1, 1, 1)
                                            var t = 0.42
                                            return Qt.rgba(folderColor.r * t + base.r * (1 - t),
                                                           folderColor.g * t + base.g * (1 - t),
                                                           folderColor.b * t + base.b * (1 - t), 1)
                                        }
                                        readonly property int miniCols: cell.isBig ? 3 : 2
                                        // Geometría de la rejilla interior, en propiedades
                                        // porque el impacto del ratón se calcula con ella:
                                        // los mini-iconos del tile grande se pueden pulsar
                                        // para abrir su app sin abrir la carpeta.
                                        readonly property int miniSize:
                                            Math.round(width * (cell.isBig ? 0.26 : 0.36))
                                        readonly property int miniSpacing:
                                            cell.isBig ? Kirigami.Units.smallSpacing : 4
                                        readonly property int miniTotal:
                                            miniCols * miniSize + (miniCols - 1) * miniSpacing
                                        readonly property int miniOrigin: (width - miniTotal) / 2
                                        readonly property int miniCount:
                                            cell.isFolder && cell.item
                                            ? Math.min(cell.isBig ? 9 : 4, cell.item.miniIcons.length)
                                            : 0

                                        // Índice del mini-icono bajo un punto en
                                        // coordenadas de la celda, o -1 si el punto cae en
                                        // el hueco entre iconos o fuera del tile.
                                        function miniIconAt(cx, cy) {
                                            if (!cell.isBig) return -1
                                            var p = mapFromItem(cell, cx, cy)
                                            var lx = p.x - miniOrigin
                                            var ly = p.y - miniOrigin
                                            if (lx < 0 || ly < 0 || lx >= miniTotal || ly >= miniTotal) return -1
                                            var step = miniSize + miniSpacing
                                            var col = Math.floor(lx / step)
                                            var row = Math.floor(ly / step)
                                            // Dentro del cuadrado del icono, no del hueco
                                            if (lx - col * step >= miniSize) return -1
                                            if (ly - row * step >= miniSize) return -1
                                            var idx = row * miniCols + col
                                            return idx < miniCount ? idx : -1
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width * (cell.isBig ? 0.16 : 0.22)
                                            // Opaco, no un velo translúcido: sobre el fondo
                                            // de pantalla un color con alfa cambia de tono
                                            // según qué haya detrás.
                                            color: folderTile.tileColor
                                            border.color: Qt.rgba(folderTile.folderColor.r,
                                                                  folderTile.folderColor.g,
                                                                  folderTile.folderColor.b, 0.45)
                                            border.width: 1
                                        }
                                        // Realce del mini-icono apuntado: uno solo,
                                        // recolocado, en vez de un Rectangle por icono.
                                        Rectangle {
                                            visible: cell.hoveredMini >= 0
                                            width:  folderTile.miniSize + 6
                                            height: width
                                            radius: width * 0.28
                                            color:  root.hoverColor
                                            x: folderTile.miniOrigin - 3
                                               + (cell.hoveredMini % folderTile.miniCols)
                                                 * (folderTile.miniSize + folderTile.miniSpacing)
                                            y: folderTile.miniOrigin - 3
                                               + Math.floor(cell.hoveredMini / folderTile.miniCols)
                                                 * (folderTile.miniSize + folderTile.miniSpacing)
                                        }

                                        Grid {
                                            x: folderTile.miniOrigin
                                            y: folderTile.miniOrigin
                                            columns: folderTile.miniCols
                                            spacing: folderTile.miniSpacing
                                            Repeater {
                                                model: folderTile.miniCount
                                                Kirigami.Icon {
                                                    source: cell.item.miniIcons[index] || ""
                                                    width:  folderTile.miniSize
                                                    height: width
                                                    roundToIconSize: false
                                                    smooth: true
                                                    animated: false
                                                }
                                            }
                                        }

                                        scale: cellMouse.pressed && !cellMouse.dragMode ? 0.88 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
                                        scale: cellMouse.pressed && !cellMouse.dragMode ? 0.88 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
                                        width:               cell.width - Kirigami.Units.smallSpacing
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
                                    // Punto donde se apretó y si el cursor se ha movido
                                    // lo bastante como para que esto sea un arrastre.
                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool moved: false
                                    // Arrancar a arrastrar es más fácil que confirmar
                                    // que NO se quería lanzar la app, así que el umbral
                                    // para mover es mayor que el que cancela el clic.
                                    readonly property real dragThreshold: Kirigami.Units.gridUnit
                                    readonly property real clickSlop: Kirigami.Units.gridUnit * 0.45

                                    // onReleased ya ha puesto dragMode a false cuando
                                    // llega onClicked, así que el arrastre tiene que
                                    // dejar dicho aparte que ese clic no cuenta: si no,
                                    // soltar tras arrastrar lanzaba la app.
                                    property bool suppressClick: false

                                    function beginDrag(mx, my) {
                                        dragMode = true
                                        suppressClick = true
                                        root.dragSourceIdx = cell.globalIdx
                                        var p = mapToItem(mainContent, mx, my)
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

                                    onPressed: mouse => {
                                        pressX = mouse.x
                                        pressY = mouse.y
                                        moved  = false
                                        suppressClick = false
                                    }

                                    onPressAndHold: mouse => beginDrag(mouse.x, mouse.y)

                                    onPositionChanged: mouse => {
                                        var dx = mouse.x - pressX
                                        var dy = mouse.y - pressY
                                        var dist = Math.sqrt(dx * dx + dy * dy)
                                        if (dist > clickSlop) moved = true
                                        // Arrastrar sin esperar el pulsado largo: mover el
                                        // icono ya no obliga a acertar con el tiempo, y
                                        // soltar tras haberlo movido no lanza la app.
                                        if (!dragMode && pressedButtons === Qt.LeftButton
                                            && dist > dragThreshold) {
                                            beginDrag(mouse.x, mouse.y)
                                        }
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
                                        if (dragMode || suppressClick) return
                                        // Se movió el dedo/ratón: era un intento de
                                        // arrastre, no un clic. Lanzar la app aquí es
                                        // justo lo que pasaba sin querer.
                                        if (moved && mouse.button === Qt.LeftButton) return
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
                                            // En el tile grande, pulsar un mini-icono lanza
                                            // esa app; el nombre y los huecos abren la carpeta.
                                            var mi = folderTile.miniIconAt(mouse.x, mouse.y)
                                            if (mi >= 0 && root.allApps) {
                                                var mem = cell.item.members[mi]
                                                if (mem && mem.sourceIdx >= 0) {
                                                    root.allApps.trigger(mem.sourceIdx, "", null)
                                                    root.toggle()
                                                    return
                                                }
                                            }
                                            var origin = cell.mapToItem(mainContent, cell.width / 2, cell.height / 2)
                                            root.openFolderAt(cell.item, origin.x, origin.y)
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
                                // selected row in a list → accent tint, never solid color (§2.1)
                                color:  Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
                                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.7)
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
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
            readonly property color folderRgb: ghostFolderColor
            // Mismo cálculo que el tile de la rejilla: el fantasma no puede
            // cambiar de tono al levantar la carpeta.
            readonly property color ghostTile: {
                var base = root.cfg_darkTheme ? Qt.rgba(0.11, 0.11, 0.12, 1)
                                              : Qt.rgba(1, 1, 1, 1)
                var t = 0.42
                return Qt.rgba(folderRgb.r * t + base.r * (1 - t),
                               folderRgb.g * t + base.g * (1 - t),
                               folderRgb.b * t + base.b * (1 - t), 1)
            }

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
                // Mismo tinte que el tile de la rejilla, para que el fantasma
                // no cambie de color al levantar la carpeta.
                Rectangle {
                    anchors.fill: parent
                    radius: width * 0.22
                    color: dragGhost.ghostTile
                    border.width: 1
                    border.color: Qt.rgba(dragGhost.folderRgb.r, dragGhost.folderRgb.g,
                                          dragGhost.folderRgb.b, 0.45)
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
            suggestedColors: root.wallpaperColors
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
                    // Se esconde la tarjeta, pero NO se cierra: cerrarla ocultaba
                    // el MouseArea que tenía el ratón cogido, así que no llegaba
                    // el soltar — el icono no se movía y el fantasma se quedaba
                    // pegado en pantalla con la carpeta vacía detrás.
                    openFolder.draggingOut = true
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
                    openFolder.draggingOut   = false
                    openFolder.visible       = false   // ya no se veía: sin animación
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
                root.clearDragState()
            }
            onInnerDragCancel: {
                root.draggingOutOfFolder = false
                openFolder.draggingOut   = false
                root.clearDragState()
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
            radius: 12
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
            // Tamaño actual del tile, para marcar la opción elegida.
            property string sizeMode: folderIdx >= 0 && folderIdx < root.folders.length
                                      ? (root.folders[folderIdx].sizeMode || "auto")
                                      : "auto"
            background: CtxMenuBackground {}

            PlasmaComponents3.MenuItem {
                text: i18n("Size: automatic")
                checkable: true
                checked: folderCtxMenu.sizeMode === "auto"
                onTriggered: root.setFolderSize(folderCtxMenu.folderIdx, "auto")
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Size: small (1×1)")
                checkable: true
                checked: folderCtxMenu.sizeMode === "1x1"
                onTriggered: root.setFolderSize(folderCtxMenu.folderIdx, "1x1")
            }
            PlasmaComponents3.MenuItem {
                text: i18n("Size: large (2×2)")
                checkable: true
                checked: folderCtxMenu.sizeMode === "2x2"
                onTriggered: root.setFolderSize(folderCtxMenu.folderIdx, "2x2")
            }
            PlasmaComponents3.MenuSeparator {}

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
