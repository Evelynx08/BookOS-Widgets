/*
    BookOS Launchpad — SearchView.qml
    Shows Kicker runner results in a centered grid.
    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.private.kicker 0.1 as Kicker

Item {
    id: searchView

    property var   runModel
    property int   iconSize:   64
    property int   cellWidth:  80
    property int   cellHeight: 96
    property bool  showLabel:  true
    property color fgColor:    "#FFFFFF"

    signal itemActivated()

    Flow {
        id: resultsFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top
        anchors.topMargin:        Kirigami.Units.largeSpacing * 2
        width:                    Math.min(parent.width * 0.8, 600)
        spacing:                  Kirigami.Units.largeSpacing

        Repeater {
            model: searchView.runModel

            delegate: Item {
                id: resultItem
                width:  searchView.cellWidth
                height: searchView.cellHeight

                required property int   index
                required property string display
                required property var    decoration

                property bool _pressed: false
                scale: _pressed ? 0.88 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: resultItem.decoration || ""
                        width:  searchView.iconSize
                        height: searchView.iconSize
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        visible:             searchView.showLabel
                        text:                resultItem.display || ""
                        color:               searchView.fgColor
                        font.pixelSize:      Kirigami.Units.gridUnit * 0.7
                        elide:               Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        width:               searchView.cellWidth
                    }
                }

                TapHandler {
                    onPressedChanged: resultItem._pressed = pressed
                    onTapped: {
                        if (searchView.runModel)
                            searchView.runModel.trigger(resultItem.index, "", null)
                        searchView.itemActivated()
                    }
                }
            }
        }
    }

    // empty state
    Text {
        anchors.centerIn: parent
        visible:          searchView.runModel === null || searchView.runModel.count === 0
        text:             i18n("No results")
        color:            searchView.fgColor
        opacity:          0.5
        font.pixelSize:   Kirigami.Units.gridUnit
    }
}
