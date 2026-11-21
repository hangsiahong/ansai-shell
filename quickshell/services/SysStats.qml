pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// CPU, memory, swap and disk use. Reads /proc every 2 s (no processes spawned), and only while
// Control Center is open, or the menu bar figures or the System desktop widget are on; disk (df) once a minute.
Singleton {
    id: root
    readonly property bool active: Shell.open === "control" || Shell.open === "procs" || Settings.barStats || Settings.widgets.includes("system")
    property real cpu: 0          // 0..1
    property real memUsed: 0      // bytes
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    readonly property real mem: memTotal ? memUsed / memTotal : 0
    readonly property real swap: swapTotal ? swapUsed / swapTotal : 0
    readonly property real disk: diskTotal ? diskUsed / diskTotal : 0
    property var last: null       // [idle, total] jiffies at the previous read

    function gb(b: real, unit = true): string {
        const g = b / 1073741824;
        return (g >= 100 ? Math.round(g) : g.toFixed(1)) + (unit ? " GB" : "");
    }

    function read(): void {
        stat.reload();
        meminfo.reload();
        const c = (stat.text().split("\n")[0] || "").trim().split(/\s+/).slice(1).map(Number);
        if (c.length >= 4) {
            const idle = c[3] + (c[4] || 0), total = c.slice(0, 8).reduce((a, b) => a + b, 0);
            if (last && total > last[1])
                cpu = Math.max(0, Math.min(1, 1 - (idle - last[0]) / (total - last[1])));
            last = [idle, total];
        }
        const m = {};
        for (const l of meminfo.text().split("\n")) {
            const p = l.split(/:\s+/);
            if (p.length === 2) m[p[0]] = parseInt(p[1]) * 1024;
        }
        memTotal = m.MemTotal || 0;
        memUsed = memTotal - (m.MemAvailable || 0);
        swapTotal = m.SwapTotal || 0;
        swapUsed = swapTotal - (m.SwapFree || 0);
    }

    onActiveChanged: if (active) { last = null; read(); df.running = true; }
    Timer { interval: 2000; repeat: true; running: root.active; onTriggered: root.read() }
    Timer { interval: 60000; repeat: true; running: root.active; onTriggered: df.running = true }

    FileView { id: stat; path: "/proc/stat"; blockLoading: true; printErrors: false }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true; printErrors: false }
    Process {
        id: df
        command: ["df", "-B1", "--output=size,used", Quickshell.env("HOME")]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                if (p.length === 2) { root.diskTotal = p[0]; root.diskUsed = p[1]; }
            }
        }
    }
}
