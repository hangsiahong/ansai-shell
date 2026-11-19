import QtQuick
import qs

// Pressable surface: hover tint, press tint, pointer cursor.
Rectangle {
    id: root
    property alias hovered: ma.containsMouse
    property alias pressed: ma.pressed
    property color base: "transparent"
    property bool active: false
    property color activeColor: Theme.fill
    signal clicked(var mouse)
    signal wheel(var wheel)

    radius: Theme.rSm
    color: active ? activeColor : ma.pressed ? Theme.press : ma.containsMouse ? Theme.hover : base
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w)
    }
}
