import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 22

    property int limit: -1
    property string kbd: ""
    readonly property bool asus: limit >= 0

    function refresh() { info.running = true; }
    Process {
        id: info
        running: true
        command: ["sh", "-c", "command -v asusctl >/dev/null || exit 0; echo limit=$(asusctl battery info 2>/dev/null | grep -o '[0-9]*%' | tr -d %); echo kbd=$(asusctl leds get 2>/dev/null | sed -n 's/.*: *//p')"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const [k, v] = [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1).trim()];
                    if (k === "limit" && v) root.limit = parseInt(v);
                    if (k === "kbd") root.kbd = v.toLowerCase();
                }
            }
        }
    }

    function dur(s) {
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h ? `${h} h ${m} min` : `${m} min`;
    }

    SGroup {
        title: "Power mode"
        SRow {
            first: true
            icon: PowerProfiles.profile === PowerProfile.Performance ? "speed" : PowerProfiles.profile === PowerProfile.PowerSaver ? "energy_savings_leaf" : "balance"
            title: "Profile"
            sub: PowerProfiles.profile === PowerProfile.Performance ? "Fastest; fans and battery drain go up"
               : PowerProfiles.profile === PowerProfile.PowerSaver ? "Quieter and cooler, longer battery" : "Balances speed and battery life"
            Seg {
                model: [{ v: PowerProfile.PowerSaver, l: "Saver" }, { v: PowerProfile.Balanced, l: "Balanced" }]
                    .concat(PowerProfiles.hasPerformanceProfile ? [{ v: PowerProfile.Performance, l: "Performance" }] : [])
                value: PowerProfiles.profile
                onPicked: v => PowerProfiles.profile = v
            }
        }
        SRow {
            icon: "coffee"
            title: "Keep awake"
            sub: "Don't lock or turn off the screen when idle (useful while agents work)"
            Switch { checked: Settings.keepAwake; onToggled: Settings.keepAwake = !Settings.keepAwake }
        }
        SRow {
            visible: Brightness.available
            icon: "brightness_6"
            title: "Screen brightness"
            Txt { text: Math.round(Brightness.value * 100) + "%"; font.pixelSize: 13; color: Theme.muted; font.features: { "tnum": 1 } }
            below: Slider {
                width: parent.width
                icon: "brightness_6"
                value: Brightness.value
                onMoved: v => Brightness.set(Math.max(0.02, v))
            }
        }
    }

    // ---- Fans (asusctl custom fan curves; each power mode has its own curve for the CPU, GPU and mid fans)
    readonly property string fanProfile: PowerProfiles.profile === PowerProfile.Performance ? "performance"
                                       : PowerProfiles.profile === PowerProfile.PowerSaver ? "quiet" : "balanced"
    readonly property var fanTemps: [40, 50, 60, 65, 70, 75, 80, 90]
    readonly property var fanPresets: ({
        silent: [0, 0, 10, 20, 30, 45, 60, 80],
        normal: [0, 15, 25, 35, 45, 60, 75, 100],
        turbo: [25, 35, 45, 55, 65, 80, 90, 100],
        max: [100, 100, 100, 100, 100, 100, 100, 100]
    })
    property var curve: null      // { temps: [8], pct: [8], enabled } of the CPU fan, as the editor shows it
    property bool fanAuto: true
    property var rpm: []          // [cpu, gpu, mid]
    property real cpuTemp: 0
    readonly property string fanMode: !curve ? "" : fanAuto ? "auto"
        : Object.keys(fanPresets).find(k => curve.temps.join() === fanTemps.join() && fanPresets[k].every((v, i) => Math.abs(v - curve.pct[i]) <= 1)) ?? "custom"

    onFanProfileChanged: readCurve()
    function readCurve() { if (asus) { curveRead.command = ["asusctl", "fan-curve", "--mod-profile", fanProfile]; curveRead.running = true; } }
    onAsusChanged: readCurve()
    Process {
        id: curveRead
        stdout: StdioCollector {
            onStreamFinished: {
                const re = /fan:\s*(\w+),\s*pwm:\s*\(([^)]*)\),\s*temp:\s*\(([^)]*)\),\s*enabled:\s*(\w+)/g, fans = [];
                for (let m = re.exec(text); m; m = re.exec(text)) fans.push(m);
                if (!fans.length) { root.curve = null; return; }
                const nums = s => s.split(",").map(x => parseInt(x));
                const cpu = fans.find(f => f[1] === "CPU") ?? fans[0];
                root.fanAuto = fans.every(f => f[4] !== "true");
                root.curve = { temps: nums(cpu[3]), pct: nums(cpu[2]).map(v => Math.round(v / 2.55)), enabled: cpu[4] === "true" };
            }
        }
    }
    // Writing a curve switches it off in asusd, so each fan is written and then switched back on.
    function applyCurve(temps, pct) {
        const data = temps.map((t, i) => `${t}c:${Math.round(pct[i])}%`).join(",");
        const p = fanProfile;
        fanAuto = false;
        curve = { temps: temps, pct: pct.map(v => Math.round(v)), enabled: true };
        Quickshell.execDetached(["sh", "-c", ["cpu", "gpu", "mid"].map(f =>
            `asusctl fan-curve --mod-profile ${p} --fan ${f} --data ${data} && asusctl fan-curve --mod-profile ${p} --fan ${f} --enable-fan-curve true`).join("; ")]);
    }
    function setFanMode(m) {
        if (m === "auto") {
            fanAuto = true;
            Quickshell.execDetached(["asusctl", "fan-curve", "--mod-profile", fanProfile, "--enable-fan-curves", "false"]);
        } else if (m === "custom") {
            applyCurve(curve?.temps?.length === 8 ? curve.temps : fanTemps, curve?.pct?.length === 8 ? curve.pct : fanPresets.normal);
        } else applyCurve(fanTemps, fanPresets[m]);
    }

    Process {   // live fan speeds and CPU temperature
        id: fanRead
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); [ \"$n\" = asus ] && echo rpm $(cat $h/fan[123]_input 2>/dev/null); [ \"$n\" = k10temp -o \"$n\" = coretemp ] && echo temp $(cat $h/temp1_input); done"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.trim().split("\n")) {
                    const w = l.split(" ");
                    if (w[0] === "rpm") root.rpm = w.slice(1).map(Number);
                    if (w[0] === "temp") root.cpuTemp = Number(w[1]) / 1000;
                }
            }
        }
    }
    Timer { interval: 2000; running: root.asus && root.visible; repeat: true; triggeredOnStart: true; onTriggered: fanRead.running = true }

    SGroup {
        title: "Fans"
        visible: root.asus && root.curve !== null
        note: "Each power mode keeps its own fan setting; this is the one for " + ({ quiet: "Saver", balanced: "Balanced", performance: "Performance" })[root.fanProfile]
            + " mode. Auto lets the laptop decide. Very low curves under heavy load make the laptop throttle to stay cool."
        SRow {
            first: true
            icon: "mode_fan"
            title: root.rpm.length ? root.rpm.map((r, i) => ["CPU", "GPU", "Mid"][i] + " " + (r ? r + " rpm" : "off")).join(" · ") : "Fans"
            sub: root.cpuTemp ? "CPU at " + Math.round(root.cpuTemp) + "°C" : ""
        }
        SRow {
            icon: "tune"
            title: "Fan speed"
            sub: ({ auto: "The laptop's own fan control", silent: "Fans stay off until 50°C and stay low", normal: "Even, moderate cooling",
                    turbo: "Always on, cools hard", max: "Full speed all the time (loud)", custom: "Your curve: drag the points below" })[root.fanMode] ?? ""
            Seg {
                small: true
                model: [{ v: "auto", l: "Auto" }, { v: "silent", l: "Silent" }, { v: "normal", l: "Normal" }, { v: "turbo", l: "Turbo" },
                        { v: "max", l: "Max" }, { v: "custom", l: "Custom" }]
                value: root.fanMode
                onPicked: v => root.setFanMode(v)
            }
        }
        SRow {
            visible: !root.fanAuto
            icon: "show_chart"
            title: "Fan curve"
            sub: "Fan speed at each temperature, for all three fans"
            below: FanCurve {
                width: parent.width
                temps: root.curve?.temps ?? root.fanTemps
                pct: root.curve?.pct ?? []
                current: root.cpuTemp
                onEdited: (temps, pct) => root.applyCurve(temps, pct)
            }
        }
    }

    SGroup {
        title: "Battery"
        visible: Battery.present
        SRow {
            first: true
            icon: Battery.icon()
            title: Math.round(Battery.pct * 100) + "%" + (Battery.charging ? " · charging" : " · on battery")
            sub: Battery.charging ? (root.dur(Battery.dev?.timeToFull) ? root.dur(Battery.dev.timeToFull) + " until full" : "Plugged in")
               : (root.dur(Battery.dev?.timeToEmpty) ? root.dur(Battery.dev.timeToEmpty) + " left" : "")
            Txt {
                visible: (Battery.dev?.changeRate ?? 0) > 0
                text: (Battery.dev?.changeRate ?? 0).toFixed(1) + " W"
                font.pixelSize: 13; color: Theme.muted
            }
        }
        SRow {
            visible: root.asus
            icon: "battery_profile"
            title: "Charge limit"
            sub: "Stops charging here to keep the battery healthy when you're mostly plugged in. 80% is a good default."
            Txt { text: chargeSlider.shown + "%"; font.pixelSize: 15; font.weight: Theme.strong; font.features: { "tnum": 1 } }
            below: Slider {
                id: chargeSlider
                width: parent.width
                icon: "battery_charging_full"
                property int shown: root.limit
                value: (shown - 20) / 80
                onMoved: v => { shown = Math.round((20 + v * 80) / 5) * 5; applyLimit.restart(); }
                Connections { target: root; function onLimitChanged() { chargeSlider.shown = root.limit; } }
                Timer {
                    id: applyLimit
                    interval: 700
                    onTriggered: {
                        root.limit = chargeSlider.shown;
                        Quickshell.execDetached(["asusctl", "battery", "limit", String(chargeSlider.shown)]);
                    }
                }
            }
        }
        SRow {
            visible: root.asus
            icon: "battery_full"
            title: "Charge to 100% once"
            sub: "For a trip: charges fully this time, then the limit applies again"
            Btn { text: "Charge fully"; onClicked: Quickshell.execDetached(["asusctl", "battery", "oneshot"]) }
        }
    }

    SGroup {
        title: "Keyboard"
        visible: root.kbd !== ""
        SRow {
            first: true
            icon: "keyboard"
            title: "Backlight"
            Seg {
                small: true
                model: [{ v: "off", l: "Off" }, { v: "low", l: "Low" }, { v: "med", l: "Medium" }, { v: "high", l: "High" }]
                value: root.kbd === "medium" ? "med" : root.kbd
                onPicked: v => { root.kbd = v; Quickshell.execDetached(["asusctl", "leds", "set", v]); }
            }
        }
    }

    // Fan curve editor: 8 points (temperature → fan %). Drag a point up or down; the curve stays rising
    // (points to the right are never lower). edited() fires on release.
    component FanCurve: Item {
        id: curveRoot
        property var temps: []
        property var pct: []
        property real current: 0        // live CPU temperature, drawn as a marker
        signal edited(var temps, var pct)

        property var work: pct.slice()  // what's shown while dragging
        onPctChanged: work = pct.slice()

        readonly property real t0: 30
        readonly property real t1: 100
        readonly property real padL: 34
        readonly property real padB: 22
        readonly property real padT: 8
        readonly property real plotW: width - padL - 8
        readonly property real plotH: height - padB - padT
        function xOf(t) { return padL + (Math.min(Math.max(t, t0), t1) - t0) / (t1 - t0) * plotW; }
        function yOf(p) { return padT + (1 - p / 100) * plotH; }

        implicitHeight: 190

        Canvas {
            id: cv
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.font = "11px sans-serif";
                c.lineWidth = 1;
                c.strokeStyle = Theme.line;
                c.fillStyle = Theme.faint;
                for (let p = 0; p <= 100; p += 25) {
                    const y = curveRoot.yOf(p);
                    c.beginPath(); c.moveTo(curveRoot.padL, y); c.lineTo(curveRoot.width - 8, y); c.stroke();
                    c.fillText(p + "%", 0, y + 4);
                }
                for (let t = 30; t <= 100; t += 10) c.fillText(t + "°", curveRoot.xOf(t) - 8, curveRoot.height - 4);
                if (curveRoot.temps.length !== curveRoot.work.length || !curveRoot.work.length) return;
                const pts = curveRoot.temps.map((t, i) => [curveRoot.xOf(t), curveRoot.yOf(curveRoot.work[i])]);
                c.beginPath();
                c.moveTo(curveRoot.padL, pts[0][1]);
                pts.forEach(p => c.lineTo(p[0], p[1]));
                c.lineTo(curveRoot.width - 8, pts[pts.length - 1][1]);
                c.lineTo(curveRoot.width - 8, curveRoot.yOf(0));
                c.lineTo(curveRoot.padL, curveRoot.yOf(0));
                c.closePath();
                c.fillStyle = Qt.alpha(Theme.accent, 0.15);
                c.fill();
                c.beginPath();
                c.moveTo(curveRoot.padL, pts[0][1]);
                pts.forEach(p => c.lineTo(p[0], p[1]));
                c.lineTo(curveRoot.width - 8, pts[pts.length - 1][1]);
                c.strokeStyle = Theme.accent;
                c.lineWidth = 2;
                c.stroke();
                if (curveRoot.current > curveRoot.t0) {
                    const x = curveRoot.xOf(curveRoot.current);
                    c.strokeStyle = Theme.warn;
                    c.lineWidth = 1;
                    c.setLineDash([3, 3]);
                    c.beginPath(); c.moveTo(x, curveRoot.padT); c.lineTo(x, curveRoot.yOf(0)); c.stroke();
                    c.setLineDash([]);
                }
            }
            Connections {
                target: curveRoot
                function onWorkChanged() { cv.requestPaint(); }
                function onTempsChanged() { cv.requestPaint(); }
                function onCurrentChanged() { cv.requestPaint(); }
                function onWidthChanged() { cv.requestPaint(); }
            }
            Connections { target: Theme; function onAccentChanged() { cv.requestPaint(); } }
        }

        // One handle per point; dragging moves it vertically.
        Repeater {
            model: curveRoot.temps.length === curveRoot.work.length ? curveRoot.temps.length : 0
            Rectangle {
                id: h
                required property int index
                readonly property bool held: ma.pressed
                x: curveRoot.xOf(curveRoot.temps[index]) - width / 2
                y: curveRoot.yOf(curveRoot.work[index] ?? 0) - height / 2
                width: held ? 18 : 14; height: width; radius: width / 2
                color: Theme.accent
                border.width: 2
                border.color: Theme.bg
                Txt {
                    visible: h.held || ma.containsMouse
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: curveRoot.temps[h.index] + "° → " + Math.round(curveRoot.work[h.index]) + "%"
                    font.pixelSize: 11
                    font.weight: Theme.strong
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.SizeVerCursor
                    preventStealing: true
                    onPositionChanged: m => {
                        if (!pressed) return;
                        const y = mapToItem(root, m.x, m.y).y;
                        const v = Math.round(Math.max(0, Math.min(100, (1 - (y - curveRoot.padT) / curveRoot.plotH) * 100)));
                        const w = curveRoot.work.slice();
                        w[h.index] = v;
                        for (let k = h.index + 1; k < w.length; k++) w[k] = Math.max(w[k], v);
                        for (let k = h.index - 1; k >= 0; k--) w[k] = Math.min(w[k], v);
                        curveRoot.work = w;
                    }
                    onReleased: curveRoot.edited(curveRoot.temps.slice(), curveRoot.work.slice())
                }
            }
        }
    }
}
