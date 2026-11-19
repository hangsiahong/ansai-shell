import QtQuick
import qs
import qs.services

// ansai: iOS battery, outlined body, level fill, nub; green while charging.
// material: Android 16 battery, a filled pill with the percentage printed inside.
Item {
    id: root
    property color ink: Theme.text
    implicitWidth: Theme.m3 ? 30 : 25
    implicitHeight: Theme.m3 ? 15 : 12

    readonly property color level: Battery.charging ? Theme.green : Battery.low ? Theme.danger : Theme.m3 ? ink : Theme.text

    Rectangle {
        id: body
        width: Theme.m3 ? 27 : 22; height: Theme.m3 ? 15 : 12; radius: Theme.m3 ? 5 : 3.5
        color: Theme.m3 ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.32) : "transparent"
        border.width: Theme.m3 ? 0 : 1
        border.color: Theme.faint
        clip: Theme.m3
        Rectangle {
            x: Theme.m3 ? 0 : 2; y: Theme.m3 ? 0 : 2
            height: parent.height - (Theme.m3 ? 0 : 4)
            width: Math.max(2, (parent.width - (Theme.m3 ? 0 : 4)) * Battery.pct)
            radius: Theme.m3 ? 0 : 2
            color: root.level
        }
        Txt {
            anchors.centerIn: parent
            visible: Theme.m3
            text: Battery.charging ? "" : Math.round(Battery.pct * 100)
            font.pixelSize: 10
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
            color: Theme.m3 && root.ink === Theme.accentInk ? Theme.accent : Theme.bg
        }
    }
    Rectangle {
        anchors { left: body.right; leftMargin: 1; verticalCenter: body.verticalCenter }
        width: Theme.m3 ? 2 : 1.5; height: Theme.m3 ? 6 : 4; radius: 1
        color: Theme.m3 ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.32) : Theme.faint
    }
    Icon {
        anchors.centerIn: body
        visible: Battery.charging
        name: "bolt"; filled: true; size: Theme.m3 ? 13 : 11
        color: Theme.m3 ? Theme.bg : Theme.dark ? "#000000" : "#ffffff"
    }
}
