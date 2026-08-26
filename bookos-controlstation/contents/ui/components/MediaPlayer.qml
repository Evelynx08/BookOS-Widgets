import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import Qt5Compat.GraphicalEffects

import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume as Vol

import "../lib" as Lib

// BookOS media card: blurred album-art background + readable scrim.
// Shows app/device line, title, artist, seek bar, times and transport controls.
Lib.Card {
    id: mediaPlayer
    visible: root.showMediaPlayer
    property bool isLongButton: true
    cornerRadius: root.bookosRadius
    flat: true            // no elevation; the art is the surface
    filled: false         // we draw our own background
    noMargins: true       // let the art bleed to the rounded edge

    Layout.fillWidth: true
    Layout.fillHeight: true

    readonly property bool hasMedia: mediaPlayerPage.track
        || (mediaPlayerPage.playbackStatus > Mpris.PlaybackStatus.Stopped)

    // Show a way to switch player right on the compact card when more than
    // one real MPRIS source is active (mpris2Model also carries a
    // "multiplexer" aggregate row, hence the +2 threshold — mirrors the
    // TabBar visibility rule in MediaPlayerPage.qml).
    readonly property int playerCount: mediaPlayerPage.mpris2Model.count
    readonly property bool hasMultiplePlayers: playerCount > 2
    function cyclePlayer(delta) {
        if (playerCount <= 0) return;
        var next = (mediaPlayerPage.mpris2Model.currentIndex + delta + playerCount) % playerCount;
        mediaPlayerPage.mpris2Model.currentIndex = next;
    }

    // Audio output device for the "playing on …" line.
    readonly property var sink: Vol.PreferredDevice.sink
    readonly property string deviceName: sink && sink.description ? sink.description : i18n("Internal Speakers")

    function fmt(us) {
        if (!us || us < 0) return "0:00";
        var s = Math.floor(us / 1000000);
        var m = Math.floor(s / 60);
        var sec = s % 60;
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    property int curPos: 0
    Timer {
        interval: 1000; repeat: true
        running: mediaPlayer.visible && mediaPlayerPage.isPlaying
        onTriggered: mediaPlayer.curPos = mediaPlayerPage.position()
    }
    Connections {
        target: mediaPlayerPage
        function onTrackChanged() { mediaPlayer.curPos = mediaPlayerPage.position(); }
    }

    // ── Rounded, clipped surface (blurred art + scrim) ──────────
    Item {
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: mediaPlayer.width
                height: mediaPlayer.height
                radius: mediaPlayer.cornerRadius
            }
        }

        // Fallback solid tile when there is no art
        Rectangle {
            anchors.fill: parent
            color: root.bookosTile
        }

        Image {
            id: artSource
            anchors.fill: parent
            source: mediaPlayerPage.albumArt
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
        }
        FastBlur {
            anchors.fill: parent
            source: artSource
            radius: 64
            visible: mediaPlayerPage.albumArt !== ""
        }
        // Legibility scrim
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: mediaPlayerPage.albumArt !== "" ? 0.45 : 0
        }
    }

    // ── Foreground content ──────────────────────────────────────
    readonly property color fg: mediaPlayerPage.albumArt !== "" ? "#FFFFFF" : Kirigami.Theme.textColor

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.largeSpacing
        spacing: root.smallSpacing

        // App + device line
        RowLayout {
            Layout.fillWidth: true
            spacing: root.smallSpacing
            Kirigami.Icon {
                source: mediaPlayerPage.playerIcon || "audio-x-generic"
                Layout.preferredHeight: root.mediumFontSize * 1.5
                Layout.preferredWidth: Layout.preferredHeight
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: mediaPlayer.hasMedia
                    ? (mediaPlayerPage.identity || i18n("Media")) + " · " + mediaPlayer.deviceName
                    : i18n("Nothing playing")
                color: mediaPlayer.fg
                opacity: 0.9
                font.pixelSize: root.smallFontSize
                elide: Text.ElideRight
            }

            // Quick switch between active players, without opening the full page.
            RowLayout {
                visible: mediaPlayer.hasMultiplePlayers
                spacing: 2
                PlasmaComponents.ToolButton {
                    icon.name: "arrow-left"
                    icon.color: mediaPlayer.fg
                    implicitWidth: root.mediumFontSize * 1.6
                    implicitHeight: implicitWidth
                    onClicked: mediaPlayer.cyclePlayer(-1)
                }
                Row {
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: mediaPlayer.playerCount
                        delegate: Rectangle {
                            required property int index
                            readonly property bool active: index === mediaPlayerPage.mpris2Model.currentIndex
                            width: active ? 12 : 6
                            height: 6
                            radius: 3
                            color: mediaPlayer.fg
                            opacity: active ? 0.95 : 0.4
                            Behavior on width { NumberAnimation { duration: 150 } }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: mediaPlayerPage.mpris2Model.currentIndex = index
                            }
                        }
                    }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "arrow-right"
                    icon.color: mediaPlayer.fg
                    implicitWidth: root.mediumFontSize * 1.6
                    implicitHeight: implicitWidth
                    onClicked: mediaPlayer.cyclePlayer(1)
                }
            }
        }

        // Title
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: mediaPlayerPage.track || i18n("Song name")
            color: mediaPlayer.fg
            font.pixelSize: root.largeFontSize
            font.weight: Font.Bold
            elide: Text.ElideRight
        }
        // Artist
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: mediaPlayerPage.artist || i18n("Artist name")
            color: mediaPlayer.fg
            opacity: 0.85
            font.pixelSize: root.mediumFontSize
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true }

        // Seek bar
        QQC2.Slider {
            id: seek
            Layout.fillWidth: true
            from: 0
            to: Math.max(1, mediaPlayerPage.length)
            value: mediaPlayer.curPos
            enabled: mediaPlayerPage.canSeek
            onMoved: mediaPlayerPage.setPosition(value)

            background: Rectangle {
                x: seek.leftPadding
                y: seek.topPadding + seek.availableHeight / 2 - height / 2
                width: seek.availableWidth
                height: 4
                radius: 2
                color: Qt.rgba(mediaPlayer.fg.r, mediaPlayer.fg.g, mediaPlayer.fg.b, 0.3)
                Rectangle {
                    width: seek.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: mediaPlayer.fg
                }
            }
            handle: Rectangle {
                x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                y: seek.topPadding + seek.availableHeight / 2 - height / 2
                width: 14; height: 14; radius: 7
                color: mediaPlayer.fg
            }
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: mediaPlayer.fmt(mediaPlayer.curPos)
                color: mediaPlayer.fg; opacity: 0.85
                font.pixelSize: root.smallFontSize
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: mediaPlayer.fmt(mediaPlayerPage.length)
                color: mediaPlayer.fg; opacity: 0.85
                font.pixelSize: root.smallFontSize
            }
        }

        // Transport controls (centered)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.largeSpacing

            PlasmaComponents.ToolButton {
                icon.name: "media-skip-backward"
                icon.color: mediaPlayer.fg
                enabled: mediaPlayerPage.canGoPrevious
                onClicked: mediaPlayerPage.previous()
            }
            PlasmaComponents.ToolButton {
                icon.name: mediaPlayerPage.isPlaying ? "media-playback-pause" : "media-playback-start"
                icon.color: mediaPlayer.fg
                enabled: mediaPlayerPage.isPlaying ? mediaPlayerPage.canPause : mediaPlayerPage.canPlay
                onClicked: mediaPlayerPage.togglePlaying()
            }
            PlasmaComponents.ToolButton {
                icon.name: "media-skip-forward"
                icon.color: mediaPlayer.fg
                enabled: mediaPlayerPage.canGoNext
                onClicked: mediaPlayerPage.next()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1   // sit behind interactive controls
        onClicked: fullRep.togglePage(fullRep.defaultInitialWidth, fullRep.defaultInitialHeight, mediaPlayerPage)
    }
}
