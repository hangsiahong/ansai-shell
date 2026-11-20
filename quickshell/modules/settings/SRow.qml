import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// One setting: icon, title, subtitle, and a control on the right (the default slot).
// `below` items span the full width under the title (chips, sliders, grids).
Item {
    id: root
    property string icon
    property string title
    property string sub
    property bool clickable: false
    property bool first: false
    property bool dim: false
    default property alias trailing: right.data
    property alias below: bottom.data
    signal clicked

    Layout.fillWidth: true
    implicitHeight: Math.max(Theme.m3 ? 64 : 50, head.implicitHeight + 22) + (bottom.visibleChildren.length ? bottom.implicitHeight + 14 : 0)
    opacity: dim ? 0.45 : 1

    Rectangle {   // hairline between rows (ansai only, inset past the icon)
        visible: !Theme.m3 && root.y > 0 && !root.first
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: root.icon ? 52 : 16 }
        height: 1
        color: Theme.line
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.m3 ? 4 : 0
        radius: Theme.m3 ? Theme.rGroup - 4 : Theme.rGroup
        visible: root.clickable
        color: ma.pressed ? Theme.press : ma.containsMouse ? Theme.hover : "transparent"
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 16; rightMargin: 16; topMargin: 11 }
        height: Math.max(Theme.m3 ? 42 : 28, implicitHeight)
        spacing: 14
        Icon {
            visible: !!root.icon
            name: root.icon
            size: 21
            color: Theme.m3 ? Theme.text2 : Theme.accent
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: root.title; font.pixelSize: Theme.m3 ? 15 : 14; visible: !!root.title }
            Txt {
                Layout.fillWidth: true
                visible: !!root.sub
                text: root.sub
                font.pixelSize: 12
                color: Theme.muted
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }
        Row {
            id: right
            spacing: 8
            Layout.alignment: Qt.AlignVCenter
        }
    }
    Item {
        id: bottom
        anchors { left: parent.left; right: parent.right; top: head.bottom; leftMargin: root.icon ? 51 : 16; rightMargin: 16; topMargin: 6 }
        implicitHeight: childrenRect.height
        height: implicitHeight
    }
}
