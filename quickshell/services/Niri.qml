pragma Singleton

import QtQuick
import qs
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

    function focusWindow(id: int): void {
        action("focus-window", "--id", String(id));
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
