import QtQuick
import QtQuick.Layouts
import qs

// Row in the control center's Wi-Fi / Bluetooth lists.
Hover {
    id: root
    property string icon
    property string title
    property string sub
    property bool current: false
    property bool busy: false
    property string trailingIcon
    default property alias extra: below.data
    Layout.fillWidth: true
    implicitHeight: 44 + below.implicitHeight
    radius: Theme.m3 ? 22 : 10
    base: current ? (Theme.m3 ? Theme.accentSoft : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)) : "transparent"

    RowLayout {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12 }
        height: 44
        spacing: 12
        Icon { name: root.icon; size: 20; filled: root.current; color: root.current ? (Theme.m3 ? Theme.accentSoftInk : Theme.accent) : Theme.text2 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Txt { Layout.fillWidth: true; text: root.title; font.pixelSize: 13; font.weight: root.current ? Theme.strong : Font.Normal; color: root.current && Theme.m3 ? Theme.accentSoftInk : Theme.text }
            Txt { Layout.fillWidth: true; visible: !!root.sub; text: root.sub; font.pixelSize: 11; color: root.current && Theme.m3 ? Theme.accentSoftInk : Theme.muted }
        }
        Icon {
            visible: !!root.trailingIcon && !root.busy
            name: root.trailingIcon
            size: 16
            color: Theme.muted
        }
        Icon {
            visible: root.busy
            name: "progress_activity"
            size: 18
            color: Theme.accent
            RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
        }
    }
    Item {
        id: below
        anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: 12; rightMargin: 12 }
        // childrenRect counts hidden children too, so measure only the visible ones.
        implicitHeight: {
            let h = 0;
            for (const c of children) if (c.visible) h = Math.max(h, c.y + c.height);
            return h ? h + 10 : 0;
        }
    }
}
