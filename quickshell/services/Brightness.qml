pragma Singleton

import QtQuick
import qs
import Quickshell
import Quickshell.Io

// brightnessctl needs no root on Arch (udev rule grants the video group / logind backlight API).
Singleton {
    id: root

    property real value: 0
    property bool available: false

    signal changed

    function set(v: real): void {
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        value = pct / 100;
        Quickshell.execDetached(["brightnessctl", "--class=backlight", "-q", "set", pct + "%"]);
        changed();
    }

    function refresh(): void {
        reader.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: reader
        command: ["brightnessctl", "--class=backlight", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                if (parts.length >= 5) {
                    root.available = true;
                    root.value = parseInt(parts[2]) / parseInt(parts[4]);
                }
            }
        }
    }
}
