/*
    BookOS Launchpad — ColorChip.qml
    Círculo de color del selector de carpeta.

    Estado seleccionado con un anillo exterior en lugar de un borde grueso: el
    borde grueso comía el propio color y dos chips contiguos parecían del mismo
    tono. El anillo deja el color intacto y se lee de un vistazo.

    SPDX-License-Identifier: GPL-2.0+
*/
import QtQuick 2.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: chip

    property color chipColor: "#3F51B5"
    property bool  selected:  false
    property bool  dark:      true

    signal picked()

    FolderTokens { id: tokens }

    implicitWidth:  Kirigami.Units.iconSizes.medium + 6
    implicitHeight: implicitWidth
    width:  implicitWidth
    height: implicitHeight

    // Anillo de selección
    Rectangle {
        anchors.fill: parent
        radius: tokens.radiusPill
        color: "transparent"
        border.width: 2
        border.color: chip.selected ? tokens.accent(chip.dark) : "transparent"
        opacity: chip.selected ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: tokens.durHover
                              easing.type: Easing.Bezier
                              easing.bezierCurve: tokens.curveStandard }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width:  parent.width - 6
        height: width
        radius: tokens.radiusPill
        color:  chip.chipColor
        border.width: 1
        border.color: tokens.popoverBorder(chip.dark)

        scale: mouse.pressed ? 0.88 : (mouse.containsMouse ? 1.08 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: tokens.durHover
                              easing.type: Easing.Bezier
                              easing.bezierCurve: tokens.curveStandard }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.picked()
    }
}
