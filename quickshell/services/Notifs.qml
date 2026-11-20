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
                n.tracked = true;
                const entry = { n: n, time: new Date(), popup: !Settings.dnd || n.urgency === NotificationUrgency.Critical };
                n.closed.connect(() => { root.list = root.list.filter(e => e.n !== n); });
                root.list = [entry, ...root.list].slice(0, 50);
            }
        }
    }
}
