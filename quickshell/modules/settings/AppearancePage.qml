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
