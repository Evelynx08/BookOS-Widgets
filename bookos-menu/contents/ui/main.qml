/*
    BookOS Menu — Apple-style system menu plasmoid for KDE Plasma 6.
    SPDX-License-Identifier: GPL-2.0-or-later

    The panel shows the BookOS logo mark (auto light/dark). Clicking it opens
    a drop-down (the plasmoid's full representation) with system actions, mac
    "menu bar" style. "About This PC" opens a BookOS-styled info window.
*/
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support 2.0 as P5Support
import "i18n.js" as I18n

PlasmoidItem {
    id: menu

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    hideOnWindowDeactivate: true
    preferredRepresentation: compactRepresentation

    readonly property string locale: Qt.locale().name  // e.g. "es_ES"

    // ── BookOS palette (dynamic light/dark) ─────────────────────────
    readonly property bool darkTheme: {
        var c = Kirigami.Theme.backgroundColor
        return (0.299*c.r + 0.587*c.g + 0.114*c.b) < 0.5
    }
    readonly property color popBg:  darkTheme ? "#1c1c1e" : "#FFFFFF"
    readonly property color tx:     darkTheme ? "#FFFFFF" : "#000000"
    readonly property color tx2:    "#8e8e93"
    readonly property color divCol: darkTheme ? Qt.rgba(1,1,1,0.10) : Qt.rgba(0,0,0,0.10)
    readonly property color accent: darkTheme ? "#0A84FF" : "#007AFF"

    // ── Shell runner for actions ────────────────────────────────────
    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            // command finished — release the source so it can run again later
            disconnectSource(source)
        }
        function exec(cmd) {
            // tag with timestamp so repeated identical actions still re-trigger
            // (connectSource on an already-connected identical string is a no-op)
            connectSource(cmd + " # " + Date.now())
        }
    }

    SysInfo { id: sysinfo }

    // ── About dialog (lazy window) ──────────────────────────────────
    Loader {
        id: aboutLoader
        active: false
        source: "AboutDialog.qml"
        onLoaded: {
            item.locale = menu.locale
            item.sysinfo = sysinfo
            item.openSettings.connect(function() { runner.exec("bookos-settings") })
            item.show()
        }
    }
    function showAbout() {
        if (aboutLoader.item) aboutLoader.item.show()
        else aboutLoader.active = true
    }

    // ── Action dispatch ─────────────────────────────────────────────
    function doAction(id) {
        switch (id) {
            case "about":    showAbout(); break
            case "prefs":    runner.exec("bookos-settings"); break
            case "store":    runner.exec("bookos-store"); break
            // Power actions: forced — no confirmation prompt, ignore inhibitors.
            case "sleep":    runner.exec("systemctl suspend -i"); break
            case "restart":  runner.exec("systemctl reboot -i || systemctl reboot --force"); break
            case "shutdown": runner.exec("systemctl poweroff -i || systemctl poweroff --force"); break
            case "lock":     runner.exec("qdbus6 org.freedesktop.ScreenSaver /ScreenSaver Lock 2>/dev/null || qdbus org.freedesktop.ScreenSaver /ScreenSaver Lock 2>/dev/null || loginctl lock-session"); break
            case "logout":   runner.exec("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptLogout 2>/dev/null || qdbus org.kde.LogoutPrompt /LogoutPrompt promptLogout"); break
        }
        // close after dispatch so the running command isn't torn down early
        Qt.callLater(function() { menu.expanded = false })
    }

    // ── Compact (panel) representation: the logo button ─────────────
    compactRepresentation: MouseArea {
        id: compact
        Layout.minimumWidth: Kirigami.Units.iconSizes.small + 10
        hoverEnabled: true
        onClicked: menu.expanded = !menu.expanded

        Image {
            id: logo
            anchors.centerIn: parent
            height: Math.min(parent.height * 0.6, 22)
            width: height
            fillMode: Image.PreserveAspectFit
            smooth: true
            source: Qt.resolvedUrl(menu.darkTheme ? "../icons/logo-on-dark.svg"
                                                   : "../icons/logo-on-light.svg")
            opacity: compact.containsMouse || menu.expanded ? 1.0 : 0.9
        }
    }

    // ── Full representation: the drop-down menu ─────────────────────
    fullRepresentation: Item {
        id: full
        implicitWidth: 210
        implicitHeight: col.implicitHeight
        Layout.minimumWidth: 210
        Layout.maximumWidth: 210
        Layout.minimumHeight: col.implicitHeight
        Layout.maximumHeight: col.implicitHeight

        // No custom background rectangle: we use Plasma's native popup frame
        // (themed rounding + shadow). A second rounded rect inside it produced
        // the "double border" artifact, so it's intentionally omitted.

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 0

            Item { Layout.preferredHeight: 2 }

            MenuRow { label: I18n.tr(locale,"about");  onTriggered: doAction("about") }

            MenuDivider {}

            MenuRow { label: I18n.tr(locale,"prefs");  onTriggered: doAction("prefs") }
            MenuRow { label: I18n.tr(locale,"store");  onTriggered: doAction("store") }

            MenuDivider {}

            MenuRow { label: I18n.tr(locale,"sleep");    onTriggered: doAction("sleep") }
            MenuRow { label: I18n.tr(locale,"restart");  onTriggered: doAction("restart") }
            MenuRow { label: I18n.tr(locale,"shutdown"); onTriggered: doAction("shutdown") }

            MenuDivider {}

            MenuRow { label: I18n.tr(locale,"lock");   shortcut: "Meta+L"; onTriggered: doAction("lock") }
            MenuRow { label: I18n.tr(locale,"logout"); shortcut: "Ctrl+Alt+Del"; onTriggered: doAction("logout") }

            Item { Layout.preferredHeight: 4 }
        }
    }

    // ── Reusable menu item ──────────────────────────────────────────
    component MenuRow : Item {
        id: row
        property string label: ""
        property string shortcut: ""
        signal triggered()

        Layout.fillWidth: true
        Layout.leftMargin: 6
        Layout.rightMargin: 6
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: rowMa.containsMouse ? menu.accent : "transparent"
        }
        RowLayout {
            anchors {
                left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                leftMargin: 11; rightMargin: 11
            }
            spacing: 8
            Text {
                text: row.label
                color: rowMa.containsMouse ? "#FFFFFF" : menu.tx
                font.pointSize: 9.5
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                visible: row.shortcut !== ""
                text: row.shortcut
                color: rowMa.containsMouse ? "#FFFFFF" : menu.tx2
                font.pointSize: 8
            }
        }
        MouseArea {
            id: rowMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.triggered()
        }
    }

    component MenuDivider : Item {
        Layout.fillWidth: true
        implicitHeight: 7
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 11; anchors.rightMargin: 11
            height: 1
            color: menu.divCol
        }
    }
}
