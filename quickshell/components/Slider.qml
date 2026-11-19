import QtQuick
import qs

// iOS control-center slider: thick rounded track, white fill, icon inside.
Item {
    id: root
    property real value: 0
    property string icon
    signal moved(real v)

    implicitHeight: 32

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.fill
        clip: true

        Rectangle {
            width: Math.max(track.height, track.width * root.value)
            height: parent.height
            radius: height / 2
            color: Theme.dark ? "#ffffff" : Theme.accent
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
        }

        Icon {
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: 17
            filled: true
            color: Theme.dark ? "#1c1c1e" : "#ffffff"
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function upd(x) { root.moved(Math.max(0, Math.min(1, x / width))); }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x); }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
