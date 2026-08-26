import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

// One UI circular quick-toggle: blue circle (active #4184FF / inactive #AECAFF)
// with a white glyph. Used inside the BookOS ToggleGrid card.
Item {
    id: toggle

    property bool active: false
    property string source: ""
    property bool customIcon: true
    property string label: ""

    signal clicked

    Layout.fillWidth: true
    Layout.fillHeight: true

    Rectangle {
        id: circle
        anchors.centerIn: parent
        // Keep it a circle: smallest of the available box sides.
        width: Math.min(parent.width, parent.height)
        height: width
        radius: width / 2
        color: toggle.active ? root.bookosActive : root.bookosInactive

        Behavior on color { ColorAnimation { duration: 120 } }

        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: parent.width * 0.28
            source: toggle.source
            isMask: toggle.customIcon
            color: "#FFFFFF"
        }
    }

    PlasmaComponents.ToolTip {
        text: toggle.label
        visible: ttArea.containsMouse && toggle.label !== ""
    }

    MouseArea {
        id: ttArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.clicked()
    }
}
