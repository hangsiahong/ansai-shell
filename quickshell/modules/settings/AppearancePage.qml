import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 22

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
        title: "Style"
        SRow {
            first: true
            icon: "style"
            title: "Look"
            sub: Theme.m3 ? "Material 3 Expressive, colours from your wallpaper" : "ansai web app: glass, blue accent"
            Seg {
                model: [{ v: "ansai", l: "ansai" }, { v: "material", l: "Android" }]
                value: Settings.style
                onPicked: v => Settings.style = v
            }
        }
        SRow {
            icon: Theme.dark ? "dark_mode" : "light_mode"
            title: "Theme"
            Seg {
                model: [{ v: "light", l: "Light", icon: "light_mode" }, { v: "dark", l: "Dark", icon: "dark_mode" }]
                value: Settings.theme === "light" ? "light" : "dark"
                onPicked: v => Settings.theme = v
            }
        }
        SRow {
            icon: "match_case"
            title: "Font"
            sub: "Used by the shell and, with system theme on, GTK apps"
            below: Chips {
                model: [{ v: "", l: "Default (" + (Theme.m3 ? "Roboto" : "Noto Sans") + ")" }].concat(Theme.fonts.map(f => ({ v: f, l: f })))
                value: Settings.font
                onPicked: v => Settings.font = v
            }
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
                    model: [""].concat(root.walls)
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

    SGroup {
        title: "Desktop"
        SRow {
            first: true
            icon: "format_paint"
            title: "Theme apps to match"
            sub: "GTK 3/4, libadwaita, Qt (via GTK) and Ghostty follow the shell's colours and font. Backup and restore.sh in ~/.config/ansai-shell/system-theme-backup."
            Switch { checked: Settings.systemTheme; onToggled: Settings.systemTheme = !Settings.systemTheme }
        }
        SRow {
            icon: "schedule"
            title: "24-hour clock"
            Switch { checked: Settings.use24h; onToggled: Settings.use24h = !Settings.use24h }
        }
        SRow {
            icon: "nightlight"
            title: "Night light"
            sub: "Warmer colours (wlsunset)"
            Switch { checked: Settings.nightLight; onToggled: Settings.nightLight = !Settings.nightLight }
        }
        SRow {
            icon: "do_not_disturb_on"
            title: "Do not disturb"
            sub: "Hide notification pop-ups"
            Switch { checked: Settings.dnd; onToggled: Settings.dnd = !Settings.dnd }
        }
    }
}
