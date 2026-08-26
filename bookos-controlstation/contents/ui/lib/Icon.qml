import QtQuick 2.15
import QtQuick.Layouts 1.15
//import QtGraphicalEffects 1.15
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import Qt5Compat.GraphicalEffects


Item
{
    property color sourceColor
    property alias source: icon.source
    property alias selected: icon.selected
    property bool fullSizeIcon : false
    property bool customIcon: false
    property bool enableQuickAction: false

    // BookOS (One UI): active = #4184FF, inactive = #AECAFF, glyph always white.
    property bool bookosColors: false

    signal quickActionTriggered

    property color highlightColor: bookosColors ? root.bookosActive
                                 : root.useSystemColorsOnToggles ? root.themeHighlightColor : root.toggleButtonsColor
    property color iconColor: bookosColors ? "#FFFFFF"
                            : root.useSystemColorsOnToggles ?  Kirigami.Theme.highlightedTextColor : root.toggleButtonsIconColor
    property color offColor: bookosColors ? root.bookosInactive
                           : sourceColor.valid ? sourceColor : root.disabledBgColor

    Rectangle {
        id: rect
        radius: width/2
        color: icon.selected ? highlightColor : offColor
        anchors.fill: parent


        Kirigami.Icon {
            id: icon
            visible: true
            anchors.fill: parent
            anchors.margins: fullSizeIcon ? root.largeSpacing : root.smallSpacing
            anchors.centerIn: parent
            selected: false
            isMask: customIcon
            color: bookosColors ? iconColor : selected ? iconColor : Kirigami.Theme.textColor
        }
    }

    MouseArea {
        enabled: !root.editingLayout && enableQuickAction
        hoverEnabled: true
        anchors.fill: parent
        
        onClicked: quickActionTriggered()
    }
}
