/*
    BookOS Launchpad — FolderView.qml
    Popup overlay that shows folder contents.
    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: folderView

    // ── public api ───────────────────────────────────────────────────
    property var    folderApps: []
    property string folderName: ""
    property int    folderIdx:  -1
    property string folderColor: "#3F51B5"

    property int    iconSize:   64
    property int    cellWidth:  100
    property int    cellHeight: 120
    property bool   showLabel:  true
    property color  fgColor:    "#FFFFFF"
    property color  bgColor:    "#1A1A1AE6"
    property bool   darkTheme:  true

    signal appLaunched()
    signal renamed(int folderIdx, string newName)
    signal colorChanged(int folderIdx, string newColor)
    // Emitted while dragging an inner app: mouse pos in folderView coords
    signal innerDragStart(int memberIdx, string appName, var iconSrc)
    signal innerDragMove(real x, real y)
    signal innerDragEnd(real x, real y)
    // Emitted when an inner app is moved within the folder grid
    signal innerReorder(int from, int to)

    // Expose card alias for outer to detect "inside/outside"
    property alias card: card

    // Compute which inner-grid index is under (x,y) in folderView coords.
    // Returns -1 if not over the grid.
    function computeInnerHoverIdx(x, y) {
        if (!appGridContainer) return -1
        var p = mapToItem(appGridContainer, x, y)
        if (p.x < 0 || p.y < 0
            || p.x > appGridContainer.width
            || p.y > appGridContainer.height) return -1
        var col = Math.floor(p.x / cellWidth)
        var row = Math.floor(p.y / cellHeight)
        if (col < 0 || col >= cardCols) return -1
        var idx = row * cardCols + col
        if (idx < 0) return -1
        if (idx > folderApps.length) idx = folderApps.length
        return idx
    }

    property var appGridContainer: null

    // ── state ────────────────────────────────────────────────────────
    visible: false
    anchors.fill: parent
    z: 500

    // sized to its parent (full overlay) — the actual card is computed below
    property int cardCols: Math.min(4, Math.max(1, folderApps.length))
    property int cardRows: Math.max(1, Math.ceil(folderApps.length / cardCols))
    property int cardW: cardCols * cellWidth + Kirigami.Units.gridUnit * 4
    property int cardH: cardRows * cellHeight
              + Kirigami.Units.gridUnit * 6   // header + padding
              + Kirigami.Units.gridUnit * 2

    function open() {
        visible = true
        opacity = 0
        card.scale = 0.85
        openAnim.start()
    }
    function close() {
        closeAnim.start()
    }

    NumberAnimation { id: openAnim
        target: folderView; property: "opacity"; from: 0; to: 1
        duration: 180; easing.type: Easing.OutCubic
    }
    NumberAnimation { id: closeAnim
        target: folderView; property: "opacity"; from: 1; to: 0
        duration: 140; easing.type: Easing.InCubic
        onFinished: { folderView.visible = false; renameField.visible = false }
    }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

    // backdrop dim — click outside the card closes
    Rectangle {
        anchors.fill: parent
        color: folderView.darkTheme ? Qt.rgba(0, 0, 0, 0.55)
                                    : Qt.rgba(0, 0, 0, 0.40)
    }
    MouseArea {
        anchors.fill: parent
        z: -1   // below the card so card receives its own clicks
        onClicked: function(mouse) {
            // only close when click is outside the card rect
            var p = mapToItem(card, mouse.x, mouse.y)
            if (p.x < 0 || p.y < 0 || p.x > card.width || p.y > card.height) {
                folderView.close()
            }
        }
    }

    // ── card ─────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  folderView.cardW
        height: folderView.cardH
        radius: Kirigami.Units.gridUnit * 1.5
        color:  folderView.darkTheme
                ? Qt.rgba(0.14, 0.14, 0.16, 0.96)
                : Qt.rgba(0.97, 0.97, 0.97, 0.96)
        border.color: folderView.darkTheme
                      ? Qt.rgba(1, 1, 1, 0.10)
                      : Qt.rgba(0, 0, 0, 0.10)
        border.width: 1

        // tinted accent strip with the folder color
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: folderView.folderColor
            opacity: 0.10
        }


        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: Kirigami.Units.largeSpacing * 2
            spacing:         Kirigami.Units.largeSpacing

            // ── header: title + color picker button ─────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Item { Layout.fillWidth: true; implicitWidth: 1 }

                // folder name display / dbl-click to edit
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth:  Math.max(titleLabel.implicitWidth, renameField.implicitWidth) + Kirigami.Units.gridUnit
                    implicitHeight: Kirigami.Units.gridUnit * 2.5

                    Text {
                        id: titleLabel
                        anchors.centerIn: parent
                        visible: !renameField.visible
                        text:    folderView.folderName || i18n("Folder")
                        color:   folderView.fgColor
                        font.pixelSize: Kirigami.Units.gridUnit
                        font.bold:      true
                    }

                    TextField {
                        id: renameField
                        anchors.centerIn: parent
                        visible:        false
                        text:           folderView.folderName
                        color:          folderView.fgColor
                        font.pixelSize: Kirigami.Units.gridUnit
                        font.bold:      true
                        horizontalAlignment: TextInput.AlignHCenter
                        implicitWidth:  Kirigami.Units.gridUnit * 12
                        background: Rectangle {
                            color:  Qt.rgba(1, 1, 1, 0.10)
                            radius: height / 2
                            border.color: Qt.rgba(1, 1, 1, 0.20)
                            border.width: 1
                        }
                        onAccepted: commit()
                        onActiveFocusChanged: if (!activeFocus) commit()
                        function commit() {
                            folderView.folderName = text
                            folderView.renamed(folderView.folderIdx, text)
                            visible = false
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onDoubleClicked: {
                            renameField.text = folderView.folderName
                            renameField.visible = true
                            renameField.forceActiveFocus()
                            renameField.selectAll()
                        }
                    }
                }

                Item { Layout.fillWidth: true; implicitWidth: 1 }

                // color picker icon button
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width:  Kirigami.Units.gridUnit * 1.6
                    height: width
                    radius: width / 2
                    color:  folderView.folderColor
                    border.color: Qt.rgba(1,1,1,0.3)
                    border.width: 1

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: colorPopup.open()
                    }
                }
            }

            // separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(folderView.fgColor.r, folderView.fgColor.g, folderView.fgColor.b, 0.08)
            }

            // ── apps grid ─────────────────────────────────────────────
            Grid {
                id: appsGrid
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: false
                columns: folderView.cardCols
                rowSpacing:    Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.smallSpacing
                Component.onCompleted: folderView.appGridContainer = appsGrid

                Repeater {
                    model: folderView.folderApps.length
                    delegate: Item {
                        id: appCell
                        required property int index
                        width:  folderView.cellWidth
                        height: folderView.cellHeight

                        property var entry: folderView.folderApps[index]
                        property bool dragging: cellMouse.dragMode

                        Column {
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing
                            opacity: appCell.dragging ? 0.0 : 1.0

                            Kirigami.Icon {
                                source: appCell.entry ? (appCell.entry.icon || "") : ""
                                fallback: "application-x-executable"
                                width:  folderView.iconSize
                                height: folderView.iconSize
                                anchors.horizontalCenter: parent.horizontalCenter
                                roundToIconSize: false
                                smooth: true
                                animated: false
                                scale: cellMouse.pressed && !cellMouse.dragMode ? 0.88 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }
                            }
                            Text {
                                visible: folderView.showLabel
                                text:    appCell.entry ? appCell.entry.name : ""
                                color:   folderView.fgColor
                                font.pixelSize:      Kirigami.Units.gridUnit * 0.75
                                elide:               Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                width:               folderView.cellWidth
                            }
                        }

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            pressAndHoldInterval: 350
                            preventStealing: true

                            property bool dragMode: false

                            onPressAndHold: mouse => {
                                dragMode = true
                                var p = mapToItem(folderView, mouse.x, mouse.y)
                                folderView.innerDragStart(appCell.index,
                                    appCell.entry ? appCell.entry.name : "",
                                    appCell.entry ? appCell.entry.icon : "")
                                folderView.innerDragMove(p.x, p.y)
                            }
                            onPositionChanged: mouse => {
                                if (!dragMode) return
                                var p = mapToItem(folderView, mouse.x, mouse.y)
                                folderView.innerDragMove(p.x, p.y)
                            }
                            onReleased: mouse => {
                                if (dragMode) {
                                    dragMode = false
                                    var p = mapToItem(folderView, mouse.x, mouse.y)
                                    folderView.innerDragEnd(p.x, p.y)
                                }
                            }
                            onCanceled: dragMode = false
                            onClicked: mouse => {
                                if (dragMode) return
                                if (appCell.entry && appCell.entry.trigger) appCell.entry.trigger()
                                folderView.close()
                                folderView.appLaunched()
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ── color picker popup (custom, no QtControls Popup) ──────────
    Item {
        id: colorPopup
        parent: card
        x: card.width  - width  - Kirigami.Units.largeSpacing
        y: Kirigami.Units.gridUnit * 3.5
        width:  Kirigami.Units.gridUnit * 13
        height: Kirigami.Units.gridUnit * 5
        visible: false
        z: 100

        function open()  { visible = true  }
        function close() { visible = false }

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.gridUnit
            color:  folderView.darkTheme
                    ? Qt.rgba(0.16, 0.16, 0.18, 0.98)
                    : Qt.rgba(1.0,  1.0,  1.0,  0.98)
            border.color: folderView.darkTheme
                          ? Qt.rgba(1, 1, 1, 0.12)
                          : Qt.rgba(0, 0, 0, 0.10)
            border.width: 1
        }

        Grid {
            anchors.centerIn: parent
            columns: 6
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: ["#3F51B5", "#E53935", "#43A047", "#FB8C00",
                        "#8E24AA", "#00ACC1", "#5D4037", "#546E7A",
                        "#F4511E", "#7CB342", "#FDD835", "#EC407A"]
                Rectangle {
                    required property int index
                    required property string modelData
                    width:  Kirigami.Units.iconSizes.medium
                    height: width
                    radius: width / 2
                    color:  modelData
                    border.color: folderView.folderColor === modelData
                                  ? folderView.fgColor
                                  : Qt.rgba(0, 0, 0, 0.15)
                    border.width: folderView.folderColor === modelData ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            folderView.folderColor = modelData
                            folderView.colorChanged(folderView.folderIdx, modelData)
                            colorPopup.close()
                        }
                    }
                }
            }
        }
    }
}
