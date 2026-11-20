pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Who is using the microphone or camera right now, for the bar's privacy dots (mic orange, camera green).
// Mic: Pipewire capture streams, minus ones recording a speaker monitor (visualisers, screen recorder audio).
// Camera: Pipewire video capture streams, or any process holding /dev/video* (browsers often skip Pipewire).
Singleton {
    id: root

    readonly property var micApps: Pipewire.nodes.values
        .filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Audio"
            && n.properties["stream.capture.sink"] !== "true" && !/\.monitor$/.test(n.properties["target.object"] ?? ""))
        .map(n => name(n))
    readonly property var pwCamApps: Pipewire.nodes.values
        .filter(n => n.isStream && n.properties["media.class"] === "Stream/Input/Video")
        .map(n => name(n))
    property var devCamApps: []
    readonly property var camApps: [...new Set(pwCamApps.concat(devCamApps))]
    readonly property bool mic: micApps.length > 0
    readonly property bool cam: camApps.length > 0

    function name(n: PwNode): string {
        return n.properties["application.name"] || n.properties["application.process.binary"] || n.nickname || n.name;
    }

    PwObjectTracker { objects: Pipewire.nodes.values.filter(n => n.isStream) }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cams.running) cams.running = true
    }
    Process {
        id: cams
        command: ["sh", "-c", "for p in $(fuser /dev/video* 2>/dev/null); do cat /proc/$p/comm; done | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.devCamApps = text.split("\n").filter(s => s && !/^(pipewire|wireplumber)$/.test(s))
        }
    }
}
