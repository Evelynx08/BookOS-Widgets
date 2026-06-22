import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kquickcontrolsaddons as KQuickAddons
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.workspace.components 2.0
import org.kde.kirigami as Kirigami

import "../lib" as Lib

Lib.Card { 
    id: battery

    Layout.fillHeight: true
    Layout.fillWidth: true
    smallTopMargins: true
    smallBottomMargins: true
    property bool isLongButton: false
    property bool showTitle: true
    property bool bookosStyle: false

    property bool small: height < (root.sectionHeight*1.3) / 3.5

    visible: batteryPage.batteryControl.hasBatteries && root.showBattery

    showContentOverflowIndicator: isLongButton && !bookosStyle

    // ── BookOS header: big centered percentage + charging bolt ──
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.smallSpacing
        visible: bookosStyle
        spacing: 0

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            Kirigami.Icon {
                source: batteryPage.batteryControl.pluggedIn ? "battery-full-charging" : "battery-full"
                Layout.preferredHeight: root.largeFontSize * 1.4
                Layout.preferredWidth: Layout.preferredHeight
            }
            PlasmaComponents.Label {
                text: i18nc("Battery percentage", "%1%", batteryPage.batteryControl.percent)
                font.pixelSize: root.largeFontSize * 1.6
                font.weight: Font.Bold
                color: batteryPage.batteryControl.percent <= 15 ? root.redColor : Kirigami.Theme.textColor
            }
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: batteryPage.batteryControl.pluggedIn ? i18n("Charging") : i18n("Battery")
            font.pixelSize: root.smallFontSize
            opacity: 0.7
        }
    }

    GridLayout {
        visible: !bookosStyle
        anchors.fill: parent
        anchors.margins: root.mediumSpacing
        clip: true

        rows: (small || isLongButton) ? 1 : 2
        columns: 2

        // BookOS-style battery icon: pill body with fill proportional to %,
        // plus a small charging bolt overlay when plugged in. iOS-like proportions.
        Item {
            id: batteryIcon
            Layout.alignment: isLongButton && showTitle ?  (Qt.AlignRight | Qt.AlignVcenter) : (Qt.AlignHCenter | Qt.AlignVcenter)
            Layout.preferredWidth: 32
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            Layout.columnSpan: (small || isLongButton ) ? 1 : 2

            readonly property int  pct: batteryPage.batteryControl.percent
            readonly property bool plugged: batteryPage.batteryControl.pluggedIn
            readonly property color fillColor: plugged ? "#34c759"
                                              : pct <= 15 ? "#ff453a"
                                              : pct <= 30 ? "#ffd60a"
                                              : Kirigami.Theme.textColor

            // Outline body (iOS-style horizontal pill)
            Rectangle {
                id: body
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 3
                height: parent.height * 0.50
                radius: 3
                color: "transparent"
                border.color: Kirigami.Theme.textColor
                border.width: 1.5
                opacity: 0.55

                // Filled portion
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: Math.max(2, (parent.width - 4) * batteryIcon.pct / 100)
                    radius: 1.5
                    color: batteryIcon.fillColor
                    opacity: 1.0 / 0.55  // counter parent opacity so fill is solid
                }
            }
            // Battery tip (right cap)
            Rectangle {
                anchors.left: body.right
                anchors.leftMargin: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: body.height * 0.45
                radius: 1
                color: Kirigami.Theme.textColor
                opacity: 0.55
            }
            // Charging bolt overlay
            PlasmaComponents.Label {
                anchors.centerIn: body
                text: "⚡"
                font.pixelSize: body.height * 0.85
                color: "#000000"
                visible: batteryIcon.plugged
            }
        }

        PlasmaComponents.Label {
            id: percentLabel
            Layout.alignment: isLongButton ?  (Qt.AlignLeft | Qt.AlignVcenter) : (Qt.AlignHCenter | Qt.AlignVcenter)
            text: i18nc("Placeholder is battery percentage", "%1%", batteryPage.batteryControl.percent)
            font.pixelSize: root.mediumFontSize
            font.weight:Font.Bold
            Layout.columnSpan: (small || isLongButton ) ? 1 : 2
            visible: showTitle
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: !root.editingLayout
        hoverEnabled: false
        onClicked: {
            var pageHeight =  batteryPage.contentItemHeight + batteryPage.headerHeight;
            fullRep.togglePage(fullRep.defaultInitialWidth, pageHeight, batteryPage);
        }
    }
}
