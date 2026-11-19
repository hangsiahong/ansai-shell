import QtQuick
import qs

// Small icon toggle. ansai: iOS circle. material: M3E shape morph, circle when off, rounded square when on.
Column {
    id: root
    property bool on
    property string icon
    property string label
    property color onColor: Theme.accent
    signal clicked
    spacing: 6

    Hover {
        id: btn
        anchors.horizontalCenter: parent.horizontalCenter
        width: Theme.m3 ? 56 : 48
        height: 48
        radius: Theme.m3 ? (root.on ? 16 : 24) : 24
        base: Theme.fill2
        active: root.on
        activeColor: Theme.on(root.onColor)
        scale: Theme.m3 && pressed ? 0.92 : 1
        Behavior on radius { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.spring } }
        onClicked: root.clicked()
        Icon { anchors.centerIn: parent; name: root.icon; size: 22; filled: root.on; color: root.on ? Theme.onInk(root.onColor) : Theme.text }
    }
    Txt {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.label
        font.pixelSize: 11
        color: Theme.muted
    }
}
