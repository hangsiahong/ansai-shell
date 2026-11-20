pragma Singleton

import QtQuick
import qs
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    // Newest first. Each entry: { n: Notification, time: Date, popup: bool }
    property var list: []
    readonly property var popups: list.filter(e => e.popup)

    // Do Not Disturb: the manual switch, or inside the daily schedule (which may cross midnight).
    readonly property int minute: Time.now.getHours() * 60 + Time.now.getMinutes()
    readonly property bool scheduled: Settings.dndSchedule && (Settings.dndFrom <= Settings.dndTo
        ? minute >= Settings.dndFrom && minute < Settings.dndTo : minute >= Settings.dndFrom || minute < Settings.dndTo)
    readonly property bool quiet: Settings.dnd || scheduled

    function appMode(name: string): string { return Settings.notifApps[name] ?? "on"; }
    function setAppMode(name: string, mode: string): void {
        const m = Object.assign({}, Settings.notifApps);
        m[name] = mode;
        Settings.notifApps = m;
    }

    // Cards get a copy of their entry (Repeater modelData), so match entries by their notification.
    function dismiss(entry: var): void {
        list = list.filter(e => e.n !== entry.n);
        entry.n?.dismiss?.();
    }

    function hidePopup(entry: var): void {
        list = list.map(e => e.n === entry.n ? Object.assign({}, e, { popup: false }) : e);
    }

    function clear(): void {
        for (const e of list)
            e.n?.dismiss?.();
        list = [];
    }

    Loader {
        active: !Shell.nested
        sourceComponent: NotificationServer {
            keepOnReload: false
            actionsSupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            imageSupported: true
            persistenceSupported: true

            onNotification: n => {
                const app = n.appName || "";
                if (app && !(app in Settings.notifApps)) root.setAppMode(app, "on");
                const mode = root.appMode(app);
                if (mode === "off" && n.urgency !== NotificationUrgency.Critical) return;   // untracked: dropped
                n.tracked = true;
                const entry = { n: n, time: new Date(), popup: n.urgency === NotificationUrgency.Critical || (!root.quiet && mode === "on") };
                n.closed.connect(() => { root.list = root.list.filter(e => e.n !== n); });
                root.list = [entry, ...root.list].slice(0, 50);
            }
        }
    }
}
