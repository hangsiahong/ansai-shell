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
    // material has no rim light, so a hairline outline + soft elevation shadow keeps it apart from pale wallpapers.
    border.width: Theme.m3 ? 1 : 0
    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)

    Repeater {
        model: Theme.m3 ? [[1, 0.06], [3, 0.05], [6, 0.03]] : []
        Rectangle {
            required property var modelData
            z: -3
            anchors { fill: parent; topMargin: modelData[0]; bottomMargin: -modelData[0]; leftMargin: -modelData[0] / 3; rightMargin: -modelData[0] / 3 }
            radius: root.radius + modelData[0] / 3
            color: Qt.rgba(0, 0, 0, Theme.dark ? modelData[1] * 3 : modelData[1])
        }
    }

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
