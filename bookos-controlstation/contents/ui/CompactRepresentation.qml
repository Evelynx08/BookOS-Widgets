import QtQml 2.15
import QtQuick 2.15
import QtQuick.Layouts 1.15
import Qt5Compat.GraphicalEffects

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
Item {
    id: compactRep

    readonly property bool useCustomButtonImage: (Plasmoid.configuration.useCustomButtonImage && Plasmoid.configuration.customButtonImage.length != 0)

    // The panel's own color scheme often stays dark regardless of the global
    // theme, so Kirigami.Theme.textColor is useless here. Read the global
    // scheme from kdeglobals instead: light scheme → dark icon, dark → light.
    property bool globalDark: true
    Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: ["kreadconfig6 --file kdeglobals --group General --key ColorScheme"]
        interval: 10000
        onNewData: (src, data) => {
            var s = (data["stdout"] || "").trim()
            if (s !== "") compactRep.globalDark = /dark/i.test(s)
        }
    }

    RowLayout {
        anchors.fill: parent
        
        Kirigami.Icon {
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: useCustomButtonImage ? Plasmoid.configuration.customButtonImage : Plasmoid.configuration.icon
            smooth: true
            isMask: true
            color: compactRep.globalDark ? "#FFFFFF" : "#1a1a1a"
            layer.enabled: true
            layer.effect: ColorOverlay { color: compactRep.globalDark ? "#FFFFFF" : "#1a1a1a" }
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.expanded = !root.expanded
                }
            }
        }
    }
}
