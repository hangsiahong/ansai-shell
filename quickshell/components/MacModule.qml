import QtQuick
import qs

// A Control Center module: a lighter glass tile inside the glass panel.
Rectangle {
    radius: 18
    color: Theme.glassTile
    border.width: 1
    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.6)
}
