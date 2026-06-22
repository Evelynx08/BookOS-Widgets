/*
    BookOS Launchpad — main.qml
    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kicker 0.1 as Kicker
import org.kde.kirigami 2.20 as Kirigami

PlasmoidItem {
    id: kicker

    signal reset

    property var globalFavorites: rootModel.favoritesModel
    property var systemFavorites: rootModel.systemFavoritesModel
    property var rootModelObj:    rootModel

    Plasmoid.icon: Plasmoid.configuration.useCustomIcon && Plasmoid.configuration.customIcon
                   ? Plasmoid.configuration.customIcon
                   : Qt.resolvedUrl("../icons/launchpad.svg")

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    preferredRepresentation: compactRepresentation

    readonly property string themeFile: "./DashboardRepresentation.qml"
    
    // ── VISTA PANTALLA COMPLETA ───────────────────────
    fullRepresentation: compactRepresentation

    // ── Compact icon for panel/dock ───────────────────────────────
    compactRepresentation: Item {
        id: compactRoot

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        // Tamaños fijos para evitar que el icono colapse a 0x0
        implicitWidth:  Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium
        Layout.minimumWidth:  vertical ? -1 : Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: vertical ? Kirigami.Units.iconSizes.medium : -1
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        Image {
            id: launchIconImage
            anchors.fill: parent
            source: Qt.resolvedUrl("../icons/launchpad.png")
            visible: !(Plasmoid.configuration.useCustomIcon && Plasmoid.configuration.customIcon)
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 128
            sourceSize.height: 128
            mipmap: true

            scale: mouseArea.pressed ? 0.85 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Kirigami.Icon {
            id: launchIcon
            anchors.fill: parent
            source: Plasmoid.configuration.customIcon
            visible: Plasmoid.configuration.useCustomIcon && Plasmoid.configuration.customIcon
            active: mouseArea.containsMouse
            smooth: true

            scale: mouseArea.pressed ? 0.85 : 1.0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            activeFocusOnTab: true

            Keys.onPressed: function (event) {
                switch (event.key) {
                    case Qt.Key_Space:
                    case Qt.Key_Enter:
                    case Qt.Key_Return:
                    case Qt.Key_Select:
                        Plasmoid.activated()
                        break
                }
            }

            Accessible.name: Plasmoid.title
            Accessible.role: Accessible.Button

            onClicked: {
                if (dashWindow) {
                    dashWindow.toggle() // Pantalla completa antigua
                }
            }
        }
    }

    // ── Dashboard window (Solo para BookOS Theme) ───────
    property Component dashWindowComponent: null
    property var dashWindow: null

    function _rebuildDashWindow() {
        if (dashWindow) { dashWindow.destroy(); dashWindow = null }
        dashWindowComponent = Qt.createComponent(Qt.resolvedUrl(themeFile), kicker)
        if (dashWindowComponent && dashWindowComponent.status === Component.Ready) {
            dashWindow = dashWindowComponent.createObject(kicker)
        }
    }

    Plasmoid.status: (dashWindow && dashWindow.visible)
                     ? PlasmaCore.Types.ActiveStatus
                     : PlasmaCore.Types.PassiveStatus

    function action_menuedit() {
        processRunner.runMenuEditor()
    }

    Kicker.RootModel {
        id: rootModel
        autoPopulate:             false
        appNameFormat:            Plasmoid.configuration.appNameFormat
        flat:                     true
        sorted:                   Plasmoid.configuration.alphaSort
        showSeparators:           false
        appletInterface:          kicker
        showAllApps:              true
        showAllAppsCategorized:   false
        showTopLevelItems:        false
        showRecentApps:           false
        showRecentDocs:           false
        showPowerSession:         false
        showFavoritesPlaceholder: false

        Component.onCompleted: {
            favoritesModel.initForClient("org.kde.plasma.kicker.favorites.instance-" + Plasmoid.id)
        }
    }

    Kicker.DragHelper    { id: dragHelper    }
    Kicker.ProcessRunner { id: processRunner }

    Component.onCompleted: {
        rootModel.refresh()
        _rebuildDashWindow()
        Plasmoid.activated.connect(function() {
            // Repara la tecla Meta (Windows)
            if (dashWindow) {
                dashWindow.toggle()
            }
        })
    }
}