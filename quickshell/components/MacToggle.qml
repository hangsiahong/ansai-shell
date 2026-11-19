import QtQuick
import qs

// Module with one circle toggle and a label (Focus, Dark Mode…): 2×1 (wide) or 1×1 (icon over label).
MacModule {
    id: root
    property bool on
    property string icon
    property string label
    property string sub
    property bool wide: true
    property color onColor: Theme.accent
    signal clicked
    implicitHeight: wide || !label ? 52 : 74

    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }

    Rectangle {
        id: c
        x: root.wide ? 11 : (parent.width - width) / 2
        y: root.wide || !root.label ? (parent.height - height) / 2 : 10
        width: 30; height: 30; radius: 15
        color: root.on ? root.onColor : Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Icon { anchors.centerIn: parent; name: root.icon; size: 17; filled: root.on; color: root.on ? "#ffffff" : Theme.text }
    }
    Column {
        visible: root.wide
        anchors { left: c.right; leftMargin: 10; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        Txt { width: parent.width; text: root.label; font.pixelSize: 13; font.weight: Font.DemiBold }
        Txt { width: parent.width; text: root.sub; font.pixelSize: 11; color: Theme.muted; visible: text !== "" }
    }
    Txt {
        visible: !root.wide && !!root.label
        anchors { horizontalCenter: parent.horizontalCenter; top: c.bottom; topMargin: 6 }
        width: parent.width - 8
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        font.pixelSize: 11
        color: Theme.text2
    }
}
