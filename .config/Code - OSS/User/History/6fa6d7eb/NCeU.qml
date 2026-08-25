pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: shared

    property bool dashboardOpen: false
    property string dashboardTab: "info"

    function toggleDashboard() {
        dashboardOpen = !dashboardOpen;
    }

    function openTab(tab) {
        dashboardTab = tab;
        dashboardOpen = true;
    }

    function openNotificationHistory() {
        openTab("history");
    }

    property ListModel toastQueue: ListModel {}
    property ListModel activeNotifications: ListModel {}
    property ListModel historyModel: ListModel {}

    readonly property int historyCap: 100

    function urgencyColor(urgency) {
        if (urgency === NotificationUrgency.Critical) return "#FF5C5C";
        if (urgency === NotificationUrgency.Low) return "#9CA3AF";
        return "#B388FF";
    }

    function urgencyLabel(urgency) {
        if (urgency === NotificationUrgency.Critical) return "\uf071";
        if (urgency === NotificationUrgency.Low) return "\uf0f3";
        return "\uf0a2";
    }

    function formatClock() {
        const d = new Date();
        let h = d.getHours();
        let m = d.getMinutes();
        return (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m);
    }

    function indexOfActive(notifId) {
        for (let i = 0; i < activeNotifications.count; i++) {
            if (activeNotifications.get(i).notifId === notifId) return i;
        }
        return -1;
    }

    function removeActive(notifId) {
        const idx = indexOfActive(notifId);
        if (idx !== -1) activeNotifications.remove(idx);
    }

    function dismissActive(notifId) {
        const idx = indexOfActive(notifId);
        if (idx === -1) return;
        const entry = activeNotifications.get(idx);
        if (entry.notifObj) entry.notifObj.dismiss();
        activeNotifications.remove(idx);
    }

    function invokeAction(notifId, actionIdentifier) {
        const idx = indexOfActive(notifId);
        if (idx === -1) return;
        const entry = activeNotifications.get(idx);
        if (!entry.notifObj || !entry.notifObj.actions) return;
        for (let i = 0; i < entry.notifObj.actions.length; i++) {
            const act = entry.notifObj.actions[i];
            if (act.identifier === actionIdentifier) {
                act.invoke();
                break;
            }
        }
        removeActive(notifId);
    }

    function clearActive() {
        for (let i = activeNotifications.count - 1; i >= 0; i--) {
            const entry = activeNotifications.get(i);
            if (entry.notifObj) entry.notifObj.dismiss();
        }
        activeNotifications.clear();
    }

    function clearHistory() {
        historyModel.clear();
    }

    property NotificationServer notifServer: NotificationServer {
        actionsSupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;

            let actionList = [];
            if (notification.actions) {
                for (let i = 0; i < notification.actions.length; i++) {
                    actionList.push({
                        identifier: notification.actions[i].identifier,
                        text: notification.actions[i].text
                    });
                }
            }

            const entry = {
                notifId: notification.id,
                appName: notification.appName && notification.appName.length > 0 ? notification.appName : "Notification",
                appIcon: notification.appIcon || "",
                summary: notification.summary || "",
                body: notification.body || "",
                urgencyValue: notification.urgency,
                timestamp: shared.formatClock(),
                notifObj: notification,
                notifActions: actionList
            };

            shared.toastQueue.append(entry);
            shared.activeNotifications.insert(0, entry);
            shared.historyModel.insert(0, entry);
            while (shared.historyModel.count > shared.historyCap) {
                shared.historyModel.remove(shared.historyModel.count - 1);
            }

            notification.closed.connect(reason => {
                shared.removeActive(notification.id);
            });
        }
    }
}
