import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Io
import QtQuick
import "." as Local

WallpaperPicker {
    id: pickerWindow
}

PanelWindow {
    id: bar

    screen: Quickshell.screens[0]
    aboveWindows: true
    focusable: false
    exclusiveZone: 52
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    // Dynamic height allowing popup expansion without clipping
    implicitHeight: bar.dashboardOpen ? 260 : 52

    property int volume: 0
    property bool muted: false
    property bool dashboardOpen: false

    property string userName: "User"
    property string sysUptime: "0 mins"
    property string weatherText: "Loading..."
    property string ramUsage: "0MB / 0MB"

    function volumeIcon() {
        if (muted || volume === 0) return "\uf026";
        if (volume < 50) return "\uf027";
        return "\uf028";
    }

    Process {
        id: volGetProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const isMuted = data.includes("[MUTED]");
                const match = data.match(/Volume:\s+([\d.]+)/);
                if (match) {
                    bar.volume = Math.round(parseFloat(match[1]) * 100);
                }
                bar.muted = isMuted;
            }
        }
    }

    Process {
        id: volSetProc
        command: ["true"]
    }

    function refreshVolume() {
        if (!volGetProc.running) {
            volGetProc.running = true;
        }
    }

    function changeVolume(deltaPercent) {
        const val = deltaPercent > 0 ? "5%+" : "5%-";
        volSetProc.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", val];
        volSetProc.running = true;
        refreshTimer.restart();
    }

    function toggleMute() {
        volSetProc.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"];
        volSetProc.running = true;
        refreshTimer.restart();
    }

    Process {
        id: userInfoProc
        command: ["whoami"]
        stdout: SplitParser {
            onRead: data => bar.userName = data.trim()
        }
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: SplitParser {
            onRead: data => bar.sysUptime = data.replace("up ", "").trim()
        }
    }

    Process {
        id: ramProc
        command: ["bash", "-c", "free -m | awk '/Mem:/ {print $3\"MB / \"$2\"MB\"}'"]
        stdout: SplitParser {
            onRead: data => bar.ramUsage = data.trim()
        }
    }

    Process {
        id: weatherProc
        command: ["curl", "-s", "--max-time", "3", "wttr.in?format=%c+%t+%C"]
        stdout: SplitParser {
            onRead: data => {
                const cleaned = data.trim();
                bar.weatherText = cleaned.length > 0 ? cleaned : "Unavailable";
            }
        }
    }

    function refreshSystemInfo() {
        if (!userInfoProc.running) userInfoProc.running = true;
        if (!uptimeProc.running) uptimeProc.running = true;
        if (!ramProc.running) ramProc.running = true;
        if (!weatherProc.running) weatherProc.running = true;
    }

    Timer {
        id: refreshTimer
        interval: 100
        onTriggered: bar.refreshVolume()
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: bar.refreshVolume()
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: bar.refreshSystemInfo()
    }

    Component.onCompleted: {
        refreshVolume();
        refreshSystemInfo();
    }

    readonly property color accent: "#7C4DFF"
    readonly property color accentGlow: "#B388FF"
    readonly property color ink: "#F3F4F6"
    readonly property color inkDim: "#9CA3AF"
    readonly property color surface: "#E6111318"
    readonly property color surfaceCard: "#F212141A"
    readonly property color surfaceHighlight: "#1FFFFFFF"
    readonly property color borderOutline: "#2AFFFFFF"

    component Divider: Rectangle {
        width: 1
        height: 14
        color: "#1FFFFFFF"
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    component IconButton: Rectangle {
        property bool hovered: false
        property bool activeState: false
        width: 28
        height: 28
        radius: 10
        color: activeState ? bar.accent : (hovered ? bar.surfaceHighlight : "transparent")
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Item {
        anchors.fill: parent

        // Notch Header
        Rectangle {
            id: notch
            width: contentRow.implicitWidth + 32
            height: 40
            radius: 20
            color: bar.surface

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: 6
            }

            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: bar.borderOutline
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: 10

                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: Hyprland.workspaces

                        Rectangle {
                            id: wsItem
                            required property var modelData
                            property bool active: modelData.active

                            width: active ? 28 : 20
                            height: 20
                            radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: active ? bar.accent : (wsHover.containsMouse ? bar.surfaceHighlight : "transparent")

                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 180; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: wsItem.modelData.id
                                color: wsItem.active ? bar.ink : bar.inkDim
                                font.pixelSize: 10
                                font.weight: wsItem.active ? Font.Bold : Font.Medium
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

                IconButton {
                    width: 28
                    height: 28
                    hovered: launcherHover.containsMouse

                    Text {
                        anchors.centerIn: parent
                        text: "\uf303"
                        color: launcherHover.containsMouse ? bar.accentGlow : bar.ink
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
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

                Rectangle {
                    width: volRow.implicitWidth + 14
                    height: 24
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: volumeHover.containsMouse ? bar.surfaceHighlight : "transparent"

                    Row {
                        id: volRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: bar.volumeIcon()
                            color: bar.muted ? bar.inkDim : bar.accentGlow
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: bar.muted ? "Mute" : bar.volume + "%"
                            color: bar.ink
                            font.pixelSize: 10
                            font.weight: Font.Medium
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

                IconButton {
                    id: dashToggleBtn
                    hovered: dashHover.containsMouse
                    activeState: bar.dashboardOpen

                    Text {
                        anchors.centerIn: parent
                        text: "\uf085"
                        color: bar.dashboardOpen ? bar.ink : (dashHover.containsMouse ? bar.accentGlow : bar.inkDim)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: dashHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            bar.dashboardOpen = !bar.dashboardOpen;
                            if (bar.dashboardOpen) bar.refreshSystemInfo();
                        }
                    }
                }
            }
        }

        // Popup Dashboard Content
        Rectangle {
            id: dashboardPanel
            width: 280
            height: 180
            radius: 16
            color: bar.surfaceCard
            border.width: 1
            border.color: bar.borderOutline
            visible: bar.dashboardOpen

            anchors {
                top: notch.bottom
                topMargin: 8
                horizontalCenter: parent.horizontalCenter
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 18
                        color: bar.accent

                        Text {
                            anchors.centerIn: parent
                            text: "\uf007"
                            color: bar.ink
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: bar.userName
                            color: bar.ink
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            text: "Uptime: " + bar.sysUptime
                            color: bar.inkDim
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: bar.borderOutline
                }

                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "\uf185"
                        color: bar.accentGlow
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: bar.weatherText
                        color: bar.ink
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: bar.borderOutline
                }

                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "\uf85a"
                        color: bar.accentGlow
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "RAM: " + bar.ramUsage
                        color: bar.ink
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}