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

    // Tray items hand over ready image URLs (image://icon/…, image://qspixmap/…); only bare names go through the theme.
    readonly property string src: !icon ? "" : icon.includes("://") ? fixPath(icon) : icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, true)
    // Some apps (Telegram, Electron) send "name?path=/dir" for icons outside the theme.
    function fixPath(u) {
        const i = u.indexOf("?path=");
        if (i < 0) return u;
        const name = u.slice("image://icon/".length, i), dir = u.slice(i + 6);
        return Quickshell.iconPath(name, true) || "file://" + dir + "/" + name + ".png";
    }

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
