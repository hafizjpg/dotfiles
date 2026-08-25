import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import QtQuick
import "." as Local

PanelWindow {
    id: dash

    screen: Quickshell.screens[0]
    aboveWindows: true
    focusable: false
    color: "transparent"
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080

    mask: Region {
        Region { item: dash.open ? backdrop : zeroArea }
        Region { item: dash.open ? panel : zeroArea }
        Region { item: toastStack }
    }

    Item { id: zeroArea; width: 0; height: 0 }

    readonly property color accent: "#6E50EB"
    readonly property color accentBright: "#A08CF0"
    readonly property color ink: "#F7EAF3"
    readonly property color inkDim: "#8a839c"
    readonly property color surface: "#e6121216"

    property bool open: Local.Shared.dashboardOpen

    // ---- Clock ----
    property date currentTime: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: dash.currentTime = new Date()
    }

    // ---- Section navigation ----
    property string activeSection: "info" // "info" | "player" | "notifications"

    // ---- Info: identity ----
    property string userName: "User"
    property string sysUptime: "0 mins"

    // ---- Info: weather ----
    property string weatherTemp: "--"
    property string weatherCond: "Loading..."

    // ---- Info: system stats ----
    property string cpuPct: "--"
    property string memPct: "--"
    property string batPct: "--"
    property string netName: "--"

    readonly property var activePlayer: (Mpris.players && Mpris.players.values.length > 0) ? Mpris.players.values[0] : null

    function playerTitle() {
        if (!activePlayer) return "";
        return activePlayer.trackTitle || activePlayer.title || "Unknown title";
    }
    function playerArtist() {
        if (!activePlayer) return "";
        return activePlayer.trackArtist || activePlayer.artist || "";
    }
    function playerIsPlaying() {
        return !!(activePlayer && (activePlayer.isPlaying || activePlayer.playbackState === 1));
    }
    function playerCtl(action) {
        if (!activePlayer) return;
        try {
            if (action === "prev" && typeof activePlayer.previous === "function") activePlayer.previous();
            else if (action === "next" && typeof activePlayer.next === "function") activePlayer.next();
            else if (action === "toggle") {
                if (typeof activePlayer.togglePlaying === "function") activePlayer.togglePlaying();
                else if (typeof activePlayer.playPause === "function") activePlayer.playPause();
            }
        } catch (e) { /* player unsupported action */ }
    }

    Component.onCompleted: {
        userInfoProc.running = true;
        uptimeProc.running = true;
        weatherProc.running = true;
        statsProc.running = true;
    }

    ListModel { id: notifModel }
    ListModel { id: toastModel }

    NotificationServer {
        id: notifServer

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (notification) => {
            notification.tracked = true;

            notifModel.insert(0, {
                notifId: notification.id,
                summary: notification.summary || "",
                body: notification.body || "",
                appName: notification.appName || "",
                urgency: notification.urgency !== undefined ? notification.urgency : 1,
                notifObj: notification
            });

            toastModel.insert(0, {
                toastId: notification.id,
                summary: notification.summary || "",
                body: notification.body || "",
                appName: notification.appName || "",
                urgency: notification.urgency !== undefined ? notification.urgency : 1
            });

            const toastTimer = expireTimerComponent.createObject(dash, { interval: 5000 });
            toastTimer.triggered.connect(() => {
                dash.removeToast(notification.id);
                toastTimer.destroy();
            });
            toastTimer.start();

            const timeout = notification.expireTimeout > 0 ? notification.expireTimeout : 8000;
            const expireTimer = expireTimerComponent.createObject(dash, { interval: timeout });
            expireTimer.triggered.connect(() => {
                dash.dismissNotification(notification.id);
                expireTimer.destroy();
            });
            expireTimer.start();

            notification.closed.connect(() => {
                dash.removeNotificationFromModel(notification.id);
                dash.removeToast(notification.id);
            });
        }
    }

    Component {
        id: expireTimerComponent
        Timer { running: false; repeat: false }
    }

    function removeNotificationFromModel(id) {
        for (let i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).notifId === id) {
                notifModel.remove(i);
                return;
            }
        }
    }

    function removeToast(id) {
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).toastId === id) {
                toastModel.remove(i);
                return;
            }
        }
    }

    function dismissNotification(id) {
        for (let i = 0; i < notifModel.count; i++) {
            const item = notifModel.get(i);
            if (item.notifId === id) {
                try {
                    if (item.notifObj && typeof item.notifObj.dismiss === "function") item.notifObj.dismiss();
                } catch (e) { /* already dismissed */ }
                notifModel.remove(i);
                return;
            }
        }
    }

    function clearAllNotifications() {
        for (let i = notifModel.count - 1; i >= 0; i--) {
            const item = notifModel.get(i);
            try {
                if (item.notifObj && typeof item.notifObj.dismiss === "function") item.notifObj.dismiss();
            } catch (e) { /* already dismissed */ }
        }
        notifModel.clear();
    }

    function urgencyColor(u) {
        if (u === 2) return "#e06c75";
        if (u === 0) return dash.inkDim;
        return dash.accentBright;
    }

    Process {
        id: userInfoProc
        command: ["whoami"]
        stdout: SplitParser {
            onRead: data => dash.userName = data.trim()
        }
    }

    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        stdout: SplitParser {
            onRead: data => dash.sysUptime = data.replace("up ", "").trim()
        }
    }

    Process {
        id: weatherProc
        command: ["bash", "-c", "curl -s 'wttr.in/?format=%t|%C' --max-time 5"]
        stdout: SplitParser {
            onRead: line => {
                if (!line || line.length === 0) return;
                const parts = line.split("|");
                if (parts.length === 2) {
                    dash.weatherTemp = parts[0].trim();
                    dash.weatherCond = parts[1].trim();
                }
            }
        }
    }
    Timer { interval: 15 * 60 * 1000; running: true; repeat: true; onTriggered: weatherProc.running = true }
    Timer { interval: 5 * 60 * 1000; running: true; repeat: true; onTriggered: { userInfoProc.running = true; uptimeProc.running = true; } }

    Process {
        id: statsProc
        command: ["bash", Quickshell.env("HOME") + "/.local/bin/dashboard-stats.sh"]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("CPU:")) dash.cpuPct = line.slice(4).trim();
                else if (line.startsWith("MEM:")) dash.memPct = line.slice(4).trim();
                else if (line.startsWith("BAT:")) dash.batPct = line.slice(4).trim() || "N/A";
                else if (line.startsWith("NET:")) dash.netName = line.slice(4).trim();
            }
        }
        onExited: (code) => {
            if (code !== 0) console.log("Dashboard stats process exited with code", code);
        }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: statsProc.running = true }

    Column {
        id: toastStack
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 8
            rightMargin: 8
        }
        width: 300
        spacing: 8

        Repeater {
            model: toastModel

            Rectangle {
                id: toastItem
                required property string summary
                required property string body
                required property string appName
                required property int urgency
                required property int toastId

                width: toastStack.width
                height: toastCol.height + 20
                radius: 16
                color: dash.surface
                border.width: 1
                border.color: dash.urgencyColor(urgency) + "55"

                opacity: 0
                x: 40
                Component.onCompleted: {
                    opacity = 1;
                    x = 0;
                }
                Behavior on opacity { NumberAnimation { duration: 0; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 0; easing.type: Easing.OutCubic } }

                Column {
                    id: toastCol
                    anchors {
                        left: parent.left
                        right: closeToastBtn.left
                        top: parent.top
                        margins: 12
                        rightMargin: 6
                    }
                    spacing: 3

                    Text {
                        text: toastItem.appName
                        color: dash.urgencyColor(toastItem.urgency)
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        text: toastItem.summary
                        color: dash.ink
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.family: "JetBrainsMono Nerd Font"
                        width: parent.width
                        wrapMode: Text.Wrap
                    }
                    Text {
                        visible: toastItem.body.length > 0
                        text: toastItem.body
                        color: dash.inkDim
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: closeToastBtn
                    width: 18
                    height: 18
                    radius: 6
                    anchors { top: parent.top; right: parent.right; margins: 8 }
                    color: closeToastHover.containsMouse ? "#1EFFFFFF" : "transparent"

                    Text { anchors.centerIn: parent; text: "\u2715"; color: dash.inkDim; font.pixelSize: 9 }

                    MouseArea {
                        id: closeToastHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: dash.removeToast(toastItem.toastId)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: dash.removeToast(toastItem.toastId)
                }
            }
        }
    }

    component TabButtonComp: Rectangle {
        id: tabBtn
        required property string sectionId
        required property string label
        required property string glyph
        readonly property bool active: dash.activeSection === sectionId

        height: 34
        radius: 12
        color: active ? dash.accent : "#11FFFFFF"

        Behavior on color { ColorAnimation { duration: 0; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: tabBtn.glyph
                color: tabBtn.active ? dash.ink : dash.inkDim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }
            Text {
                text: tabBtn.label
                color: tabBtn.active ? dash.ink : dash.inkDim
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.family: "JetBrainsMono Nerd Font"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: dash.activeSection = tabBtn.sectionId
        }
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: "#7A000000"
        visible: dash.open
        opacity: dash.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 0; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked: Local.Shared.toggleDashboard()
        }
    }

    Rectangle {
        id: panel
        width: 460
        height: Math.min((dash.screen ? dash.screen.height : 1080) - 120, 780)
        anchors.centerIn: parent
        radius: 24
        color: dash.surface
        border.width: 1
        border.color: "#22FFFFFF"
        clip: true

        opacity: dash.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 0; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
            height: 1
            color: "#26FFFFFF"
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 18
            contentHeight: content.height
            clip: true

            Column {
                id: content
                width: parent.width
                spacing: 16

                Row {
                    width: parent.width
                    Text {
                        text: "Dashboard"
                        color: dash.ink
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Item { width: parent.width - 130; height: 1 }
                    Rectangle {
                        width: 26; height: 26; radius: 8
                        color: dashCloseHover.containsMouse ? "#1EFFFFFF" : "transparent"
                        Text { anchors.centerIn: parent; text: "\u2715"; color: dash.ink; font.pixelSize: 13 }
                        MouseArea {
                            id: dashCloseHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Local.Shared.toggleDashboard()
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8

                    TabButtonComp { width: (parent.width - 16) / 3; sectionId: "info"; label: "Info"; glyph: "\uf05a" }
                    TabButtonComp { width: (parent.width - 16) / 3; sectionId: "player"; label: "Player"; glyph: "\uf001" }
                    TabButtonComp {
                        width: (parent.width - 16) / 3
                        sectionId: "notifications"
                        label: notifModel.count > 0 ? "Alerts (" + notifModel.count + ")" : "Alerts"
                        glyph: "\uf0f3"
                    }
                }

                // ---------------- INFO SECTION ----------------
                Column {
                    width: parent.width
                    spacing: 16
                    visible: dash.activeSection === "info"

                    Rectangle {
                        width: parent.width
                        height: clockCol.height + 28
                        radius: 16
                        color: "#11FFFFFF"

                        Column {
                            id: clockCol
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 4

                            Text {
                                text: Qt.formatDateTime(dash.currentTime, "HH:mm:ss")
                                color: dash.ink
                                font.pixelSize: 34
                                font.weight: Font.Bold
                                font.family: "JetBrainsMono Nerd Font"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: Qt.formatDateTime(dash.currentTime, "dddd, d MMMM yyyy")
                                color: dash.inkDim
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: userRow.height + 24
                        radius: 16
                        color: "#11FFFFFF"

                        Row {
                            id: userRow
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 10

                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: dash.accent
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf007"
                                    color: dash.ink
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: dash.userName
                                    color: dash.ink
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                Text {
                                    text: "Uptime: " + dash.sysUptime
                                    color: dash.inkDim
                                    font.pixelSize: 10
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 56
                        radius: 16
                        color: "#11FFFFFF"

                        Row {
                            anchors.centerIn: parent
                            spacing: 10

                            Text { text: "\uf185"; color: dash.accentBright; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18 }
                            Text { text: dash.weatherTemp; color: dash.ink; font.pixelSize: 16; font.weight: Font.DemiBold; font.family: "JetBrainsMono Nerd Font" }
                            Text { text: dash.weatherCond; color: dash.inkDim; font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font" }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: statsCol.height + 24
                        radius: 16
                        color: "#11FFFFFF"

                        Column {
                            id: statsCol
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 10

                            Repeater {
                                model: [
                                    { label: "CPU", value: dash.cpuPct + "%", glyph: "\uf2db" },
                                    { label: "RAM", value: dash.memPct + "%", glyph: "\uf538" },
                                    { label: "Battery", value: dash.batPct + (dash.batPct === "N/A" ? "" : "%"), glyph: "\uf240" },
                                    { label: "Network", value: dash.netName, glyph: "\uf1eb" }
                                ]

                                Row {
                                    required property var modelData
                                    width: statsCol.width
                                    spacing: 10

                                    Text { text: modelData.glyph; color: dash.accentBright; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; width: 18 }
                                    Text { text: modelData.label; color: dash.inkDim; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; width: 70 }
                                    Text { text: modelData.value; color: dash.ink; font.pixelSize: 12; font.weight: Font.DemiBold; font.family: "JetBrainsMono Nerd Font" }
                                }
                            }
                        }
                    }
                }

                // ---------------- MUSIC PLAYER SECTION ----------------
                Column {
                    width: parent.width
                    spacing: 16
                    visible: dash.activeSection === "player"

                    Rectangle {
                        width: parent.width
                        height: mediaCol.height + 24
                        radius: 16
                        color: "#11FFFFFF"
                        visible: dash.activePlayer !== null

                        Column {
                            id: mediaCol
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 8

                            Text {
                                text: dash.playerTitle()
                                color: dash.ink
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                font.family: "JetBrainsMono Nerd Font"
                                width: parent.width
                                elide: Text.ElideRight
                            }
                            Text {
                                text: dash.playerArtist()
                                color: dash.inkDim
                                font.pixelSize: 11
                                font.family: "JetBrainsMono Nerd Font"
                                width: parent.width
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 18
                                anchors.horizontalCenter: parent.horizontalCenter

                                Text {
                                    text: "\uf048"
                                    color: dash.ink
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: dash.playerCtl("prev") }
                                }
                                Text {
                                    text: dash.playerIsPlaying() ? "\uf04c" : "\uf04b"
                                    color: dash.accentBright
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: dash.playerCtl("toggle") }
                                }
                                Text {
                                    text: "\uf051"
                                    color: dash.ink
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: dash.playerCtl("next") }
                                }
                            }
                        }
                    }

                    Text {
                        text: "No media playing"
                        color: dash.inkDim
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                        visible: dash.activePlayer === null
                    }
                }

                // ---------------- NOTIFICATION CENTER SECTION ----------------
                Column {
                    width: parent.width
                    spacing: 16
                    visible: dash.activeSection === "notifications"

                    Row {
                        width: parent.width
                        Text {
                            text: "Notifications"
                            color: dash.inkDim
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Item { width: parent.width - 170; height: 1 }
                        Text {
                            visible: notifModel.count > 0
                            text: "Clear all"
                            color: dash.accentBright
                            font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: dash.clearAllNotifications() }
                        }
                    }

                    Text {
                        visible: notifModel.count === 0
                        text: "No notifications"
                        color: dash.inkDim
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Repeater {
                        model: notifModel

                        Rectangle {
                            required property string summary
                            required property string body
                            required property string appName
                            required property int urgency
                            required property int notifId

                            width: content.width
                            height: notifCol.height + 20
                            radius: 14
                            color: "#11FFFFFF"
                            border.width: 1
                            border.color: dash.urgencyColor(urgency) + "44"

                            Column {
                                id: notifCol
                                anchors {
                                    left: parent.left
                                    right: closeBtn.left
                                    top: parent.top
                                    margins: 12
                                    rightMargin: 6
                                }
                                spacing: 3

                                Text {
                                    text: appName
                                    color: dash.urgencyColor(urgency)
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    font.family: "JetBrainsMono Nerd Font"
                                }
                                Text {
                                    text: summary
                                    color: dash.ink
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    font.family: "JetBrainsMono Nerd Font"
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    visible: body.length > 0
                                    text: body
                                    color: dash.inkDim
                                    font.pixelSize: 11
                                    font.family: "JetBrainsMono Nerd Font"
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                id: closeBtn
                                width: 20
                                height: 20
                                radius: 6
                                anchors { top: parent.top; right: parent.right; margins: 8 }
                                color: closeBtnHover.containsMouse ? "#1EFFFFFF" : "transparent"

                                Text { anchors.centerIn: parent; text: "\u2715"; color: dash.inkDim; font.pixelSize: 10 }

                                MouseArea {
                                    id: closeBtnHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: dash.dismissNotification(notifId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
