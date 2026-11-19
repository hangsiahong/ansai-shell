import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs
import qs.services

// The blurred wallpaper behind ansai glass, drawn by the shell instead of niri. niri's blur mask is
// built from wl_region rectangles, so its corners step and the steps show wherever a window sits
// behind the glass; this one is clipped with antialiasing. Like niri's x-ray blur it shows the
// wallpaper, not the windows. Set screenX/screenY to where this item's top-left is on screen.
ClippingRectangle {
    id: root
    property real screenX: 0
    property real screenY: 0
    color: "transparent"

    readonly property real sw: Screen.width
    readonly property real sh: Screen.height
    readonly property int down: 8   // blur at 1/8 size, then scale up: cheap and smooth

    Item {
        id: small
        width: Math.ceil(root.sw / root.down)
        height: Math.ceil(root.sh / root.down)
        transformOrigin: Item.TopLeft
        scale: root.down
        x: -root.screenX
        y: -root.screenY

        Image {
            id: wall
            anchors.fill: parent
            source: Scheme.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width
            sourceSize.height: height
            asynchronous: true
            cache: true
            visible: false
        }
        Rectangle {   // no wallpaper image: the plain field the Background draws
            anchors.fill: parent
            visible: wall.status !== Image.Ready
            color: Theme.dark ? "#050507" : "#e9ecf3"
        }
        MultiEffect {
            anchors.fill: parent
            visible: wall.status === Image.Ready
            source: wall
            blurEnabled: true
            blur: 1.0
            blurMax: 12
            saturation: 0.45
            autoPaddingEnabled: false
        }
    }
}
