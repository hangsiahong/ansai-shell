import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Spotlight-style palette, like the web app's "Search or run…" (Ctrl K).
// Open windows first, then apps ranked by match + launch count.
// "> cmd" runs a shell command, "= expr" evaluates math.
Sheet {
    id: root
    name: "launcher"
    exclusiveKeys: true
    panelWidth: Math.min(Theme.m3 ? 640 : 680, width - 32)
    panelHeight: (Theme.m3 ? 64 : 60) + Math.min(results.count, 8) * 52 + (results.count > 0 ? 16 : 0)
    panelY: height * (Theme.m3 ? 0.18 : 0.24)
    // ansai: macOS Spotlight, a full pill until results open it into a rounded panel.
    panelRadius: Theme.m3 ? 28 : results.count > 0 ? 26 : 30

    property string query: ""
    property int sel: 0

    onShownChanged: if (shown) { query = ""; input.text = ""; sel = 0; input.forceActiveFocus(); }

    readonly property var items: {
        const q = query.trim().toLowerCase();
        if (q.startsWith(">")) {
            const cmd = query.trim().slice(1).trim();
            return cmd ? [{ kind: "run", title: cmd, sub: "Run in terminal", icon: "terminal" }] : [];
        }
        if (q.startsWith("=")) {
            let val = "";
            try {
                const expr = q.slice(1).replace(/[^0-9+\-*/().% ^]/g, "").replace(/\^/g, "**");
                val = expr ? String(Function("return (" + expr + ")")()) : "";
            } catch (e) {}
            return val ? [{ kind: "calc", title: val, sub: "Copy result", icon: "calculate" }] : [];
        }

        // ansai: like macOS search, nothing below the field until you type.
        if (!q && !Theme.m3) return [];
        const out = [];
        const score = (name, extra) => {
            if (!q) return 1;
            const n = name.toLowerCase();
            if (n.startsWith(q)) return 100;
            if (n.split(/[\s\-_.]/).some(w => w.startsWith(q))) return 70;
            if (n.includes(q)) return 50;
            if (extra && extra.toLowerCase().includes(q)) return 20;
            return 0;
        };

        // Running apps: Enter switches to their most recent window instead of starting another copy.
        const running = {};
        for (const w of Object.values(Niri.windows)) {
            const k = Niri.appKey(w.app_id);
            (running[k] = running[k] ?? []).push(w);
        }
        for (const k in running)
            running[k].sort((a, b) => Niri.stamp(b) - Niri.stamp(a));

        const usage = Settings.usage ?? {};
        const shown = {};
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue;
            const s = score(a.name, [a.genericName, a.comment, (a.keywords ?? []).join(" ")].join(" "));
            if (s <= 0) continue;
            const wins = running[a.id.toLowerCase()] ?? [];
            if (wins.length) shown[a.id.toLowerCase()] = true;
            out.push({
                kind: "app", entry: a, title: a.name, app: a.icon, wins: wins,
                sub: wins.length ? `Open · switch to ${wins.length > 1 ? "last of " + wins.length + " windows" : "window"}  (Shift+Enter: new window)` : a.genericName || a.comment || "",
                s: s + Math.min(30, (usage[a.id] ?? 0) * 3) + (wins.length ? 15 : 0)
            });
        }

        // Individual windows by title; skip ones whose app already matched above unless the title itself matches.
        for (const w of Object.values(Niri.windows)) {
            const titleS = score(w.title ?? "", "");
            const s = titleS || score("", w.app_id ?? "");
            if (!q || s <= 0 || (!titleS && shown[Niri.appKey(w.app_id)])) continue;
            out.push({ kind: "win", id: w.id, title: w.title, sub: "Open window · " + (DesktopEntries.heuristicLookup(w.app_id)?.name ?? w.app_id ?? ""), app: w.app_id, s: s + 5 });
        }
        out.sort((a, b) => b.s - a.s || a.title.localeCompare(b.title));
        return out.slice(0, 40);
    }

    function activate(i: int, fresh: bool): void {
        const it = items[i];
        if (!it) return;
        if (it.kind === "app" && it.wins.length && !fresh) {
            Niri.focusWindow(it.wins[0].id);
        } else if (it.kind === "app") {
            const u = Object.assign({}, Settings.usage ?? {});
            u[it.entry.id] = (u[it.entry.id] ?? 0) + 1;
            Settings.usage = u;
            it.entry.execute();
        } else if (it.kind === "win") {
            Niri.focusWindow(it.id);
        } else if (it.kind === "run") {
            Quickshell.execDetached([Settings.terminal, "-e", "sh", "-c", it.title + "; exec $SHELL"]);
        } else if (it.kind === "calc") {
            Quickshell.execDetached(["wl-copy", it.title]);
        }
        Shell.close();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.m3 ? 56 : 44
            radius: height / 2
            color: Theme.m3 ? Theme.surface3 : "transparent"

            Icon {
                id: searchIcon
                x: Theme.m3 ? 18 : 10
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: Theme.m3 ? 22 : 24
                color: Theme.m3 ? Theme.text2 : Theme.muted
            }

            TextInput {
                id: input
                anchors { left: searchIcon.right; leftMargin: 10; right: hint.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.m3 ? 19 : 22
                selectionColor: Theme.accentSoft
                selectedTextColor: Theme.text
                clip: true
                focus: true
                onTextChanged: { root.query = text; root.sel = 0; }

                Keys.onEscapePressed: Shell.close()
                Keys.onReturnPressed: e => root.activate(root.sel, !!(e.modifiers & Qt.ShiftModifier))
                Keys.onEnterPressed: e => root.activate(root.sel, !!(e.modifiers & Qt.ShiftModifier))
                Keys.onDownPressed: root.sel = Math.min(root.items.length - 1, root.sel + 1)
                Keys.onUpPressed: root.sel = Math.max(0, root.sel - 1)
                Keys.onTabPressed: root.sel = (root.sel + 1) % Math.max(1, root.items.length)

                Txt {
                    anchors.fill: parent
                    visible: !input.text
                    text: Theme.m3 ? "Search or run…" : "Search apps and windows"
                    color: Theme.faint
                    font.pixelSize: Theme.m3 ? 19 : 22
                }
            }

            Rectangle {
                id: hint
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: hintTxt.implicitWidth + 12
                height: 22
                radius: Theme.m3 ? 11 : 6
                color: "transparent"
                border.width: Theme.m3 ? 0 : 1
                border.color: Theme.line
                Txt { id: hintTxt; anchors.centerIn: parent; text: "esc"; font.pixelSize: 11; color: Theme.muted }
            }
        }

        ListView {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.items
            clip: true
            spacing: 2
            currentIndex: root.sel
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Hover {
                id: row
                required property var modelData
                required property int index
                width: results.width
                height: Theme.m3 ? 52 : 50
                radius: Theme.m3 ? height / 2 : 12
                active: index === root.sel
                activeColor: Theme.m3 ? Theme.accentSoft : Theme.accent
                readonly property color ink: Theme.m3 ? Theme.accentSoftInk : Theme.accentInk
                onClicked: m => root.activate(index, m.button === Qt.MiddleButton || !!(m.modifiers & Qt.ShiftModifier))
                onHoveredChanged: if (hovered) root.sel = index

                Item {
                    id: ic
                    x: Theme.m3 ? 12 : 10
                    width: 32; height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    AppIcon {
                        anchors.fill: parent
                        visible: row.modelData.kind === "app" || row.modelData.kind === "win"
                        icon: row.modelData.kind === "win" ? (DesktopEntries.heuristicLookup(row.modelData.app)?.icon ?? row.modelData.app ?? "") : (row.modelData.app ?? "")
                        label: row.modelData.title
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: !(row.modelData.kind === "app" || row.modelData.kind === "win")
                        radius: Theme.m3 ? 16 : 8
                        color: Theme.m3 ? Theme.tonal : Theme.surface3
                        Icon { anchors.centerIn: parent; name: row.modelData.icon ?? ""; size: 20 }
                    }
                }

                Column {
                    anchors { left: ic.right; leftMargin: 12; right: badge.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 1
                    Txt {
                        width: parent.width
                        text: row.modelData.title
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        color: row.active ? row.ink : Theme.text
                    }
                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.sub
                        font.pixelSize: 12
                        color: row.active ? Qt.rgba(row.ink.r, row.ink.g, row.ink.b, 0.75) : Theme.muted
                    }
                }

                Txt {
                    id: badge
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    visible: row.active
                    text: "↵"
                    font.pixelSize: 15
                    color: row.ink
                }
            }
        }
    }
}
