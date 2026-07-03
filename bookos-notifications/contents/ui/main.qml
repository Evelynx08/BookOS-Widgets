import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.notificationmanager as NotificationManager
import org.kde.kirigami as Kirigami
import QtQuick.Effects

PlasmoidItem {
    id: root

    // ── ESTADO ───────────────────────────────────────────────────────────
    property bool   dnd:        false
    property string dndUntil:   ""      // texto descriptivo del fin
    property bool   pickDuration: false // mostrar selector de duración

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
    readonly property color purple: isDarkMode ? Qt.color("#BF5AF2") : Qt.color("#AF52DE")
    readonly property string resolvedFont: Kirigami.Theme.defaultFont.family

    readonly property bool popupOpen: root.expanded

    // i18n ligero: español si el locale empieza por "es", inglés por defecto
    function tr(es, en) { return Qt.locale().name.indexOf("es") === 0 ? es : en }

    preferredRepresentation: compactRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ── Notification Manager ─────────────────────────────────────────────
    NotificationManager.Settings { id: notificationSettings }

    function computeInhibited() {
        var inhibited = false
        var until = notificationSettings.notificationsInhibitedUntil
        if (until && !isNaN(until.getTime())) inhibited = inhibited || (Date.now() < until.getTime())
        if (notificationSettings.notificationsInhibitedByApplication) inhibited = true
        if (notificationSettings.inhibitNotificationsWhenScreensMirrored) inhibited = inhibited || notificationSettings.screensMirrored
        return inhibited
    }
    function syncState() {
        root.dnd = computeInhibited()
        var until = notificationSettings.notificationsInhibitedUntil
        if (root.dnd && until && !isNaN(until.getTime())) {
            var d = new Date(until.getTime())
            var now = new Date()
            // más de 100 días → "hasta desactivarlo"
            if ((d.getTime() - now.getTime()) > 100 * 24 * 3600 * 1000) root.dndUntil = tr("Activo hasta desactivarlo","On until turned off")
            else if (d.toDateString() === now.toDateString()) root.dndUntil = tr("Hasta las ","Until ") + Qt.formatTime(d, "HH:mm")
            else root.dndUntil = tr("Hasta ","Until ") + Qt.formatDateTime(d, "ddd HH:mm")
        } else if (root.dnd) {
            root.dndUntil = tr("Activo","On")
        } else {
            root.dndUntil = ""
        }
    }
    Connections {
        target: notificationSettings
        function onNotificationsInhibitedUntilChanged() { root.syncState() }
        function onNotificationsInhibitedByApplicationChanged() { root.syncState() }
        function onScreensMirroredChanged() { root.syncState() }
    }
    Timer { running: root.dnd; interval: 30000; repeat: true; onTriggered: root.syncState() }
    Component.onCompleted: syncState()

    // ── Historial de notificaciones ──────────────────────────────────────
    NotificationManager.Notifications {
        id: historyModel
        showExpired: true
        showDismissed: true
        showJobs: false
        groupMode: NotificationManager.Notifications.GroupDisabled
        sortMode: NotificationManager.Notifications.SortByDate
    }
    readonly property int notifCount: historyModel.count
    readonly property int unread: historyModel.unreadNotificationsCount

    function clearAllNotifs() { historyModel.clear(NotificationManager.Notifications.ClearExpired) }
    function closeNotif(i) { historyModel.close(historyModel.index(i, 0)) }
    function relTime(d) {
        if (!d || isNaN(d.getTime())) return ""
        var s = Math.floor((Date.now() - d.getTime()) / 1000)
        if (s < 60) return tr("ahora","now")
        if (s < 3600) return Math.floor(s / 60) + " min"
        if (s < 86400) return Math.floor(s / 3600) + " h"
        return Math.floor(s / 86400) + tr(" d"," d")
    }

    // ── SVG icons (feather) ──────────────────────────────────────────────
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
    function icoBell(color) {
        return svg('<path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>', color)
    }
    function icoBellOff(color) {
        return svg('<path d="M13.73 21a2 2 0 0 1-3.46 0"/><path d="M18.63 13A17.89 17.89 0 0 1 18 8"/><path d="M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7-3 9-3 9h14"/><path d="M18 8a6 6 0 0 0-9.33-5"/><line x1="1" y1="1" x2="23" y2="23"/>', color)
    }
    function icoMoon(color) {
        return svg('<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>', color)
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

        PlasmaComponents.ToolTip { text: root.dnd ? root.tr("No molestar · ","Do Not Disturb · ") + root.dndUntil : root.tr("Notificaciones activas","Notifications on") }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: (m) => {
                if (m.button === Qt.MiddleButton) { root.toggleDnd(); return }
                root.expanded = !root.expanded
            }
            Image {
                id: bellImg
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.small; height: width
                sourceSize: Qt.size(width * 2, height * 2); smooth: true
                source: root.dnd ? root.icoBellOff(root.purple) : root.icoBell(root.txt)
            }
            // badge de no leídas
            Rectangle {
                visible: root.unread > 0 && !root.dnd
                anchors { right: bellImg.right; top: bellImg.top; rightMargin: -3; topMargin: -2 }
                width: Math.max(13, badgeTxt.implicitWidth + 6); height: 13; radius: 6.5
                color: root.isDarkMode ? "#FF453A" : "#FF3B30"
                border.width: 1.5; border.color: root.bg
                PlasmaComponents.Label {
                    id: badgeTxt; anchors.centerIn: parent
                    text: root.unread > 9 ? "9+" : root.unread
                    font.family: root.resolvedFont; font.pixelSize: 8; font.weight: Font.Bold; color: "#FFFFFF"
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // FULL — popup
    // ═══════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        Layout.minimumWidth: 320; Layout.preferredWidth: 320; Layout.maximumWidth: 320
        Layout.minimumHeight:   popupCol.implicitHeight + 32
        Layout.preferredHeight: popupCol.implicitHeight + 32
        Layout.maximumHeight:   popupCol.implicitHeight + 32

        Rectangle { anchors.fill: parent; radius: 18; color: root.bg }

        property real entryOpacity: 0.0
        property real entryScale: 0.96
        Component.onCompleted: { entryOpacity = 1.0; entryScale = 1.0; root.syncState() }
        opacity: entryOpacity; scale: entryScale
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: popupCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: root.tr("Notificaciones","Notifications")
                    font.family: root.resolvedFont; font.weight: Font.Bold
                    font.pixelSize: 18; font.letterSpacing: -0.3
                    color: root.txt
                    Layout.fillWidth: true
                }
                Rectangle {
                    visible: root.notifCount > 0
                    Layout.preferredHeight: 26; Layout.preferredWidth: clearTxt.implicitWidth + 22
                    radius: 13
                    color: clearMouse.containsMouse ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, root.isDarkMode ? 0.18 : 0.12) : "transparent"
                    Behavior on color { ColorAnimation { duration: 130 } }
                    PlasmaComponents.Label {
                        id: clearTxt; anchors.centerIn: parent
                        text: root.tr("Borrar todo","Clear all")
                        font.family: root.resolvedFont; font.pixelSize: 12; font.weight: Font.DemiBold
                        color: root.hi
                    }
                    MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearAllNotifs() }
                }
            }

            // ── Historial de notificaciones ──────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 18
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                clip: true
                implicitHeight: root.notifCount > 0 ? Math.min(histList.contentHeight, 300) : 64

                // vacío
                ColumnLayout {
                    visible: root.notifCount === 0
                    anchors.centerIn: parent; spacing: 4
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.tr("Sin notificaciones","No notifications")
                        font.family: root.resolvedFont; font.pixelSize: 13; color: root.txt2
                    }
                }

                ListView {
                    id: histList
                    visible: root.notifCount > 0
                    anchors.fill: parent
                    clip: true
                    model: historyModel
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        width: histList.width
                        implicitHeight: nRow.implicitHeight + 18
                        Rectangle {
                            anchors.fill: parent
                            color: nMouse.containsMouse ? root.hovCol : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        Rectangle {
                            visible: index < root.notifCount - 1
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14 }
                            height: 1; color: root.divCol
                        }
                        RowLayout {
                            id: nRow
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 10 }
                            spacing: 11
                            // icono de la app
                            Rectangle {
                                Layout.alignment: Qt.AlignTop; Layout.topMargin: 1
                                width: 30; height: 30; radius: 15
                                color: root.isDarkMode ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.05)
                                Kirigami.Icon {
                                    anchors.centerIn: parent; width: 18; height: 18
                                    source: (model.applicationIconName && model.applicationIconName !== "") ? model.applicationIconName
                                          : (model.iconName && model.iconName !== "") ? model.iconName : "dialog-information"
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 6
                                    PlasmaComponents.Label {
                                        text: model.summary && model.summary !== "" ? model.summary : (model.applicationName || "")
                                        font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold
                                        color: root.txt; Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    PlasmaComponents.Label {
                                        text: root.relTime(model.updated || model.created)
                                        font.family: root.resolvedFont; font.pixelSize: 10; color: root.txt2
                                    }
                                }
                                PlasmaComponents.Label {
                                    visible: text !== ""
                                    text: (model.body || "").replace(/<[^>]*>/g, "")
                                    font.family: root.resolvedFont; font.pixelSize: 11; color: root.txt2
                                    Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                }
                            }
                            // cerrar
                            Rectangle {
                                Layout.alignment: Qt.AlignTop; Layout.topMargin: 1
                                width: 22; height: 22; radius: 11
                                opacity: nMouse.containsMouse ? 1 : 0
                                color: closeMouse.containsMouse ? (root.isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.08)) : "transparent"
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                Image { anchors.centerIn: parent; width: 11; height: 11; sourceSize: Qt.size(22,22); smooth: true
                                    source: root.svg('<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>', root.txt2) }
                                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.closeNotif(index) }
                            }
                        }
                        MouseArea { id: nMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                }
            }

            // ── Tarjeta No molestar (toggle) ─────────────────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 18
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                implicitHeight: 70
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
                    Rectangle {
                        width: 42; height: 42; radius: 21
                        color: root.dnd ? root.purple : (root.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.06))
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Image {
                            anchors.centerIn: parent; width: 22; height: 22; sourceSize: Qt.size(44,44); smooth: true
                            source: root.dnd ? root.icoMoon("#FFFFFF") : root.icoBell(root.txt)
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        PlasmaComponents.Label { text: root.tr("No molestar","Do Not Disturb"); font.family: root.resolvedFont; font.pixelSize: 15; font.weight: Font.DemiBold; color: root.txt }
                        PlasmaComponents.Label {
                            text: root.dnd ? root.dndUntil : root.tr("Las notificaciones se muestran","Notifications are shown")
                            font.family: root.resolvedFont; font.pixelSize: 11; color: root.dnd ? root.purple : root.txt2
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 44; Layout.preferredHeight: 26
                        radius: 15
                        color: root.dnd ? root.purple : (root.isDarkMode ? Qt.rgba(1,1,1,0.18) : Qt.rgba(0,0,0,0.16))
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 20; height: 20; radius: 10; color: "#FFFFFF"
                            y: 3; x: root.dnd ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root.dnd ? root.clearDnd() : (root.pickDuration = !root.pickDuration) }
                    }
                }
            }

            // ── Selector de duración (aparece al activar) ────────────────
            Rectangle {
                Layout.fillWidth: true; radius: 18; clip: true
                color: root.card; border.width: 1; border.color: root.brdCol
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.isDarkMode ? Qt.rgba(0,0,0,0.5) : Qt.rgba(0,0,0,0.13); shadowVerticalOffset: 2; shadowBlur: 0.4; autoPaddingEnabled: true }
                visible: opacity > 0.01
                opacity: (root.pickDuration && !root.dnd) ? 1 : 0
                Layout.preferredHeight: (root.pickDuration && !root.dnd) ? durCol.implicitHeight + 20 : 0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                ColumnLayout {
                    id: durCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 6
                    PlasmaComponents.Label {
                        text: root.tr("Silenciar durante","Mute for"); Layout.leftMargin: 4
                        font.family: root.resolvedFont; font.weight: Font.DemiBold; font.pixelSize: 12; color: root.txt2
                    }
                    Repeater {
                        model: [
                            { label: root.tr("1 hora","1 hour"),    mins: 60 },
                            { label: root.tr("4 horas","4 hours"),  mins: 240 },
                            { label: root.tr("8 horas","8 hours"),  mins: 480 },
                            { label: root.tr("Hasta desactivarlo","Until I turn it off"), mins: -2 }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 12
                            color: durMouse.containsMouse ? Qt.rgba(root.purple.r, root.purple.g, root.purple.b, root.isDarkMode ? 0.20 : 0.12)
                                                          : (root.isDarkMode ? Qt.rgba(1,1,1,0.05) : Qt.rgba(0,0,0,0.035))
                            Behavior on color { ColorAnimation { duration: 120 } }
                            scale: durMouse.pressed ? 0.98 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true; text: modelData.label
                                    font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.Medium
                                    color: durMouse.containsMouse ? root.purple : root.txt
                                }
                                PlasmaComponents.Label {
                                    text: modelData.mins === -2 ? "∞" : (modelData.mins >= 60 ? (modelData.mins/60) + "h" : modelData.mins + "m")
                                    font.family: root.resolvedFont; font.pixelSize: 12; color: root.txt2
                                }
                            }
                            MouseArea { id: durMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.setDndFor(modelData.mins); root.pickDuration = false } }
                        }
                    }
                }
            }

            // ── Footer ───────────────────────────────────────────────────
            Rectangle {
                id: settBtn
                readonly property bool hov: settMouse.containsMouse
                readonly property color fg: hov ? root.hi : root.txt
                Layout.fillWidth: true; Layout.preferredHeight: 38
                radius: height / 2
                color: hov ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, root.isDarkMode ? 0.18 : 0.12)
                           : (root.isDarkMode ? Qt.rgba(1,1,1,0.07) : Qt.rgba(0,0,0,0.05))
                border.width: 1
                border.color: hov ? Qt.rgba(root.hi.r, root.hi.g, root.hi.b, 0.40) : "transparent"
                Behavior on color { ColorAnimation { duration: 130 } }
                scale: settMouse.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                RowLayout {
                    anchors.centerIn: parent; spacing: 7
                    Image { width: 15; height: 15; sourceSize: Qt.size(30,30); smooth: true; source: root.icoSettings(settBtn.fg) }
                    PlasmaComponents.Label { text: root.tr("Ajustes de notificaciones","Notification settings"); font.family: root.resolvedFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: settBtn.fg }
                }
                MouseArea { id: settMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSettings("notificaciones") }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ACCIONES
    // ═══════════════════════════════════════════════════════════════════════
    function toggleDnd() {
        if (computeInhibited()) {
            clearDnd()
        } else {
            setDndFor(-2)   // hasta apagar
        }
    }
    function clearDnd() {
        notificationSettings.notificationsInhibitedUntil = undefined
        notificationSettings.revokeApplicationInhibitions()
        notificationSettings.screensMirrored = false
        notificationSettings.save()
        root.pickDuration = false
        syncState()
    }
    function setDndFor(mins) {
        var d = new Date()
        if (mins === -2) {                      // hasta apagar
            d.setFullYear(d.getFullYear() + 1)
        } else if (mins === -1) {               // mañana a las 8:00
            d.setDate(d.getDate() + 1)
            d.setHours(8, 0, 0, 0)
        } else {
            d.setMinutes(d.getMinutes() + mins)
        }
        notificationSettings.notificationsInhibitedUntil = d
        notificationSettings.save()
        root.pickDuration = false
        syncState()
    }
    function openSettings(page) {
        root.expanded = false
        cmd.run("sh -c 'echo " + page + " > /tmp/bookos-start-page; gtk-launch bookos-settings.desktop 2>/dev/null || bookos-settings'")
    }

    Plasma5Support.DataSource {
        id: cmd; engine: "executable"; connectedSources: []
        onNewData: (s, data) => disconnectSource(s)
        function run(c) { connectSource(c) }
    }
}
