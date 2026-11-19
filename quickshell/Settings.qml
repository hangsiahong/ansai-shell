pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persisted to ~/.config/ansai-shell/settings.json; edits from the UI or by hand both apply live.
Singleton {
    id: settings
    property alias theme: adapter.theme
    property alias style: adapter.style
    property alias font: adapter.font
    property alias wallpaper: adapter.wallpaper
    property alias terminal: adapter.terminal
    property alias use24h: adapter.use24h
    property alias dnd: adapter.dnd
    property alias nightLight: adapter.nightLight
    property alias keepAwake: adapter.keepAwake
    property alias pinned: adapter.pinned
    property alias usage: adapter.usage
    property alias dockMode: adapter.dockMode
    property alias dockSize: adapter.dockSize
    property alias dockMagnify: adapter.dockMagnify
    property alias systemTheme: adapter.systemTheme

    readonly property string dir: Quickshell.env("XDG_CONFIG_HOME") ? Quickshell.env("XDG_CONFIG_HOME") + "/ansai-shell" : Quickshell.env("HOME") + "/.config/ansai-shell"

    FileView {
        path: settings.dir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property string theme: "dark"
            property string style: "ansai"   // "ansai" | "material"
            property string font: ""   // empty: the style's own font
            property string wallpaper: ""
            property string terminal: "ghostty"
            property bool use24h: false
            property bool dnd: false
            property bool nightLight: false
            property bool keepAwake: true
            property var usage: ({})
            property string dockMode: "smart"   // "smart": hide when a window covers it | "auto": always hide | "always": never hide
            property int dockSize: 44
            property bool dockMagnify: true
            property bool systemTheme: true   // theme GTK/Qt apps and Ghostty to match (services/SystemTheme.qml)
            property list<string> pinned: ["org.gnome.Nautilus", "com.mitchellh.ghostty", "zen", "firefox", "code"]
        }
    }
}
