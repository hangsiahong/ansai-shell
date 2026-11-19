pragma Singleton

import QtQuick
import qs
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    signal changed

    function setVolume(v: real): void {
        if (sink?.ready && sink.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function toggleMute(): void {
        if (sink?.ready && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function icon(): string {
        if (muted || volume <= 0.001)
            return "volume_off";
        if (volume < 0.34)
            return "volume_mute";
        if (volume < 0.67)
            return "volume_down";
        return "volume_up";
    }

    onVolumeChanged: changed()
    onMutedChanged: changed()

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
