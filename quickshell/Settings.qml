pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persisted to ~/.config/ansai-shell/settings.json; edits from the UI or by hand both apply live.
Singleton {
    id: settings
    property alias theme: adapter.theme
    property alias wallpaper: adapter.wallpaper
    property alias terminal: adapter.terminal
    property alias use24h: adapter.use24h
    property alias dnd: adapter.dnd
    property alias nightLight: adapter.nightLight
    property alias pinned: adapter.pinned
    property alias usage: adapter.usage

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
            property string wallpaper: ""
            property string terminal: "ghostty"
            property bool use24h: false
            property bool dnd: false
            property bool nightLight: false
            property var usage: ({})
            property list<string> pinned: ["org.gnome.Nautilus", "com.mitchellh.ghostty", "zen", "firefox", "code"]
        }
    }
}
