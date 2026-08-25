import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Io
import QtQuick
import "." as Local

PanelWindow {
    id: bar

    screen: Quickshell.screens[0]
    aboveWindows: true
    focusable: false
    exclusiveZone: 56
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 56

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
    readonly property color accent: "#6E50EB"
    readonly property color accentBright: "#A08CF0"
    readonly property color ink: "#F7EAF3"
    readonly property color inkDim: "#8a839c"
    readonly property color surface: "#f2121216"

    component Divider: Rectangle {
        width: 1
        height: 18
        color: "#20FFFFFF"
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    component IconButton: Rectangle {
        property bool hovered: false
        property bool activeState: false
        width: 26
        height: 26
        radius: 8
        color: activeState ? bar.accent : (hovered ? "#1EFFFFFF" : "transparent")
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: notch
            width: contentRow.implicitWidth + 36
            height: 44
            radius: 18
            color: bar.surface
            border.width: 1
            border.color: "#22FFFFFF"

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: 0
            }

            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: parent.radius
                color: bar.surface
            }

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                height: 1
                radius: 1
                color: "#26FFFFFF"
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 12

                // -- workspaces -------------------------------------------------
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: Hyprland.workspaces

                        Rectangle {
                            id: wsItem
                            required property var modelData
                            property bool active: modelData.active
                            width: active ? 22 : 18
                            height: active ? 22 : 18
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: active ? bar.accent : (wsHover.containsMouse ? "#1EFFFFFF" : "transparent")

                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: wsItem.modelData.id
                                color: wsItem.active ? bar.ink : bar.inkDim
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.family: "JetBrainsMono Nerd Font"
                            }

                            MouseArea {
                                id: wsHover
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: wsItem.modelData.activate()
                            }
                        }
                    }
                }

                Divider {}

                // -- launcher -----------------------------------------------------
                IconButton {
                    width: 30
                    height: 30
                    hovered: launcherHover.containsMouse

                    Text {
                        anchors.centerIn: parent
                        text: "\u25C6"
                        color: bar.ink
                        font.pixelSize: 15
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
                        command: ["bash", "-c", "~/.config/rofi/launchers/type-1/launcher.sh"]
                    }

                    Process {
                        id: powermenuProc
                        command: ["bash", "-c", "~/.config/rofi/powermenu/type-1/powermenu.sh"]
                    }
                }

                Divider {}

                // -- volume ---------------------------------------------------
                Rectangle {
                    width: volRow.implicitWidth + 16
                    height: 26
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: volumeHover.containsMouse ? "#1EFFFFFF" : "transparent"

                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Row {
                        id: volRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: bar.volumeIcon()
                            color: bar.muted ? bar.inkDim : bar.ink
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: bar.muted ? "muted" : bar.volume + "%"
                            color: bar.ink
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

                Divider { visible: SystemTray.items.values.length > 0 }

                // -- tray: left-click activates, right-click shows its menu ----
                Row {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: SystemTray.items

                        IconButton {
                            id: trayBtn
                            required property var modelData
                            hovered: trayHover.containsMouse

                            Image {
                                source: trayBtn.modelData.icon
                                width: 14
                                height: 14
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                id: trayHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton && trayBtn.modelData.hasMenu)
                                        trayBtn.modelData.display(bar, mouse.x, mouse.y);
                                    else
                                        trayBtn.modelData.activate();
                                }
                            }
                        }
                    }
                }

                Divider {}

                // -- dashboard toggle: only way to open Dashboard.qml now -------
                IconButton {
                    hovered: dashHover.containsMouse
                    activeState: Local.Shared.dashboardOpen

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0f3"
                        color: bar.ink
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: dashHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Local.Shared.toggleDashboard()
                    }
                }
            }
        }
    }
}
