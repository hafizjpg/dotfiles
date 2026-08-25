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
    implicitHeight: 110

    mask: Region { item: island }

    readonly property color ink: "#F7EAF3"
    readonly property color inkDim: "#8a839c"

    property string phase: "idle"
    property var current: null
    property bool busy: false

    function processQueue() {
        if (busy) return;
        if (!Local.Shared.toastQueue || Local.Shared.toastQueue.count === 0) {
            current = null;
            phase = "idle";
            return;
        }
        
        busy = true;
        const item = Local.Shared.toastQueue.get(0);
        Local.Shared.toastQueue.remove(0);
        current = item;
        lifecycle.restart();
    }

    Connections {
        target: Local.Shared.toastQueue
        function onCountChanged() {
            if (Local.Shared.toastQueue.count > 0 && !toast.busy) {
                Qt.callLater(toast.processQueue);
            }
        }
    }

    SequentialAnimation {
        id: lifecycle

        ScriptAction { script: toast.phase = "compact" }
        PauseAnimation { duration: 1300 }
        ScriptAction {
            script: {
                if (toast.current && toast.current.body && toast.current.body.length > 0) {
                    toast.phase = "expanded";
                }
            }
        }
        PauseAnimation { duration: 3000 }
        ScriptAction { script: toast.phase = "compact" }
        PauseAnimation { duration: 250 }
        ScriptAction { script: toast.phase = "idle" }
        PauseAnimation { duration: 220 }
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
        PauseAnimation { duration: 150 }
        ScriptAction { script: toast.phase = "idle" }
        PauseAnimation { duration: 220 }
        ScriptAction {
            script: {
                toast.busy = false;
                toast.current = null;
                Qt.callLater(toast.processQueue);
            }
        }
    }

    Item {
        id: island
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 12

        width: pill.width
        height: pill.height

        Rectangle {
            id: pill
            radius: 22
            color: "#e6121216"
            border.width: 1
            border.color: "#22FFFFFF"
            clip: true

            width: {
                if (toast.phase === "idle") return 1;
                if (toast.phase === "compact") return 240;
                return 400;
            }
            height: {
                if (toast.phase === "idle") return 1;
                if (toast.phase === "compact") return 46;
                return 96;
            }

            opacity: toast.phase === "idle" ? 0 : 1
            scale: toast.phase === "idle" ? 0.7 : 1

            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }
            Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

            MouseArea {
                anchors.fill: parent
                onClicked: toast.dismissEarly()
            }

            Item {
                anchors.fill: parent
                anchors.margins: 12
                visible: toast.current !== null && toast.phase !== "idle"

                Rectangle {
                    id: iconDot
                    width: 26; height: 26; radius: 13
                    anchors.left: parent.left
                    anchors.top: parent.top
                    color: toast.current && typeof Local.Shared.urgencyColor === "function" 
                           ? Local.Shared.urgencyColor(toast.current.urgency) + "33" 
                           : "#22FFFFFF"

                    Text {
                        anchors.centerIn: parent
                        text: "\uf0f3"
                        color: toast.current && typeof Local.Shared.urgencyColor === "function" 
                               ? Local.Shared.urgencyColor(toast.current.urgency) 
                               : toast.ink
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
            }
        }
    }
}