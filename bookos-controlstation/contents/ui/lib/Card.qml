import QtQuick 2.15
import QtQml 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    id: rectangle
    color: "transparent"
    border.width: 1
    border.color: root.editingLayout ? root.disabledBgColor : "transparent"

    /******
     We need to gain space to display the shadow so we reduce top and bottom margins to avoid cut elements
     in small widgets such as UserAvatar 
    *******/
    property bool smallTopMargins: false
    property bool smallBottomMargins: false
    property bool smallLeftMargins: false
    property bool smallRightMargins: false
    /******
     This is used to manage widget background color so we can change the color depending on widget status(Command Run) 
    *******/
    property alias customBgColor: cardBg.color


    property bool flat: false

    property bool shadow: (flat || tileStyle) ? false : true

    property bool filled:  flat ? false : true

    property bool bordr:  flat ? false : true

    property bool glassEffect: false

    // BookOS flat tile: neutral grey @80%, no shadow, no border, big radius.
    property bool tileStyle: false

    property bool noMargins: false

    property bool roundedWidget: false

    property int cornerRadius: tileStyle ? root.bookosRadius : roundedWidget ? 32 : 12

    property var margins: shadowContainer.margins
    default property alias content: dataContainer.data
    radius: 12

    property bool hovered: false
    property bool showContentOverflowIndicator: false

    signal clicked
    
    MouseArea {
        anchors.fill: contentOverflowIndicator
        enabled: !root.editingLayout
        hoverEnabled: enabled

        onEntered: rectangle.hovered = true;
        onExited: rectangle.hovered = false;

        onClicked: rectangle.clicked()
    }

    Item {
        id: shadowContainer
        visible: shadow
        
        anchors.fill: parent
        anchors.margins: 0
        layer.enabled: true

        opacity: 0.1 // This controls the opcity of the shadow
        clip: true

        /*
        * This is the real widget where the the shadow is drawn around, we applied some margins
        * to separate it from it's parent(container) so the shadow could be displayed
        */
        Rectangle {
            id: shadowWidget
            anchors.fill: parent
            anchors.margins: 6
            color: root.themeBgColor
            radius: cornerRadius
        }
        DropShadow {
            anchors.fill: shadowWidget
            source: shadowWidget
            transparentBorder: true
            horizontalOffset: 0
            verticalOffset: 2
            radius: 12
            samples: 25
            color: "black"
        }
    }

    Rectangle {
        id: cardBg;
        // glassEffect = pull alpha way down so KWin blur effect bleeds the wallpaper through.
        // Without it cards stay solid even if KWin blur is enabled, because alpha is too high.
        // BookOS (One UI) style: cards read as solid elevated surfaces, slightly
        // lighter/darker than the popup background, instead of mac-glass panes.
        readonly property color elevated: root.isDarkTheme
            ? Qt.lighter(root.themeBgColor, 1.35)
            : Qt.rgba(1, 1, 1, 1)
        color: !filled ? "transparent" :
                tileStyle ? root.bookosTile
                : glassEffect ?
                Qt.rgba(elevated.r, elevated.g, elevated.b, 0.75)
                : root.enableTransparency ?
                Qt.rgba(root.themeBgColor.r, root.themeBgColor.g, root.themeBgColor.b, root.transparencyLevel/100)
                : root.themeBgColor

        border.color: root.isDarkTheme ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
        // glass cards get a hairline so tiles read as distinct surfaces; flat tiles stay borderless
        border.width: tileStyle ? 0 : ((root.showBorders && bordr) || glassEffect) ? 1 : 0
        anchors.centerIn: shadowContainer
        width: shadowWidget.width
        height: shadowWidget.height
        radius: cornerRadius
        z: -1
    }

    Item {
        id: dataContainer
        anchors.fill: parent
        anchors.topMargin: noMargins ? -1 : smallTopMargins ? 4 : 9
        anchors.bottomMargin: noMargins ? -1 : smallBottomMargins ? 4 : 9
        anchors.leftMargin: (noMargins || smallLeftMargins) ? -1 : 9
        anchors.rightMargin: (noMargins || smallRightMargins) ? -1 : 9
    }

    Rectangle {
        id: contentOverflowIndicator
        width: cardBg.width
        height: cardBg.height - 2
        color: "transparent"
        radius: cornerRadius
        visible: showContentOverflowIndicator
        opacity: rectangle.hovered ? 1 : 0
        
        anchors.right: cardBg.right
        anchors.rightMargin: 1
        anchors.verticalCenter: cardBg.verticalCenter

        Kirigami.Icon {
            source: "arrow-right"
            width: 15
            height: width
            scale: contentOverflowIndicator.opacity

            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter

        }

        Behavior on opacity { PropertyAnimation {} }
    }
}