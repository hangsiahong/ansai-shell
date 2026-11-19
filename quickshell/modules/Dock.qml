import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Bottom dock: pinned apps, then running ones. Auto-hides (smart, auto, or never; see Settings.dockMode).
// Left click focuses / launches / cycles windows, middle opens a new one, wheel cycles,
// drag reorders (drag up and off to unpin), right click opens DockMenu.
PanelWindow {
    id: root
    required property ShellScreen modelData
    screen: modelData

    readonly property int size: Settings.dockSize
    readonly property int pad: 8
    readonly property int gap: 8          // dock to screen edge
    readonly property int boxH: size + pad * 2
    readonly property int tipRoom: 44     // tooltip and magnify headroom

    anchors { bottom: true; left: true; right: true }
    // Grows while dragging so a pulled-up icon is not clipped.
    implicitHeight: boxH + gap + tipRoom + (dragKey !== "" ? 120 : 0)
    color: "transparent"
    exclusionMode: Settings.dockMode === "always" ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: Settings.dockMode === "always" ? boxH + gap : 0
    WlrLayershell.namespace: "ansai-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ---- what is on the dock
    readonly property var ws: Niri.workspaces.find(w => (w.output === modelData.name || !w.output) && w.is_active) ?? null
    readonly property var items: {
        const wins = Object.values(Niri.windows);
        const byKey = {};
        for (const w of wins) {
            const k = Niri.appKey(w.app_id);
            (byKey[k] = byKey[k] ?? []).push(w);
        }
        const out = [];
        const seen = {};
        for (const id of Settings.pinned) {
            const k = Niri.appKey(id);
            if (seen[k]) continue;
            seen[k] = true;
            out.push({ key: k, id: id, pinned: true, entry: DesktopEntries.heuristicLookup(id), windows: byKey[k] ?? [] });
        }
        for (const w of wins.sort((a, b) => a.id - b.id)) {
            const k = Niri.appKey(w.app_id);
            if (seen[k]) continue;
            seen[k] = true;
            out.push({ key: k, id: w.app_id, pinned: false, entry: DesktopEntries.heuristicLookup(w.app_id), windows: byKey[k] });
        }
        for (const it of out)
            it.windows.sort((a, b) => Niri.stamp(b) - Niri.stamp(a));
        return out;
    }

    // ---- auto-hide
    readonly property real boxTop: height - gap - boxH
    // Tiled windows always span the full height in niri, so any tiled window covers the dock.
    readonly property bool covered: {
        if (!ws) return false;
        return Niri.windowsOn(ws.id).some(w => {
            if (!w.is_floating) return true;
            const p = w.layout?.tile_pos_in_workspace_view, s = w.layout?.tile_size;
            if (!p || !s) return true;
            return p[1] + s[1] > boxTop && p[0] < box.x + box.width && p[0] + s[0] > box.x;
        });
    }
    readonly property bool menuHere: Shell.open === "dockmenu"
    property bool hot: false
    property string dragKey: ""
    readonly property bool revealed: Settings.dockMode === "always"
        || hot || menuHere || dragKey !== "" || items.some(i => i.windows.some(w => w.is_urgent))
        || (Settings.dockMode === "smart" && !covered && Shell.open === "")

    HoverHandler {
        onHoveredChanged: {
            if (hovered) { leave.stop(); root.hot = true; }
            else leave.restart();
        }
    }
    Timer { id: leave; interval: 400; onTriggered: root.hot = false }

    mask: Region { item: root.revealed ? hit : edge }
    Item { id: edge; x: box.x; width: box.width; y: root.height - 2; height: 2 }
    Item { id: hit; x: box.x; width: box.width; y: root.boxTop; height: root.height - root.boxTop }

    BackgroundEffect.blurRegion: Region { item: box; radius: box.radius }

    // ---- the dock
    Glass {
        id: box
        width: row.width + root.pad * 2
        height: root.boxH
        x: (root.width - width) / 2
        y: root.revealed ? root.boxTop : root.height + 2
        radius: Theme.m3 ? height / 2 : Theme.rLg + 4
        Behavior on y { NumberAnimation { duration: Theme.med; easing.type: root.revealed ? Theme.spring : Theme.easing } }
        Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: m => root.openMenu(null, box.x + m.x)
        }

        Row {
            id: row
            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Apps grid button
            Hover {
                width: root.size; height: root.size
                radius: Theme.m3 ? height / 2 : root.size * 0.258
                base: Theme.m3 ? Theme.accentSoft : Theme.fill2
                active: Shell.open === "launcher"
                activeColor: Theme.accent
                onClicked: m => {
                    if (m.button === Qt.RightButton) root.openMenu(null, box.x + row.x + x + width / 2);
                    else Shell.toggle("launcher");
                }
                Icon {
                    anchors.centerIn: parent
                    name: "apps"
                    size: root.size * 0.5
                    color: parent.active ? Theme.accentInk : Theme.m3 ? Theme.accentSoftInk : Theme.text
                }
            }
            Rectangle {
                width: 1; height: root.size * 0.6
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.line
                visible: root.items.length > 0
            }

            Repeater {
                id: rep
                model: root.items
                DockItem {
                    dock: root
                    required property var modelData
                    required property int index
                    item: modelData
                    idx: index
                    firstUnpinned: !modelData.pinned && index > 0 && root.items[index - 1].pinned
                }
            }
        }

        // Drop marker while reordering
        Rectangle {
            id: marker
            visible: root.dragKey !== "" && root.dropX >= 0
            x: root.dropX - box.x - 1
            y: root.pad
            width: 3; height: root.size
            radius: 1.5
            color: Theme.accent
        }
    }

    // ---- actions
    property real dropX: -1
    property int dropIdx: -1

    function launch(it: var): void {
        if (it.entry) {
            const u = Object.assign({}, Settings.usage ?? {});
            u[it.entry.id] = (u[it.entry.id] ?? 0) + 1;
            Settings.usage = u;
            it.entry.execute();
        } else {
            Quickshell.execDetached([it.id]);
        }
    }

    // Focused app: cycle through its windows. Otherwise jump to its most recent one.
    function activate(it: var, step: int): void {
        if (it.windows.length === 0) { launch(it); return; }
        const ids = it.windows.map(w => w.id).sort((a, b) => a - b);
        const cur = ids.indexOf(Niri.focusedWindowId);
        if (cur < 0) Niri.focusWindow(it.windows[0].id);
        else if (ids.length > 1) Niri.focusWindow(ids[(cur + step + ids.length) % ids.length]);
    }

    function openMenu(it: var, x: real): void {
        Shell.dockItem = it;
        Shell.dockMenuX = x;
        Shell.dockTop = root.screen.height - root.gap - root.boxH;   // screen coordinates, for the menu sheet
        Shell.open = "dockmenu";
        root.hot = true;
    }

    function pin(id: string, at: int): void {
        const k = Niri.appKey(id);
        const list = Array.from(Settings.pinned).filter(p => Niri.appKey(p) !== k);
        const entry = DesktopEntries.heuristicLookup(id);
        list.splice(Math.max(0, Math.min(at < 0 ? list.length : at, list.length)), 0, entry?.id ?? id);
        Settings.pinned = list;
    }
    function unpin(id: string): void {
        const k = Niri.appKey(id);
        Settings.pinned = Array.from(Settings.pinned).filter(p => Niri.appKey(p) !== k);
    }

    // Called by a dragged DockItem with its centre in window coordinates.
    function dragTo(cx: real): void {
        let best = -1, bestD = 1e9, bx = -1;
        const n = Settings.pinned.length;
        for (let i = 0; i < rep.count; i++) {
            const d = rep.itemAt(i);
            if (!d || !d.item.pinned) continue;
            const p = d.mapToItem(root.contentItem, 0, 0);
            for (const [slot, sx] of [[i, p.x - 3], [i + 1, p.x + d.width + 3]]) {
                const dist = Math.abs(cx - sx);
                if (dist < bestD) { bestD = dist; best = slot; bx = sx; }
            }
        }
        if (n === 0) {
            const first = rep.itemAt(0);
            bx = first ? first.mapToItem(root.contentItem, 0, 0).x - 3 : box.x + root.pad;
            best = 0;
        }
        dropIdx = best;
        dropX = bx;
    }
    function drop(it: var, offDock: bool): void {
        if (offDock) {
            if (it.pinned) unpin(it.id);
        } else if (dropIdx >= 0) {
            const from = Settings.pinned.findIndex(p => Niri.appKey(p) === it.key);
            pin(it.id, from >= 0 && from < dropIdx ? dropIdx - 1 : dropIdx);
        }
        dragKey = "";
        dropIdx = -1;
        dropX = -1;
    }
}
