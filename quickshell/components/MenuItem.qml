import QtQuick
import QtQuick.Layouts
import qs

// macOS-style menu row: accent highlight on hover with white text, optional icon and shortcut hint.
Hover {
    id: mi
    property string icon
    property string label
    property string hint
    property bool destructive: false
    Layout.fillWidth: true
    Layout.preferredHeight: Theme.m3 ? 36 : 26
    radius: Theme.m3 ? 18 : 7
    activeColor: Theme.accent
    active: !Theme.m3 && hovered
    readonly property color ink: !Theme.m3 && hovered ? "#ffffff" : destructive ? Theme.danger : Theme.text
    RowLayout {
        anchors { fill: parent; leftMargin: Theme.m3 ? 12 : 9; rightMargin: 10 }
        spacing: 8
        Icon { visible: !!mi.icon; name: mi.icon; size: Theme.m3 ? 17 : 15; color: !Theme.m3 && mi.hovered ? "#ffffff" : mi.destructive ? Theme.danger : Theme.text2 }
        Txt { Layout.fillWidth: true; text: mi.label; font.pixelSize: 13; color: mi.ink }
        Txt { visible: !!mi.hint; text: mi.hint; font.pixelSize: 12; color: !Theme.m3 && mi.hovered ? Qt.rgba(1, 1, 1, 0.8) : Theme.faint }
    }
}
