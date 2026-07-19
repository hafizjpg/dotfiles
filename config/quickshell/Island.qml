import Quickshell
import Quickshell.Services.Mpris
import QtQuick

PanelWindow {
    aboveWindows: true
    focusable: false
    mask: Region { item: island }
    anchors {
        top: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0
    implicitHeight: 220

    property var mpdPlayer: {
        for (const p of Mpris.players.values) {
            if (p.identity && p.identity.toLowerCase().includes("mpd"))
                return p;
        }
        return Mpris.players.values.length > 0 ? Mpris.players.values[0] : null;
    }
    property bool hasTrack: mpdPlayer !== null && mpdPlayer.trackTitle !== ""
    property bool isPlaying: mpdPlayer !== null && mpdPlayer.isPlaying
    property string clockText: Qt.formatTime(new Date(), "HH:mm")

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: clockText = Qt.formatTime(new Date(), "HH:mm")
    }

    Rectangle {
        id: island

        property bool expanded: false

        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 12
        }

        width: expanded ? 340 : 110
        height: expanded ? 176 : 40
        radius: expanded ? 24 : 20
        color: "#cc1c1d1f"
        border.color: expanded ? "#8C6E50EB" : "#3AFFFFFF"
        border.width: 1
        clip: true

        Behavior on width {
            NumberAnimation { duration: 380; easing.type: Easing.OutExpo }
        }
        Behavior on height {
            NumberAnimation { duration: 380; easing.type: Easing.OutExpo }
        }
        Behavior on radius {
            NumberAnimation { duration: 380; easing.type: Easing.OutExpo }
        }
        Behavior on border.color {
            ColorAnimation { duration: 250 }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: island.expanded = true
            onExited: island.expanded = false
        }

        Item {
            anchors.fill: parent
            opacity: island.expanded ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    visible: isPlaying
                    width: 6
                    height: 6
                    radius: 3
                    color: "#6E50EB"
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: isPlaying
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 700 }
                        NumberAnimation { to: 1.0; duration: 700 }
                    }
                }

                Text {
                    color: "#F7EAF3"
                    text: clockText
                    font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                    font.weight: Font.DemiBold
                }
            }
        }

        Column {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 10
            opacity: island.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

            Row {
                width: parent.width
                Text {
                    text: clockText
                    color: "#F7EAF3"
                    font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                    font.weight: Font.DemiBold
                }
                Item { width: parent.width - 120; height: 1 }
                Text {
                    text: mpdPlayer === null ? "no player" : (isPlaying ? "playing" : "paused")
                    color: "#9E8CF0"
                    font.pixelSize: 11
                    font.family: "JetBrainsMono Nerd Font"
                }
            }

            Row {
                width: parent.width
                spacing: 12

                Rectangle {
                    width: 56
                    height: 56
                    radius: 14
                    color: "#33FFFFFF"
                    border.color: "#406E50EB"
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: (mpdPlayer !== null && mpdPlayer.trackArtUrl) ? mpdPlayer.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: source !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: mpdPlayer === null || !mpdPlayer.trackArtUrl
                        text: "♪"
                        color: "#6E50EB"
                        font.pixelSize: 22
                    }
                }

                Column {
                    width: parent.width - 68
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        text: hasTrack ? mpdPlayer.trackTitle : "Nothing playing"
                        color: "#F7EAF3"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.family: "JetBrainsMono Nerd Font"
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: hasTrack ? (mpdPlayer.trackArtist || "Unknown Artist") : "mpd"
                        color: "#B8AEE0"
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: "#26FFFFFF"

                Rectangle {
                    height: parent.height
                    radius: 2
                    color: "#6E50EB"
                    width: {
                        if (mpdPlayer === null || !mpdPlayer.lengthSupported || mpdPlayer.length <= 0)
                            return 0;
                        return parent.width * (mpdPlayer.position / mpdPlayer.length);
                    }

                    Behavior on width { NumberAnimation { duration: 300 } }
                }

                Timer {
                    interval: 1000
                    repeat: true
                    running: island.expanded && isPlaying
                    onTriggered: if (mpdPlayer !== null) mpdPlayer.positionChanged()
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28

                Text {
                    text: "\u23EE"
                    color: "#F7EAF3"
                    font.pixelSize: 18
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: if (mpdPlayer !== null && mpdPlayer.canGoPrevious) mpdPlayer.previous()
                    }
                }

                Text {
                    text: isPlaying ? "\u23F8" : "\u25B6"
                    color: "#6E50EB"
                    font.pixelSize: 20
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: if (mpdPlayer !== null && mpdPlayer.canTogglePlaying) mpdPlayer.togglePlaying()
                    }
                }

                Text {
                    text: "\u23ED"
                    color: "#F7EAF3"
                    font.pixelSize: 18
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: if (mpdPlayer !== null && mpdPlayer.canGoNext) mpdPlayer.next()
                    }
                }
            }
        }
    }

}
