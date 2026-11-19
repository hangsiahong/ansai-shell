import QtQuick
import qs

// Panel surface over compositor blur. material: tonal fill. ansai: Liquid Glass, after the
// liquid-glass GNOME extension: a light tint over a light, saturated blur, a rim lit on the edges
// facing the light, and a hair of inner shadow on the others (GlassRim). No uniform border.
Rectangle {
    id: root
    color: Theme.glass
    radius: Theme.rLg
    border.width: 0

    GlassRim {
        anchors.fill: parent
        radius: root.radius
        z: 1000
    }
}
