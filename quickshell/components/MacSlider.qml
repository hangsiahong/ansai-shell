import QtQuick
import qs

// macOS 27 Control Center slider: slim glass track, white fill, round knob, icon at the left.
Item {
    id: root
    property real value: 0
    property string icon
    signal moved(real v)
    implicitHeight: 24

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 24
        radius: 12
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
        Rectangle {
            width: Math.max(track.height, track.width * root.value)
            height: parent.height
            radius: height / 2
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.92) : "#ffffff"
            border.width: Theme.dark ? 0 : 1
            border.color: Qt.rgba(0, 0, 0, 0.06)
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
        }
        Icon {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 15
            filled: true
            color: "#5a5a5e"
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: m => root.moved(Math.max(0, Math.min(1, m.x / width)))
        onPositionChanged: m => { if (pressed) root.moved(Math.max(0, Math.min(1, m.x / width))); }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
