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
            sub: Theme.m3 ? "Material 3 Expressive, tonal colours" : "macOS-style Liquid Glass"
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
            icon: "palette"
            title: "Accent colour"
            sub: {
                const a = Settings.accent || (Theme.m3 ? "wallpaper" : "blue");
                return a === "wallpaper" ? "From your wallpaper" : a.charAt(0).toUpperCase() + a.slice(1);
            }
            Row {
                spacing: 7
                Repeater {
                    model: ["wallpaper", "blue", "purple", "pink", "red", "orange", "yellow", "green", "graphite"]
                    Item {
                        id: dot
                        required property string modelData
                        readonly property bool on: (Settings.accent || (Theme.m3 ? "wallpaper" : "blue")) === modelData
                        width: 22; height: 22
                        Rectangle {
                            anchors.centerIn: parent
                            width: 22; height: 22; radius: 11
                            color: "transparent"
                            border.width: dot.on ? 2 : 0
                            border.color: Theme.text2
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 8
                            color: dot.modelData === "wallpaper" ? Theme.pal.tone(Theme.pal.wallHue, 60, 55) : Theme.accents[dot.modelData][Theme.dark ? 1 : 0]
                            Icon { visible: dot.modelData === "wallpaper"; anchors.centerIn: parent; name: "wallpaper"; size: 11; color: "#ffffff" }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.accent = dot.modelData === (Theme.m3 ? "wallpaper" : "blue") ? "" : dot.modelData
                        }
                    }
                }
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
        SRow {
            icon: "widgets"
            title: "Desktop widgets"
            sub: "On the wallpaper of an empty workspace. Drag a widget to move it."
            Btn {
                visible: Object.keys(Settings.widgetPos).length > 0
                text: "Reset layout"
                onClicked: Settings.widgetPos = ({})
            }
            below: Flow {
                width: parent ? parent.width : 300
                spacing: 8
                Repeater {
                    model: [["clock", "schedule", "Clock"], ["weather", "partly_cloudy_day", "Weather"], ["calendar", "calendar_month", "Calendar"],
                        ["battery", "battery_full", "Battery"], ["system", "memory", "System"], ["media", "music_note", "Now playing"]]
                    Hover {
                        id: wc
                        required property var modelData
                        readonly property bool on: Settings.widgets.includes(modelData[0])
                        width: wcRow.implicitWidth + 28
                        height: 36
                        radius: 18
                        base: on ? Theme.accentSoft : (Theme.m3 ? Theme.surface3 : Theme.fill2)
                        border.width: on ? 1 : 0
                        border.color: Theme.accent
                        onClicked: Settings.widgets = on ? Settings.widgets.filter(w => w !== modelData[0]) : Settings.widgets.concat([modelData[0]])
                        Row {
                            id: wcRow
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: wc.modelData[1]; filled: wc.on; size: 16; color: wc.on ? Theme.accent : Theme.text }
                            Txt { anchors.verticalCenter: parent.verticalCenter; text: wc.modelData[2]; font.pixelSize: 13; font.weight: Theme.strong; color: wc.on ? Theme.accent : Theme.text }
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
            icon: "apps"
            title: "App icons"
            sub: "Icon theme for apps (GTK now, the dock and launcher after the shell's next start). ansai pairs with WhiteSur, Android with Papirus or Fluent."
            below: Flow {
                id: iconGrid
                width: parent ? parent.width : 300
                spacing: 8
                readonly property real tileW: Math.floor((width - spacing * 3) / 4)
                property var themes: []
                property string current: ""
                Process {
                    running: true
                    command: ["sh", "-c", "gsettings get org.gnome.desktop.interface icon-theme; python3 \"$1\"", "sh", Quickshell.shellDir + "/scripts/icon-themes.py"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const l = text.split("\n");
                            iconGrid.current = l[0].replace(/'/g, "").trim();
                            try { iconGrid.themes = JSON.parse(l[1]); } catch (e) {}
                        }
                    }
                }
                Process { id: setIcons }
                Repeater {
                    model: iconGrid.themes
                    Hover {
                        id: it
                        required property var modelData
                        readonly property bool on: iconGrid.current === modelData.name
                        width: iconGrid.tileW
                        height: 74
                        radius: Theme.m3 ? 20 : 12
                        base: Theme.m3 ? Theme.surface3 : Theme.fill2
                        border.width: on ? 2 : 0
                        border.color: Theme.accent
                        onClicked: {
                            iconGrid.current = modelData.name;
                            setIcons.exec(["sh", "-c", 'gsettings set org.gnome.desktop.interface icon-theme "$1"; kwriteconfig6 --file kdeglobals --group Icons --key Theme "$1"', "sh", modelData.name]);
                        }
                        Column {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                            spacing: 6
                            Row {
                                spacing: 4
                                Repeater {
                                    model: it.modelData.icons
                                    Image {
                                        required property string modelData
                                        width: 26; height: 26
                                        source: "file://" + modelData
                                        sourceSize: Qt.size(52, 52)
                                        asynchronous: true
                                    }
                                }
                            }
                            Txt {
                                width: parent.width
                                text: it.modelData.title
                                font.pixelSize: 12
                                font.weight: it.on ? Theme.strong : Font.Normal
                                color: it.on ? Theme.accent : Theme.text
                            }
                        }
                    }
                }
            }
        }
        SRow {
            icon: "partly_cloudy_day"
            title: "Weather"
            sub: Weather.error ? Weather.error : Weather.place ? "Showing " + Weather.place + " in the calendar panel (Open-Meteo)" : "Type a city to show weather in the calendar panel. Only the city name is sent (Open-Meteo)."
            Rectangle {
                width: 200
                height: Theme.m3 ? 40 : 30
                radius: Theme.m3 ? 20 : 8
                color: Theme.m3 ? Theme.surface3 : Theme.fill2
                TextInput {
                    id: cityIn
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    clip: true
                    text: Settings.weatherCity
                    onEditingFinished: Settings.weatherCity = text.trim()
                    Txt { visible: !cityIn.text; anchors.verticalCenter: parent.verticalCenter; text: "City, e.g. Phnom Penh"; color: Theme.faint; font.pixelSize: 13 }
                }
            }
        }
        SRow {
            icon: "schedule"
            title: "24-hour clock"
            Switch { checked: Settings.use24h; onToggled: Settings.use24h = !Settings.use24h }
        }
        SRow {
            icon: "monitoring"
            title: "System use in the menu bar"
            sub: "CPU, memory, swap and disk, in percent"
            Switch { checked: Settings.barStats; onToggled: Settings.barStats = !Settings.barStats }
        }
    }
}
