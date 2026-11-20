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

    SGroup {
        title: "Style"
        SRow {
            first: true
            icon: "style"
            title: "Look"
            sub: Theme.m3 ? "Material 3 Expressive, colours from your wallpaper" : "macOS-style Liquid Glass, blue accent"
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
            icon: "widgets"
            title: "Icons"
            sub: Theme.phosphor ? "Phosphor: thin, SF Symbols-like line icons" : "Material Symbols Rounded"
            Seg {
                model: [{ v: "", l: "Auto" }, { v: "phosphor", l: "Phosphor" }, { v: "material", l: "Material" }]
                value: Settings.iconSet
                onPicked: v => Settings.iconSet = v
            }
        }
        SRow {
            icon: "match_case"
            title: "Font"
            sub: "Used by the shell and, with system theme on, GTK apps"
            below: Flow {
                id: fontGrid
                width: parent ? parent.width : 300
                spacing: 8
                readonly property real tileW: Math.floor((width - spacing * 3) / 4)
                readonly property var notes: ({ "Inter": "SF-like, ansai default", "Google Sans Flex": "Android 16, Material default",
                    "Geist": "crisp, technical", "Figtree": "friendly geometric", "Nunito": "soft and rounded", "Roboto": "classic Android",
                    "Noto Sans": "widest script coverage", "Kantumruy Pro": "Khmer first" })
                Repeater {
                    model: Theme.fonts
                    Hover {
                        id: ft
                        required property string modelData
                        readonly property bool on: Theme.fontName === modelData
                        width: fontGrid.tileW
                        height: 92
                        radius: Theme.m3 ? 20 : 12
                        base: Theme.m3 ? Theme.surface3 : Theme.fill2
                        border.width: on ? 2 : 0
                        border.color: Theme.accent
                        onClicked: Settings.font = modelData === Theme.defaultFont ? "" : modelData
                        Column {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                            spacing: 1
                            Text {
                                text: "Aa ក"
                                font.family: ft.modelData; font.pixelSize: 24; font.weight: Font.DemiBold
                                color: ft.on ? Theme.accent : Theme.text
                            }
                            Text {
                                width: parent.width; elide: Text.ElideRight
                                text: ft.modelData
                                font.family: ft.modelData; font.pixelSize: 13; font.weight: Font.Medium
                                color: Theme.text
                            }
                            Txt {
                                width: parent.width
                                text: fontGrid.notes[ft.modelData] ?? ""
                                font.pixelSize: 11; color: Theme.muted
                            }
                        }
                    }
                }
            }
        }
    }

    SGroup {
        title: "Wallpaper"
        SRow {
            first: true
            title: Settings.wallpaper ? Settings.wallpaper.split("/").pop() : "Same as GNOME"
            sub: "Pictures from ~/Pictures/Wallpapers and the system backgrounds"
            clickable: true
            onClicked: Shell.settingsPage = "wallpaper"
            ClippingRectangle {
                width: 72; height: 45; radius: 8
                color: Theme.surface3
                Image {
                    anchors.fill: parent
                    source: Scheme.wallpaperUrl
                    sourceSize.width: 144
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Btn { text: "Change…"; onClicked: Shell.settingsPage = "wallpaper" }
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
