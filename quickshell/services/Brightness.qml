pragma Singleton

import QtQuick
import qs
import Quickshell
import Quickshell.Io

// brightnessctl needs no root on Arch (udev rule grants the video group / logind backlight API).
// Hybrid laptops list a dead nvidia_0 next to the panel's real backlight (amdgpu_bl*, intel_backlight),
// and brightnessctl's default picks the first, so the device is chosen here: anything but nvidia first.
Singleton {
    id: root

    property real value: 0
    property bool available: false
    property string device: ""

    signal changed

    function set(v: real): void {
        const pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100);
        value = pct / 100;
        Quickshell.execDetached(["brightnessctl", "-d", device || "*", "--class=backlight", "-q", "set", pct + "%"]);
        changed();
    }

    function refresh(): void {
        if (device) reader.running = true;
        else finder.running = true;
    }

    Process {
        id: finder
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").filter(s => s);
                root.device = l.find(d => !/nvidia/i.test(d)) ?? l[0] ?? "";
                if (root.device) reader.running = true;
            }
        }
    }

    Component.onCompleted: refresh()

    Process {
        id: reader
        command: ["brightnessctl", "-d", root.device, "--class=backlight", "-m"]
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
