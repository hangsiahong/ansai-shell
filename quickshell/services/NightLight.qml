pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs

// Night light through wlsunset: on now (Settings.nightLight), or on a schedule, sunset to sunrise
// (wlsunset fades over the twilight) or set times. Sun times need a place: the Weather city, else the
// time zone's main city from tzdata, so nothing leaves the machine.
Singleton {
    id: root

    property var tzCoords: null
    readonly property var coords: Weather.coords ?? tzCoords
    readonly property int minute: { const d = Time.now; return d.getHours() * 60 + d.getMinutes(); }
    // For the UI; wlsunset decides the actual sun times (and fades over twilight).
    readonly property var window: Settings.nightSchedule === "custom" ? [Settings.nightFrom, Settings.nightTo]
        : Settings.nightSchedule === "sun" && sun.length === 2 ? [sun[1], sun[0]] : []
    readonly property bool inSchedule: window.length === 2 && (window[0] <= window[1]
        ? minute >= window[0] && minute < window[1] : minute >= window[0] || minute < window[1])
    property bool paused: false   // turned off by hand during scheduled hours; resumes next time
    onInScheduleChanged: if (!inSchedule) paused = false
    readonly property bool active: Settings.nightLight || (inSchedule && !paused)
    readonly property string status: Settings.nightLight ? "On" : active ? "Until " + clock(window[1])
        : window.length === 2 ? (Settings.nightSchedule === "sun" ? "Sunset " : "From ") + clock(window[0]) : "Off"

    function clock(m: int): string { return Qt.formatTime(new Date(2000, 0, 1, Math.floor(m / 60), m % 60), Settings.use24h ? "HH:mm" : "h:mm AP"); }
    function toggle(): void {
        if (active) {
            Settings.nightLight = false;
            if (inSchedule) paused = true;
        } else if (inSchedule) {
            paused = false;
        } else {
            Settings.nightLight = true;
        }
    }

    readonly property var sun: coords ? times(coords[0], coords[1], Time.now) : []   // [sunrise, sunset], local minutes

    function hm(m: int): string {
        return String(Math.floor(m / 60) % 24).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }
    // NOAA sunrise equation, good to a minute or two.
    function times(lat: real, lon: real, now: var): var {
        const rad = Math.PI / 180;
        const start = new Date(now.getFullYear(), 0, 0);
        const n = Math.floor((now - start) / 86400000);
        const g = 2 * Math.PI / 365 * (n - 1);
        const eq = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g) - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        const dec = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g) + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        const c = (Math.cos(90.833 * rad) - Math.sin(lat * rad) * Math.sin(dec)) / (Math.cos(lat * rad) * Math.cos(dec));
        if (c > 1 || c < -1) return [];
        const ha = Math.acos(c) / rad;
        const tz = -now.getTimezoneOffset();
        return [Math.round(720 - 4 * (lon + ha) - eq + tz), Math.round(720 - 4 * (lon - ha) - eq + tz)].map(m => (m + 1440) % 1440);
    }

    readonly property var command: {
        const base = ["wlsunset", "-T", "6500", "-t", String(Settings.nightTemp)];
        if (Settings.nightLight) return base.concat(["-S", "00:00", "-s", "00:01", "-d", "1"]);
        if (paused) return [];
        if (Settings.nightSchedule === "sun" && coords) return base.concat(["-l", coords[0].toFixed(2), "-L", coords[1].toFixed(2)]);
        if (Settings.nightSchedule === "custom") return base.concat(["-S", hm(Settings.nightTo), "-s", hm(Settings.nightFrom), "-d", "1800"]);
        return [];
    }

    // Recreated (old wlsunset stopped) whenever the command changes.
    Instantiator {
        model: root.command.length ? [JSON.stringify(root.command)] : []
        delegate: Process {
            required property string modelData
            running: true
            command: JSON.parse(modelData)
        }
    }

    Process {
        running: true
        command: ["sh", "-c", 'z=$(readlink /etc/localtime | sed "s|.*/zoneinfo/||"); [ -n "$z" ] || z=$(cat /etc/timezone 2>/dev/null); awk -v z="$z" "\\$3==z{print \\$2; exit}" /usr/share/zoneinfo/zone.tab /usr/share/zoneinfo/zone1970.tab']
        stdout: StdioCollector {
            onStreamFinished: {
                // ISO 6709: +DDMM[SS]+DDDMM[SS]
                const m = text.trim().match(/^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/);
                if (!m) return;
                const v = (s, d, mi, se) => (s === "-" ? -1 : 1) * (+d + +mi / 60 + +(se ?? 0) / 3600);
                root.tzCoords = [v(m[1], m[2], m[3], m[4]), v(m[5], m[6], m[7], m[8])];
            }
        }
    }
}
