import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Changes apply live through `niri msg output`, then ask to keep them; kept settings are written to
// ~/.config/niri/ansai-outputs.kdl (included by niri/config.kdl), unkept ones revert after 15 s.
ColumnLayout {
    id: root
    spacing: 22

    property var outs: ({})
    readonly property var names: Object.keys(outs).sort()
    readonly property string cfg: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/niri/ansai-outputs.kdl"

    // Pending confirmation: { name, before } where before is the output's previous state.
    property var pending: null
    property int secs: 0

    function refresh() { query.running = true; }
    Process {
        id: query
        running: true
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.outs = JSON.parse(text); } catch (e) {} }
        }
    }
    Timer { interval: 4000; running: root.pending === null; repeat: true; onTriggered: root.refresh() }

    function modeStr(m) { return `${m.width}x${m.height}@${(m.refresh_rate / 1000).toFixed(3)}`; }
    function cur(o) { return o.current_mode !== null && o.current_mode !== undefined ? o.modes[o.current_mode] : null; }
    function tf(t) { return ({ Normal: "normal", _90: "90", _180: "180", _270: "270", Flipped: "flipped", Flipped90: "flipped-90", Flipped180: "flipped-180", Flipped270: "flipped-270" })[t] ?? String(t).toLowerCase(); }
    function vrrOf(o) { return o.vrr_enabled ? "on" : "off"; }

    // Snapshot of what we can set, for revert and for writing the kdl.
    function state(o) {
        const m = cur(o);
        return {
            on: !!o.logical && !!m,
            mode: m ? modeStr(m) : "",
            scale: o.logical?.scale ?? 1,
            transform: tf(o.logical?.transform ?? "Normal"),
            vrr: vrrOf(o),
            x: o.logical?.x ?? 0,
            y: o.logical?.y ?? 0
        };
    }

    function msg(name, args) {
        Quickshell.execDetached(["niri", "msg", "output", name].concat(args));
    }
    function applyState(name, s) {
        if (!s.on) { msg(name, ["off"]); return; }
        msg(name, ["on"]);
        if (s.mode) msg(name, ["mode", s.mode]);
        msg(name, ["scale", String(s.scale)]);
        msg(name, ["transform", s.transform]);
        msg(name, s.vrr === "on-demand" ? ["vrr", "on", "--on-demand"] : ["vrr", s.vrr]);
        msg(name, ["position", "set", String(s.x), String(s.y)]);
    }

    // One change: remember the old state, apply, and start the countdown.
    function change(name, args) {
        const o = outs[name];
        if (!o) return;
        if (!pending) pending = { name: name, before: state(o) };
        msg(name, args);
        secs = 15;
        countdown.restart();
        settle.restart();
    }
    Timer { id: settle; interval: 600; onTriggered: root.refresh() }
    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: { if (--root.secs <= 0) root.revert(); }
    }
    function revert() {
        countdown.stop();
        if (pending) applyState(pending.name, pending.before);
        pending = null;
        settle.restart();
    }
    function keep() {
        countdown.stop();
        pending = null;
        save();
    }

    // VRR from niri's JSON only says on/off; keep "on-demand" from the file we wrote before.
    property var savedVrr: ({})
    FileView {
        id: file
        path: root.cfg
        blockLoading: false
        printErrors: false
        atomicWrites: true
        onLoaded: {
            const v = {};
            const re = /output "([^"]+)" \{([^}]*)\}/g;
            for (let m = re.exec(text()); m; m = re.exec(text()))
                if (/variable-refresh-rate on-demand=true/.test(m[2])) v[m[1]] = "on-demand";
                else if (/variable-refresh-rate/.test(m[2])) v[m[1]] = "on";
            root.savedVrr = v;
        }
    }
    function vrrMode(name) {
        const o = outs[name];
        if (!o) return "off";
        if (savedVrr[name] === "on-demand") return "on-demand";
        return vrrOf(o);
    }
    function save() {
        let t = "// Display settings. ansai Settings > Displays rewrites this file when you keep a change.\n";
        for (const n of names) {
            const o = outs[n], s = state(o);
            t += `\noutput "${n}" {\n`;
            if (!s.on) { t += "    off\n}\n"; continue; }
            if (s.mode) t += `    mode "${s.mode}"\n`;
            t += `    scale ${s.scale}\n`;
            if (s.transform !== "normal") t += `    transform "${s.transform}"\n`;
            const v = vrrMode(n);
            if (v === "on-demand") t += "    variable-refresh-rate on-demand=true\n";
            else if (v === "on") t += "    variable-refresh-rate\n";
            if (names.length > 1) t += `    position x=${s.x} y=${s.y}\n`;
            t += "}\n";
        }
        file.setText(t);
        Qt.callLater(() => file.reload());
    }

    // ---- confirm banner
    Rectangle {
        visible: root.pending !== null
        Layout.fillWidth: true
        implicitHeight: bannerRow.implicitHeight + 28
        radius: Theme.rGroup
        color: Theme.m3 ? Theme.accentSoft : Theme.accent
        RowLayout {
            id: bannerRow
            anchors { fill: parent; margins: 14; leftMargin: 18 }
            spacing: 12
            Icon { name: "help"; size: 22; color: Theme.m3 ? Theme.accentSoftInk : "#ffffff" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Txt { text: "Keep these display settings?"; font.pixelSize: 15; font.weight: Theme.strong; color: Theme.m3 ? Theme.accentSoftInk : "#ffffff" }
                Txt { text: `Reverting in ${root.secs} s`; font.pixelSize: 12; color: Theme.m3 ? Theme.accentSoftInk : "#ffffffcc" }
            }
            Btn { text: "Revert"; kind: "text"; onClicked: root.revert() }
            Btn { text: "Keep"; kind: Theme.m3 ? "filled" : "tonal"; onClicked: root.keep() }
        }
    }

    Repeater {
        model: root.names
        SGroup {
            id: g
            required property string modelData
            readonly property var o: root.outs[modelData]
            readonly property var s: o ? root.state(o) : ({})
            readonly property var m: o ? root.cur(o) : null
            readonly property var sizes: o ? o.modes.map(x => `${x.width}x${x.height}`).filter((v, i, a) => a.indexOf(v) === i) : []
            readonly property string size: m ? `${m.width}x${m.height}` : ""
            readonly property var rates: o ? o.modes.filter(x => `${x.width}x${x.height}` === size) : []
            readonly property int onCount: root.names.filter(n => root.outs[n].logical).length
            title: `${modelData} · ${(o?.make ?? "").trim()} ${(o?.model ?? "").trim()}`
            note: o?.physical_size ? `${(Math.hypot(o.physical_size[0], o.physical_size[1]) / 25.4).toFixed(1)}″ panel · ${o.physical_size[0]}×${o.physical_size[1]} mm`
                + (o.logical ? ` · desktop ${o.logical.width}×${o.logical.height} at ${o.logical.x},${o.logical.y}` : "") : ""

            SRow {
                first: true
                icon: "desktop_windows"
                title: "Use this display"
                sub: g.onCount <= 1 && g.s.on ? "It is the only one on" : ""
                Switch {
                    checked: g.s.on ?? false
                    opacity: g.onCount <= 1 && g.s.on ? 0.4 : 1
                    onToggled: if (!(g.onCount <= 1 && g.s.on)) root.change(g.modelData, [g.s.on ? "off" : "on"])
                }
            }
            SRow {
                visible: g.s.on ?? false
                icon: "aspect_ratio"
                title: "Resolution"
                sub: g.m?.is_preferred ? "Recommended" : ""
                below: Chips {
                    model: g.sizes.map(v => ({ v: v, l: v.replace("x", " × ") + (g.o.modes.some(x => x.is_preferred && `${x.width}x${x.height}` === v) ? "  ★" : "") }))
                    value: g.size
                    onPicked: v => {
                        // Keep the refresh rate if this size has it, else the fastest.
                        const opts = g.o.modes.filter(x => `${x.width}x${x.height}` === v).sort((a, b) => b.refresh_rate - a.refresh_rate);
                        const same = opts.find(x => Math.abs(x.refresh_rate - (g.m?.refresh_rate ?? 0)) < 500);
                        root.change(g.modelData, ["mode", root.modeStr(same ?? opts[0])]);
                    }
                }
            }
            SRow {
                visible: (g.s.on ?? false) && g.rates.length > 0
                icon: "speed"
                title: "Refresh rate"
                below: Chips {
                    model: g.rates.map(x => ({ v: x.refresh_rate, l: (x.refresh_rate / 1000).toFixed(x.refresh_rate % 1000 ? 2 : 0) + " Hz" }))
                    value: g.m?.refresh_rate
                    onPicked: v => root.change(g.modelData, ["mode", root.modeStr(g.rates.find(x => x.refresh_rate === v))])
                }
            }
            SRow {
                visible: g.s.on ?? false
                icon: "zoom_out_map"
                title: "Scale"
                sub: g.o?.logical ? `Looks like ${Math.round(g.m.width / g.s.scale)} × ${Math.round(g.m.height / g.s.scale)}` : ""
                below: Chips {
                    model: {
                        const l = [1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3];
                        if (g.s.scale && !l.includes(g.s.scale)) l.push(g.s.scale);
                        return l.sort((a, b) => a - b).map(v => ({ v: v, l: Math.round(v * 100) + "%" }));
                    }
                    value: g.s.scale
                    onPicked: v => root.change(g.modelData, ["scale", String(v)])
                }
            }
            SRow {
                visible: g.s.on ?? false
                icon: "screen_rotation"
                title: "Rotation"
                Seg {
                    small: true
                    model: [{ v: "normal", l: "None" }, { v: "90", l: "90°" }, { v: "180", l: "180°" }, { v: "270", l: "270°" }]
                    value: g.s.transform
                    onPicked: v => root.change(g.modelData, ["transform", v])
                }
            }
            SRow {
                visible: (g.s.on ?? false) && (g.o?.vrr_supported ?? false)
                icon: "motion_blur"
                title: "Variable refresh rate"
                sub: root.vrrMode(g.modelData) === "on-demand" ? "Only for windows with the VRR window rule (games, video)"
                   : root.vrrMode(g.modelData) === "on" ? "Always on: smoother, may flicker on some panels" : "Fixed refresh rate"
                Seg {
                    small: true
                    model: [{ v: "off", l: "Off" }, { v: "on-demand", l: "On demand" }, { v: "on", l: "On" }]
                    value: root.vrrMode(g.modelData)
                    onPicked: v => {
                        const sv = Object.assign({}, root.savedVrr);
                        sv[g.modelData] = v;
                        root.savedVrr = sv;
                        root.change(g.modelData, v === "on-demand" ? ["vrr", "on", "--on-demand"] : ["vrr", v]);
                    }
                }
            }
            SRow {
                visible: (g.s.on ?? false) && root.names.length > 1
                icon: "view_quilt"
                title: "Position"
                sub: "Where this display sits next to the others"
                Seg {
                    small: true
                    model: [{ v: "left", l: "Left" }, { v: "right", l: "Right" }, { v: "above", l: "Above" }, { v: "below", l: "Below" }]
                    value: ""
                    onPicked: v => {
                        // Place relative to the first other display that is on.
                        const other = root.names.map(n => root.outs[n]).find(x => x.name !== g.modelData && x.logical);
                        if (!other) return;
                        const L = other.logical, me = g.o.logical;
                        const p = v === "left" ? [L.x - me.width, L.y] : v === "right" ? [L.x + L.width, L.y]
                                : v === "above" ? [L.x, L.y - me.height] : [L.x, L.y + L.height];
                        root.change(g.modelData, ["position", "set", String(p[0]), String(p[1])]);
                    }
                }
            }
        }
    }

    SGroup {
        SRow {
            first: true
            icon: "cable"
            title: root.names.length > 1 ? `${root.names.length} displays connected` : "Plug in a display"
            sub: "HDMI and USB-C displays show up here a moment after you connect them. Super+Shift+arrows moves windows between them."
            Btn { text: "Refresh"; icon: "refresh"; onClicked: root.refresh() }
        }
    }
}
