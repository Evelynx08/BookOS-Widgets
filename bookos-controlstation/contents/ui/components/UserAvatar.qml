import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.components 1.0 as KirigamiComponents
import org.kde.kcmutils as KCM
import org.kde.coreaddons 1.0 as KCoreAddons
import "../lib" as Lib

Lib.Card {
    id: userAvatar

    Layout.fillWidth: true
    Layout.fillHeight: true

    visible: root.showAvatar

    // When true (BookOS header), show avatar + name side by side.
    property bool showName: false

    // Back-compat no-op props used by other layouts.
    property bool isLongButton: false
    property bool showTitle: true
    property bool singleLineWidget: false

    KCoreAddons.KUser {
        id: kuser
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.mediumSpacing
        spacing: root.smallSpacing

        KirigamiComponents.AvatarButton {
            id: avatar
            source: kuser.faceIconUrl
            name: kuser.fullName || kuser.loginName
            Layout.alignment: Qt.AlignVCenter | (userAvatar.showName ? Qt.AlignLeft : Qt.AlignHCenter)
            Layout.preferredHeight: Math.min(parent.height, userAvatar.showName ? parent.height : parent.width) - 4
            Layout.preferredWidth: Layout.preferredHeight
            onClicked: userAvatar.openUsers()
        }

        ColumnLayout {
            visible: userAvatar.showName
            Layout.fillWidth: true
            spacing: 0
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: kuser.fullName || kuser.loginName
                font.pixelSize: root.mediumFontSize
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: kuser.loginName
                font.pixelSize: root.smallFontSize
                opacity: 0.7
                elide: Text.ElideRight
            }
        }
    }

    function openUsers() {
        KCM.KCMLauncher.openSystemSettings("kcm_users")
        root.toggle()
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.editingLayout
        cursorShape: Qt.PointingHandCursor
        onClicked: userAvatar.openUsers()
    }
}
