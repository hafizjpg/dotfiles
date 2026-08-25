import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
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

    implicitHeight: 52

    // ---- Pipewire volume tracking ----
    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    readonly property var audioSink: Pipewire.defaultAudioSink
    property real volume: bar.audioSink && bar.audioSink.audio ? bar.audioSink.audio.volume : 0
    property bool muted: bar.audioSink && bar.audioSink.audio ? bar.audioSink.audio.muted : false

    property bool shouldShowOsd: false

    Timer {
        id: osdHideTimer
        interval: 1200
        onTriggered: bar.shouldShowOsd = false
    }

    function showOsd() {
        bar.shouldShowOsd = true;
        osdHideTimer.restart();
    }

    Connections {
        target: bar.audioSink ? bar.audioSink.audio : null
        function onVolumeChanged() { bar.showOsd(); }
        function onMutedChanged() { bar.showOsd(); }
    }

    function volumeIcon() {
        if (bar.muted || bar.volume === 0) return "\uf026";
        if (bar.volume < 0.5) return "\uf027";
        return "\uf028";
    }

    function changeVolume(deltaPercent) {
        if (!bar.audioSink || !bar.audioSink.audio) return;
        let newVol = bar.audioSink.audio.volume + (deltaPercent / 100);
        newVol = Math.max(0, Math.min(1, newVol));
        bar.audioSink.audio.volume = newVol;
        bar.showOsd();
    }

    function toggleMute() {
        if (!bar.audioSink || !bar.audioSink.audio) return;
        bar.audioSink.audio.muted = !bar.audioSink.audio.muted;
        bar.showOsd();
    }

    readonly property color accent: "#7C4DFF"
    readonly property color accentGlow: "#B388FF"
    readonly property color ink: "#F3F4F6"
    readonly property color inkDim: "#9CA3AF"
    readonly property color surface: "#E6111318"
    readonly property color surfaceCard: "#F212141A"
    readonly property color surfaceHighlight: "#1FFFFFFF"
    readonly property color borderOutline: "#2AFFFFFF"

    // ---- Tray right-click debug/kill state ----
    property string trayDebugText: ""

    Timer {
        id: trayDebugTimer
        interval: 8000
        onTriggered: bar.trayDebugText = ""
    }

    Process { id: trayKillProc }

    // Right-click handler shared by every tray icon: shows an on-screen debug
    // label (id/title/hasMenu) AND tries to kill the owning process by
    // matching its id/title against the running process list.
    function handleTrayRightClick(item) {
        const target = (item.id && item.id.length > 0) ? item.id : item.title;

        bar.trayDebugText = "id=[" + item.id + "] title=[" + item.title + "] hasMenu=" + item.hasMenu;
        trayDebugTimer.restart();

        if (target && target.length > 0) {
            trayKillProc.command = ["bash", "-c", "pkill -i -f " + JSON.stringify(target) + " || true"];
            trayKillProc.running = true;
        }
    }

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

        Behavior on color { ColorAnimation { duration: 0; easing.type: Easing.OutCubic } }
    }

    Item {
        anchors.fill: parent

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

            Behavior on width { NumberAnimation { duration: 0; easing.type: Easing.OutCubic } }

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

                            Behavior on width { NumberAnimation { duration: 0; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 0; easing.type: Easing.OutCubic } }

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
                            text: bar.muted ? "Mute" : Math.round(bar.volume * 100) + "%"
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

                // -- tray: left-click opens the app, right-click kills its process --
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
                                    if (mouse.button === Qt.RightButton)
                                        bar.handleTrayRightClick(trayBtn.modelData);
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
                    activeState: Local.Shared.dashboardOpen

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
                        onClicked: Local.Shared.dashboardOpen = !Local.Shared.dashboardOpen
                    }
                }
            }
        Rectangle {
            visible: bar.trayDebugText.length > 0
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: notch.bottom
                topMargin: 6
            }
            width: debugText.implicitWidth + 24
            height: debugText.implicitHeight + 12
            radius: 8
            color: "#EE111318"
            border.width: 1
            border.color: bar.borderOutline
            z: 999

            Text {
                id: debugText
                anchors.centerIn: parent
                text: bar.trayDebugText
                color: bar.ink
                font.pixelSize: 11
                font.family: "JetBrainsMono Nerd Font"
            }
        }
    }

    LazyLoader {
        active: bar.shouldShowOsd

        PanelWindow {
            screen: bar.screen
            aboveWindows: true
            focusable: false
            color: "white"

            anchors.bottom: true
            margins.bottom: bar.screen ? bar.screen.height / 6 : 200
            exclusiveZone: 0

            implicitWidth: 300
            implicitHeight: 56

            mask: Region {}

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: bar.surface
                border.width: 1
                border.color: bar.borderOutline

                Item {
                    anchors {
                        fill: parent
                        leftMargin: 16
                        rightMargin: 16
                    }

                    Text {
                        id: osdIcon
                        text: bar.volumeIcon()
                        color: bar.muted ? bar.inkDim : bar.accentGlow
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        id: osdPct
                        text: bar.muted ? "Mute" : Math.round(bar.volume * 100) + "%"
                        color: bar.ink
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                    }

                    Rectangle {
                        id: osdTrack
                        height: 8
                        radius: 4
                        color: "#33FFFFFF"
                        anchors {
                            left: osdIcon.right
                            right: osdPct.left
                            leftMargin: 12
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            radius: parent.radius
                            color: bar.muted ? bar.inkDim : bar.accent
                            width: parent.width * (bar.muted ? 0 : bar.volume)
                        }
                    }
                }
            }
        }
    }
}
