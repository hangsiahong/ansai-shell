import QtQuick
import qs

Column {
    id: root
    property bool on
    property string icon
    property string label
    property color onColor: Theme.accent
    signal clicked
    spacing: 6

    Hover {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 48; height: 48; radius: 24
        base: Theme.fill2
        active: root.on
        activeColor: root.onColor
        onClicked: root.clicked()
        Icon { anchors.centerIn: parent; name: root.icon; size: 22; filled: root.on; color: root.on ? "#ffffff" : Theme.text }
    }
    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        font.pixelSize: 11
        color: Theme.muted
    }
}
