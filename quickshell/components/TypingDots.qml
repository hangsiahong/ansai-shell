import QtQuick
import qs

// Three dots rising and brightening in a wave: an answer is on its way.
Row {
    id: root
    property color color: Theme.text
    property int size: 6
    property real phase: 0
    spacing: Math.round(size * 0.6)
    height: size * 2

    NumberAnimation on phase { from: 0; to: 1; duration: 1100; loops: Animation.Infinite; running: root.visible }

    Repeater {
        model: 3
        Rectangle {
            required property int index
            readonly property real k: Math.max(0, Math.sin(2 * Math.PI * (((root.phase - index * 0.16) % 1 + 1) % 1)))
            anchors.verticalCenter: parent.verticalCenter
            width: root.size
            height: root.size
            radius: root.size / 2
            color: root.color
            opacity: 0.3 + 0.7 * k
            scale: 0.85 + 0.25 * k
            transform: Translate { y: -k * root.size * 0.5 }
        }
    }
}
