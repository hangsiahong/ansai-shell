import QtQuick
import qs

// ansai: iOS control-center slider, thick rounded track with a white fill and the icon inside.
// material: M3 Expressive slider, primary active track, a gap, a bar handle, tonal rest track with a stop dot.
Item {
    id: root
    property real value: 0
    property string icon
    signal moved(real v)

    implicitHeight: Theme.m3 ? 44 : 32

    // ---- ansai
    Rectangle {
        id: track
        visible: !Theme.m3
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

    // ---- material
    Item {
        id: m3
        visible: Theme.m3
        anchors.fill: parent
        readonly property real gap: 6
        readonly property real handleW: ma.pressed ? 2 : 4
        readonly property real th: 40   // track height
        readonly property real minActive: th
        // Handle centre, kept so the active part is at least a circle wide.
        property real hx: Math.max(minActive + gap, Math.min(width - 2, minActive + gap + (width - minActive - gap - 2) * root.value))
        Behavior on hx { enabled: !ma.pressed; NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }

        // Active track: outer corners round, inner corner tight (M3E "inside corner").
        Rectangle {
            id: act
            anchors.verticalCenter: parent.verticalCenter
            width: m3.hx - m3.gap
            height: m3.th
            radius: m3.th / 2
            color: Theme.accent
            Rectangle {
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: Math.min(parent.width / 2, m3.th / 2)
                radius: 4
                color: parent.color
            }
            Icon {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon
                size: 18
                filled: true
                color: Theme.accentInk
            }
        }
        Rectangle {
            id: rest
            anchors.verticalCenter: parent.verticalCenter
            x: m3.hx + m3.gap
            width: Math.max(0, parent.width - x)
            height: m3.th
            radius: m3.th / 2
            color: Theme.tonal
            visible: width > 0
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.min(parent.width / 2, m3.th / 2)
                radius: 4
                color: parent.color
            }
            Rectangle {   // stop indicator
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                width: 4; height: 4; radius: 2
                color: Theme.accent
                visible: parent.width > 28
            }
        }
        Rectangle {
            x: m3.hx - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: m3.handleW
            height: parent.height
            radius: width / 2
            color: Theme.accent
            Behavior on width { NumberAnimation { duration: Theme.fast } }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function upd(x) {
            const lo = Theme.m3 ? m3.minActive + m3.gap : 0;
            const hi = Theme.m3 ? width - 2 : width;
            root.moved(Math.max(0, Math.min(1, (x - lo) / (hi - lo))));
        }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x); }
        onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
