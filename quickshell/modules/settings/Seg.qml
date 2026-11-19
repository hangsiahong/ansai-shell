import QtQuick
import qs
import qs.components

// Segmented control (ansai) / connected button group (Android). model: [{ v, l, icon? }]
Rectangle {
    id: root
    property var model: []
    property var value
    property bool small: false
    signal picked(var v)

    implicitWidth: row.implicitWidth + (Theme.m3 ? 0 : 4)
    implicitHeight: Theme.m3 ? (small ? 34 : 40) : (small ? 26 : 30)
    radius: Theme.m3 ? height / 2 : 9
    color: Theme.m3 ? "transparent" : Theme.fill

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.m3 ? 2 : 0
        Repeater {
            model: root.model
            Hover {
                id: b
                required property var modelData
                required property int index
                readonly property bool on: root.value === modelData.v
                readonly property bool firstB: index === 0
                readonly property bool lastB: index === root.model.length - 1
                width: lbl.implicitWidth + (ic.visible ? ic.width + 6 : 0) + (Theme.m3 ? 28 : 22)
                height: root.height - (Theme.m3 ? 0 : 4)
                radius: Theme.m3 ? (on ? height / 2 : 8) : 7
                base: Theme.m3 ? Theme.surface3 : "transparent"
                active: on
                activeColor: Theme.m3 ? Theme.accent : Theme.seg
                Behavior on radius { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                onClicked: root.picked(modelData.v)
                // M3 connected group: outer corners stay round.
                Rectangle {
                    visible: Theme.m3 && !b.on && (b.firstB || b.lastB)
                    anchors { top: parent.top; bottom: parent.bottom; left: b.firstB ? parent.left : undefined; right: b.lastB ? parent.right : undefined }
                    width: parent.height / 2
                    radius: parent.height / 2
                    color: parent.color
                    z: -1
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon {
                        id: ic
                        visible: !!b.modelData.icon || (Theme.m3 && b.on)
                        name: b.modelData.icon || "check"
                        size: 16
                        color: lbl.color
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Txt {
                        id: lbl
                        text: b.modelData.l
                        font.pixelSize: root.small ? 12 : 13
                        font.weight: b.on ? Theme.strong : Font.Normal
                        color: Theme.m3 ? (b.on ? Theme.accentInk : Theme.text) : Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
