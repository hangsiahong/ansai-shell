import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// macOS-style Launchpad: every app as a paged icon grid over the blurred desktop, with a search field.
// Click an app to open it (or switch to it if it's running), click empty space or Esc to close.
Sheet {
    id: root
    name: "launchpad"
    exclusiveKeys: true
    panelX: 0
    panelY: 0
    panelWidth: width
    panelHeight: height
    panelRadius: 0
    enterFrom: 0

    // Stay mapped while closed (invisible, clicks pass through) so the icons are already loaded when it opens.
    visible: true
    mask: shown ? null : noInput
    property Region noInput: Region {}

    property string query: ""
    property int page: 0

    onShownChanged: if (shown) { input.text = ""; page = 0; pages.off = 0; input.forceActiveFocus(); }

    // Tabs: the apps you use, everything, then one per category (an app goes in the first that fits).
    readonly property var cats: [
        { k: "Games", l: "Games", c: ["Game"] },
        { k: "Develop", l: "Develop", c: ["Development", "IDE"] },
        { k: "Graphics", l: "Graphics", c: ["Graphics", "Photography"] },
        { k: "Media", l: "Media", c: ["AudioVideo", "Audio", "Video"] },
        { k: "Office", l: "Office", c: ["Office"] },
        { k: "Internet", l: "Internet", c: ["Network", "WebBrowser", "Chat", "Email"] },
        { k: "Education", l: "Education", c: ["Education", "Science"] },
        { k: "Settings", l: "Settings", c: ["Settings", "DesktopSettings", "HardwareSettings"] },
        { k: "System", l: "System", c: ["System", "Monitor", "TerminalEmulator", "FileManager", "PackageManager"] },
        { k: "Utilities", l: "Utilities", c: ["Utility", "Accessories"] }
    ]
    function catOf(a): string {
        const have = a.categories ?? [];
        return cats.find(c => c.c.some(x => have.includes(x)))?.k ?? "Other";
    }
    readonly property var all: {
        const l = [];
        for (const a of DesktopEntries.applications.values)
            if (!a.noDisplay) l.push(a);
        l.sort((a, b) => a.name.localeCompare(b.name));
        return l;
    }
    // Opened from here or Search, pinned in the dock, or running now; most used first.
    readonly property var frequent: {
        const usage = Settings.usage ?? {};
        const pinned = (Settings.pinned ?? []).map(p => String(p).toLowerCase());
        const running = {};
        for (const w of Object.values(Niri.windows)) running[Niri.appKey(w.app_id)] = true;
        const id = a => a.id.toLowerCase();
        const l = all.filter(a => (usage[a.id] ?? 0) > 0 || pinned.includes(id(a)) || running[id(a)]);
        l.sort((a, b) => (usage[b.id] ?? 0) - (usage[a.id] ?? 0) || a.name.localeCompare(b.name));
        return l;
    }
    readonly property var tabs: {
        const n = {};
        for (const a of all) { const k = catOf(a); n[k] = (n[k] ?? 0) + 1; }
        const t = [];
        if (frequent.length) t.push({ k: "frequent", l: "Frequent", n: frequent.length });
        t.push({ k: "all", l: "All", n: all.length });
        for (const c of cats) if (n[c.k]) t.push({ k: c.k, l: c.l, n: n[c.k] });
        if (n.Other) t.push({ k: "Other", l: "Other", n: n.Other });
        return t;
    }
    readonly property string tab: tabs.some(t => t.k === Settings.padTab) ? Settings.padTab : tabs[0].k
    function setTab(k: string): void { Settings.padTab = k; go(0); }
    function stepTab(d: int): void {
        const i = tabs.findIndex(t => t.k === tab);
        setTab(tabs[(i + d + tabs.length) % tabs.length].k);
    }

    // Searching looks through every app, whatever the tab.
    readonly property var apps: {
        const q = query.trim().toLowerCase();
        if (!q) return tab === "frequent" ? frequent : tab === "all" ? all : all.filter(a => catOf(a) === tab);
        const l = all.filter(a => [a.name, a.genericName, (a.keywords ?? []).join(" ")].join(" ").toLowerCase().includes(q));
        const rank = a => a.name.toLowerCase().startsWith(q) ? 0 : a.name.toLowerCase().includes(q) ? 1 : 2;
        return l.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
    }

    readonly property int cellW: 132
    readonly property int cellH: 128
    readonly property int cols: Math.max(3, Math.min(8, Math.floor((width - 160) / cellW)))
    readonly property int rows: Math.max(2, Math.min(5, Math.floor((height - 250) / cellH)))
    readonly property int perPage: cols * rows
    readonly property int pageCount: Math.max(1, Math.ceil(apps.length / perPage))

    function launch(a): void {
        if (!a) return;
        const wins = Object.values(Niri.windows).filter(w => Niri.appKey(w.app_id) === a.id.toLowerCase())
            .sort((x, y) => Niri.stamp(y) - Niri.stamp(x));
        if (wins.length) Niri.focusWindow(wins[0].id);
        else {
            const u = Object.assign({}, Settings.usage ?? {});
            u[a.id] = (u[a.id] ?? 0) + 1;
            Settings.usage = u;
            a.execute();
        }
        Shell.close();
    }
    function go(p: int): void {
        page = Math.max(0, Math.min(pageCount - 1, p));
    }

    // Empty space closes, like macOS.
    MouseArea { anchors.fill: parent; onClicked: Shell.close() }

    Rectangle {
        id: field
        anchors.horizontalCenter: parent.horizontalCenter
        y: 48
        width: 260
        height: 34
        radius: height / 2
        color: Theme.m3 ? Theme.surface3 : Theme.fill
        border.width: Theme.m3 ? 0 : 1
        border.color: Theme.glassLine

        Icon {
            id: si
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: 18
            color: Theme.muted
        }
        TextInput {
            id: input
            anchors { left: si.right; leftMargin: 6; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 15
            selectionColor: Theme.accentSoft
            clip: true
            focus: true
            onTextChanged: { root.query = text; root.go(0); }
            Keys.onEscapePressed: text ? (text = "") : Shell.close()
            Keys.onReturnPressed: root.launch(root.apps[0])
            Keys.onEnterPressed: root.launch(root.apps[0])
            Keys.onLeftPressed: e => { if (!text) root.go(root.page - 1); else e.accepted = false; }
            Keys.onRightPressed: e => { if (!text) root.go(root.page + 1); else e.accepted = false; }
            Keys.onPressed: e => {
                if (e.key === Qt.Key_PageDown) root.go(root.page + 1);
                else if (e.key === Qt.Key_PageUp) root.go(root.page - 1);
                else if (e.key === Qt.Key_Tab) root.stepTab(1);
                else if (e.key === Qt.Key_Backtab) root.stepTab(-1);
                else return;
                e.accepted = true;
            }
            Txt {
                anchors.verticalCenter: parent.verticalCenter
                visible: !input.text
                text: "Search"
                color: Theme.faint
                font.pixelSize: 15
            }
        }
    }

    // Category tabs; hidden while searching, since search covers every app.
    Row {
        id: chips
        anchors { top: field.bottom; topMargin: 18; horizontalCenter: parent.horizontalCenter }
        spacing: 6
        opacity: root.query.trim() ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        Repeater {
            model: root.tabs
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: modelData.k === root.tab && !root.query.trim()
                width: chipTxt.implicitWidth + 24
                height: 28
                radius: 14
                color: on ? Theme.accent : chipMa.containsMouse ? Theme.fill : "transparent"
                Txt {
                    id: chipTxt
                    anchors.centerIn: parent
                    text: chip.modelData.l
                    font.pixelSize: 13
                    font.weight: chip.on ? Theme.strong : Font.Normal
                    color: chip.on ? Theme.accentInk : Theme.text
                }
                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { input.text = ""; root.setTab(chip.modelData.k); }
                }
            }
        }
    }

    // Pages sit side by side; `off` is how far a swipe or drag has moved them from the current page.
    Item {
        id: pages
        anchors { top: chips.bottom; topMargin: 28; bottom: dots.top; bottomMargin: 20; horizontalCenter: parent.horizontalCenter }
        width: root.cols * root.cellW
        clip: true
        property real off: 0
        property bool moving: false
        property real acc: 0

        // Lifted fingers: settle on the page the swipe pointed at.
        function settle(): void {
            const t = width * 0.12;
            const p = off < -t ? root.page + 1 : off > t ? root.page - 1 : root.page;
            moving = false;
            off = 0;
            root.go(p);
        }
        Timer { id: idle; interval: 120; onTriggered: pages.settle() }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: w => {
                const px = w.pixelDelta;
                if (px.x !== 0 || px.y !== 0) {
                    // Touchpad: the grid follows the fingers, either direction works.
                    const d = Math.abs(px.x) >= Math.abs(px.y) ? px.x : px.y;
                    pages.moving = true;
                    const lo = root.page >= root.pageCount - 1 ? -pages.width * 0.15 : -pages.width;
                    const hi = root.page <= 0 ? pages.width * 0.15 : pages.width;
                    pages.off = Math.max(lo, Math.min(hi, pages.off + d));
                    idle.restart();
                } else {
                    // Mouse wheel: one notch flips a page.
                    pages.acc += w.angleDelta.y !== 0 ? -w.angleDelta.y : -w.angleDelta.x;
                    if (Math.abs(pages.acc) >= 120) { root.go(root.page + (pages.acc > 0 ? 1 : -1)); pages.acc = 0; }
                }
            }
        }
        // Click-and-drag also flips pages.
        DragHandler {
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onActiveTranslationChanged: if (active) { pages.moving = true; pages.off = activeTranslation.x; }
            onActiveChanged: if (!active) pages.settle()
        }

        Row {
            x: -root.page * pages.width + pages.off
            Behavior on x { enabled: !pages.moving; NumberAnimation { duration: Theme.med * 1.6; easing.type: Easing.OutCubic } }
            Repeater {
                model: root.pageCount
        delegate: Item {
            id: pg
            required property int index
            width: pages.width
            height: pages.height

            MouseArea { anchors.fill: parent; onClicked: Shell.close() }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: root.cols
                Repeater {
                    model: root.apps.slice(pg.index * root.perPage, (pg.index + 1) * root.perPage)
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool first: pg.index === 0 && index === 0 && root.query.trim() !== ""
                        width: root.cellW
                        height: root.cellH

                        Rectangle {
                            anchors.centerIn: parent
                            width: root.cellW - 12
                            height: root.cellH - 8
                            radius: 18
                            color: cell.first ? Theme.fill : "transparent"
                        }
                        AppIcon {
                            id: ic
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            size: 72
                            icon: cell.modelData.icon
                            label: cell.modelData.name
                            scale: ma.pressed ? 0.9 : ma.containsMouse ? 1.06 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast } }
                        }
                        Txt {
                            anchors { top: ic.bottom; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                            width: root.cellW - 16
                            horizontalAlignment: Text.AlignHCenter
                            text: cell.modelData.name
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            color: Theme.text
                            style: Theme.m3 ? Text.Normal : Text.Raised
                            styleColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.35 : 0)
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launch(cell.modelData)
                        }
                    }
                }
            }
        }
        }
        }
    }

    Txt {
        anchors.centerIn: pages
        visible: root.apps.length === 0
        text: "No apps match “" + root.query.trim() + "”"
        color: Theme.muted
        font.pixelSize: 15
    }

    Row {
        id: dots
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
        spacing: 10
        visible: root.pageCount > 1
        height: 10
        Repeater {
            model: root.pageCount
            delegate: Rectangle {
                required property int index
                width: 8; height: 8; radius: 4
                color: Theme.text
                opacity: index === root.page ? 0.9 : 0.3
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.go(parent.index) }
            }
        }
    }
}
