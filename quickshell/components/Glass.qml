import QtQuick
import qs

// Panel surface over compositor blur. material: tonal fill. ansai: macOS 27 Liquid Glass, a thin
// tint, a specular sheen fading down from the top rim, a bright hairline and a darker outer edge.
Rectangle {
    id: root
    color: Theme.glass
    radius: Theme.rLg
    border.width: 0

    Rectangle {   // specular sheen
        visible: !Theme.m3
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.35) }
            GradientStop { position: Math.min(1, 60 / Math.max(1, root.height)); color: "transparent" }
        }
    }
    Rectangle {   // darker edge
        visible: !Theme.m3
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.glassEdge
    }
    Rectangle {   // bright rim just inside
        visible: !Theme.m3
        anchors { fill: parent; margins: 1 }
        radius: root.radius - 1
        color: "transparent"
        border.width: 1
        border.color: Theme.glassLine
    }
}
