import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import "settings"

// Ask Ansai → Scheduled: add or edit one task (AI.saveSchedule). The next run is checked by agent/schedule.mjs as you type.
Item {
    id: root
    property var task: null        // a copy being edited; null hides the editor
    signal closed()
    readonly property var t: task ?? AI.newSchedule()
    property var check: ({})
    property bool picking: false
    readonly property bool timed: ["daily", "weekdays", "weekly"].includes(t.kind)
    readonly property bool timeOk: !timed || /^([01]?\d|2[0-3]):[0-5]\d$/.test(t.time ?? "")
    readonly property bool canSave: !!(t.name ?? "").trim() && !!(t.prompt ?? "").trim() && timeOk && !!check.cal
    readonly property var allModels: (AI.hasKey ? AI.models.map(m => ({ v: m, l: m })) : [])
        .concat(...[...new Set(AI.accounts.map(a => a.provider))].map(p => (AI.catalogModels[p] ?? []).map(m => ({ v: p + "/" + m.id, l: m.id + " · " + AI.providerName(p) }))))

    function set(v): void { task = Object.assign({}, t, v); }
    onTaskChanged: if (task) checkT.restart()
    Timer { id: checkT; interval: 250; onTriggered: { chk.command = ["node", AI.schedScript, "check", JSON.stringify({ kind: root.t.kind, time: root.t.time, day: root.t.day, cron: root.t.cron })]; chk.running = true; } }
    Process {
        id: chk
        stdout: StdioCollector { onStreamFinished: { try { root.check = JSON.parse(text); } catch (e) { root.check = { e: "Couldn't check the schedule" }; } } }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: col
            x: Math.max(0, (parent.width - width) / 2)
            width: Math.min(parent.width, 600)
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 8
                IconButton { icon: "arrow_back"; iconSize: 19; iconColor: Theme.text2; onClicked: root.closed() }
                Txt { Layout.fillWidth: true; text: root.t.id ? "Edit scheduled task" : "New scheduled task"; font.pixelSize: 15; font.weight: Theme.strong }
                IconButton {
                    visible: !!root.t.id
                    icon: "delete"; iconSize: 18; iconColor: Theme.muted
                    onClicked: { AI.deleteSchedule(root.t.id); root.closed(); }
                }
            }

            Lbl { text: "Name" }
            Field {
                id: nameF
                Layout.fillWidth: true
                placeholder: "Morning brief"
                text: root.t.name
                onTextChanged: if (text !== root.t.name) root.set({ name: text })
            }

            Lbl { text: "What should it do?" }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(110, promptE.implicitHeight + 20)
                radius: Theme.m3 ? 20 : 8
                color: Theme.m3 ? Theme.surface3 : Theme.fill2
                TextEdit {
                    id: promptE
                    anchors { fill: parent; margins: 10; leftMargin: 12; rightMargin: 12 }
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentInk
                    font.family: Theme.font
                    font.pixelSize: 13
                    text: root.t.prompt
                    onTextChanged: if (text !== root.t.prompt) root.set({ prompt: text })
                    Txt {
                        visible: !promptE.text
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "e.g. Check my KOOMPI Cloud usage and tell me if anything is close to its limit."
                        color: Theme.faint; font.pixelSize: 13
                    }
                }
            }

            Lbl { text: "Repeats" }
            Seg {
                model: [{ v: "hourly", l: "Hourly" }, { v: "daily", l: "Daily" }, { v: "weekdays", l: "Weekdays" }, { v: "weekly", l: "Weekly" }, { v: "custom", l: "Custom" }]
                value: root.t.kind
                onPicked: v => root.set({ kind: v })
            }
            Seg {
                visible: root.t.kind === "weekly"
                small: true
                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map(d => ({ v: d, l: d }))
                value: root.t.day
                onPicked: v => root.set({ day: v })
            }
            RowLayout {
                visible: root.timed
                spacing: 10
                Txt { text: "At"; font.pixelSize: 13; color: Theme.text2 }
                Field {
                    implicitWidth: 90
                    placeholder: "08:00"
                    text: root.t.time
                    onTextChanged: if (text !== root.t.time) root.set({ time: text.trim() })
                }
                Txt { visible: !root.timeOk; text: "Use 24-hour time, like 07:30"; font.pixelSize: 12; color: Theme.danger }
            }
            Field {
                visible: root.t.kind === "custom"
                Layout.fillWidth: true
                placeholder: "cron, like 0 9 * * 1-5 — or systemd OnCalendar, like Sat *-*-* 10:00"
                text: root.t.cron
                onTextChanged: if (text !== root.t.cron) root.set({ cron: text })
            }
            Txt {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: 12
                color: root.check.e && root.timeOk ? Theme.danger : Theme.muted
                text: !root.timeOk ? "" : root.check.e ? root.check.e
                    : root.check.at ? "Next run: " + Qt.formatDateTime(new Date(root.check.at), Settings.use24h ? "dddd d MMM, HH:mm" : "dddd d MMM, h:mm AP") + ". If the laptop is off then, it runs when it's back." : ""
            }

            Lbl { text: "Model" }
            Hover {
                Layout.fillWidth: true
                implicitHeight: Theme.m3 ? 40 : 30
                radius: Theme.m3 ? 20 : 8
                base: Theme.m3 ? Theme.surface3 : Theme.fill2
                onClicked: root.picking = !root.picking
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                    Txt {
                        Layout.fillWidth: true
                        font.pixelSize: 13
                        text: (root.t.model.includes("/") ? root.t.model.slice(root.t.model.indexOf("/") + 1) + " · " + AI.providerName(root.t.model.split("/")[0]) : root.t.model)
                    }
                    Icon { name: root.picking ? "expand_less" : "expand_more"; size: 16; color: Theme.muted }
                }
            }
            Rectangle {
                visible: root.picking
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(mcol.implicitHeight + 8, 220)
                radius: Theme.m3 ? 16 : 8
                color: Theme.surface2
                border.width: 1
                border.color: Theme.line
                Flickable {
                    anchors { fill: parent; margins: 4 }
                    contentHeight: mcol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ColumnLayout {
                        id: mcol
                        width: parent.width
                        spacing: 0
                        Repeater {
                            model: root.allModels
                            MenuItem {
                                required property var modelData
                                label: modelData.l
                                hint: root.t.model === modelData.v ? "✓" : ""
                                onClicked: { root.set({ model: modelData.v, account: modelData.v.includes("/") ? root.t.account : "" }); root.picking = false; }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Txt { text: "Act without asking"; font.pixelSize: 13; font.weight: Theme.strong }
                    Txt {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                        color: Theme.muted
                        text: root.t.act ? "On: it works on its own. Commands, file changes, messages and other actions run right away."
                                         : "Off: it only looks things up. Actions are declined, and the result says what it would have done."
                    }
                }
                Switch { checked: root.t.act; onToggled: root.set({ act: !root.t.act }) }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                Item { Layout.fillWidth: true }
                Btn { text: "Cancel"; onClicked: root.closed() }
                Btn {
                    text: "Save"
                    kind: "filled"
                    enabled: root.canSave
                    opacity: enabled ? 1 : 0.45
                    onClicked: { AI.saveSchedule(Object.assign({}, root.t, { name: root.t.name.trim(), prompt: root.t.prompt.trim() })); root.closed(); }
                }
            }
        }
    }

    component Lbl: Txt { font.pixelSize: 12; font.weight: Theme.strong; color: Theme.text2; Layout.bottomMargin: -8 }
}
