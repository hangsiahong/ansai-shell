pragma Singleton

import QtQuick
import qs
import qs.services
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool available: Quickshell.env("NIRI_SOCKET") !== ""
    property var workspaces: []
    property var windows: ({})
    property int focusedWindowId: -1
    property bool overviewOpen: false
    property var layoutNames: []
    property int layoutIdx: 0
    readonly property string keyboardLayout: layoutNames[layoutIdx] ?? ""
    readonly property string focusedOutput: workspaces.find(w => w.is_focused)?.output ?? ""
    readonly property var focusedWindow: windows[focusedWindowId] ?? null
    // Survives shell overlays taking keyboard focus (niri then reports no focused window).
    property int lastWindowId: -1
    onFocusedWindowIdChanged: if (focusedWindowId >= 0) lastWindowId = focusedWindowId
    readonly property var barWindow: Shell.open !== "" ? (windows[lastWindowId] ?? null) : focusedWindow

    function workspacesOn(output: string): var {
        return workspaces.filter(w => w.output === output || !w.output).sort((a, b) => a.idx - b.idx);
    }

    function windowsOn(workspaceId: int): var {
        return Object.values(windows).filter(w => w.workspace_id === workspaceId);
    }

    function action(...args): void {
        Quickshell.execDetached(["niri", "msg", "action", ...args]);
    }

    function focusWorkspace(ws: var): void {
        action("focus-workspace", String(ws.idx));
    }

    function closeWindow(id: int): void {
        action("close-window", "--id", String(id));
    }

    // Desktop-entry id for an app_id or a pinned id, so windows and pins match.
    function appKey(id: string): string {
        if (!id) return "";
        const e = DesktopEntries.heuristicLookup(id);
        return (e?.id ?? id).toLowerCase();
    }

    function stamp(w: var): real {
        const t = w.focus_timestamp;
        return t ? t.secs * 1e3 + t.nanos / 1e6 : 0;
    }

    function focusWindow(id: int): void {
        action("focus-window", "--id", String(id));
    }

    // App hotkeys: focus the app's latest window, start it if none is open, and if it's already
    // focused go back to the window used before it. `id` is the desktop entry id (without .desktop).
    function raiseApp(id: string): void {
        const key = appKey(id);
        const byTime = l => l.sort((a, b) => stamp(b) - stamp(a));
        const all = Object.values(windows);
        const cur = windows[focusedWindowId];
        if (cur && appKey(cur.app_id) === key) {
            const back = byTime(all.filter(w => appKey(w.app_id) !== key))[0];
            if (back) focusWindow(back.id);
            return;
        }
        const mine = byTime(all.filter(w => appKey(w.app_id) === key))[0];
        if (mine) { focusWindow(mine.id); return; }
        const e = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
        if (e) e.execute();
        else Quickshell.execDetached(["notify-send", "ansai", "No app called " + id]);
    }

    function handle(ev: var): void {
        if (ev.WorkspacesChanged) {
            workspaces = ev.WorkspacesChanged.workspaces;
        } else if (ev.WorkspaceActivated) {
            const { id, focused } = ev.WorkspaceActivated;
            const target = workspaces.find(w => w.id === id);
            workspaces = workspaces.map(w => {
                const c = Object.assign({}, w);
                if (target && w.output === target.output)
                    c.is_active = w.id === id;
                if (focused)
                    c.is_focused = w.id === id;
                return c;
            });
        } else if (ev.WindowsChanged) {
            const m = {};
            for (const w of ev.WindowsChanged.windows) {
                m[w.id] = w;
                if (w.is_focused)
                    focusedWindowId = w.id;
            }
            windows = m;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const m = Object.assign({}, windows);
            m[w.id] = w;
            windows = m;
            if (w.is_focused)
                focusedWindowId = w.id;
        } else if (ev.WindowClosed) {
            const m = Object.assign({}, windows);
            delete m[ev.WindowClosed.id];
            windows = m;
        } else if (ev.WindowLayoutsChanged) {
            const m = Object.assign({}, windows);
            for (const [id, layout] of ev.WindowLayoutsChanged.changes) {
                if (m[id])
                    m[id] = Object.assign({}, m[id], { layout: layout });
            }
            windows = m;
        } else if (ev.WindowFocusTimestampChanged) {
            const e = ev.WindowFocusTimestampChanged;
            if (windows[e.id]) {
                const m = Object.assign({}, windows);
                m[e.id] = Object.assign({}, m[e.id], { focus_timestamp: e.focus_timestamp });
                windows = m;
            }
        } else if (ev.WindowUrgencyChanged) {
            const e = ev.WindowUrgencyChanged;
            if (windows[e.id]) {
                const m = Object.assign({}, windows);
                m[e.id] = Object.assign({}, m[e.id], { is_urgent: e.urgent });
                windows = m;
            }
        } else if (ev.WindowFocusChanged) {
            focusedWindowId = ev.WindowFocusChanged.id ?? -1;
        } else if (ev.OverviewOpenedOrClosed) {
            overviewOpen = ev.OverviewOpenedOrClosed.is_open;
        } else if (ev.KeyboardLayoutsChanged) {
            const k = ev.KeyboardLayoutsChanged.keyboard_layouts;
            layoutNames = k.names;
            layoutIdx = k.current_idx;
        } else if (ev.KeyboardLayoutSwitched) {
            layoutIdx = ev.KeyboardLayoutSwitched.idx;
        }
    }

    Process {
        id: stream
        running: root.available
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line));
                } catch (e) {}
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 1000
        onTriggered: stream.running = root.available
    }
}
