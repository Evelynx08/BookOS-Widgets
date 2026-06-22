/*
    BookOS Launchpad — Win11Theme.qml
    Windows 11 style Start menu in standard popup.
    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker

Item {
    id: root

    // Tamaño fijo para la ventana emergente
    Layout.minimumWidth: 580
    Layout.minimumHeight: 680
    Layout.preferredWidth: 580
    Layout.preferredHeight: 680

    // ── theme ─────────────────────────────────────────────────────────
    property bool cfg_darkTheme: {
        var bg = Kirigami.Theme.backgroundColor
        var lum = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        return lum < 0.5
    }
    property color fgColor:    cfg_darkTheme ? "#FFFFFF" : "#1A1A1A"
    property color subFgColor: cfg_darkTheme ? Qt.rgba(1,1,1,0.65) : Qt.rgba(0,0,0,0.55)
    property color panelBg:    cfg_darkTheme ? Qt.rgba(0.13,0.13,0.15,0.92)
                                             : Qt.rgba(0.97,0.97,0.97,0.92)
    property color cellBg:     cfg_darkTheme ? Qt.rgba(1,1,1,0.06) : Qt.rgba(0,0,0,0.04)
    property color cellHover:  cfg_darkTheme ? Qt.rgba(1,1,1,0.12) : Qt.rgba(0,0,0,0.08)
    property color borderCol:  cfg_darkTheme ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)

    // ── data ──────────────────────────────────────────────────────────
    property var allApps: {
        if (!kicker.rootModelObj) return null
        var rm = kicker.rootModelObj
        if (rm.count <= 0) return null
        var best = null, bestCount = -1
        for (var i = 0; i < rm.count; i++) {
            var m = rm.modelForRow(i)
            if (m && m.count > bestCount) { best = m; bestCount = m.count }
        }
        return best
    }

    property var allAppsList: {
        var arr = []
        if (!allApps) return arr
        for (var i = 0; i < allApps.count; i++) {
            var name = allApps.data(allApps.index(i, 0), Qt.DisplayRole) || ""
            var icon = allApps.data(allApps.index(i, 0), Qt.DecorationRole) || ""
            arr.push({ name: name, icon: icon, sourceIdx: i })
        }
        arr.sort(function(a, b) { return a.name.localeCompare(b.name) })
        return arr
    }

    property var pinnedNames: Plasmoid.configuration.favoriteApps || []
    property var pinnedList: {
        var arr = []
        if (!allApps) return arr
        var nameMap = {}
        for (var i = 0; i < allAppsList.length; i++) nameMap[allAppsList[i].name] = allAppsList[i]
        for (var k = 0; k < pinnedNames.length; k++) {
            var p = nameMap[pinnedNames[k]]
            if (p) arr.push(p)
        }
        return arr
    }

    property string searchText: searchField.text
    property var searchResults: filterSearch(searchText)

    function filterSearch(q) {
        if (!q || q.length === 0) return []
        var qq = q.toLowerCase().trim()
        if (qq.length === 0) return []
        var hits = []
        for (var i = 0; i < allAppsList.length; i++) {
            var n = allAppsList[i].name.toLowerCase()
            if (n.indexOf(qq) === -1) continue
            hits.push(allAppsList[i])
            if (hits.length >= 32) break
        }
        hits.sort(function(a, b) {
            var as = a.name.toLowerCase().indexOf(qq) === 0 ? 0 : 1
            var bs = b.name.toLowerCase().indexOf(qq) === 0 ? 0 : 1
            if (as !== bs) return as - bs
            return a.name.localeCompare(b.name)
        })
        return hits
    }

    function trigger(sourceIdx) {
        if (allApps) {
            allApps.trigger(sourceIdx, "", null)
            closePopup()
        }
    }

    function reset() { searchField.clear(); allAppsView.visible = false }
    
    function closePopup() { Plasmoid.expanded = false }

    function triggerSystem(actionId) {
        var sm = kicker.systemFavorites
        if (!sm) return
        for (var i = 0; i < sm.count; i++) {
            var name = sm.data(sm.index(i, 0), Qt.DisplayRole) || ""
            var nlow = name.toLowerCase()
            if ((actionId === "shutdown" && (nlow.indexOf("shut") !== -1 || nlow.indexOf("apag") !== -1)) ||
                (actionId === "reboot"   && (nlow.indexOf("restart") !== -1 || nlow.indexOf("reboot") !== -1 || nlow.indexOf("reinici") !== -1)) ||
                (actionId === "logout"   && (nlow.indexOf("log out") !== -1 || nlow.indexOf("logout") !== -1 || nlow.indexOf("cerrar") !== -1))) {
                sm.trigger(i, "", null)
                return
            }
        }
    }

    Keys.onEscapePressed: {
        if (allAppsView.visible) { allAppsView.visible = false; return }
        if (searchText.length > 0) { searchField.clear(); return }
        closePopup()
    }

    onVisibleChanged: {
        if (visible) {
            searchField.clear()
            allAppsView.visible = false
            searchField.forceActiveFocus()
            appearAnim.start()
        }
    }

    // ── panel ─────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 22
        color: root.panelBg
        border.color: root.borderCol
        border.width: 1

        opacity: 0
        scale: 0.96
        transform: Translate { id: panelSlide; y: 24 }

        ParallelAnimation {
            id: appearAnim
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale";   from: 0.96; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: panelSlide; property: "y";  from: 24; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit * 1.5
            spacing: Kirigami.Units.largeSpacing

            // ── search ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: Kirigami.Units.gridUnit * 2.5
                radius: height / 2
                color: root.cellBg
                border.color: root.borderCol
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.gridUnit
                    anchors.rightMargin: Kirigami.Units.gridUnit
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "search"
                        Layout.preferredWidth:  Kirigami.Units.iconSizes.small
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        color: root.subFgColor
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: i18n("Type to search")
                        color: root.fgColor
                        background: Item {}
                        onAccepted: {
                            if (root.searchResults.length > 0)
                                root.trigger(root.searchResults[0].sourceIdx)
                        }
                    }
                }
            }

            // ── content stack: search results | pinned+all | all apps list ─
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // SEARCH RESULTS
                ListView {
                    anchors.fill: parent
                    visible: root.searchText.length > 0
                    model: root.searchResults
                    clip: true
                    spacing: 2
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: Kirigami.Units.gridUnit * 2.6
                        radius: 6
                        color: srMA.containsMouse ? root.cellHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Kirigami.Units.smallSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.gridUnit

                            Kirigami.Icon {
                                source: modelData.icon
                                fallback: "application-x-executable"
                                Layout.preferredWidth:  Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: root.fgColor
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: srMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.trigger(modelData.sourceIdx)
                        }
                    }
                }

                // PINNED + ALL APPS BUTTON
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.searchText.length === 0 && !allAppsView.visible
                    spacing: Kirigami.Units.gridUnit

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: i18n("Pinned")
                            color: root.fgColor
                            font.pixelSize: Kirigami.Units.gridUnit * 0.95
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        Rectangle {
                            implicitWidth: allAppsBtn.implicitWidth + Kirigami.Units.gridUnit
                            implicitHeight: Kirigami.Units.gridUnit * 1.8
                            radius: implicitHeight / 2
                            color: aaMA.containsMouse ? root.cellHover : root.cellBg
                            border.color: root.borderCol
                            border.width: 1
                            RowLayout {
                                id: allAppsBtn
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing
                                Label { text: i18n("All apps"); color: root.fgColor }
                                Label { text: "›"; color: root.subFgColor; font.pixelSize: Kirigami.Units.gridUnit }
                            }
                            MouseArea {
                                id: aaMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: allAppsView.visible = true
                            }
                        }
                    }

                    GridView {
                        id: pinnedGrid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cellWidth:  Math.floor(width / 6)
                        cellHeight: Kirigami.Units.gridUnit * 6
                        clip: true
                        model: root.pinnedList.length > 0 ? root.pinnedList : root.allAppsList.slice(0, 18)

                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: pinnedGrid.cellWidth
                            height: pinnedGrid.cellHeight

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                height: parent.height - 4
                                radius: 8
                                color: pinMA.containsMouse ? root.cellHover : "transparent"
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: modelData.icon
                                    fallback: "application-x-executable"
                                    width:  Kirigami.Units.iconSizes.large
                                    height: Kirigami.Units.iconSizes.large
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Label {
                                    text: modelData.name
                                    color: root.fgColor
                                    width: pinnedGrid.cellWidth - 8
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.75
                                }
                            }

                            MouseArea {
                                id: pinMA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.trigger(modelData.sourceIdx)
                            }
                        }
                    }
                }

                // ALL APPS LIST
                Item {
                    id: allAppsView
                    anchors.fill: parent
                    visible: false

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle {
                                implicitWidth: backBtn.implicitWidth + Kirigami.Units.gridUnit
                                implicitHeight: Kirigami.Units.gridUnit * 1.8
                                radius: 6
                                color: backMA.containsMouse ? root.cellHover : "transparent"
                                RowLayout {
                                    id: backBtn
                                    anchors.centerIn: parent
                                    spacing: Kirigami.Units.smallSpacing
                                    Label { text: "‹"; color: root.fgColor; font.pixelSize: Kirigami.Units.gridUnit }
                                    Label { text: i18n("All apps"); color: root.fgColor; font.bold: true }
                                }
                                MouseArea {
                                    id: backMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: allAppsView.visible = false
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        ListView {
                            id: allAppsListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: root.allAppsList
                            clip: true
                            spacing: 1
                            flickDeceleration: 6000
                            maximumFlickVelocity: 5000
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { active: true }
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: (event) => {
                                    var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y
                                    allAppsListView.contentY = Math.max(0,
                                        Math.min(allAppsListView.contentHeight - allAppsListView.height,
                                                 allAppsListView.contentY - dy * 1.5))
                                    event.accepted = true
                                }
                            }

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: Kirigami.Units.gridUnit * 2.6
                                radius: 6
                                color: aMA.containsMouse ? root.cellHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Kirigami.Units.smallSpacing
                                    anchors.rightMargin: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.gridUnit

                                    Kirigami.Icon {
                                        source: modelData.icon
                                        fallback: "application-x-executable"
                                        Layout.preferredWidth:  Kirigami.Units.iconSizes.medium
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: root.fgColor
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: aMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.trigger(modelData.sourceIdx)
                                }
                            }
                        }
                    }
                }
            }

            // ── power row ────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.borderCol
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Item { Layout.fillWidth: true }

                Repeater {
                    model: [
                        { icon: "system-log-out",   tip: i18n("Log out"),  action: "logout"   },
                        { icon: "system-reboot",    tip: i18n("Restart"),  action: "reboot"   },
                        { icon: "system-shutdown",  tip: i18n("Shutdown"), action: "shutdown" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width:  Kirigami.Units.gridUnit * 2.2
                        height: Kirigami.Units.gridUnit * 2.2
                        radius: 6
                        color: pMA.containsMouse ? root.cellHover : "transparent"

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            source: modelData.icon
                            width:  Kirigami.Units.iconSizes.smallMedium
                            height: Kirigami.Units.iconSizes.smallMedium
                        }

                        ToolTip.visible: pMA.containsMouse
                        ToolTip.text: modelData.tip
                        ToolTip.delay: 400

                        MouseArea {
                            id: pMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.triggerSystem(modelData.action)
                                root.closePopup()
                            }
                        }
                    }
                }
            }
        }
    }
}