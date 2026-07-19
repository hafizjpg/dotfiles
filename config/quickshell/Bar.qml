import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Io
import QtQuick

PanelWindow {
    id: bar

    property string terminal: "kitty"

    screen: Quickshell.screens[0]
    aboveWindows: true
    focusable: false
    exclusiveZone: 64
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 64

    property int volume: 0
    property bool muted: false

    function volumeIcon() {
        if (muted || volume === 0) return "\uf026";
        if (volume < 50) return "\uf027";            
        return "\uf028";                           
    }

    Process {
        id: volGetProc
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | head -1; pactl get-sink-mute @DEFAULT_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const volMatch = data.match(/(\d+)%/);
                if (volMatch) bar.volume = parseInt(volMatch[1]);
                if (data.includes("Mute:")) bar.muted = data.includes("yes");
            }
        }
    }

    Process {
        id: volSetProc
        command: ["true"]
    }

    function refreshVolume() {
        volGetProc.running = true;
    }

    function changeVolume(deltaPercent) {
        const sign = deltaPercent >= 0 ? "+" : "-";
        volSetProc.command = ["bash", "-c", "pactl set-sink-volume @DEFAULT_SINK@ " + sign + Math.abs(deltaPercent) + "%"];
        volSetProc.running = true;
        refreshTimer.restart();
    }

    function toggleMute() {
        volSetProc.command = ["bash", "-c", "pactl set-sink-mute @DEFAULT_SINK@ toggle"];
        volSetProc.running = true;
        refreshTimer.restart();
    }

    Timer {
        id: refreshTimer
        interval: 120
        onTriggered: bar.refreshVolume()
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: bar.refreshVolume()
    }

    Component.onCompleted: refreshVolume()
    // ---------------------------------------------------------------

    component Glow: Item {
        property alias color: g3.color
        property real intensity: 1.0
        anchors.fill: parent
        anchors.margins: -10
        Rectangle { id: g3; anchors.fill: parent; anchors.margins: 0; radius: height / 2; opacity: 0.05 * intensity; color: "#6E50EB" }
        Rectangle { anchors.fill: parent; anchors.margins: 4; radius: height / 2; opacity: 0.08 * intensity; color: "#6E50EB" }
        Rectangle { anchors.fill: parent; anchors.margins: 8; radius: height / 2; opacity: 0.10 * intensity; color: "#6E50EB" }
    }

    component GlassPill: Rectangle {
        radius: height / 2
        color: "#cc1c1d1f"
        border.color: "#3AFFFFFF"
        border.width: 1

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 1
            }
            height: parent.height * 0.45
            radius: parent.radius - 1
            color: "transparent"
            border.width: 0
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "#14FFFFFF"
            }
        }
    }

    Item {
        anchors.fill: parent

        GlassPill {
            id: wsPill
            height: 40
            width: wsRow.implicitWidth + 24
            anchors {
                left: parent.left
                leftMargin: 16
                bottom: parent.bottom
                bottomMargin: 12
            }

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: Hyprland.workspaces

                    Item {
                        required property var modelData
                        width: 30
                        height: 30

                        Glow {
                            visible: modelData.active
                            intensity: 1.0
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 15
                            color: modelData.active ? "#6E50EB" : "#22FFFFFF"
                            border.color: modelData.active ? "#A08CF0" : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.id
                                color: modelData.active ? "#F7EAF3" : "#948BA8"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.activate()
                        }

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }

        GlassPill {
            id: launcherPill
            width: 52
            height: 48
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 12
            }
            color: launcherHover.containsMouse ? "#cc2f2040" : "#cc1c1d1f"
            border.color: launcherHover.containsMouse ? "#8C6E50EB" : "#3AFFFFFF"

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }

            Text {
                anchors.centerIn: parent
                text: "\u25C6"
                color: '#eaedf7'
                font.pixelSize: 20
            }

            MouseArea {
                id: launcherHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        powermenuProc.running = true;
                    else
                        launcherProc.running = true;
                }
            }

            Process {
                id: launcherProc
                command: ["bash", "-c", "~/.config/rofi/launchers/type-2/launcher.sh"]
            }

            Process {
                id: powermenuProc
                command: ["bash", "-c", "~/.config/rofi/powermenu/type-1/powermenu.sh"]
            }
        }

        GlassPill {
            height: 40
            width: rightRow.implicitWidth + 24
            anchors {
                right: parent.right
                rightMargin: 16
                bottom: parent.bottom
                bottomMargin: 12
            }

            Row {
                id: rightRow
                anchors.centerIn: parent
                spacing: 14

                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: volText.implicitWidth + 34
                        height: 26
                        radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: volumeHover.containsMouse ? "#332F2040" : "transparent"

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: bar.volumeIcon()
                                color: "#F7EAF3"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: volText
                                text: bar.muted ? "muted" : bar.volume + "%"
                                color: "#F7EAF3"
                                font.pixelSize: 11
                                font.family: "JetBrainsMono Nerd Font"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: volumeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            onClicked: bar.toggleMute()
                            onWheel: wheel => {
                                bar.changeVolume(wheel.angleDelta.y > 0 ? 5 : -5);
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 16
                    color: "#30FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                    model: SystemTray.items

                    Image {
                        required property var modelData
                        source: modelData.icon
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton && modelData.hasMenu)
                                    modelData.display(bar, mouse.x, mouse.y);
                                else
                                    modelData.activate();
                            }
                        }
                    }
                }

                Rectangle {
                    visible: SystemTray.items.values.length > 0
                    width: 1
                    height: 16
                    color: "#30FFFFFF"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: notifHover.containsMouse ? "#6E50EB" : "#22FFFFFF"

                    Behavior on color { ColorAnimation { duration: 180 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0f3"
                        color: "#F7EAF3"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: notifHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: swayncToggleProc.running = true
                    }

                    Process {
                        id: swayncToggleProc
                        command: ["bash", "-c", "swaync-client -t -sw"]
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: wallpaperHover.containsMouse ? "#6E50EB" : "#22FFFFFF"

                    Behavior on color { ColorAnimation { duration: 180 } }

                    Text {
                        anchors.centerIn: parent
                        text: "\u25A3"
                        color: "#F7EAF3"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: wallpaperHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: waltProc.running = true
                    }

                    Process {
                        id: waltProc
                        command: ["bash", "-c", bar.terminal + " -e waypaper"]
                    }
                }
            }
        }
    }
}
