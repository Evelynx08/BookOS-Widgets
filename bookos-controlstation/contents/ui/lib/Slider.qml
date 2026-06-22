import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami 

Card {
    id: sliderComp
    signal moved
    signal actionButtonClicked

    // BookOS: let the pill fill the wrapper exactly so the parent card controls spacing.
    noMargins: bookosStyle

    property bool pressed: false
    property alias title: title.text
    property alias secondaryTitle: secondaryTitle.text
    property var value: 0
    property bool useIconButton: false
    property string source

    property bool canTogglePage: false

    property bool showTitle: true
    property bool thinSlider: false
    property bool mediumSizeSlider: false

    // BookOS (One UI) fat pill: no title, no left icon, thick blue fill, white handle,
    // plus a circular blue side-button (dark/light, DnD, …).
    property bool bookosStyle: false
    property bool bookosShowLeftIcon: false
    // Right side circular toggle
    property bool showRightButton: false
    property string rightButtonSource: ""
    property bool rightButtonActive: false
    property bool rightButtonCustomIcon: false
    signal rightButtonClicked

    property int from: 0
    property int to: 100
    property real stepSize: 2

    property color highlightColor: root.useSystemColorsOnSliders ? root.themeHighlightColor : root.slidersColor

    // Helps to play volume feedback while moving with cursor
    Binding {
        sliderComp.pressed: sliderLoader.item ? sliderLoader.item.pressed : false
        when: !sliderComp.bookosStyle
    }

    // Binds slider value whent it's changed by keyboard
    Binding { 
        target: sliderLoader.item
        property: "value"
        value: sliderComp.value
        restoreMode: Binding.RestoreBindingOrValue
    }

    Connections {
        target: sliderLoader.item
        function onMoved() {
            sliderComp.value = sliderLoader.item.value;
            sliderComp.moved();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: bookosStyle ? 0 : root.largeSpacing
        clip: !bookosStyle
        spacing: 1

        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 1
            visible: showTitle

            PlasmaComponents.Label {
                id: title
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft
                font.pixelSize: root.largeFontSize
                font.weight: Font.Bold
                font.capitalization: Font.Capitalize
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                id: secondaryTitle
                visible: root.showPercentage
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                font.pixelSize: root.largeFontSize
                font.weight: Font.Bold
                font.capitalization: Font.Capitalize
                horizontalAlignment: Text.AlignRight
            }


        }
        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 0

            Kirigami.Icon {
                id: icon
                source: sliderComp.source
                visible: !sliderComp.useIconButton && (!bookosStyle || bookosShowLeftIcon)
                Layout.preferredHeight: root.largeFontSize*2
                Layout.preferredWidth: Layout.preferredHeight
                Layout.margins: 0
            }

            PlasmaComponents.ToolButton {
                id: iconButton
                visible: sliderComp.useIconButton && (!bookosStyle || bookosShowLeftIcon)
                icon.name: sliderComp.source
                Layout.preferredHeight: root.largeFontSize*2
                Layout.preferredWidth: Layout.preferredHeight
                onClicked: sliderComp.actionButtonClicked()
            }

            // ── BookOS fat pill (custom, One UI style) ──────────
            Item {
                id: bookosPill
                visible: bookosStyle
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real frac: (sliderComp.value - sliderComp.from)
                                             / Math.max(1, (sliderComp.to - sliderComp.from))

                Rectangle {
                    id: pillTrough
                    anchors.fill: parent
                    radius: height / 2
                    color: root.bookosTrough
                    clip: true

                    Rectangle {
                        id: pillFill
                        height: parent.height
                        // Empty at the minimum, fills proportionally. Rounded both ends
                        // (left cap is clipped round by the trough).
                        width: bookosPill.frac <= 0 ? 0 : Math.max(height, bookosPill.frac * parent.width)
                        radius: height / 2
                        color: root.bookosActive
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    function setFromX(mx) {
                        var f = Math.min(1, Math.max(0, mx / width));
                        var v = sliderComp.from + f * (sliderComp.to - sliderComp.from);
                        if (sliderComp.stepSize > 0)
                            v = Math.round(v / sliderComp.stepSize) * sliderComp.stepSize;
                        sliderComp.value = v;
                        sliderComp.moved();
                    }
                    onPressed: { sliderComp.pressed = true; setFromX(mouse.x); }
                    onPositionChanged: if (pressed) setFromX(mouse.x)
                    onReleased: sliderComp.pressed = false
                    onCanceled: sliderComp.pressed = false
                }
            }

            Loader {
                id: sliderLoader
                visible: !bookosStyle
                sourceComponent: root.usePlasmaSliders ? plasmaSlider : customSlider
                Layout.fillWidth: !bookosStyle
                Layout.preferredWidth: bookosStyle ? 0 : -1
                Layout.margins: 0

                onLoaded: { sliderLoader.item.value = sliderComp.value; }
            }

            Component {
                id: customSlider

                Slider {
                    id: slider
                    Layout.fillWidth: true
                    Layout.margins: 0
                    from: sliderComp.from
                    to: sliderComp.to
                    stepSize: sliderComp.stepSize
                    snapMode: Slider.SnapAlways

                    background: Rectangle {
                        x: slider.leftPadding
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: bookosStyle ? 38 : thinSlider ? 7 : mediumSizeSlider ? 11 : 22
                        width: slider.availableWidth
                        height: bookosStyle ? 38 : parent.height
                        radius: height / 2
                        color: bookosStyle ? root.bookosTrough : root.disabledBgColor
                        border.color: bookosStyle ? "transparent" : root.isDarkTheme ? root.disabledBgColor : Qt.rgba(0, 0, 0, 0.27)

                        Rectangle {
                            id: levelIndicator
                            width: bookosStyle
                                   ? Math.max(parent.height, (value - from) / (to - from) * parent.width)
                                   : (value - from) / (to - from) * (slider.width - handle.width) + (handle.width)
                            height: parent.height - (bookosStyle ? 0 : 2)
                            color: bookosStyle ? root.bookosActive : highlightColor
                            radius: height / 2
                            border.width: 0
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    handle: Rectangle {
                        id: handle
                        visible: !bookosStyle
                        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                        y: slider.topPadding + slider.availableHeight / 2 - height / 2
                        implicitWidth: thinSlider ? 17 :
                                        (mediumSizeSlider&&(slider.hovered || slider.pressed)) ? levelIndicator.height*3.7 :
                                        levelIndicator.height
                        implicitHeight: thinSlider ? 17 :
                                        (mediumSizeSlider&&(slider.hovered || slider.pressed)) ? levelIndicator.height*2.5 :
                                        levelIndicator.height
                        radius: mediumSizeSlider ? 10 : height / 2
                        color: mediumSizeSlider && slider.pressed ? "transparent" : slider.pressed ? "#f0f0f0" : "#f6f6f6"
                        border.color: "#bdbebf"
                        Behavior on implicitWidth {
                            NumberAnimation { duration: 200 }
                        }
                    }

                    WheelHandler {
                        orientation: Qt.Vertical | Qt.Horizontal
                        property int wheelDelta: 0
                        acceptedButtons: Qt.NoButton
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: wheel => {
                            const lastValue = slider.value
                            // We want a positive delta to increase the slider for up/right scrolling,
                            // independently of the scrolling inversion setting
                            // The x-axis is also inverted (scrolling right produce negative values)
                            const delta = (wheel.angleDelta.y || -wheel.angleDelta.x) * (wheel.inverted ? -1 : 1)
                            wheelDelta += delta;
                            // magic number 120 for common "one click"
                            // See: https://doc.qt.io/qt-6/qml-qtquick-wheelevent.html#angleDelta-prop
                            while (wheelDelta >= 120) {
                                wheelDelta -= 120;
                                slider.increase();
                            }
                            while (wheelDelta <= -120) {
                                wheelDelta += 120;
                                slider.decrease();
                            }
                            if (lastValue !== slider.value) {
                                slider.moved();
                            }
                        }     
                    }
                }

            }

            Component {
                id: plasmaSlider

                PlasmaComponents.Slider {
                    id: slider
                    Layout.fillWidth: true
                    Layout.margins: 0
                    from: sliderComp.from
                    to: sliderComp.to
                    stepSize: sliderComp.stepSize
                    snapMode: Slider.SnapAlways
                }
            }
            
            PlasmaComponents.ToolButton {
                id: openVolumePageButton
                visible: sliderComp.canTogglePage && !bookosStyle
                icon.name: "arrow-right"
                Layout.preferredHeight: root.largeFontSize*2
                Layout.preferredWidth: Layout.preferredHeight
                onClicked: sliderComp.clicked()
            }

            // BookOS circular side toggle (dark/light, Do-Not-Disturb, …)
            Item {
                visible: bookosStyle && showRightButton
                Layout.leftMargin: root.smallSpacing
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: sliderComp.rightButtonActive ? root.bookosActive : root.bookosInactive

                    Kirigami.Icon {
                        anchors.fill: parent
                        anchors.margins: 9
                        source: sliderComp.rightButtonSource
                        isMask: true
                        color: "#FFFFFF"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sliderComp.rightButtonClicked()
                }
            }
        }
    }
}
