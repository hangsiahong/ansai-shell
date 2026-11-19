import QtQuick
import qs

// ansai: iOS switch. material: M3 switch, outlined track when off, thumb grows and shows a check when on.
Item {
    id: root
    property bool checked
    signal toggled
    implicitWidth: Theme.m3 ? 52 : 44
    implicitHeight: Theme.m3 ? 32 : 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.m3 ? (root.checked ? Theme.accent : Theme.surface3) : root.checked ? Theme.green : Theme.fill
        border.width: Theme.m3 && !root.checked ? 2 : 0
        border.color: Theme.faint
        Behavior on color { ColorAnimation { duration: Theme.med } }

        Rectangle {
            property real d: Theme.m3 ? (ma.pressed ? 28 : root.checked ? 24 : 16) : parent.height - 4
            width: d
            height: d
            radius: d / 2
            y: (parent.height - d) / 2
            x: root.checked ? parent.width - d - (parent.height - d) / 2 : (parent.height - d) / 2
            color: Theme.m3 ? (root.checked ? Theme.accentInk : Theme.faint) : "#ffffff"
            Behavior on x { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
            Behavior on d { NumberAnimation { duration: Theme.fast; easing.type: Theme.spring } }
            Icon {
                anchors.centerIn: parent
                visible: Theme.m3 && root.checked
                name: "check"
                size: 16
                color: Theme.accent
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
