import QtQuick
import qs

// Row in the connectivity module: the circle toggles, the text opens the list.
Item {
    id: root
    property bool on
    property string icon
    property string title
    property string sub
    property bool expanded: false
    signal toggle
    signal expand
    implicitHeight: 40

    Hover {
        id: circle
        anchors.verticalCenter: parent.verticalCenter
        width: 30; height: 30; radius: 15
        base: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
        active: root.on
        activeColor: Theme.accent
        onClicked: root.toggle()
        Icon { anchors.centerIn: parent; name: root.icon; size: 17; filled: true; color: root.on ? "#ffffff" : Theme.text }
    }
    Hover {
        anchors { left: circle.right; leftMargin: 4; right: parent.right; top: parent.top; bottom: parent.bottom }
        radius: 9
        active: root.expanded
        activeColor: Theme.hover
        onClicked: root.expand()
        Column {
            anchors { left: parent.left; leftMargin: 6; right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            Txt { width: parent.width; text: root.title; font.pixelSize: 13; font.weight: Font.DemiBold }
            Txt { width: parent.width; text: root.sub; font.pixelSize: 11; color: Theme.muted; visible: text !== "" }
        }
    }
}
