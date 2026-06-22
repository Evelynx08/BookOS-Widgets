import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.networkmanagement as PlasmaNM

import "../../../lib" as Lib
import "../../../components" as Components

// BookOS card holding a 2×3 grid of circular quick-toggles.
// Tile background DFDFDF @80%, radius 27.
Lib.Card {
    id: grid
    tileStyle: true

    Layout.fillWidth: true

    // ── Backends ──────────────────────────────────────────────
    Plasma5Support.DataSource {
        id: exe
        engine: "executable"
        connectedSources: []
        onNewData: {
            if (sourceName.indexOf("charge_control_end_threshold") !== -1) {
                var v = parseInt((data.stdout || "").trim());
                if (!isNaN(v)) grid.batteryLimitOn = (v <= 85);
            }
            disconnectSource(sourceName);
        }
        function run(cmd) { connectSource(cmd); }
    }

    Components.Network { id: network }

    property bool batteryLimitOn: false
    property bool keepScreenOn: false
    property bool eyeProtectOn: false

    readonly property bool airplaneOn: PlasmaNM.Configuration.airplaneModeEnabled

    // Read current battery charge limit once.
    Component.onCompleted: {
        exe.run("sh -c 'cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -n1'");
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: root.mediumSpacing
        rows: 2
        columns: 3
        rowSpacing: root.smallSpacing
        columnSpacing: root.mediumSpacing

        // 1 ── Nearby share (KDE Connect)
        BookToggle {
            active: false
            label: i18n("Nearby Share")
            source: Qt.resolvedUrl("../../../icons/bookos/nearby-share.svg")
            onClicked: exe.run("kdeconnect-app")
        }

        // 2 ── Airplane mode
        BookToggle {
            active: grid.airplaneOn
            label: i18n("Airplane Mode")
            source: Qt.resolvedUrl("../../../icons/bookos/airplane.svg")
            onClicked: {
                network.handler.enableAirplaneMode(!grid.airplaneOn);
                PlasmaNM.Configuration.airplaneModeEnabled = !grid.airplaneOn;
            }
        }

        // 3 ── Eye protector (Night Light)
        BookToggle {
            active: grid.eyeProtectOn
            label: i18n("Eye Comfort Shield")
            source: Qt.resolvedUrl("../../../icons/bookos/eye-comfort.svg")
            onClicked: {
                grid.eyeProtectOn = !grid.eyeProtectOn;
                exe.run("qdbus org.kde.KWin /org/kde/KWin/NightLight org.kde.KWin.NightLight."
                        + (grid.eyeProtectOn ? "inhibit" : "uninhibit"));
            }
        }

        // 4 ── Battery protection (stop charging ~80%)
        BookToggle {
            active: grid.batteryLimitOn
            label: i18n("Protect Battery")
            source: Qt.resolvedUrl("../../../icons/bookos/battery-protect.svg")
            onClicked: {
                grid.batteryLimitOn = !grid.batteryLimitOn;
                var v = grid.batteryLimitOn ? 80 : 100;
                exe.run("sh -c 'for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; "
                        + "do echo " + v + " | pkexec tee \"$f\"; done'");
            }
        }

        // 5 ── Keep screen on
        BookToggle {
            active: grid.keepScreenOn
            label: i18n("Keep Screen On")
            source: Qt.resolvedUrl("../../../icons/bookos/keep-screen-on.svg")
            onClicked: {
                grid.keepScreenOn = !grid.keepScreenOn;
                // Best-effort: suspend/resume the screen-energy saver via KDE PowerDevil
                exe.run("qdbus org.freedesktop.ScreenSaver /ScreenSaver "
                        + (grid.keepScreenOn ? "Inhibit BookOS keep-on" : "UnInhibit 0"));
            }
        }

        // 6 ── Screenshot
        BookToggle {
            active: false
            label: i18n("Screenshot")
            source: Qt.resolvedUrl("../../../icons/bookos/screenshot.svg")
            onClicked: exe.run(root.screenshotCommand || "spectacle")
        }
    }
}
