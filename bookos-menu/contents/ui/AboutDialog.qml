/*
    AboutDialog — "About This PC" panel, BookOS look.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "i18n.js" as I18n

Window {
    id: win
    width: 360
    height: 560
    minimumWidth: 360
    minimumHeight: 560
    maximumWidth: 360
    maximumHeight: 560
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: I18n.tr(locale, "about")

    property string locale: ""
    property var sysinfo: null

    // ── BookOS palette ──────────────────────────────────────────────
    readonly property bool darkTheme: {
        var c = Kirigami.Theme.backgroundColor
        return (0.299*c.r + 0.587*c.g + 0.114*c.b) < 0.5
    }
    readonly property color bg:    darkTheme ? "#1c1c1e" : "#ececec"
    readonly property color tx:    darkTheme ? "#FFFFFF" : "#000000"
    readonly property color tx2:   "#8e8e93"
    readonly property color blue:  darkTheme ? "#0A84FF" : "#007AFF"
    readonly property color btnBg: darkTheme ? "#2c2c2e" : "#FFFFFF"
    readonly property color btnBd: darkTheme ? Qt.rgba(1,1,1,0.14) : Qt.rgba(0,0,0,0.18)

    function show() { win.visible = true; win.raise(); win.requestActivate() }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: bg
        border.color: darkTheme ? Qt.rgba(1,1,1,0.12) : Qt.rgba(0,0,0,0.15)
        border.width: 1

        // Drag the window by the top strip
        MouseArea {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 40
            onPressed: win.startSystemMove()
        }

        // Close button — top-right, BookOS rounded-square style
        Rectangle {
            id: closeBtn
            anchors { right: parent.right; top: parent.top; margins: 14 }
            width: 26; height: 26; radius: 8
            color: closeMa.containsMouse ? (darkTheme ? "#FF453A" : "#FF3B30")
                                         : (darkTheme ? "#2c2c2e" : "#e6e6e9")
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeMa.containsMouse ? "#FFFFFF" : tx2
                font.pixelSize: 13
                font.bold: true
            }
            MouseArea {
                id: closeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.visible = false
            }
        }

        ColumnLayout {
            anchors {
                top: closeBtn.bottom; left: parent.left; right: parent.right
                bottom: parent.bottom; topMargin: 10
                leftMargin: 28; rightMargin: 28; bottomMargin: 22
            }
            spacing: 0

            Item { Layout.preferredHeight: 6 }

            // Laptop render, chosen by detected model (like macOS About).
            Image {
                id: laptopImg
                Layout.alignment: Qt.AlignHCenter
                sourceSize.width: 240
                fillMode: Image.PreserveAspectFit
                source: sysinfo ? sysinfo.modelImage : ""
                // fallback to the BookOS logo if a render is missing
                onStatusChanged: if (status === Image.Error)
                    source = Qt.resolvedUrl("../icons/book-os.svg")
            }

            Item { Layout.preferredHeight: 18 }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: sysinfo ? (sysinfo.model || I18n.tr(locale,"unknown")) : ""
                color: tx
                font.pixelSize: 26
                font.weight: Font.Bold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                text: sysinfo ? sysinfo.osName : ""
                color: tx2
                font.pixelSize: 12
            }

            Item { Layout.preferredHeight: 22 }

            // Spec rows
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 2
                rowSpacing: 8
                columnSpacing: 14

                component K : Text {
                    color: tx
                    font.pointSize: 9
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignRight
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                }
                component V : Text {
                    color: tx
                    font.pointSize: 9
                    Layout.maximumWidth: 200
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                K { text: I18n.tr(locale,"chip") }
                V { text: sysinfo ? sysinfo.chip : "" }

                K { text: I18n.tr(locale,"graphics") }
                V { text: sysinfo ? sysinfo.graphics : "" }

                K { text: I18n.tr(locale,"memory") }
                V { text: sysinfo ? sysinfo.memory : "" }

                K { text: I18n.tr(locale,"serial") }
                V { text: sysinfo ? sysinfo.serial : "" }

                K { text: I18n.tr(locale,"os") }
                V { text: sysinfo ? sysinfo.osVersion : "" }
            }

            Item { Layout.fillHeight: true }

            // More info button
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: moreTx.implicitWidth + 36
                implicitHeight: 30
                radius: 8
                color: moreMa.containsMouse ? Qt.darker(btnBg, darkTheme ? 0.85 : 1.05) : btnBg
                border.color: btnBd
                border.width: 1
                Text {
                    id: moreTx
                    anchors.centerIn: parent
                    text: I18n.tr(locale,"moreInfo")
                    color: tx
                    font.pointSize: 9
                }
                MouseArea {
                    id: moreMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.openSettings()
                }
            }

            Item { Layout.preferredHeight: 14 }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: I18n.tr(locale,"regulatory")
                color: blue
                font.pixelSize: 11
                font.underline: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                text: I18n.tr(locale,"rights")
                color: tx2
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    signal openSettings()
}
