import QtQuick
import qs

// Big two-line toggle tile (Wi-Fi, Bluetooth). ansai: accent when on.
// material: Android 16 QS tile, pill when off, morphs to a rounded rect in primary when on.
Hover {
    id: root
    property bool on
    property string icon
    property string title
    property string sub
    property bool more: false       // shows a chevron that opens a list (networks, devices)
    property bool expanded: false
    signal expand
    implicitHeight: Theme.m3 ? 64 : 60
    radius: Theme.m3 ? (on ? 20 : height / 2) : Theme.r
    base: Theme.fill2
    active: on
    activeColor: Theme.accent
    scale: Theme.m3 && pressed ? 0.96 : 1
    Behavior on radius { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
    Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.spring } }

    readonly property color ink: on ? Theme.accentInk : Theme.text

    Rectangle {
        id: dot
        x: Theme.m3 ? 12 : 10
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.m3 ? 40 : 36; height: width
        radius: Theme.m3 && root.on ? 12 : width / 2
        color: Theme.m3
            ? (root.on ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14) : Theme.fill)
            : (root.on ? Qt.rgba(1, 1, 1, 0.22) : Theme.fill)
        Behavior on radius { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
        Icon { anchors.centerIn: parent; name: root.icon; size: 20; filled: true; color: root.ink }
    }
    Column {
        anchors { left: dot.right; leftMargin: 10; right: chev.visible ? chev.left : parent.right; rightMargin: chev.visible ? 2 : 12; verticalCenter: parent.verticalCenter }
        Txt { width: parent.width; text: root.title; font.pixelSize: 14; font.weight: Theme.strong; color: root.ink }
        Txt { width: parent.width; text: root.sub; font.pixelSize: 12; color: root.on ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.78) : Theme.muted; visible: text !== "" }
    }

    Hover {
        id: chev
        visible: root.more
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        width: 30; height: 40
        radius: 15
        onClicked: root.expand()
        Icon {
            anchors.centerIn: parent
            name: "chevron_right"
            size: 20
            color: root.ink
            rotation: root.expanded ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
        }
    }
}
