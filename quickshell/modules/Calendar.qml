import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Clock dropdown: month calendar + notification history.
Sheet {
    id: root
    name: "calendar"
    panelWidth: 380
    // ansai (macOS) has the clock at the far right of the menu bar.
    panelX: Theme.m3 ? (width - panelWidth) / 2 : width - panelWidth - 8
    panelHeight: Math.min(height - 60, col.implicitHeight + 24)

    property date month: new Date()
    onShownChanged: if (shown) month = new Date()

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 12 }
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: cal.implicitHeight + 24
            radius: Theme.r
            color: Theme.fill2

            ColumnLayout {
                id: cal
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                RowLayout {
                    Txt {
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.month, "MMMM yyyy")
                        font.pixelSize: 16
                        font.weight: Font.Bold
                    }
                    IconButton { icon: "chevron_left"; iconColor: Theme.accent; implicitWidth: 28; implicitHeight: 28
                        onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() - 1, 1) }
                    IconButton { icon: "chevron_right"; iconColor: Theme.accent; implicitWidth: 28; implicitHeight: 28
                        onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 1) }
                }

                Grid {
                    Layout.fillWidth: true
                    columns: 7
                    readonly property real cell: (cal.width) / 7
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        Txt {
                            required property string modelData
                            width: parent.cell; height: 22
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.pixelSize: 11; font.weight: Theme.strong
                            color: Theme.faint
                        }
                    }
                    Repeater {
                        model: {
                            const y = root.month.getFullYear(), m = root.month.getMonth();
                            const first = (new Date(y, m, 1).getDay() + 6) % 7;
                            const days = new Date(y, m + 1, 0).getDate();
                            const out = [];
                            for (let i = 0; i < 42; i++) {
                                const d = new Date(y, m, i - first + 1);
                                out.push({ d: d.getDate(), inMonth: d.getMonth() === m, today: d.toDateString() === Time.now.toDateString() });
                            }
                            return out.slice(0, Math.ceil((first + days) / 7) * 7);
                        }
                        Item {
                            required property var modelData
                            width: parent.cell; height: 34
                            Rectangle {
                                anchors.centerIn: parent
                                width: 30; height: 30; radius: 15
                                color: modelData.today ? (Theme.m3 ? Theme.accent : Theme.danger) : "transparent"
                            }
                            Txt {
                                anchors.centerIn: parent
                                text: modelData.d
                                font.pixelSize: 14
                                font.weight: modelData.today ? Font.Bold : Font.Normal
                                font.features: { "tnum": 1 }
                                color: modelData.today ? Theme.accentInk : modelData.inMonth ? Theme.text : Theme.faint
                            }
                        }
                    }
                }
            }
        }

        Rectangle {   // weather (Settings → Appearance → Weather)
            visible: Weather.enabled && Weather.current !== null
            Layout.fillWidth: true
            Layout.preferredHeight: wcol.implicitHeight + 24
            radius: Theme.r
            color: Theme.fill2
            ColumnLayout {
                id: wcol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10
                RowLayout {
                    spacing: 10
                    Icon {
                        readonly property var lk: Weather.current ? Weather.look(Weather.current.code, Weather.current.day) : ["cloud", ""]
                        name: lk[0]; size: 34; filled: true
                        color: Theme.accent
                    }
                    Txt { text: (Weather.current?.temp ?? "") + "°"; font.pixelSize: 30; font.weight: Font.Light }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt { Layout.fillWidth: true; text: Weather.current ? Weather.look(Weather.current.code, Weather.current.day)[1] : ""; font.pixelSize: 13; font.weight: Theme.strong }
                        Txt { Layout.fillWidth: true; text: Weather.place; font.pixelSize: 12; color: Theme.muted }
                    }
                    Txt {
                        visible: Weather.days.length > 0
                        text: Weather.days.length ? "H " + Weather.days[0].max + "°  L " + Weather.days[0].min + "°" : ""
                        font.pixelSize: 12; color: Theme.muted; font.features: { "tnum": 1 }
                    }
                }
                Row {
                    id: fc
                    Layout.fillWidth: true
                    Repeater {
                        model: Weather.days.slice(1, 5)
                        Column {
                            required property var modelData
                            width: fc.width / 4
                            spacing: 3
                            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd"); font.pixelSize: 11; color: Theme.muted }
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.look(modelData.code, true)[0]; size: 20; color: Theme.text2 }
                            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.max + "°  <font color='" + Theme.muted + "'>" + modelData.min + "°</font>"; textFormat: Text.StyledText; font.pixelSize: 11; font.features: { "tnum": 1 } }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Txt {
                Layout.fillWidth: true
                text: "NOTIFICATIONS"
                font.pixelSize: 12; font.weight: Theme.strong; font.letterSpacing: 0.4
                color: Theme.muted
            }
            Hover {
                visible: Notifs.list.length > 0
                Layout.preferredHeight: 24
                Layout.preferredWidth: clr.implicitWidth + 16
                radius: 12
                base: Theme.fill
                onClicked: Notifs.clear()
                Txt { id: clr; anchors.centerIn: parent; text: "Clear"; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.text2 }
            }
        }

        Txt {
            visible: Notifs.list.length === 0
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            horizontalAlignment: Text.AlignHCenter
            text: Notifs.quiet ? "Focus is on · notifications are silent" : "No notifications"
            color: Theme.faint
            font.pixelSize: 13
        }

        ListView {
            visible: Notifs.list.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: Math.min(contentHeight, 420)
            clip: true
            spacing: 8
            // Grouped per app, newest group first; a group of several shows its newest card over a stack until opened.
            property var open: ({})
            model: {
                const g = [], at = {};
                for (const e of Notifs.list) {
                    const k = e.n?.appName || "Notification";
                    if (at[k] === undefined) { at[k] = g.length; g.push({ app: k, entries: [] }); }
                    g[at[k]].entries.push(e);
                }
                return g;
            }
            boundsBehavior: Flickable.StopAtBounds
            delegate: Column {
                id: grp
                required property var modelData
                readonly property int count: modelData.entries.length
                readonly property bool expanded: count === 1 || ListView.view.open[modelData.app] === true
                width: ListView.view.width
                spacing: 6

                RowLayout {
                    visible: grp.count > 1
                    width: parent.width
                    Txt {
                        Layout.fillWidth: true
                        leftPadding: 4
                        text: grp.modelData.app + "  ·  " + grp.count
                        font.pixelSize: 12; font.weight: Theme.strong; color: Theme.muted
                    }
                    Hover {
                        Layout.preferredHeight: 22
                        Layout.preferredWidth: lessTxt.implicitWidth + 16
                        radius: 11
                        base: Theme.fill
                        onClicked: {
                            const lv = grp.ListView.view, o = Object.assign({}, lv.open);
                            o[grp.modelData.app] = !grp.expanded;
                            lv.open = o;
                        }
                        Txt { id: lessTxt; anchors.centerIn: parent; text: grp.expanded ? "Show less" : "Show all"; font.pixelSize: 11; color: Theme.text2 }
                    }
                    IconButton {
                        implicitWidth: 22; implicitHeight: 22
                        icon: "close"; iconSize: 14; iconColor: Theme.muted
                        onClicked: grp.modelData.entries.forEach(e => Notifs.dismiss(e))
                    }
                }
                Item {
                    width: parent.width
                    height: top.height + (grp.expanded ? 0 : Math.min(grp.count - 1, 2) * 7)
                    Repeater {   // the stack's edges peeking out under the newest card
                        model: grp.expanded ? 0 : Math.min(grp.count - 1, 2)
                        Rectangle {
                            required property int index
                            x: (index + 1) * 10; width: parent.width - x * 2
                            y: top.height - 20 + (index + 1) * 7; height: 20
                            z: -index - 1
                            radius: 12
                            color: Theme.m3 ? Theme.surface2 : Theme.glassTile
                            opacity: 0.8 - index * 0.25
                        }
                    }
                    NotifCard {
                        id: top
                        width: parent.width
                        entry: grp.modelData.entries[0]
                    }
                }
                Repeater {
                    model: grp.expanded ? grp.modelData.entries.slice(1) : []
                    NotifCard {
                        required property var modelData
                        entry: modelData
                        width: grp.width
                    }
                }
            }
        }
    }
}
