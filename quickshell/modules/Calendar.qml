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
                            font.pixelSize: 11; font.weight: Font.DemiBold
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
                                color: modelData.today ? Theme.danger : "transparent"
                            }
                            Txt {
                                anchors.centerIn: parent
                                text: modelData.d
                                font.pixelSize: 14
                                font.weight: modelData.today ? Font.Bold : Font.Normal
                                font.features: { "tnum": 1 }
                                color: modelData.today ? "#ffffff" : modelData.inMonth ? Theme.text : Theme.faint
                            }
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
                font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.4
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
            text: Settings.dnd ? "Focus is on · notifications are silent" : "No notifications"
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
            model: Notifs.list
            boundsBehavior: Flickable.StopAtBounds
            delegate: NotifCard {
                required property var modelData
                entry: modelData
                width: ListView.view.width
            }
        }
    }
}
