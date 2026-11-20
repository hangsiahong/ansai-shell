import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 22

    function hm(m) {
        const d = new Date(2000, 0, 1, Math.floor(m / 60), m % 60);
        return Qt.formatTime(d, Settings.use24h ? "HH:mm" : "h:mm AP");
    }
    readonly property var apps: Object.keys(Settings.notifApps).sort((a, b) => a.localeCompare(b))

    // Apps with notifications from before this page existed.
    Component.onCompleted: {
        for (const e of Notifs.list) if (e.n?.appName && !(e.n.appName in Settings.notifApps)) Notifs.setAppMode(e.n.appName, "on");
    }

    SGroup {
        title: "Focus"
        note: "Critical alerts (low battery and the like) still pop up."
        SRow {
            first: true
            icon: "do_not_disturb_on"
            title: "Do Not Disturb"
            sub: Settings.dnd ? "On: notifications are silent" : Notifs.scheduled ? "On by schedule until " + root.hm(Settings.dndTo) : "Notifications pop up"
            Switch { checked: Settings.dnd; onToggled: Settings.dnd = !Settings.dnd }
        }
        SRow {
            icon: "schedule"
            title: "Scheduled"
            sub: "Turn on every day, e.g. overnight"
            Switch { checked: Settings.dndSchedule; onToggled: Settings.dndSchedule = !Settings.dndSchedule }
        }
        SRow {
            visible: Settings.dndSchedule
            icon: "bedtime"
            title: "From"
            TimeStep { key: "dndFrom" }
        }
        SRow {
            visible: Settings.dndSchedule
            icon: "wb_sunny"
            title: "To"
            TimeStep { key: "dndTo" }
        }
    }

    SGroup {
        title: "Apps"
        note: root.apps.length ? "Silent: kept in the list without a pop-up. Off: dropped." : ""
        SRow {
            visible: !root.apps.length
            first: true
            icon: "notifications"
            title: "No apps yet"
            sub: "Apps show up here after their first notification"
        }
        Repeater {
            model: root.apps
            SRow {
                id: ar
                required property string modelData
                required property int index
                first: index === 0
                readonly property var entry: DesktopEntries.applications.values.find(e => e.name.toLowerCase() === modelData.toLowerCase())
                    ?? DesktopEntries.heuristicLookup(modelData)
                title: entry?.name ?? modelData
                icon: "\u200b"   // keeps the icon column; the app's own icon sits on top
                AppIcon {
                    parent: ar
                    x: 15; anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    icon: ar.entry?.icon ?? ""
                    label: ar.modelData
                }
                Seg {
                    model: [{ v: "on", l: "On" }, { v: "silent", l: "Silent" }, { v: "off", l: "Off" }]
                    value: Notifs.appMode(ar.modelData)
                    onPicked: v => Notifs.setAppMode(ar.modelData, v)
                }
            }
        }
    }
}
