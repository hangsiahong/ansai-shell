import QtQuick
import qs
import Quickshell
import Quickshell.Widgets

// App icon from the icon theme, falling back to a squircle with the first letter.
Item {
    id: root
    property string icon
    property string label
    property real size: 32
    implicitWidth: size
    implicitHeight: size

    readonly property string src: icon ? Quickshell.iconPath(icon, true) : ""

    IconImage {
        id: img
        anchors.fill: parent
        source: root.src
        visible: root.src !== "" && status !== Image.Error
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: !img.visible
        radius: width * 0.258
        color: Theme.surface3
        Txt {
            anchors.centerIn: parent
            text: (root.label || "?").charAt(0).toUpperCase()
            font.pixelSize: root.size * 0.45
            font.weight: Theme.strong
            color: Theme.text2
        }
    }
}
