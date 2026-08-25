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
    implicitHeight: 130

    mask: Region { item: island }

    readonly property color ink: "#F7EAF3"
    readonly property color inkDim: "#8a839c"

    property string phase: "idle" // idle | materializing | compact | expanded | collapsing
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

    // materialize -> compact peek -> expand (if there's a body) -> hold -> collapse -> idle
    SequentialAnimation {
        id: lifecycle

        ScriptAction { script: toast.phase = "materializing" }
        PauseAnimation { duration: 90 }
        ScriptAction { script: toast.phase = "compact" }
        PauseAnimation { duration: 1200 }
        ScriptAction {
            script: {
                if (toast.current && toast.current.body && toast.current.body.length > 0) {
                    toast.phase = "expanded";
                }
            }
        }
        PauseAnimation { duration: 3200 }
        ScriptAction { script: toast.phase = "compact" }
        PauseAnimation { duration: 260 }
        ScriptAction { script: toast.phase = "idle" }
        PauseAnimation { duration: 240 }
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

        ScriptAction { script: toast.phase = "compact" }
        PauseAnimation { duration: 140 }
        ScriptAction { script: toast.phase = "idle" }
        PauseAnimation { duration: 240 }
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
        anchors.topMargin: 10

        width: pill.width
        height: pill.height

        // Faint expanding ring that pulses once when a new toast lands,
        // like the island "waking up".
        Rectangle {
            id: pulseRing
            anchors.centerIn: pill
            width: pill.width
            height: pill.height
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) : "#B388FF"
            opacity: 0
            scale: 1

            function restart() { pulseAnim.restart(); }

            SequentialAnimation {
                id: pulseAnim
                ScriptAction { script: { pulseRing.opacity = 0.55; pulseRing.scale = 1; } }
                ParallelAnimation {
                    NumberAnimation { target: pulseRing; property: "opacity"; to: 0; duration: 500; easing.type: Easing.OutCubic }
                    NumberAnimation { target: pulseRing; property: "scale"; to: 1.18; duration: 500; easing.type: Easing.OutCubic }
                }
            }
        }

        Rectangle {
            id: pill
            radius: height / 2
            color: "#F5000000" // near-black, true "island" black
            border.width: 1
            border.color: "#1FFFFFFF"
            clip: true

            width: {
                if (toast.phase === "idle") return 1;
                if (toast.phase === "materializing") return 54;
                if (toast.phase === "compact") return 240;
                return 408;
            }
            height: {
                if (toast.phase === "idle") return 1;
                if (toast.phase === "materializing") return 36;
                if (toast.phase === "compact") return 44;
                return 112;
            }

            opacity: toast.phase === "idle" ? 0 : 1
            scale: toast.phase === "idle" ? 0.6 : 1

            // Punchy overshoot on the way out (materialize/expand), calm
            // settle on the way back down — this asymmetry is what sells
            // the "island" feel over a generic toast.
            Behavior on width {
                NumberAnimation {
                    duration: toast.phase === "compact" || toast.phase === "idle" ? 320 : 460
                    easing.type: toast.phase === "expanded" || toast.phase === "materializing" ? Easing.OutBack : Easing.OutExpo
                    easing.overshoot: 1.6
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: toast.phase === "compact" || toast.phase === "idle" ? 320 : 460
                    easing.type: toast.phase === "expanded" || toast.phase === "materializing" ? Easing.OutBack : Easing.OutExpo
                    easing.overshoot: 1.6
                }
            }
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

            MouseArea {
                anchors.fill: parent
                onClicked: toast.dismissEarly()
            }

            Item {
                anchors.fill: parent
                anchors.margins: 12
                visible: toast.current !== null && toast.phase !== "idle" && toast.phase !== "materializing"
                opacity: visible ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 160 } }

                Rectangle {
                    id: iconDot
                    width: 26; height: 26; radius: 13
                    anchors.left: parent.left
                    anchors.top: parent.top
                    color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) + "33" : "#22FFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: toast.current ? Local.Shared.urgencyLabel(toast.current.urgency) : "\uf0f3"
                        color: toast.current ? Local.Shared.urgencyColor(toast.current.urgency) : toast.ink
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }
                }

                Column {
                    anchors.left: iconDot.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 2

                    Text {
                        text: toast.current ? (toast.current.appName || "") : ""
                        color: toast.inkDim
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: toast.current ? (toast.current.summary || "") : ""
                        color: toast.ink
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.family: "JetBrainsMono Nerd Font"
                        width: parent.width
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        visible: toast.phase === "expanded" && text.length > 0
                        text: toast.current ? (toast.current.body || "") : ""
                        color: toast.inkDim
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }

                // Footer row, only in the expanded state: jump to the
                // notification history without waiting for the toast
                // to auto-collapse.
                Row {
                    visible: toast.phase === "expanded"
                    opacity: visible ? 1 : 0
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                    }
                    spacing: 6

                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Rectangle {
                        width: historyLabel.implicitWidth + 22
                        height: 22
                        radius: 11
                        color: historyBtnHover.containsMouse ? "#2AFFFFFF" : "#16FFFFFF"

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: "\uf1da"
                                color: toast.ink
                                font.pixelSize: 9
                                font.family: "JetBrainsMono Nerd Font"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: historyLabel
                                text: "History"
                                color: toast.ink
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
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

            // Stacked-queue peek: small dots hugging the bottom edge of the
            // compact pill, hinting there are more toasts waiting behind
            // this one — mirrors how the island hints at background activity.
            Row {
                visible: toast.phase === "compact" && toast.queuedCount() > 0
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 5
                }
                spacing: 3

                Repeater {
                    model: Math.min(toast.queuedCount(), 4)
                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: "#55FFFFFF"
                    }
                }
            }
        }
    }
}
