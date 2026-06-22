/*
    BookOS Launchpad — ConfigGeneral.qml
    Settings panel shown in Plasma widget config dialog.
    SPDX-License-Identifier: GPL-2.0+
*/

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0

Kirigami.FormLayout {
    id: configPage

    property alias cfg_iconSize:   iconSizeCombo.currentIndex
    property alias cfg_showLabels: showLabelsCheck.checked
    property alias cfg_alphaSort:  alphaSortCheck.checked
    property alias cfg_darkTheme:  darkThemeCheck.checked
    property alias cfg_blurRadius: blurSlider.value
    property alias cfg_appNameFormat: appNameFormatCombo.currentIndex
    // ── Icons ───────────────────────────────────────────────────────
    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Icons") }

    ComboBox {
        id: iconSizeCombo
        Kirigami.FormData.label: i18n("Icon size:")
        model: [i18n("Small"), i18n("Small Medium"), i18n("Medium"), i18n("Large"), i18n("Huge"), i18n("Enormous")]
        currentIndex: 3
    }

    CheckBox {
        id: showLabelsCheck
        Kirigami.FormData.label: i18n("Show labels:")
        checked: true
    }

    ComboBox {
        id: appNameFormatCombo
        Kirigami.FormData.label: i18n("Name format:")
        model: [i18n("Name"), i18n("Generic name"), i18n("Name (Generic)"), i18n("Generic (Name)")]
        currentIndex: 0
    }

    // ── Sort ────────────────────────────────────────────────────────
    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Behaviour") }

    CheckBox {
        id: alphaSortCheck
        Kirigami.FormData.label: i18n("Sort alphabetically:")
        checked: true
    }

    // ── Appearance ──────────────────────────────────────────────────
    Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Appearance") }



    CheckBox {
        id: darkThemeCheck
        Kirigami.FormData.label: i18n("Dark theme:")
        checked: true
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Blur radius:")
        Slider {
            id: blurSlider
            from: 0; to: 64; stepSize: 1; value: 24
            Layout.fillWidth: true
        }
        Label { text: blurSlider.value.toFixed(0) }
    }
}
