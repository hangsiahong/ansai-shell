import QtQuick
import qs
import qs.components

// Wrapping choice chips for longer lists (resolutions, refresh rates, scales). model: [{ v, l, sub? }]
Flow {
    id: root
    property var model: []
    property var value
    signal picked(var v)
    width: parent ? parent.width : 300
    spacing: 6

    Repeater {
        model: root.model
        Hover {
            id: c
            required property var modelData
            readonly property bool on: root.value === modelData.v
            width: col.implicitWidth + 24
            height: Theme.m3 ? 36 : 30
            radius: Theme.m3 ? (on ? height / 2 : 10) : 8
            base: Theme.m3 ? "transparent" : Theme.fill2
            border.width: Theme.m3 && !on ? 1 : 0
            border.color: Theme.line
            active: on
            activeColor: Theme.m3 ? Theme.accentSoft : Theme.accent
            onClicked: root.picked(modelData.v)
            Column {
                id: col
                anchors.centerIn: parent
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: c.modelData.l
                    font.pixelSize: 12
                    font.weight: c.on ? Theme.strong : Font.Normal
                    font.features: { "tnum": 1 }
                    color: c.on ? (Theme.m3 ? Theme.accentSoftInk : Theme.accentInk) : Theme.text
                }
            }
        }
    }
}
