pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording with gpu-screen-recorder: the focused output plus desktop audio, to ~/Videos/Recordings.
Singleton {
    id: root
    readonly property bool available: probe.found
    readonly property bool recording: proc.running
    property string file: ""
    property int seconds: 0
    readonly property string elapsed: Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0")

    function toggle(): void { recording ? stop() : start(); }
    function start(): void {
        if (recording || !available) return;
        const dir = Quickshell.env("HOME") + "/Videos/Recordings";
        file = dir + "/Recording_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        seconds = 0;
        proc.command = ["sh", "-c", 'mkdir -p "$1" && exec gpu-screen-recorder -w "$2" -f 60 -a default_output -cursor yes -o "$3"',
            "sh", dir, Niri.focusedOutput || "screen", file];
        proc.running = true;
    }
    function stop(): void { if (recording) proc.signal(2); }

    Process {
        id: proc
        onExited: code => {
            note.exec(["notify-send", "-a", "Screen Recording", "-i", "media-record",
                code === 0 ? "Recording saved" : "Recording failed", code === 0 ? root.file.replace(Quickshell.env("HOME"), "~") : "gpu-screen-recorder exited with " + code]);
        }
    }
    Process { id: note }
    Process {
        id: probe
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v gpu-screen-recorder"]
        onExited: code => found = code === 0
    }
    Timer { interval: 1000; repeat: true; running: root.recording; onTriggered: root.seconds++ }
}
