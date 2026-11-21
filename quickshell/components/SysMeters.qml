import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// CPU, memory, swap and disk as labelled thin bars (Control Center, System widget).
GridLayout {
    id: root
    columns: 2
    columnSpacing: 14
    rowSpacing: 8
    readonly property var rows: [
        ["CPU", SysStats.cpu, Math.round(SysStats.cpu * 100) + "%"],
        ["Memory", SysStats.mem, SysStats.gb(SysStats.memUsed, false) + " / " + SysStats.gb(SysStats.memTotal)],
        ["Swap", SysStats.swap, SysStats.swapTotal ? SysStats.gb(SysStats.swapUsed, false) + " / " + SysStats.gb(SysStats.swapTotal) : "Off"],
        ["Disk", SysStats.disk, SysStats.diskTotal ? SysStats.gb(SysStats.diskTotal - SysStats.diskUsed) + " free" : ""]
    ]
    Repeater {
        model: root.rows.length
        Column {
            id: m
            required property int index
            readonly property var r: root.rows[index]
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 4
            Item {
                width: parent.width
                height: lab.implicitHeight
                Txt { id: lab; text: m.r[0]; font.pixelSize: 11; font.weight: Theme.strong; color: Theme.text2 }
                Txt { anchors.right: parent.right; text: m.r[2]; font.pixelSize: 11; color: Theme.muted; font.features: { "tnum": 1 } }
            }
            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
                Rectangle {
                    width: Math.max(height, parent.width * m.r[1])
                    height: parent.height
                    radius: 2
                    color: m.r[1] > 0.9 ? Theme.danger : m.r[1] > 0.75 ? Theme.warn : Theme.accent
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
