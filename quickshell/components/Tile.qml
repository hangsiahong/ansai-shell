import QtQuick
import qs

// Big two-line toggle tile (Wi-Fi, Bluetooth). Accent when on.
Hover {
    id: root
    property bool on
    property string icon
    property string title
    property string sub
    implicitHeight: 60
    radius: Theme.r
    base: Theme.fill2
    active: on
    activeColor: Theme.accent

    Rectangle {
        id: dot
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 36; height: 36; radius: 18
        color: root.on ? Qt.rgba(1, 1, 1, 0.22) : Theme.fill
        Icon { anchors.centerIn: parent; name: root.icon; size: 20; filled: true; color: root.on ? "#ffffff" : Theme.text }
    }
    Column {
        anchors { left: dot.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        Txt { width: parent.width; text: root.title; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.on ? "#ffffff" : Theme.text }
        Txt { width: parent.width; text: root.sub; font.pixelSize: 12; color: root.on ? Qt.rgba(1, 1, 1, 0.78) : Theme.muted; visible: text !== "" }
    }
}
