import QtQuick
import qs

// A Control Center module: a lighter glass tile inside the glass panel.
// Light: hairline + soft shadow keep tiles apart on bright wallpapers, where panel and tile both blur to near white.
// Dark: shadows go muddy, so tiles get the Liquid Glass edge light instead (lit top and bottom rims).
Rectangle {
    id: root
    radius: 18
    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Theme.glassTile
    border.width: Theme.dark ? 0 : 1
    border.color: Qt.rgba(0, 0, 0, 0.06)
    Rectangle {
        visible: !Theme.dark
        z: -1
        anchors { fill: parent; topMargin: 2; bottomMargin: -2 }
        radius: root.radius
        color: Qt.rgba(0, 0, 0, 0.05)
    }
    GlassRim {
        visible: Theme.dark
        z: 1000
        anchors.fill: parent
        radius: root.radius
        rimWidth: 1.6
        rimIntensity: 0.38
        rimPower: 1.4
        aoIntensity: 0
    }
}
