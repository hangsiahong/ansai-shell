import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// A titled card of SRows (Android: tonal container; ansai: iOS inset grouped list).
ColumnLayout {
    id: root
    property string title
    property string note
    default property alias content: inner.data
    Layout.fillWidth: true
    spacing: 8

    Txt {
        visible: !!root.title
        Layout.leftMargin: Theme.m3 ? 16 : 14
        text: Theme.m3 ? root.title : root.title.toUpperCase()
        font.pixelSize: Theme.m3 ? 14 : 12
        font.weight: Theme.strong
        font.letterSpacing: Theme.m3 ? 0 : 0.4
        color: Theme.m3 ? Theme.accent : Theme.muted
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight
        radius: Theme.rGroup
        color: Theme.m3 ? Theme.surface2 : Theme.dark ? "#1c1c1e" : "#ffffff"
        ColumnLayout {
            id: inner
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 0
        }
    }
    Txt {
        visible: !!root.note
        Layout.fillWidth: true
        Layout.leftMargin: Theme.m3 ? 16 : 14
        Layout.rightMargin: 14
        text: root.note
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
        font.pixelSize: 12
        color: Theme.muted
    }
}
