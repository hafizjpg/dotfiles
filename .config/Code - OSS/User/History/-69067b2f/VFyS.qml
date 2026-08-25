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
    exclusiveZone: 52
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    // Dynamic height allowing popup expansion without clipping
    implicitHeight: Local.Shared.dashboardOpen ? dashboardPanel.y + dashboardPanel.height + 12 : 52

    property int volume: 0
    property bool muted: false

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

    // Notifications now live entirely in Local.Shared (Shared.qml) so the
    // bar and the toast island share one NotificationServer and one
    // history log. See: Local.Shared.activeNotifications / .historyModel.

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

    // Shared notification-card delegate, reused by both the "Notifications"
    // and "History" tabs so they stay visually consistent.
    component NotificationCard: Rectangle {
        id: card
        required property var entryData
        property bool dismissible: true

        width: ListView.view ? ListView.view.width : 0
        height: notifCol.implicitHeight + 20
        radius: 12
        color: "#14FFFFFF"
        border.width: 1
        border.color: bar.borderOutline

        Rectangle {
            width: 3
            radius: 2
            color: Local.Shared.urgencyColor(card.entryData.urgencyValue)
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                topMargin: 10
                bottomMargin: 10
                leftMargin: 6
            }
        }

        Column {
            id: notifCol
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 16
                rightMargin: card.dismissible ? 28 : 16
            }
            spacing: 3

            Row {
                width: parent.width
                spacing: 6

                Text {
                    text: Local.Shared.urgencyLabel(card.entryData.urgencyValue)
                    color: Local.Shared.urgencyColor(card.entryData.urgencyValue)
                    font.pixelSize: 10
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: card.entryData.appName
                    color: bar.ink
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item { width: 1; height: 1 }

                Text {
                    text: card.entryData.timestamp
                    color: bar.inkDim
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                width: parent.width
                text: card.entryData.summary
                color: bar.ink
                font.pixelSize: 11
                font.weight: Font.Medium
                font.family: "JetBrainsMono Nerd Font"
                wrapMode: Text.WordWrap
                visible: card.entryData.summary.length > 0
            }

            Text {
                width: parent.width
                text: card.entryData.body
                color: bar.inkDim
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                visible: card.entryData.body.length > 0
            }

            Row {
                width: parent.width
                spacing: 6
                visible: card.dismissible && card.entryData.notifActions && card.entryData.notifActions.length > 0

                Repeater {
                    model: card.entryData.notifActions

                    Rectangle {
                        required property var modelData
                        width: actionLabel.implicitWidth + 16
                        height: 20
                        radius: 8
                        color: actionHover.containsMouse ? bar.accent : "#1FFFFFFF"

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: bar.ink
                            font.pixelSize: 9
                            font.family: "JetBrainsMono Nerd Font"
                        }

                        MouseArea {
                            id: actionHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Local.Shared.invokeAction(card.entryData.notifId, modelData.identifier)
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: card.dismissible
            width: 18
            height: 18
            radius: 9
            color: closeHover.containsMouse ? bar.surfaceHighlight : "transparent"
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 8
                rightMargin: 8
            }

            Text {
                anchors.centerIn: parent
                text: "\uf00d"
                color: closeHover.containsMouse ? bar.ink : bar.inkDim
                font.pixelSize: 9
                font.family: "JetBrainsMono Nerd Font"
            }

            MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Local.Shared.dismissActive(card.entryData.notifId)
            }
        }
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

                // -- Notification Bell (live / active) ---------------------------
                IconButton {
                    id: bellToggleBtn
                    hovered: bellHover.containsMouse
                    activeState:Local.Shared.dashboardTab === "notifications"

                    Text {
                        anchors.centerIn: parent
                        text: Local.Shared.activeNotifications.count > 0 ? "\uf0f3" : "\uf1f6"
                        color: bellToggleBtn.activeState ? bar.ink : (bellHover.containsMouse ? bar.accentGlow : bar.inkDim)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    Rectangle {
                        visible: Local.Shared.activeNotifications.count > 0
                        width: 14
                        height: 14
                        radius: 7
                        color: "#FF5C5C"
                        anchors {
                            top: parent.top
                            right: parent.right
                            topMargin: -3
                            rightMargin: -3
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Local.Shared.activeNotifications.count > 9 ? "9+" : Local.Shared.activeNotifications.count
                            color: "#FFFFFF"
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    MouseArea {
                        id: bellHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (Local.Shared.dashboardTab === "notifications") {
                                Local.Shared.dashboardOpen = false;
                            } else {
                                Local.Shared.openTab("notifications");
                            }
                        }
                    }
                }

                // -- Notification History ----------------------------------------
                IconButton {
                    id: historyToggleBtn
                    hovered: historyHover.containsMouse
                    activeState: Local.Shared.dashboardOpen && Local.Shared.dashboardTab === "history"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf1da" // clock / history icon
                        color: historyToggleBtn.activeState ? bar.ink : (historyHover.containsMouse ? bar.accentGlow : bar.inkDim)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: historyHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (Local.Shared.dashboardOpen && Local.Shared.dashboardTab === "history") {
                                Local.Shared.dashboardOpen = false;
                            } else {
                                Local.Shared.openTab("history");
                            }
                        }
                    }
                }

                Divider {}

                // -- Dashboard Toggle (system info) -------------------------------
                IconButton {
                    id: dashToggleBtn
                    hovered: dashHover.containsMouse
                    activeState: Local.Shared.dashboardOpen && Local.Shared.dashboardTab === "info"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf085"
                        color: dashToggleBtn.activeState ? bar.ink : (dashHover.containsMouse ? bar.accentGlow : bar.inkDim)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: dashHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (Local.Shared.dashboardOpen && Local.Shared.dashboardTab === "info") {
                                Local.Shared.dashboardOpen = false;
                            } else {
                                Local.Shared.openTab("info");
                                bar.refreshSystemInfo();
                            }
                        }
                    }
                }
            }
        }

        // Popup Dashboard Content
        Rectangle {
            id: dashboardPanel
            width: 300
            height: Local.Shared.dashboardTab === "info" ? 180 : 340
            radius: 16
            color: bar.surfaceCard
            border.width: 1
            border.color: bar.borderOutline
            visible: Local.Shared.dashboardOpen
            clip: true

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            anchors {
                top: notch.bottom
                topMargin: 8
                horizontalCenter: parent.horizontalCenter
            }

            // -- Tab Switcher -----------------------------------------------
            Row {
                id: tabRow
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 12
                }
                spacing: 4

                Rectangle {
                    width: 60
                    height: 22
                    radius: 8
                    color: Local.Shared.dashboardTab === "info" ? bar.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "Info"
                        color: Local.Shared.dashboardTab === "info" ? bar.ink : bar.inkDim
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Local.Shared.dashboardTab = "info"
                    }
                }

                Rectangle {
                    width: 108
                    height: 22
                    radius: 8
                    color: Local.Shared.dashboardTab === "notifications" ? bar.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "Active" + (Local.Shared.activeNotifications.count > 0 ? " (" + Local.Shared.activeNotifications.count + ")" : "")
                        color: Local.Shared.dashboardTab === "notifications" ? bar.ink : bar.inkDim
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Local.Shared.dashboardTab = "notifications"
                    }
                }

                Rectangle {
                    width: 76
                    height: 22
                    radius: 8
                    color: Local.Shared.dashboardTab === "history" ? bar.accent : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "History"
                        color: Local.Shared.dashboardTab === "history" ? bar.ink : bar.inkDim
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Local.Shared.dashboardTab = "history"
                    }
                }
            }

            // -- Info Tab -----------------------------------------------------
            Column {
                anchors {
                    top: tabRow.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 12
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 12
                visible: Local.Shared.dashboardTab === "info"

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
