import QtQuick
import Quickshell
import qs
import qs.services

// The current workspace's columns, left to right like niri scrolls them. Click focuses, wheel scrolls,
// drag a pill sideways to move that app's column to another spot.
Rectangle {
    id: root
    required property string output

    readonly property var ws: Niri.workspacesOn(output).find(w => w.is_active) ?? null
    // [{ idx, wins: [...] }] by column, tiled windows only.
    readonly property var cols: {
        if (!ws) return [];
        const by = {};
        for (const w of Niri.windowsOn(ws.id)) {
            const p = w.layout?.pos_in_scrolling_layout;
            if (w.is_floating || !p) continue;
            (by[p[0]] = by[p[0]] ?? []).push(w);
        }
        return Object.keys(by).map(Number).sort((a, b) => a - b)
            .map(i => ({ idx: i, wins: by[i].sort((a, b) => a.layout.pos_in_scrolling_layout[1] - b.layout.pos_in_scrolling_layout[1]) }));
    }

    property int dragFrom: -1   // index into cols
    property int dropAt: -1

    visible: cols.length > 0
    implicitWidth: row.implicitWidth + 8
    // ansai: no capsule, just app icons in the menu bar; the active one sits in a soft pill with its name.
    implicitHeight: Theme.m3 ? 32 : Theme.barH - 4
    radius: height / 2
    color: Theme.m3 ? Theme.tonal : "transparent"

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => Niri.action((e.angleDelta.y || -e.angleDelta.x) > 0 ? "focus-column-left" : "focus-column-right")
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            id: rep
            model: root.cols
            Rectangle {
                id: pill
                required property var modelData
                required property int index
                readonly property var win: modelData.wins.find(w => w.id === Niri.focusedWindowId) ?? modelData.wins[0]
                readonly property bool on: modelData.wins.some(w => w.id === Niri.focusedWindowId)
                readonly property string name: DesktopEntries.heuristicLookup(win.app_id)?.name ?? (win.app_id ?? "").split(".").pop()
                readonly property bool dragged: root.dragFrom === index

                height: root.height - (Theme.m3 ? 6 : 0)
                width: on ? Math.min(180, label.implicitWidth + height + 14) : height + (modelData.wins.length > 1 ? 8 : 0)
                radius: height / 2
                color: on ? (Theme.m3 ? Theme.accent : Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.08)) : ma.containsMouse ? Theme.hover : "transparent"
                z: dragged ? 2 : 0
                opacity: dragged ? 0.85 : 1
                Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                transform: Translate { x: pill.dragged ? ma.dx : 0 }

                // Drop marker
                Rectangle {
                    visible: root.dragFrom >= 0 && root.dropAt === pill.index && root.dragFrom !== pill.index
                    x: root.dropAt < root.dragFrom ? -3 : parent.width + 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2; height: parent.height + 4; radius: 1
                    color: Theme.accent
                }

                AppIcon {
                    id: ic
                    x: (pill.height - size) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    size: pill.height - (Theme.m3 ? 8 : 6)
                    opacity: pill.on || Theme.m3 ? 1 : 0.8
                    icon: DesktopEntries.heuristicLookup(pill.win.app_id)?.icon ?? pill.win.app_id ?? ""
                    label: pill.name
                }
                // Stacked windows in this column
                Text {
                    visible: !pill.on && pill.modelData.wins.length > 1
                    anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                    text: pill.modelData.wins.length
                    font.pixelSize: 9; font.weight: Font.Bold
                    color: Theme.muted
                }
                Txt {
                    id: label
                    visible: pill.on
                    anchors { left: ic.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    width: Math.min(implicitWidth, 180 - pill.height - 14)
                    text: pill.name
                    font.pixelSize: 12
                    font.weight: Theme.strong
                    color: Theme.m3 ? Theme.accentInk : Theme.text
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.dragFrom >= 0 ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    property real px: 0
                    property real dx: 0
                    onPressed: m => { px = m.x; dx = 0; }
                    onPositionChanged: m => {
                        if (!(pressedButtons & Qt.LeftButton)) return;
                        dx = m.x - px;
                        if (root.dragFrom < 0 && Math.abs(dx) < 6) return;
                        root.dragFrom = pill.index;
                        // Nearest slot by centre
                        const cx = pill.mapToItem(row, pill.width / 2 + dx, 0).x;
                        let best = pill.index, bd = 1e9;
                        for (let i = 0; i < rep.count; i++) {
                            const it = rep.itemAt(i);
                            const d = Math.abs(it.x + it.width / 2 - cx);
                            if (d < bd) { bd = d; best = i; }
                        }
                        root.dropAt = best;
                    }
                    onReleased: {
                        if (root.dragFrom >= 0) {
                            const to = root.dropAt, from = root.dragFrom;
                            root.dragFrom = -1; root.dropAt = -1; dx = 0;
                            if (to >= 0 && to !== from)
                                Quickshell.execDetached(["sh", "-c", `niri msg action focus-window --id ${pill.win.id} && niri msg action move-column-to-index ${root.cols[to].idx}`]);
                        }
                    }
                    onClicked: m => {
                        if (Math.abs(dx) >= 6) return;
                        if (m.button === Qt.MiddleButton) Niri.closeWindow(pill.win.id);
                        else Niri.focusWindow(pill.win.id);
                    }
                }

                // Tooltip with all windows in the column
                Rectangle {
                    visible: ma.containsMouse && root.dragFrom < 0
                    y: parent.height + 10
                    x: (parent.width - width) / 2
                    width: Math.min(360, tip.implicitWidth + 20); height: 26
                    radius: Theme.m3 ? 13 : 8
                    color: Theme.m3 ? Theme.surface3 : Theme.dark ? "#2c2c2e" : "#ffffff"
                    border.width: Theme.m3 ? 0 : 1
                    border.color: Theme.glassLine
                    Txt {
                        id: tip
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 340)
                        text: pill.modelData.wins.map(w => w.title || pill.name).join("  ·  ")
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
