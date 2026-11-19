import QtQuick
import qs
import qs.services

// iOS-style battery: outlined body, level fill, nub; green while charging.
Item {
    implicitWidth: 25
    implicitHeight: 12

    Rectangle {
        id: body
        width: 22; height: 12; radius: 3.5
        color: "transparent"
        border.width: 1
        border.color: Theme.faint
        Rectangle {
            x: 2; y: 2
            height: parent.height - 4
            width: Math.max(2, (parent.width - 4) * Battery.pct)
            radius: 2
            color: Battery.charging ? Theme.green : Battery.low ? Theme.danger : Theme.text
        }
    }
    Rectangle {
        anchors { left: body.right; leftMargin: 1; verticalCenter: body.verticalCenter }
        width: 1.5; height: 4; radius: 1
        color: Theme.faint
    }
    Icon {
        anchors.centerIn: body
        visible: Battery.charging
        name: "bolt"; filled: true; size: 11
        color: Theme.dark ? "#000000" : "#ffffff"
    }
}
