import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Process viewer (Alt+Shift+Backspace): running programs grouped by name, sorted by memory, CPU or GPU,
// refreshed every 2 s from scripts/procs.py while open. Type to filter, ↑↓ to move, Enter expands a group,
// Tab changes the sort. Kill (or Delete) twice force-kills (SIGKILL) the group or one process.
Sheet {
    id: root
    name: "procs"
    exclusiveKeys: true
    panelWidth: Math.min(760, width - 32)
    panelHeight: Math.min(660, height - panelY - 40)
    panelY: height * 0.12
    panelRadius: Theme.m3 ? 28 : 22

    property var procs: []
    property string query: ""
    property string sort: "mem"   // mem | cpu | gpu
    property int sel: 0
    property string open: ""      // expanded group name
    property string armed: ""     // "g:<name>" or "p:<pid>": the kill button waiting for its second click
    readonly property var sorts: [["mem", "Memory"], ["cpu", "CPU"], ["gpu", "GPU"]]
    readonly property var protect: ["niri", "qs", "quickshell", "systemd", "dbus-broker", "pipewire", "wireplumber"]

    function key(p): real { return sort === "cpu" ? p.cpu : sort === "gpu" ? p.gpu * 1000 + (p.nv ? 1 : 0) + p.vram / 1e9 : p.rss + p.swap; }
    readonly property var groups: {
        const q = query.trim().toLowerCase();
        const m = {};
        for (const p of procs) {
            if (q && !p.name.toLowerCase().includes(q) && !p.cmd.toLowerCase().includes(q)) continue;
            const g = m[p.name] ?? (m[p.name] = { name: p.name, n: 0, cpu: 0, rss: 0, swap: 0, gpu: 0, vram: 0, nv: false, mine: true, kids: [] });
            g.n++; g.cpu += p.cpu; g.rss += p.rss; g.swap += p.swap; g.gpu += p.gpu; g.vram += p.vram;
            g.nv = g.nv || p.nv; g.mine = g.mine && p.mine;
            g.kids.push(p);
        }
        const out = Object.values(m).sort((a, b) => key(b) - key(a)).slice(0, 80);
        for (const g of out) g.kids.sort((a, b) => key(b) - key(a));
        return out;
    }

    function mem(kb: real): string {
        return kb >= 1048576 ? (kb / 1048576).toFixed(1) + " GB" : Math.round(kb / 1024) + " MB";
    }
    function canKill(name: string, mine: bool): bool { return mine && !protect.includes(name); }
    function kill(tag: string, pids: var): void {
        if (armed !== tag) { armed = tag; disarm.restart(); return; }
        armed = "";
        Quickshell.execDetached(["kill", "-9"].concat(pids.map(String)));
        procs = procs.filter(p => !pids.includes(p.pid));
    }
    Timer { id: disarm; interval: 3000; onTriggered: root.armed = "" }

    onShownChanged: if (shown) {
        input.text = ""; query = ""; sel = 0; open = ""; armed = "";
        input.forceActiveFocus();
    }

    Process {
        running: root.shown
        command: ["python3", Quickshell.shellDir + "/scripts/procs.py", "2"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => { try { root.procs = JSON.parse(data); } catch (e) {} }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // ---- search + sort
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.m3 ? 52 : 44
            Layout.fillHeight: false
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: height / 2
                color: Theme.m3 ? Theme.surface3 : "transparent"
                Icon { id: sIcon; x: 14; anchors.verticalCenter: parent.verticalCenter; name: "monitoring"; size: 22; color: Theme.muted }
                TextInput {
                    id: input
                    anchors { left: sIcon.right; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 18
                    clip: true
                    focus: true
                    onTextChanged: { root.query = text; root.sel = 0; }
                    Keys.onEscapePressed: root.open ? (root.open = "") : Shell.close()
                    Keys.onDownPressed: root.sel = Math.min(root.groups.length - 1, root.sel + 1)
                    Keys.onUpPressed: root.sel = Math.max(0, root.sel - 1)
                    Keys.onReturnPressed: { const g = root.groups[root.sel]; if (g) root.open = root.open === g.name ? "" : g.name; }
                    Keys.onTabPressed: root.sort = root.sorts[(root.sorts.findIndex(s => s[0] === root.sort) + 1) % root.sorts.length][0]
                    Keys.onPressed: e => {
                        if (e.key !== Qt.Key_Delete) return;
                        const g = root.groups[root.sel];
                        if (g && root.canKill(g.name, g.mine)) root.kill("g:" + g.name, g.kids.map(p => p.pid));
                        e.accepted = true;
                    }
                    Txt { anchors.fill: parent; visible: !input.text; text: "Search processes"; color: Theme.faint; font.pixelSize: 18 }
                }
            }
            Repeater {
                model: root.sorts
                Hover {
                    id: sb
                    required property var modelData
                    readonly property bool on: root.sort === modelData[0]
                    Layout.preferredWidth: sbTxt.implicitWidth + 24
                    Layout.preferredHeight: 30
                    radius: 15
                    base: on ? Theme.accent : Theme.fill2
                    onClicked: { root.sort = modelData[0]; input.forceActiveFocus(); }
                    Txt { id: sbTxt; anchors.centerIn: parent; text: sb.modelData[1]; font.pixelSize: 12; font.weight: Theme.strong; color: sb.on ? Theme.accentInk : Theme.text }
                }
            }
        }

        // ---- totals
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            spacing: 18
            Repeater {
                model: [["developer_board", "CPU " + Math.round(SysStats.cpu * 100) + "%"],
                        ["memory", "RAM " + SysStats.gb(SysStats.memUsed, false) + " / " + SysStats.gb(SysStats.memTotal)],
                        ["sync", "Swap " + SysStats.gb(SysStats.swapUsed, false) + " / " + SysStats.gb(SysStats.swapTotal)]]
                Row {
                    required property var modelData
                    spacing: 5
                    Icon { name: parent.modelData[0]; size: 15; filled: true; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: parent.modelData[1]; font.pixelSize: 12; color: Theme.text2; font.features: { "tnum": 1 }; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Item { Layout.fillWidth: true }
            Txt { text: root.procs.length ? root.procs.length + " processes" : "Reading…"; font.pixelSize: 12; color: Theme.faint }
        }

        // ---- column titles
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 10
            spacing: 8
            Txt { Layout.fillWidth: true; text: "Name"; font.pixelSize: 11; font.weight: Theme.strong; color: Theme.muted }
            Txt { Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight; text: "CPU"; font.pixelSize: 11; font.weight: Theme.strong; color: root.sort === "cpu" ? Theme.accent : Theme.muted }
            Txt { Layout.preferredWidth: 130; horizontalAlignment: Text.AlignRight; text: "Memory (+swap)"; font.pixelSize: 11; font.weight: Theme.strong; color: root.sort === "mem" ? Theme.accent : Theme.muted }
            Txt { Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight; text: "GPU"; font.pixelSize: 11; font.weight: Theme.strong; color: root.sort === "gpu" ? Theme.accent : Theme.muted }
            Item { Layout.preferredWidth: 78 }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.groups
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.sel
            highlightMoveDuration: 0
            delegate: Column {
                id: grp
                required property var modelData
                required property int index
                readonly property bool expanded: root.open === modelData.name
                width: list.width

                ProcRow {
                    width: parent.width
                    active: grp.index === root.sel
                    title: grp.modelData.name + (grp.modelData.n > 1 ? "  ×" + grp.modelData.n : "")
                    sub: ""
                    p: grp.modelData
                    chevron: grp.modelData.n > 1 ? (grp.expanded ? "expand_less" : "expand_more") : ""
                    killTag: "g:" + grp.modelData.name
                    count: grp.modelData.n
                    killable: root.canKill(grp.modelData.name, grp.modelData.mine)
                    onClicked: { root.sel = grp.index; root.open = grp.expanded ? "" : grp.modelData.name; input.forceActiveFocus(); }
                    onKill: root.kill("g:" + grp.modelData.name, grp.modelData.kids.map(k => k.pid))
                }
                Repeater {
                    model: grp.expanded ? grp.modelData.kids.slice(0, 40) : []
                    ProcRow {
                        required property var modelData
                        width: grp.width
                        indent: 22
                        title: String(modelData.pid)
                        sub: modelData.cmd
                        p: modelData
                        killTag: "p:" + modelData.pid
                        killable: root.canKill(modelData.name, modelData.mine)
                        onKill: root.kill("p:" + modelData.pid, [modelData.pid])
                    }
                }
            }
        }

        Txt {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            text: "Enter: expand · Tab: sort · Delete twice: force kill · Esc: close"
            font.pixelSize: 11
            color: Theme.faint
        }
    }

    // One row: name (or pid + command), CPU, memory (+swap), GPU (% and VRAM, "dGPU" when it holds the NVIDIA GPU), kill.
    component ProcRow: Hover {
        id: r
        property string title
        property string sub
        property var p
        property string chevron: ""
        property string killTag
        property bool killable: true
        property int indent: 0
        property int count: 1
        signal kill()
        readonly property bool armed: root.armed === killTag
        height: sub ? 40 : 38
        radius: Theme.m3 ? height / 2 : 9
        activeColor: Theme.m3 ? Theme.accentSoft : Theme.fill
        RowLayout {
            anchors { fill: parent; leftMargin: 14 + r.indent; rightMargin: 8 }
            spacing: 8
            Column {
                Layout.fillWidth: true
                spacing: 0
                Row {
                    spacing: 4
                    Txt { text: r.title; font.pixelSize: 13; font.weight: r.indent ? Font.Normal : Theme.strong; color: r.indent ? Theme.text2 : Theme.text; font.features: { "tnum": 1 } }
                    Icon { visible: !!r.chevron; name: r.chevron || "expand_more"; size: 15; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                }
                Txt { visible: !!r.sub; width: parent.width; text: r.sub; font.pixelSize: 11; color: Theme.muted; elide: Text.ElideRight }
            }
            Txt {
                Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight
                text: r.p.cpu >= 10 ? Math.round(r.p.cpu) + "%" : r.p.cpu.toFixed(1) + "%"
                font.pixelSize: 12; font.features: { "tnum": 1 }
                color: r.p.cpu >= 100 ? Theme.danger : r.p.cpu < 0.1 ? Theme.faint : Theme.text2
            }
            Row {
                Layout.preferredWidth: 130
                layoutDirection: Qt.RightToLeft
                spacing: 4
                Txt { visible: r.p.swap > 10240; text: "+" + root.mem(r.p.swap); font.pixelSize: 11; color: Theme.faint; anchors.baseline: mt.baseline; font.features: { "tnum": 1 } }
                Txt { id: mt; text: root.mem(r.p.rss); font.pixelSize: 12; color: r.p.rss + r.p.swap > 2097152 ? Theme.warn : Theme.text2; font.features: { "tnum": 1 } }
            }
            Row {
                Layout.preferredWidth: 90
                layoutDirection: Qt.RightToLeft
                spacing: 5
                Txt { text: r.p.gpu >= 0.1 ? r.p.gpu.toFixed(1) + "%" : r.p.vram > 10240 ? root.mem(r.p.vram) : "–"; font.pixelSize: 12; color: r.p.gpu >= 0.1 || r.p.vram > 10240 ? Theme.text2 : Theme.faint; font.features: { "tnum": 1 } }
                Rectangle {
                    visible: r.p.nv
                    width: nvTxt.implicitWidth + 8; height: 16; radius: 4
                    color: Theme.green
                    anchors.verticalCenter: parent.verticalCenter
                    Txt { id: nvTxt; anchors.centerIn: parent; text: "dGPU"; font.pixelSize: 9; font.weight: Font.Bold; color: "#ffffff" }
                }
            }
            Hover {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 26
                radius: 13
                opacity: r.killable ? 1 : 0
                enabled: r.killable
                base: r.armed ? Theme.danger : (r.hovered || hovered ? Theme.fill2 : "transparent")
                onClicked: r.kill()
                Txt { anchors.centerIn: parent; text: r.armed ? (r.count > 1 ? "Kill " + r.count + "?" : "Kill?") : "Kill"; font.pixelSize: 12; font.weight: Theme.strong; color: r.armed ? "#ffffff" : Theme.danger }
            }
        }
    }
}
