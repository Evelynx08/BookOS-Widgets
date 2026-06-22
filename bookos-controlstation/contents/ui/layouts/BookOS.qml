// BookOS layout — Samsung One UI inspired control center.
// Pure white/black background, grey 80% tiles, blue circular toggles,
// fat pill sliders with side toggles, and a blurred album-art media card.
import QtQml 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.0
import "../components" as Components
import "../lib" as Lib
import "components/BookOS" as BookOS

Item {
    id: wrapper
    anchors.fill: parent
    implicitHeight: col.implicitHeight + 28

    // Pure white / near-black background behind everything.
    Rectangle {
        anchors.fill: parent
        color: root.bookosBg
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── Header: user, battery, power ────────────────────────
        GridLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 72 * root.scale
            Layout.maximumHeight: Layout.preferredHeight
            rows: 1
            columns: 3
            columnSpacing: 10

            Components.UserAvatar {
                Layout.columnSpan: 1
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileStyle: true
                showName: true
            }
            Components.Battery {
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileStyle: true
                bookosStyle: true
            }
            Components.SystemActions {
                Layout.fillWidth: true
                Layout.fillHeight: true
                tileStyle: true
            }
        }

        // ── Two solitary pills: Wi-Fi + Bluetooth ───────────────
        GridLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.bookosSolitaryHeight
            Layout.maximumHeight: Layout.preferredHeight
            rows: 1
            columns: 2
            columnSpacing: 10

            Components.NetworkBtn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                isLongButton: true
                tileStyle: true
                bookosColors: true
            }
            Components.BluetoothBtn {
                Layout.fillWidth: true
                Layout.fillHeight: true
                isLongButton: true
                tileStyle: true
                bookosColors: true
            }
        }

        // ── 2×3 circular quick-toggles card ─────────────────────
        BookOS.ToggleGrid {
            Layout.fillWidth: true
            Layout.preferredHeight: root.bookosCardHeight
            Layout.maximumHeight: Layout.preferredHeight
        }

        // ── Slider card: brightness + volume with side toggles ──
        Lib.Card {
            id: sliderCard
            tileStyle: true
            Layout.fillWidth: true
            Layout.preferredHeight: root.bookosCardHeight
            Layout.maximumHeight: Layout.preferredHeight

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Components.BrightnessSlider {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    flat: true
                    bookosStyle: true
                }
                Components.Volume {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    flat: true
                    bookosStyle: true
                }
            }
        }

        // ── Media player card ───────────────────────────────────
        Components.MediaPlayer {
            Layout.fillWidth: true
            Layout.preferredHeight: 160 * root.scale
            Layout.maximumHeight: Layout.preferredHeight
        }
    }
}
