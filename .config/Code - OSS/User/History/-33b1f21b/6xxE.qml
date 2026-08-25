import Quickshell
import QtQuick
import "." as Local

PanelWindow {
    id: toast

    screen: Quickshell.screens[0]
    aboveWindows: true
    focusable: false
    color: "transparent"
    exclusiveZone: 0

    anchors { top: true }

    implicitWidth: 460
    implicitHeight: 160

    mask: Region { item: island }

    readonly property color ink: "#F7EAF3"
    readonly property color inkDim: "#8a839c"

    // Phases: idle -> materializing -> compact -> expanded -> collapsing -> idle
    property string phase: "idle" 
    property var current: null
    property bool busy: false

    function queuedCount() {
        return Local.Shared.toastQueue ? Local.Shared.toastQueue.count : 0;
    }

    function processQueue() {
        if (busy) return;
        if (queuedCount() === 0) {
            current = null;
            phase = "idle";
            return;
        }

        busy = true;
        const item = Local.Shared.toastQueue.get(0);
        Local.Shared.toastQueue.remove(0);
        current = item;
        pulseRing.restart();
        lifecycle.restart();
    }

    Connections {
        target: Local.Shared.toastQueue
        function onCountChanged() {
            if (toast.queuedCount() > 0 && !toast.busy) {
                Qt.callLater(toast.processQueue);
            }
        }
    }

    // Dynamic Island State Machine Sequence
    SequentialAnimation {
        id: lifecycle

        ScriptAction { script: toast.phase = "materializing" }
        PauseAnimation { duration: 150 }

        ScriptAction { script: toast.phase = "compact" }
        // Compact peek duration
        PauseAnimation { duration: 800 } 

        ScriptAction {
            script: {
                if (toast.current && toast.current.body && toast.current.body.length > 0) {
                    toast.phase = "expanded";
                }
            }
        }
        // Extended hold time if expanded with body text
        PauseAnimation { duration: toast.phase === "expanded" ? 3500 : 1200 }

        ScriptAction { script: toast.phase = "collapsing" }
        PauseAnimation { duration: 250 }

        ScriptAction { script: toast.phase = "idle" }
        PauseAnimation { duration: 150 }

        ScriptAction {
            script: {
                toast.busy = false;
                toast.current = null;
                Qt.callLater(toast.processQueue);
            }
        }
    }

    function dismissEarly() {
        if (!busy) return;
        lifecycle.stop();
        collapseThenNext.restart();
    }

    SequentialAnimation {
        id: collapseThenNext

        ScriptAction { script: toast.phase = "collapsing" }
        PauseAnimation { duration: 200 }
        ScriptAction { script: toast.phase = "idle" }
        PauseAnimation { duration: 100 }
        ScriptAction {
            script: {
                toast.busy = false;
                toast.current = null;
                Qt.callLater(toast.processQueue);
            }
        }
    }

    function openHistory() {
        Local.Shared.openNotificationHistory();
        dismissEarly();
    }

    Item {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12

        width: pill.width
        height: pill.height

        // Outer pulsing energy ring (Apple-style subtle wake-up aura)
        Rectangle {
            id: pulseRing
            anchors.centerIn: pill
            width: pill.width + 8
            height: pill.height + 8
            radius: height / 2
            color: "transparent"
            border.width: 1.5
            border.color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) : "#B388FF"
            opacity: 0
            scale: 1

            function restart() { pulseAnim.restart(); }

            SequentialAnimation {
                id: pulseAnim
                ScriptAction { script: { pulseRing.opacity = 0.6; pulseRing.scale = 0.95; } }
                ParallelAnimation {
                    NumberAnimation { target: pulseRing; property: "opacity"; to: 0; duration: 600; easing.type: Easing.OutCubic }
                    NumberAnimation { target: pulseRing; property: "scale"; to: 1.12; duration: 600; easing.type: Easing.OutBack }
                }
            }
        }

        // Main Island Container
        Rectangle {
            id: pill
            radius: height / 2
            color: "#FF000000" // OLED Pitch Black
            border.width: 1
            border.color: "#26FFFFFF"
            clip: true

            // Responsive Dimensions per Phase
            width: {
                if (toast.phase === "idle") return 36;
                if (toast.phase === "materializing") return 80;
                if (toast.phase === "compact") return 260;
                if (toast.phase === "expanded") return 410;
                if (toast.phase === "collapsing") return 50;
                return 36;
            }
            height: {
                if (toast.phase === "idle") return 12;
                if (toast.phase === "materializing") return 36;
                if (toast.phase === "compact") return 42;
                if (toast.phase === "expanded") return 118;
                if (toast.phase === "collapsing") return 36;
                return 12;
            }

            opacity: toast.phase === "idle" ? 0 : 1
            scale: toast.phase === "idle" ? 0.4 : 1.0

            // Fluid Spring Animations
            Behavior on width {
                NumberAnimation {
                    duration: toast.phase === "expanded" ? 420 : 320
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: toast.phase === "expanded" ? 420 : 320
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.3
                }
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

            MouseArea {
                anchors.fill: parent
                onClickAndHold: toast.openHistory()
                onClicked: toast.dismissEarly()
            }

            // --- COMPACT VIEW (Left App Icon + Right Activity Indicator) ---
            Item {
                id: compactView
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                visible: toast.phase === "compact" || toast.phase === "materializing"
                opacity: visible ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Left: App / Urgency Indicator Icon
                Rectangle {
                    id: compactIconDot
                    width: 24; height: 24; radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) + "33" : "#22FFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: toast.current ? Local.Shared.urgencyLabel(toast.current.urgency) : "\uf0f3"
                        color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) : toast.ink
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                }

                // Center: Brief Summary
                Text {
                    anchors.left: compactIconDot.right
                    anchors.right: compactRightDot.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: toast.current ? (toast.current.summary || toast.current.appName || "") : ""
                    color: toast.ink
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // Right: Dynamic Pulse Dot (Simulates background activity like Apple's orange/green dots)
                Rectangle {
                    id: compactRightDot
                    width: 8; height: 8; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) : "#00FF99"

                    SequentialAnimation on opacity {
                        running: compactView.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }
            }

            // --- EXPANDED VIEW (Full Detailed Toast Content) ---
            Item {
                id: expandedView
                anchors.fill: parent
                anchors.margins: 14
                visible: toast.phase === "expanded"
                opacity: visible ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 200 } }

                // Top Left Icon Badge
                Rectangle {
                    id: expIconDot
                    width: 32; height: 32; radius: 16
                    anchors.left: parent.left
                    anchors.top: parent.top
                    color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) + "33" : "#22FFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: toast.current ? Local.Shared.urgencyLabel(toast.current.urgency) : "\uf0f3"
                        color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) : toast.ink
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                    }
                }

                // Header & Body Text Area
                Column {
                    anchors.left: expIconDot.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 3

                    Text {
                        text: toast.current ? (toast.current.appName || "Notification") : ""
                        color: toast.inkDim
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: toast.current ? (toast.current.summary || "") : ""
                        color: toast.ink
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        text: toast.current ? (toast.current.body || "") : ""
                        color: toast.inkDim
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                // Expanded Footer Action Button
                Row {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    spacing: 6

                    Rectangle {
                        width: historyLabel.implicitWidth + 24
                        height: 24
                        radius: 12
                        color: historyBtnHover.containsMouse ? "#33FFFFFF" : "#1AFFFFFF"

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "\uf1da"
                                color: toast.ink
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: historyLabel
                                text: "History"
                                color: toast.ink
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.family: "JetBrainsMono Nerd Font"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: historyBtnHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: toast.openHistory()
                        }
                    }
                }
            }

            // Queued Stack Indicator Dots at the bottom of the pill
            Row {
                visible: (toast.phase === "compact" || toast.phase === "expanded") && toast.queuedCount() > 0
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 4
                }
                spacing: 4

                Repeater {
                    model: Math.min(toast.queuedCount(), 4)
                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: "#77FFFFFF"
                    }
                }
            }
        }
    }
}