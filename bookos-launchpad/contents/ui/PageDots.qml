/*
    BookOS Launchpad — PageIndicator.qml
    Row of dots. Click any dot to jump to that page.
    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: indicator

    property int   pageCount:     1
    property int   current:       0
    property color activeColor:   "#FFFFFF"
    property color inactiveColor: "#59FFFFFF"

    signal pageClicked(int page)

    implicitWidth:  row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing * 2

        Repeater {
            model: indicator.pageCount
            delegate: Item {
                required property int index
                property bool isActive: index === indicator.current

                // Outer footprint is fixed at the active dot's max width, so the
                // Row layout never reflows mid-animation (only this dot's own
                // rectangle resizes inside its already-reserved slot).
                width:  20
                height: 8

                Rectangle {
                    anchors.centerIn: parent
                    width:  parent.isActive ? 20 : 8
                    height: 8
                    radius: height / 2
                    color:  parent.isActive ? indicator.activeColor : indicator.inactiveColor
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                TapHandler {
                    onTapped: indicator.pageClicked(parent.index)
                }
            }
        }
    }
}
