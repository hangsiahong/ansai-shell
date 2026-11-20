import QtQuick
import qs

// A Control Center module: a lighter glass tile inside the glass panel.
// Hairline + soft shadow keep tiles apart from the panel on bright wallpapers, where both blur to near white.
Rectangle {
    id: root
    radius: 18
    color: Theme.glassTile
    border.width: 1
    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
    Rectangle {
        z: -1
        anchors { fill: parent; topMargin: 2; bottomMargin: -2 }
        radius: root.radius
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(0, 0, 0, 0.05)
    }
}
