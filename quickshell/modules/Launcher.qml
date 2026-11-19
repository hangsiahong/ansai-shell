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
    panelWidth: Math.min(640, width - 32)
    panelHeight: 64 + Math.min(results.count, 8) * 52 + (results.count > 0 ? 16 : 0)
    panelY: height * 0.18
    panelRadius: 22

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

        for (const w of Object.values(Niri.windows)) {
            const s = score(w.title ?? "", w.app_id ?? "");
            if (q && s > 0)
                out.push({ kind: "win", id: w.id, title: w.title, sub: "Open window · " + (w.app_id ?? ""), app: w.app_id, s: s + 5 });
        }

        const usage = Settings.usage ?? {};
        for (const a of DesktopEntries.applications.values) {
            if (a.noDisplay) continue;
            const s = score(a.name, [a.genericName, a.comment, (a.keywords ?? []).join(" ")].join(" "));
            if (s > 0)
                out.push({ kind: "app", entry: a, title: a.name, sub: a.genericName || a.comment || "", app: a.icon, s: s + Math.min(30, (usage[a.id] ?? 0) * 3) });
        }
        out.sort((a, b) => b.s - a.s || a.title.localeCompare(b.title));
        return out.slice(0, 40);
    }

    function activate(i: int): void {
        const it = items[i];
        if (!it) return;
        if (it.kind === "app") {
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
            Layout.preferredHeight: 48
            radius: 14
            color: Theme.fill2

            Icon {
                id: searchIcon
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 22
                color: Theme.muted
            }

            TextInput {
                id: input
                anchors { left: searchIcon.right; leftMargin: 10; right: hint.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 19
                selectionColor: Theme.accentSoft
                selectedTextColor: Theme.text
                clip: true
                focus: true
                onTextChanged: { root.query = text; root.sel = 0; }

                Keys.onEscapePressed: Shell.close()
                Keys.onReturnPressed: root.activate(root.sel)
                Keys.onEnterPressed: root.activate(root.sel)
                Keys.onDownPressed: root.sel = Math.min(root.items.length - 1, root.sel + 1)
                Keys.onUpPressed: root.sel = Math.max(0, root.sel - 1)
                Keys.onTabPressed: root.sel = (root.sel + 1) % Math.max(1, root.items.length)

                Txt {
                    anchors.fill: parent
                    visible: !input.text
                    text: "Search or run…"
                    color: Theme.faint
                    font.pixelSize: 19
                }
            }

            Rectangle {
                id: hint
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: hintTxt.implicitWidth + 12
                height: 22
                radius: 6
                color: "transparent"
                border.width: 1
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
                height: 50
                radius: 12
                active: index === root.sel
                activeColor: Theme.accent
                onClicked: root.activate(index)
                onHoveredChanged: if (hovered) root.sel = index

                Item {
                    id: ic
                    x: 10
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
                        radius: 8
                        color: Theme.surface3
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
                        color: row.active ? Theme.accentInk : Theme.text
                    }
                    Txt {
                        width: parent.width
                        visible: text !== ""
                        text: row.modelData.sub
                        font.pixelSize: 12
                        color: row.active ? Qt.rgba(1, 1, 1, 0.75) : Theme.muted
                    }
                }

                Txt {
                    id: badge
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    visible: row.active
                    text: "↵"
                    font.pixelSize: 15
                    color: Theme.accentInk
                }
            }
        }
    }
}
