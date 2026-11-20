import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Left-edge dock: apps button, workspaces (vertical, like niri stacks them), pinned apps, then running ones.
// Auto-hides (smart, auto, or never; see Settings.dockMode).
// Left click focuses / launches / cycles windows, middle opens a new one, wheel cycles,
// drag reorders (drag right and off to unpin), right click opens DockMenu.
PanelWindow {
    id: root
    required property ShellScreen modelData
    screen: modelData

    readonly property int size: Settings.dockSize
    readonly property int pad: 8
    readonly property int gap: 8          // dock to screen edge
    readonly property int boxW: size + pad * 2
    readonly property int tipRoom: 260    // tooltip and magnify room to the right

    anchors { left: true; top: true; bottom: true }
    // Grows while dragging so a pulled-out icon is not clipped.
    implicitWidth: boxW + gap + tipRoom + (dragKey !== "" ? 120 : 0)
    color: "transparent"
    exclusionMode: Settings.dockMode === "always" ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: Settings.dockMode === "always" ? boxW + gap : 0
    WlrLayershell.namespace: "ansai-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ---- what is on the dock
    readonly property var wss: Niri.workspacesOn(modelData.name)
    readonly property var ws: wss.find(w => w.is_active) ?? null
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
    readonly property real boxRight: gap + boxW
    // niri lays tiled columns out from the left edge, so any tiled window covers the dock.
    readonly property bool covered: {
        if (!ws) return false;
        return Niri.windowsOn(ws.id).some(w => {
            if (!w.is_floating) return true;
            const p = w.layout?.tile_pos_in_workspace_view, s = w.layout?.tile_size;
            if (!p || !s) return true;
            return p[0] < boxRight && p[1] < box.y + box.height && p[1] + s[1] > box.y;
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
    Item { id: edge; x: 0; width: 2; y: box.y; height: box.height }
    Item { id: hit; x: 0; width: root.boxRight; y: box.y; height: box.height }

    BackgroundEffect.blurRegion: Region { item: Theme.m3 ? box : null; radius: box.radius + (Theme.m3 ? 0 : 8) }

    // ---- the dock
    Glass {
        id: box
        screenX: x
        screenY: y + root.screen.height - root.height
        width: root.boxW
        height: col.height + root.pad * 2
        x: root.revealed ? root.gap : -width - 2
        y: Math.max(root.gap, (root.height - height) / 2)
        radius: Theme.m3 ? width / 2 : Theme.rLg + 4
        Behavior on x { NumberAnimation { duration: Theme.med; easing.type: root.revealed ? Theme.spring : Theme.easing } }
        Behavior on height { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: m => root.openMenu(null, box.y + m.y)
        }

        Column {
            id: col
            y: root.pad
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            // Apps grid button
            Hover {
                width: root.size; height: root.size
                radius: Theme.m3 ? height / 2 : root.size * 0.258
                base: Theme.m3 ? Theme.accentSoft : Theme.fill2
                active: Shell.open === "launchpad"
                activeColor: Theme.accent
                onClicked: m => {
                    if (m.button === Qt.RightButton) root.openMenu(null, box.y + col.y + y + height / 2);
                    else Shell.toggle("launchpad");
                }
                Icon {
                    anchors.centerIn: parent
                    name: "apps"
                    size: root.size * 0.5
                    color: parent.active ? Theme.accentInk : Theme.m3 ? Theme.accentSoftInk : Theme.text
                }
            }

            // Workspaces, top to bottom like niri. Wheel moves between them.
            Rectangle {
                visible: root.wss.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.size * 0.62
                height: wsCol.height + 14
                radius: width / 2
                color: Theme.m3 ? Theme.tonal : Theme.fill2

                MouseArea {
                    anchors.fill: parent
                    onWheel: w => Niri.action(w.angleDelta.y > 0 ? "focus-workspace-up" : "focus-workspace-down")
                }

                Column {
                    id: wsCol
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                        model: root.wss
                        Hover {
                            id: wsb
                            required property var modelData
                            readonly property bool on: modelData.is_active
                            readonly property int count: Niri.windowsOn(modelData.id).length
                            width: root.size * 0.62 - 8
                            height: on ? 34 : 18
                            radius: width / 2
                            base: "transparent"
                            anchors.horizontalCenter: parent.horizontalCenter
                            Behavior on height { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                            onClicked: Niri.focusWorkspace(modelData)
                            Rectangle {
                                anchors.centerIn: parent
                                width: wsb.on ? parent.width - 6 : 8
                                height: wsb.on ? parent.height - 6 : 8
                                radius: width / 2
                                color: wsb.on ? Theme.accent : wsb.count > 0 ? (Theme.m3 ? Theme.tonalInk : Theme.muted) : Theme.faint
                                Behavior on height { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                                Behavior on color { ColorAnimation { duration: Theme.med } }
                                Txt {
                                    anchors.centerIn: parent
                                    visible: wsb.on
                                    text: wsb.modelData.idx
                                    font.pixelSize: 11
                                    font.weight: Theme.strong
                                    color: Theme.accentInk
                                }
                            }
                            Rectangle {   // tooltip
                                visible: wsb.hovered
                                x: parent.width + 18
                                anchors.verticalCenter: parent.verticalCenter
                                width: wsTip.implicitWidth + 20; height: 26
                                radius: Theme.m3 ? 13 : 8
                                color: Theme.m3 ? Theme.surface3 : Theme.dark ? "#2c2c2e" : "#ffffff"
                                border.width: Theme.m3 ? 0 : 1
                                border.color: Theme.glassLine
                                Txt {
                                    id: wsTip
                                    anchors.centerIn: parent
                                    text: (wsb.modelData.name || "Workspace " + wsb.modelData.idx) + (wsb.count ? `  ·  ${wsb.count}` : "  ·  empty")
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: root.size * 0.6; height: 1
                anchors.horizontalCenter: parent.horizontalCenter
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
            visible: root.dragKey !== "" && root.dropY >= 0
            y: root.dropY - box.y - 1
            x: root.pad
            width: root.size; height: 3
            radius: 1.5
            color: Theme.accent
        }
    }

    // ---- actions
    property real dropY: -1
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

    // y is in window coordinates; the window may start below the bar when it reserves space.
    function openMenu(it: var, y: real): void {
        Shell.dockItem = it;
        Shell.dockMenuY = y + root.screen.height - root.height;
        Shell.dockEdge = root.boxRight;
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
    function dragTo(cy: real): void {
        let best = -1, bestD = 1e9, by = -1;
        for (let i = 0; i < rep.count; i++) {
            const d = rep.itemAt(i);
            if (!d || !d.item.pinned) continue;
            const p = d.mapToItem(root.contentItem, 0, 0);
            for (const [slot, sy] of [[i, p.y - 3], [i + 1, p.y + d.height + 3]]) {
                const dist = Math.abs(cy - sy);
                if (dist < bestD) { bestD = dist; best = slot; by = sy; }
            }
        }
        if (best < 0) {
            const first = rep.itemAt(0);
            by = first ? first.mapToItem(root.contentItem, 0, 0).y - 3 : box.y + root.pad;
            best = 0;
        }
        dropIdx = best;
        dropY = by;
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
        dropY = -1;
    }
}
