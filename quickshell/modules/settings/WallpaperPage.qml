import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Wallpaper picker, a page of its own so Appearance opens instantly. Shows 12 at a time.
ColumnLayout {
    id: root
    spacing: 22
    property int shown: 12
    property var walls: []
    Process {
        running: true
        command: ["sh", "-c", `
for d in "$HOME/Pictures/Wallpapers" "$HOME/Pictures/wallpapers" "$HOME/.local/share/backgrounds"; do
  [ -d "$d" ] && find -L "$d" -maxdepth 2 -type f; done
[ -d "$HOME/Pictures" ] && find "$HOME/Pictures" -maxdepth 1 -type f
[ -d /usr/share/backgrounds ] && find -L /usr/share/backgrounds -maxdepth 2 -type f
true`]
        stdout: StdioCollector {
            onStreamFinished: root.walls = text.split("\n")
                .filter(f => /\.(jpe?g|png|webp|jxl|avif|svg)$/i.test(f) && !/screenshot/i.test(f))
                .filter((f, i, a) => a.indexOf(f) === i)
                .slice(0, 80)
        }
    }

    SGroup {
        title: "Wallpaper"
        note: "Put your own pictures in ~/Pictures/Wallpapers. With the Android look, colours follow the wallpaper."
        Item {
            Layout.fillWidth: true
            implicitHeight: grid.height + 24
            Flow {
                id: grid
                x: 12; y: 12
                width: parent.width - 24
                spacing: 10
                readonly property int cols: Math.max(2, Math.floor((width + spacing) / 170))
                readonly property real tw: (width - spacing * (cols - 1)) / cols

                Repeater {
                    model: [""].concat(root.walls.slice(0, root.shown))
                    Item {
                        id: t
                        required property string modelData
                        readonly property bool on: Settings.wallpaper === modelData
                        width: grid.tw
                        height: grid.tw * 0.625
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: t.on ? 4 : 0
                            radius: Theme.m3 ? 16 : 10
                            color: Theme.surface3
                            Behavior on anchors.margins { NumberAnimation { duration: Theme.fast } }
                            Image {
                                anchors.fill: parent
                                visible: !!t.modelData
                                source: t.modelData ? "file://" + t.modelData : ""
                                sourceSize.width: 320
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                            Column {
                                visible: !t.modelData
                                anchors.centerIn: parent
                                spacing: 4
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "wallpaper"; size: 22; color: Theme.text2 }
                                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: "Same as GNOME"; font.pixelSize: 12; color: Theme.text2 }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.m3 ? 20 : 13
                            color: "transparent"
                            border.width: t.on ? 3 : ma.containsMouse ? 1 : 0
                            border.color: t.on ? Theme.accent : Theme.line
                        }
                        Rectangle {
                            visible: t.on
                            anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                            width: 22; height: 22; radius: 11
                            color: Theme.accent
                            Icon { anchors.centerIn: parent; name: "check"; size: 15; color: Theme.accentInk }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.wallpaper = t.modelData
                        }
                    }
                }
            }
        }
    }


    Btn {
        visible: root.walls.length > root.shown
        Layout.alignment: Qt.AlignHCenter
        text: `Show more (${root.walls.length - root.shown})`
        onClicked: root.shown += 12
    }
}
