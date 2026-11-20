import QtQuick
import qs

// Panel surface. material: tonal fill over a blur. ansai: Liquid Glass after the liquid-glass
// GNOME extension: a light tint over a light, saturated blur, a rim lit on the edges facing the
// light and a hair of inner shadow on the others (GlassRim). When the host says where the glass is
// on screen (screenX/screenY), the blur is drawn here (GlassBackdrop) so the corners stay smooth.
Rectangle {
    id: root
    property real screenX: NaN
    property real screenY: NaN
    readonly property bool ownBlur: !isNaN(screenX) && !isNaN(screenY)
    color: ownBlur ? "transparent" : Theme.glass
    radius: Theme.rLg
    border.width: 0

    GlassBackdrop {
        visible: root.ownBlur
        anchors.fill: parent
        radius: root.radius
        screenX: root.screenX
        screenY: root.screenY
        z: -2
    }
    Rectangle {
        visible: root.ownBlur
        anchors.fill: parent
        radius: root.radius
        color: Theme.glass
        z: -1
    }
    GlassRim {
        anchors.fill: parent
        radius: root.radius
        z: 1000
    }
}
