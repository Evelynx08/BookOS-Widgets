import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmaCore.Dialog {
    id: popupWin
    type: PlasmaCore.Dialog.Notification
    location: PlasmaCore.Types.Floating
    flags: Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false
    backgroundHints: PlasmaCore.Dialog.NoBackground
    visible: true

    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: "dialog-information"
    property var actionNames: []
    property var actionLabels: []
    property int notifId: -1
    property int timeoutMs: 6000
    property bool showCountdown: true
    property string themeMode: "auto"   // auto | light | dark

    signal dismissed()
    signal defaultActionInvoked()
    signal actionInvoked(string actionId)

    readonly property bool isDarkMode: {
        if (themeMode === "dark") return true
        if (themeMode === "light") return false
        var b = Kirigami.Theme.backgroundColor
        return (b.r + b.g + b.b) / 3.0 < 0.5
    }
    readonly property color bg:     isDarkMode ? Qt.color("#1c1c1e") : Qt.color("#FFFFFF")
    readonly property color txt:    isDarkMode ? Qt.color("#FFFFFF") : Qt.color("#000000")
    readonly property color txt2:   Qt.color("#8e8e93")
    readonly property color brdCol: isDarkMode ? Qt.rgba(1,1,1,0.12) : Qt.rgba(0,0,0,0.10)
    readonly property color hi:     isDarkMode ? Qt.color("#0A84FF") : Qt.color("#007AFF")

    // progreso restante 1 → 0
    property real countdown: 1.0

    mainItem: Item {
        width: 340
        height: card.height

        Rectangle {
            id: card
            width: parent.width
            height: contentCol.implicitHeight + 28 + (popupWin.showCountdown && popupWin.timeoutMs > 0 ? 10 : 0)
            radius: 16
            color: popupWin.bg
            border.width: 1
            border.color: popupWin.brdCol
            clip: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: popupWin.defaultActionInvoked()
            }

            Rectangle {
                width: 20; height: 20; radius: 10
                anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 10 }
                color: closeMouse.containsMouse ? (popupWin.isDarkMode ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.08)) : "transparent"
                z: 2
                Text { anchors.centerIn: parent; text: "✕"; color: popupWin.txt2; font.pixelSize: 11 }
                MouseArea {
                    id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: popupWin.dismissed()
                }
            }

            ColumnLayout {
                id: contentCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Kirigami.Icon {
                        source: popupWin.appIcon
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignTop
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.rightMargin: 20; spacing: 2
                        PlasmaComponents.Label {
                            text: popupWin.summary !== "" ? popupWin.summary : popupWin.appName
                            font.weight: Font.DemiBold; font.pixelSize: 13
                            color: popupWin.txt; Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            visible: text !== ""
                            text: popupWin.body.replace(/<[^>]*>/g, "")
                            font.pixelSize: 12; color: popupWin.txt2
                            Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: popupWin.actionNames.length > 0
                    spacing: 8
                    Repeater {
                        model: popupWin.actionNames
                        delegate: Rectangle {
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: actLabel.implicitWidth + 20
                            radius: 14
                            color: actMouse.containsMouse ? Qt.rgba(popupWin.hi.r, popupWin.hi.g, popupWin.hi.b, 0.16)
                                                           : (popupWin.isDarkMode ? Qt.rgba(1,1,1,0.08) : Qt.rgba(0,0,0,0.05))
                            PlasmaComponents.Label {
                                id: actLabel; anchors.centerIn: parent
                                text: popupWin.actionLabels[index] || modelData
                                font.pixelSize: 11; font.weight: Font.Medium; color: popupWin.hi
                            }
                            MouseArea {
                                id: actMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: popupWin.actionInvoked(modelData)
                            }
                        }
                    }
                }
            }

            // barra de cuenta atrás — indica cuándo se cerrará solo
            Rectangle {
                visible: popupWin.showCountdown && popupWin.timeoutMs > 0
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 9 }
                height: 3; radius: 1.5
                color: popupWin.isDarkMode ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.07)
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: parent.width * popupWin.countdown
                    radius: 1.5
                    color: popupWin.hi
                    opacity: 0.9
                }
            }
        }

        NumberAnimation {
            target: popupWin
            property: "countdown"
            from: 1.0; to: 0.0
            duration: popupWin.timeoutMs
            running: popupWin.timeoutMs > 0
        }
        Timer {
            running: popupWin.timeoutMs > 0
            interval: popupWin.timeoutMs
            onTriggered: popupWin.dismissed()
        }
    }
}
