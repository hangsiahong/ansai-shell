import QtQuick
import qs

// iOS switch, 51x31 like UISwitch.
Item {
    id: root
    property bool checked
    signal toggled
    implicitWidth: 44
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.green : Theme.fill
        Behavior on color { ColorAnimation { duration: Theme.med } }

        Rectangle {
            width: parent.height - 4
            height: width
            radius: width / 2
            y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
