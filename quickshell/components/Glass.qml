import QtQuick
import qs

// The web's .glass sheet: translucent fill over compositor blur, hairline edge.
Rectangle {
    color: Theme.glass
    radius: Theme.rLg
    border.width: 1
    border.color: Theme.glassLine
}
