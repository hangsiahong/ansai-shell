import QtQuick
import QtQuick.Shapes
import qs

// Settings.wallpaper if set, otherwise a dark field with soft accent glows.
Item {
    id: root
    clip: true

    Rectangle {
        anchors.fill: parent
        color: Theme.dark ? "#050507" : "#e9ecf3"
        visible: !img.visible

        Glow { cx: parent.width * 0.12; cy: parent.height * 0.05; r: parent.width * 0.55; c: Qt.rgba(10/255, 132/255, 1, Theme.dark ? 0.30 : 0.22) }
        Glow { cx: parent.width * 0.92; cy: parent.height * 0.95; r: parent.width * 0.5; c: Qt.rgba(94/255, 92/255, 230/255, Theme.dark ? 0.26 : 0.18) }
    }

    component Glow: Shape {
        property real cx
        property real cy
        property real r
        property color c
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: cx; centerY: cy; centerRadius: r
                focalX: cx; focalY: cy
                GradientStop { position: 0; color: c }
                GradientStop { position: 1; color: "transparent" }
            }
            PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
        }
    }

    Image {
        id: img
        anchors.fill: parent
        source: Settings.wallpaper ? (Settings.wallpaper.startsWith("/") ? "file://" + Settings.wallpaper : Settings.wallpaper) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: width
        sourceSize.height: height
        visible: status === Image.Ready
    }
}
